import Foundation

/// 專為 Apple Watch 生態系與 HealthKit 光學傳感器打造之穩健生理指標引擎 (AppleWatchBiomarkerEngine)
public struct AppleWatchBiomarkerEngine: Sendable {

    public struct Configuration: Sendable {
        public let baselineWindowDays: Int
        public let minimumBaselineSamples: Int
        public let madConsistencyConstant: Double
        public let lnHRVNoiseFloor: Double
        public let rhrNoiseFloorBpm: Double
        public let rhrWarningDeltaBpm: Double
        public let respRateWarningDeltaRpm: Double
        public let lutealRHRShiftBpm: Double
        public let lutealRespShiftRpm: Double
        public let minimumNightlySDNNSamples: Int

        public init(
            baselineWindowDays: Int = 28,
            minimumBaselineSamples: Int = 14,
            madConsistencyConstant: Double = 1.4826,
            lnHRVNoiseFloor: Double = 0.05,
            rhrNoiseFloorBpm: Double = 2.0,
            rhrWarningDeltaBpm: Double = 3.0,
            respRateWarningDeltaRpm: Double = 2.0,
            lutealRHRShiftBpm: Double = 2.5,
            lutealRespShiftRpm: Double = 0.5,
            minimumNightlySDNNSamples: Int = 3
        ) {
            self.baselineWindowDays = baselineWindowDays
            self.minimumBaselineSamples = minimumBaselineSamples
            self.madConsistencyConstant = madConsistencyConstant
            self.lnHRVNoiseFloor = lnHRVNoiseFloor
            self.rhrNoiseFloorBpm = rhrNoiseFloorBpm
            self.rhrWarningDeltaBpm = rhrWarningDeltaBpm
            self.respRateWarningDeltaRpm = respRateWarningDeltaRpm
            self.lutealRHRShiftBpm = lutealRHRShiftBpm
            self.lutealRespShiftRpm = lutealRespShiftRpm
            self.minimumNightlySDNNSamples = minimumNightlySDNNSamples
        }
    }

    public let config: Configuration

    public init(configuration: Configuration = .init()) {
        self.config = configuration
    }

    /// 計算單夜對數轉換後之穩健 ln(SDNN) 中位數
    /// 先取 ln 再取中位數（幾何平均），並嚴格過濾光學偽影離群值 (< 5.0ms 或 > 350.0ms)
    /// 若有效夜間樣本少於 3 筆，回傳 nil 以免少數噪聲拉偏結果
    public func computeNightlyLnHRV(from sdnnSamplesMs: [Double]) -> Double? {
        let valid = sdnnSamplesMs.filter { $0 >= 5.0 && $0 <= 350.0 }
        guard valid.count >= config.minimumNightlySDNNSamples else {
            return nil
        }
        let logs = valid.map { log($0) }
        return Self.median(of: logs)
    }

