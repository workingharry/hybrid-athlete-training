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
        public let lutealTempShiftCelsius: Double
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
            lutealTempShiftCelsius: Double = 0.35,
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
            self.lutealTempShiftCelsius = lutealTempShiftCelsius
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
                wristTemperatureBaselineDeltaCelsius: today.wristTemperatureBaselineDeltaCelsius,
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
        let historicalTemps = cleanHistory.compactMap { normalizedTemp(for: $0) }

        // 4. 今日指標正規化
        let todayLnHRV = computeNightlyLnHRV(from: today.nightlySDNNValuesMs)
        let todayNormRHR = normalizedRHR(for: today)
        let todayNormTemp = normalizedTemp(for: today)

        // 5. 具備物理底噪保護 (σ_min) 之穩健 Z-Score (使用 PersonalBaseline.robustZ)
        let lnHRVZScore: Double? = {
            guard let current = todayLnHRV, !historicalLnHRVs.isEmpty else { return nil }
            let res = PersonalBaseline.robustZ(today: current, history: historicalLnHRVs, minDays: config.minimumBaselineSamples)
            return res.isReliable ? res.z : nil
        }()

        let tempZScore: Double? = {
            guard let current = todayNormTemp, !historicalTemps.isEmpty else { return nil }
            let res = PersonalBaseline.robustZ(today: current, history: historicalTemps, minDays: 7)
            return res.isReliable ? res.z : nil
        }()

        // 6. 連續 2 日 RHR 與呼吸率噪聲過濾檢查
        let rhrMedian = Self.median(of: historicalRHRs)
        let respMedian = Self.median(of: historicalRespRates)
        let rhrZScore: Double? = {
            guard let current = todayNormRHR, !historicalRHRs.isEmpty else { return nil }
            let res = PersonalBaseline.robustZ(today: current, history: historicalRHRs, minDays: config.minimumBaselineSamples)
            return res.isReliable ? res.z : nil
        }()

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

        // 7. StrainGate 多信號一致性門檻 (溫度 + HRV + RHR 至少 2 項同向偏離且持續 >= 2 晚才觸發減載)
        let consecutiveNights = max(consecutiveRHRDays, consecutiveRespDays)
        let shouldDeloadStrainGate = StrainGate.shouldDeload(
            tempZ: tempZScore ?? 0.0,
            hrvZ: lnHRVZScore ?? 0.0,
            rhrZ: rhrZScore ?? 0.0,
            consecutiveNights: consecutiveNights
        )

        // 8. 自主神經狀態判定 (納入 HRR 1-min 與 步行心率 破除假性副交感亢進)
        let autonomic: AutonomicState
        if today.confounders.contains(.alcohol) {
            autonomic = .metabolicallyConfounded
        } else if let z = lnHRVZScore {
            let isVagalBlunted = today.isVagalReactivationBlunted
            let isWalkingHRHigh: Bool = {
                guard let todayWHR = today.walkingHeartRateAverageBpm else { return false }
                let historyWHRs = cleanHistory.compactMap { $0.walkingHeartRateAverageBpm }
                guard let medWHR = Self.median(of: historyWHRs) else { return false }
                return todayWHR >= (medWHR + 5.0)
            }()
            
            if z < -1.5 || isWalkingHRHigh {
                autonomic = .sympatheticOverload
            } else if z > 1.8 && (consecutiveRHRDays >= 1 || consecutiveRespDays >= 1 || isVagalBlunted) {
                // 副交感假性過度亢進 (伴隨心率、呼吸率異常或 HRR 驟降遲滯)
                autonomic = .parasympatheticHyperactivity
            } else {
                autonomic = .balanced
            }
        } else {
            autonomic = .balanced
        }

        // 9. 非線性綜合評估分數 (0~100)
        let (score, zone) = calculateScoreAndZone(
            lnHRVZScore: lnHRVZScore,
            consecutiveRHRDays: consecutiveRHRDays,
            consecutiveRespDays: consecutiveRespDays,
            respWarning: respWarning,
            shouldDeloadStrainGate: shouldDeloadStrainGate,
            tempZScore: tempZScore,
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
        if today.isVagalReactivationBlunted {
            diagnostics.append("運動後一分鐘心率恢復遲緩 (<18 bpm)，提示副交感神經迷走張力尚未完全復原，建議降低今日訓練強度。")
        }
        if shouldDeloadStrainGate {
            diagnostics.append("夜間手腕溫度與心率指標出現連續多晚同向偏離個人基準，可能與疲勞累積、環境應激或身體修復負擔增加有關，系統已自動安排防衛減載。")
        } else if let tempZ = tempZScore, tempZ >= 1.8 {
            diagnostics.append("夜間手腕溫度相對個人基準偏高 (Z=\(String(format: "%.1f", tempZ)))，但尚未達多信號一致性減載門檻，持續觀察。")
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
            wristTemperatureBaselineDeltaCelsius: today.wristTemperatureBaselineDeltaCelsius,
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

    private func normalizedTemp(for sample: NightlyBiomarkerSample) -> Double? {
        guard let temp = sample.wristTemperatureBaselineDeltaCelsius ?? sample.sleepingWristTemperatureCelsius.map({ $0 - 36.5 }) else { return nil }
        return sample.confounders.contains(.lutealPhase) ? (temp - config.lutealTempShiftCelsius) : temp
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
        shouldDeloadStrainGate: Bool,
        tempZScore: Double?,
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
        
        // 溫度偏離扣分 (結合 StrainGate 與單夜顯著升溫防衛)
        if shouldDeloadStrainGate {
            baseScore -= 20.0
        } else if let tempZ = tempZScore {
            if tempZ >= 3.0 {
                // 單夜顯著偏高 (Z >= 3.0 或偏差 >= 0.5°C) 提示感染前兆或外周強應激
                baseScore -= 12.0
            } else if tempZ >= 1.8 {
                // 輕度偏高但未達多信號一致性門檻
                baseScore -= 5.0
            }
        }
        
        // HRR 1-min 迷走神經遲滯扣分
        if today.isVagalReactivationBlunted {
            baseScore -= 8.0
        }

        let clampedScore = max(10, min(98, Int(baseScore.rounded())))

        let zone: ReadinessZone
        if clampedScore >= 80 && consecutiveRHRDays < 2 && !shouldDeloadStrainGate {
            zone = .ready
        } else if clampedScore >= 60 && consecutiveRHRDays < 2 && !shouldDeloadStrainGate {
            zone = .steady
        } else if clampedScore >= 35 || consecutiveRHRDays >= 2 || shouldDeloadStrainGate {
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

    /// 特徵缺失動態權重重新歸一化與信心度計算 (Claude Review §4.5)
    /// 當使用者部分授權被拒或傳感器資料缺失時，依可用特徵自適應計算分數，而非把缺失當作 0 或崩潰。
    public static func computeReadiness(_ features: [Feature], minFeatures: Int = 3) -> ReadinessScore? {
        let available = features.compactMap { f in f.normalizedScore.map { (f.weight, $0) } }
        guard available.count >= minFeatures else { return nil }
        let wSum = available.reduce(0.0) { $0 + $1.0 }
        guard wSum > 0.0 else { return nil }
        let s = available.reduce(0.0) { $0 + $1.0 * $1.1 } / wSum
        return ReadinessScore(score: s, usedFeatures: available.count, totalFeatures: features.count)
    }
}
