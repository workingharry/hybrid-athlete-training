import Foundation

/// 睡眠階段枚舉 (對標 Apple HealthKit sleepAnalysis)
public enum SleepStage: String, Sendable, Codable, Equatable {
    case inBed
    case awake
    case asleepUnspecified
    case core
    case deep
    case rem
}

/// 傳感器無依賴純 Swift DTO (可在非 HealthKit/非真機環境下 100% 單元測試)
public struct RawBiomarkerSampleDTO: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        case sdnn
        case heartRate
        case restingHeartRate
        case respiratoryRate
        case sleep
        case mindfulSession
        case dietaryEnergy
        case activeEnergy
        case sleepingWristTemperature   // HKQuantityTypeIdentifier.appleSleepingWristTemperature (degC)
        case walkingHeartRateAverage    // HKQuantityTypeIdentifier.walkingHeartRateAverage (bpm)
        case heartRateRecoveryOneMinute // HKQuantityTypeIdentifier.heartRateRecoveryOneMinute (bpm)
    }
    
    public let uuid: UUID
    public let kind: Kind
    public let value: Double?
    public let sleepStage: SleepStage?
    public let start: Date
    public let end: Date
    public let sourceBundleId: String
    public let sourceProductType: String?
    public let isUserEntered: Bool
    public let timeZoneIdentifier: String?
    
    public init(
        uuid: UUID = UUID(),
        kind: Kind,
        value: Double? = nil,
        sleepStage: SleepStage? = nil,
        start: Date,
        end: Date,
        sourceBundleId: String = "com.apple.health",
        sourceProductType: String? = "Watch7,1",
        isUserEntered: Bool = false,
        timeZoneIdentifier: String? = nil
    ) {
        self.uuid = uuid
        self.kind = kind
        self.value = value
        self.sleepStage = sleepStage
        self.start = start
        self.end = end
        self.sourceBundleId = sourceBundleId
        self.sourceProductType = sourceProductType
        self.isUserEntered = isUserEntered
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

/// watchOS 睡眠分析異步狀態
public enum SleepSyncStatus: String, Sendable, Codable, Equatable {
    case durationOnly       // 剛醒來 0~30 分鐘，僅有睡眠總時長，分期計算中
    case finalized          // watchOS 已完成 Core/Deep/REM 分期計算
    case finalizedDegraded  // 分期寫入但部分時段缺失或睡眠不足
    case insufficientData   // 睡眠配戴不足 4 小時
}

/// 生理情境干擾標籤 (用於 28 天基準池隔離與歸一化)
public enum ConfounderTag: String, Sendable, Codable, CaseIterable, Hashable {
    case alcohol            // 昨夜飲酒：排除於 28d 基準池，當日屏蔽自主衰竭誤報
    case jetlagOrShift      // 跨時區/熬夜：放寬睡眠規律性懲罰
    case lutealPhase        // 女性黃體期：RHR 基準平移 +2.5 bpm，呼吸率 +0.5 rpm
    case illness            // 身體微恙/生病：排除於基準池，觸發保護鎖定
}

/// 單夜生理指標聚合樣本 (對齊早晨醒來時所歸屬之訓練日)
public struct NightlyBiomarkerSample: Sendable, Equatable, Codable {
    public let date: Date
    public let sleepWindow: DateInterval?
    public let sleepSyncStatus: SleepSyncStatus
    public let totalSleepDurationSeconds: TimeInterval
    public let deepSleepSeconds: TimeInterval?
    public let remSleepSeconds: TimeInterval?
    public let nightlySDNNValuesMs: [Double]
    public let nocturnalSleepingHeartRateBpm: Double?
    public let morningRestingHRBpm: Double?
    public let sleepingRespiratoryRateRpm: Double?
    public let sleepingWristTemperatureCelsius: Double?
    public let wristTemperatureBaselineDeltaCelsius: Double?
    public let walkingHeartRateAverageBpm: Double?
    public let heartRateRecoveryOneMinuteBpm: Double?
    public let confounders: Set<ConfounderTag>

    public init(
        date: Date,
        sleepWindow: DateInterval? = nil,
        sleepSyncStatus: SleepSyncStatus = .finalized,
        totalSleepDurationSeconds: TimeInterval,
        deepSleepSeconds: TimeInterval? = nil,
        remSleepSeconds: TimeInterval? = nil,
        nightlySDNNValuesMs: [Double] = [],
        nocturnalSleepingHeartRateBpm: Double? = nil,
        morningRestingHRBpm: Double? = nil,
        sleepingRespiratoryRateRpm: Double? = nil,
        sleepingWristTemperatureCelsius: Double? = nil,
        wristTemperatureBaselineDeltaCelsius: Double? = nil,
        walkingHeartRateAverageBpm: Double? = nil,
        heartRateRecoveryOneMinuteBpm: Double? = nil,
        confounders: Set<ConfounderTag> = []
    ) {
        self.date = date
        self.sleepWindow = sleepWindow
        self.sleepSyncStatus = sleepSyncStatus
        self.totalSleepDurationSeconds = totalSleepDurationSeconds
        self.deepSleepSeconds = deepSleepSeconds
        self.remSleepSeconds = remSleepSeconds
        self.nightlySDNNValuesMs = nightlySDNNValuesMs
        self.nocturnalSleepingHeartRateBpm = nocturnalSleepingHeartRateBpm ?? morningRestingHRBpm
        self.morningRestingHRBpm = morningRestingHRBpm ?? nocturnalSleepingHeartRateBpm
        self.sleepingRespiratoryRateRpm = sleepingRespiratoryRateRpm
        self.sleepingWristTemperatureCelsius = sleepingWristTemperatureCelsius
        self.wristTemperatureBaselineDeltaCelsius = wristTemperatureBaselineDeltaCelsius
        self.walkingHeartRateAverageBpm = walkingHeartRateAverageBpm
        self.heartRateRecoveryOneMinuteBpm = heartRateRecoveryOneMinuteBpm
        self.confounders = confounders
    }
    
    /// 手腕夜間溫度是否處於人類生理合理界限 (30.0°C ~ 42.0°C)
    public var hasValidWristTemperature: Bool {
        guard let temp = sleepingWristTemperatureCelsius else { return false }
        return temp >= 30.0 && temp <= 42.0
    }
    
    /// 運動後 1 分鐘心率驟降是否顯著遲滯 (< 18 bpm)
    public var isVagalReactivationBlunted: Bool {
        guard let hrr = heartRateRecoveryOneMinuteBpm else { return false }
        return hrr < 18.0
    }
}

/// 訓練準備度四色區間
public enum ReadinessZone: String, Codable, Sendable, Equatable {
    case ready               // 80-100: 充沛狀態，適宜高強度或大容量課表
    case steady              // 60-79: 穩態，正常執行課表
    case overreached         // 35-59: 負荷適應/過載，建議降載或輕量活動
    case protectiveLockdown  // 0-34: 傷病/感染保護，強制休息
}

/// 自主神經功能狀態
public enum AutonomicState: String, Codable, Sendable, Equatable {
    case balanced
    case sympatheticOverload          // 交感神經過載 (lnHRV 偏低)
    case parasympatheticHyperactivity // 副交感神經假性亢進 (lnHRV 異常偏高伴隨心率上升或疲勞)
    case metabolicallyConfounded      // 受酒精或代謝因素干擾
    case calibrating                  // 基準線累積中 (有效樣本 < 14 天)
}

/// 4:00 AM 訓練日劃分鍵值
public struct TrainingDayKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let dateString: String // YYYY-MM-DD
    
    public init(date: Date, calendar: Calendar = Calendar.current) {
        // 4:00 AM 以前屬於前一訓練日
        var cal = calendar
        cal.timeZone = TimeZone.current
        let hour = cal.component(.hour, from: date)
        let effectiveDate: Date
        if hour < 4 {
            effectiveDate = cal.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            effectiveDate = date
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        self.dateString = formatter.string(from: effectiveDate)
    }
    
    public var description: String { dateString }
}

/// 晨間最終綜合準備度評估
public struct ReadinessAssessment: Sendable, Codable, Equatable {
    public let dayKey: TrainingDayKey
    public let score: Int
    public let zone: ReadinessZone
    public let autonomic: AutonomicState
    public let confidence: MetricConfidence
    public let sleepStatus: SleepSyncStatus
    public let lnHRVZScore: Double?
    public let wristTemperatureBaselineDeltaCelsius: Double?
    public let consecutiveElevatedRHRDays: Int
    public let consecutiveElevatedRespRateDays: Int
    public let respiratoryWarningTriggered: Bool
    public let revision: Int
    public let algorithmVersion: String
    public let diagnosticMessages: [String]

    public init(
        dayKey: TrainingDayKey,
        score: Int,
        zone: ReadinessZone,
        autonomic: AutonomicState,
        confidence: MetricConfidence,
        sleepStatus: SleepSyncStatus,
        lnHRVZScore: Double?,
        wristTemperatureBaselineDeltaCelsius: Double? = nil,
        consecutiveElevatedRHRDays: Int,
        consecutiveElevatedRespRateDays: Int,
        respiratoryWarningTriggered: Bool,
        revision: Int = 1,
        algorithmVersion: String = "4.2.0-applewatch",
        diagnosticMessages: [String] = []
    ) {
        self.dayKey = dayKey
        self.score = score
        self.zone = zone
        self.autonomic = autonomic
        self.confidence = confidence
        self.sleepStatus = sleepStatus
        self.lnHRVZScore = lnHRVZScore
        self.wristTemperatureBaselineDeltaCelsius = wristTemperatureBaselineDeltaCelsius
        self.consecutiveElevatedRHRDays = consecutiveElevatedRHRDays
        self.consecutiveElevatedRespRateDays = consecutiveElevatedRespRateDays
        self.respiratoryWarningTriggered = respiratoryWarningTriggered
        self.revision = revision
        self.algorithmVersion = algorithmVersion
        self.diagnosticMessages = diagnosticMessages
    }
}

/// 數據不足具體原因
public enum InsufficientReason: String, Sendable, Codable, Equatable {
    case tooFewSamples       // 夜間 SDNN 樣本少於 3 筆
    case poorTimeCoverage    // 配戴少於 4 小時
    case noSleepWindow       // 未能檢測到有效睡眠區間
}

/// 引擎評估成果枚舉 (杜絕非法狀態)
public enum BiomarkerOutcome: Sendable, Equatable {
    case assessed(ReadinessAssessment)
    case calibrating(cleanDays: Int, partial: ReadinessAssessment?)
    case insufficientData(InsufficientReason)
}

/// 符合 2023 IOC REDs CAT2 指南之能量可用性 (EA) 評估結構
public struct EAEstimate: Sendable, Codable, Equatable {
    public enum State: String, Sendable, Codable {
        case insufficientDays // 過去 7 日有效完整日少於 4 天
        case estimated
    }
    public let state: State
    public let point: Double?       // kcal/kg FFM
    public let lower: Double?       // 不確定性下限 (-5 kcal/kg FFM)
    public let upper: Double?       // 不確定性上限 (+5 kcal/kg FFM)
    public let completeDays: Int
    public let excludedDays: Int

    public init(
        state: State,
        point: Double?,
        lower: Double? = nil,
        upper: Double? = nil,
        completeDays: Int,
        excludedDays: Int
    ) {
        self.state = state
        self.point = point
        self.lower = lower ?? point.map { max(0.0, $0 - 5.0) }
        self.upper = upper ?? point.map { $0 + 5.0 }
        self.completeDays = completeDays
        self.excludedDays = excludedDays
    }
}

// MARK: - Apple Watch Series 10 硬體賦能與韌性架構領域模型 (P0-P2)

/// 容錯並發查詢結果隔離 (解決 Claude Review R1: 空集合 ≠ 無數據)
public enum MetricResult<Value: Sendable>: Sendable {
    case value(Value)
    case noData           // 授權疑似 OK 但區間內無樣本
    case unavailable      // 型別在此裝置/OS 不可用 (如 S10 之前無水溫/呼吸紊亂)
    case failed(String)   // 查詢錯誤 (含裝置鎖定 Data Protection)
    
    public var value: Value? {
        if case .value(let v) = self { return v }
        return nil
    }
    
    public var isAvailable: Bool {
        if case .unavailable = self { return false }
        return true
    }
    
    public var isSuccess: Bool {
        if case .value = self { return true }
        return false
    }
    
    public func map<T>(_ transform: (Value) -> T) -> MetricResult<T> {
        switch self {
        case .value(let v): return .value(transform(v))
        case .noData: return .noData
        case .unavailable: return .unavailable
        case .failed(let msg): return .failed(msg)
        }
    }
}

extension MetricResult: Equatable where Value: Equatable {}
extension MetricResult: Hashable where Value: Hashable {}

/// 特徵缺失動態歸一化項目 (解決 Claude Review R2 / R3)
public struct Feature: Sendable, Equatable, Codable {
    public let name: String
    public let weight: Double
    public let normalizedScore: Double?   // nil = 缺失 / 未授權 / 冷啟動

    public init(name: String, weight: Double, normalizedScore: Double?) {
        self.name = name
        self.weight = weight
        self.normalizedScore = normalizedScore
    }
}

/// 具備可用特徵與信心度標記之準備度分數
public struct ReadinessScore: Sendable, Equatable, Codable {
    public let score: Double
    public let usedFeatures: Int
    public let totalFeatures: Int
    public var confidence: Double {
        Double(usedFeatures) / Double(max(totalFeatures, 1))
    }

    public init(score: Double, usedFeatures: Int, totalFeatures: Int) {
        self.score = score
        self.usedFeatures = usedFeatures
        self.totalFeatures = totalFeatures
    }
}

/// 睡眠樣本雜湊指紋，防範早晨分數跳變 (解決 Claude Review R4)
public struct SleepFingerprint: Codable, Sendable, Equatable, Hashable {
    public let sampleUUIDsHash: Int
    public let lastSampleArrival: Date

    public init(sampleUUIDsHash: Int, lastSampleArrival: Date) {
        self.sampleUUIDsHash = sampleUUIDsHash
        self.lastSampleArrival = lastSampleArrival
    }
}

public enum SleepFinalization {
    /// 距最後一個樣本到達超過 stableWindow (預設 15 分鐘) 才視為「已結算」
    public static func isFinalized(
        _ fp: SleepFingerprint,
        now: Date = Date(),
        stableWindow: TimeInterval = 15 * 60
    ) -> Bool {
        now.timeIntervalSince(fp.lastSampleArrival) >= stableWindow
    }
}

/// 個人化穩健基線 Z-Score (解決 Claude Review R5: 捨棄固定 +0.40°C)
public enum PersonalBaseline {
    public struct Result: Sendable, Equatable {
        public let z: Double
        public let nDays: Int
        public let isReliable: Bool

        public init(z: Double, nDays: Int, isReliable: Bool) {
            self.z = z
            self.nDays = nDays
            self.isReliable = isReliable
        }
    }

    /// 使用中位數 + MAD（穩健抗離群，乘數 1.4826 對齊常態分布標準差）
    public static func robustZ(today: Double, history: [Double], minDays: Int = 14) -> Result {
        let n = history.count
        guard n >= minDays else { return .init(z: 0.0, nDays: n, isReliable: false) }
        let sorted = history.sorted()
        let median: Double
        if n % 2 == 1 {
            median = sorted[n / 2]
        } else {
            median = (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        }
        let diffs = history.map { abs($0 - median) }.sorted()
        let mad: Double
        if n % 2 == 1 {
            mad = diffs[n / 2]
        } else {
            mad = (diffs[n / 2 - 1] + diffs[n / 2]) / 2.0
        }
        let sigma = max(1.4826 * mad, 0.05)   // 地板值避免除以近零
        return .init(z: (today - median) / sigma, nDays: n, isReliable: true)
    }
}

/// 多信號一致性門檻 (溫度 + HRV + RHR 至少 2 項同向偏離且持續 2 晚才減載)
public struct StrainGate {
    public static func shouldDeload(
        tempZ: Double,
        hrvZ: Double,
        rhrZ: Double,
        consecutiveNights: Int
    ) -> Bool {
        let signals = [tempZ >= 1.5, hrvZ <= -1.5, rhrZ >= 1.5].filter { $0 }.count
        return signals >= 2 && consecutiveNights >= 2
    }
}

/// 裝置世代更替偵測器 (解決 Claude Review R2: 換錶基線污染)
public enum DeviceGenerationDetector {
    /// 依據硬體版本或型號偵測裝置是否更替 (如升級至 Apple Watch Series 10)
    public static func hasHardwareGenerationChanged(productTypes: [String?]) -> Bool {
        let validTypes = Set(productTypes.compactMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return validTypes.count > 1
    }
}