    /// 核心評估純函數：輸入今日指標與過去至多 28 天之歷史樣本
    public func evaluate(
        today: NightlyBiomarkerSample,
        history28d: [NightlyBiomarkerSample]
    ) -> BiomarkerOutcome {
        let dayKey = TrainingDayKey(date: today.date)

        // 1. 疾病一票否決 (Illness Gate)
        if today.confounders.contains(.illness) {
            let assessment = ReadinessAssessment(
                dayKey: dayKey,
                score: 30,
                zone: .protectiveLockdown,
                autonomic: .sympatheticOverload,
                confidence: .high,
                sleepStatus: today.sleepSyncStatus,
                lnHRVZScore: nil,
                consecutiveElevatedRHRDays: 0,
                consecutiveElevatedRespRateDays: 0,
                respiratoryWarningTriggered: true,
                revision: 1,
                diagnosticMessages: ["身體微恙或生病，啟動傷病保護鎖定，今日不進行大重量或高心率訓練。"]
            )
            return .assessed(assessment)
        }

        // 2. 構建乾淨的 28 天基準池 (Baseline Reference Pool Masking)
        // 排除酒精日與感冒日，避免宿醉與感染極端值永久墊高/拉低基準線
        let cleanHistory = history28d.filter { sample in
            !sample.confounders.contains(.alcohol) && !sample.confounders.contains(.illness)
        }

        // 3. 檢查有效基準樣本數 (Cold Start Gate)
        if cleanHistory.count < config.minimumBaselineSamples {
            return .calibrating(cleanDays: cleanHistory.count, partial: nil)
        }

        let historicalLnHRVs = cleanHistory.compactMap { computeNightlyLnHRV(from: $0.nightlySDNNValuesMs) }
        let historicalRHRs = cleanHistory.compactMap { normalizedRHR(for: $0) }
        let historicalRespRates = cleanHistory.compactMap { normalizedRespRate(for: $0) }

        // 4. 今日指標正規化
        let todayLnHRV = computeNightlyLnHRV(from: today.nightlySDNNValuesMs)
        let todayNormRHR = normalizedRHR(for: today)
        let todayNormResp = normalizedRespRate(for: today)

        // 5. 具備物理底噪保護 (σ_min) 之穩健 Z-Score
        let lnHRVZScore: Double? = {
            guard let current = todayLnHRV,
                  !historicalLnHRVs.isEmpty,
                  let med = Self.median(of: historicalLnHRVs),
                  let mad = Self.mad(of: historicalLnHRVs, median: med) else {
                return nil
            }
            let scale = max(config.madConsistencyConstant * mad, config.lnHRVNoiseFloor)
            return (current - med) / scale
        }()

        // 6. 連續 2 日 RHR 與呼吸率噪聲過濾檢查
        let rhrMedian = Self.median(of: historicalRHRs)
        let respMedian = Self.median(of: historicalRespRates)

        let sortedRecent = (history28d.sorted { $0.date < $1.date }.suffix(3)) + [today]
        let consecutiveRHRDays = countConsecutiveElevatedDays(
            samples: Array(sortedRecent),
            baselineMedian: rhrMedian,
            thresholdDelta: config.rhrWarningDeltaBpm,
            extractor: { normalizedRHR(for: $0) }
        )

        let consecutiveRespDays = countConsecutiveElevatedDays(
            samples: Array(sortedRecent),
            baselineMedian: respMedian,
            thresholdDelta: config.respRateWarningDeltaRpm,
            extractor: { normalizedRespRate(for: $0) }
        )

        let respWarning = consecutiveRespDays >= 2 && (consecutiveRHRDays >= 1 || (todayNormRHR ?? 0) > (rhrMedian ?? 999) + config.rhrNoiseFloorBpm)

        // 7. 自主神經狀態判定
        let autonomic: AutonomicState
        if today.confounders.contains(.alcohol) {
            autonomic = .metabolicallyConfounded
        } else if let z = lnHRVZScore {
            if z < -1.5 {
                autonomic = .sympatheticOverload
            } else if z > 2.0 && (consecutiveRHRDays >= 1 || consecutiveRespDays >= 1) {
                // 副交感假性過度亢進 (伴隨心率或呼吸率異常)
                autonomic = .parasympatheticHyperactivity
            } else {
                autonomic = .balanced
            }
        } else {
            autonomic = .balanced
        }

        // 8. 非線性綜合評估分數 (0~100)
        let (score, zone) = calculateScoreAndZone(
            lnHRVZScore: lnHRVZScore,
            consecutiveRHRDays: consecutiveRHRDays,
            consecutiveRespDays: consecutiveRespDays,
            respWarning: respWarning,
            today: today,
            autonomic: autonomic
        )

        let confidence: MetricConfidence
        if today.sleepSyncStatus == .finalized && lnHRVZScore != nil {
            confidence = .high
        } else if today.sleepSyncStatus == .durationOnly {
            confidence = .medium
        } else {
            confidence = .low
        }

        var diagnostics: [String] = []
        if consecutiveRHRDays >= 2 {
            diagnostics.append("靜息心率連續2天高於基準線 3 bpm 以上，提示潛在疲勞積累。")
        }
        if respWarning {
            diagnostics.append("睡眠呼吸率與靜息心率出現同步抬升，請注意身體免疫與修復狀態。")
        }
        if today.sleepSyncStatus == .durationOnly {
            diagnostics.append("Apple Watch 睡眠分期同步中，目前先以睡眠總時數給出基礎評估。")
        }

        let assessment = ReadinessAssessment(
            dayKey: dayKey,
            score: score,
            zone: zone,
            autonomic: autonomic,
            confidence: confidence,
            sleepStatus: today.sleepSyncStatus,
            lnHRVZScore: lnHRVZScore,
            consecutiveElevatedRHRDays: consecutiveRHRDays,
            consecutiveElevatedRespRateDays: consecutiveRespDays,
            respiratoryWarningTriggered: respWarning,
            revision: today.sleepSyncStatus == .durationOnly ? 1 : 2,
            diagnosticMessages: diagnostics
        )

        return .assessed(assessment)
    }

    // MARK: - Private Helpers

    private func normalizedRHR(for sample: NightlyBiomarkerSample) -> Double? {
        guard let rhr = sample.nocturnalSleepingHeartRateBpm ?? sample.morningRestingHRBpm else { return nil }
        return sample.confounders.contains(.lutealPhase) ? (rhr - config.lutealRHRShiftBpm) : rhr
    }

    private func normalizedRespRate(for sample: NightlyBiomarkerSample) -> Double? {
        guard let resp = sample.sleepingRespiratoryRateRpm else { return nil }
        return sample.confounders.contains(.lutealPhase) ? (resp - config.lutealRespShiftRpm) : resp
    }

    private func countConsecutiveElevatedDays(
        samples: [NightlyBiomarkerSample],
        baselineMedian: Double?,
        thresholdDelta: Double,
        extractor: (NightlyBiomarkerSample) -> Double?
    ) -> Int {
        guard let baseline = baselineMedian else { return 0 }
        var streak = 0
        for sample in samples.reversed() {
            if sample.confounders.contains(.alcohol) { break }
            guard let val = extractor(sample), (val - baseline) >= thresholdDelta else { break }
            streak += 1
        }
        return streak
    }

    private func calculateScoreAndZone(
        lnHRVZScore: Double?,
        consecutiveRHRDays: Int,
        consecutiveRespDays: Int,
        respWarning: Bool,
        today: NightlyBiomarkerSample,
        autonomic: AutonomicState
    ) -> (Int, ReadinessZone) {
        var baseScore = 75.0

        // HRV 貢獻 (-20 ~ +15)
        if let z = lnHRVZScore {
            let clampedZ = max(-2.5, min(2.0, z))
            baseScore += clampedZ * 8.0
        }

        // 睡眠長度修復貢獻
        let sleepHours = today.totalSleepDurationSeconds / 3600.0
        if sleepHours >= 7.5 {
            baseScore += 5.0
        } else if sleepHours < 6.0 {
            baseScore -= 12.0
        }

        // 睡眠分期 (深睡 SWS 權重)
        if let deep = today.deepSleepSeconds {
            let deepHours = deep / 3600.0
            if deepHours >= 1.2 {
                baseScore += 4.0
            } else if deepHours < 0.6 {
                baseScore -= 6.0
            }
        }

        // 連續升溫扣分
        if consecutiveRHRDays >= 2 {
            baseScore -= 18.0
        } else if consecutiveRHRDays == 1 {
            // 單日升高僅微調
            baseScore -= 4.0
        }

        if respWarning {
            baseScore -= 15.0
        }

        if autonomic == .parasympatheticHyperactivity {
            baseScore -= 12.0
        }

        let clampedScore = max(10, min(98, Int(baseScore.rounded())))

        let zone: ReadinessZone
        if clampedScore >= 80 && consecutiveRHRDays < 2 {
            zone = .ready
        } else if clampedScore >= 60 && consecutiveRHRDays < 2 {
            zone = .steady
        } else if clampedScore >= 35 || consecutiveRHRDays >= 2 {
            zone = .overreached
        } else {
            zone = .protectiveLockdown
        }

        return (clampedScore, zone)
    }

    // MARK: - Statistical Utilities

    public static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        } else {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        }
    }

    public static func mad(of values: [Double], median: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let absoluteDeviations = values.map { abs($0 - median) }
        return self.median(of: absoluteDeviations)
    }
}
