import Foundation

/// 單次訓練會話領域實體 (WorkoutSession)
public struct WorkoutSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let discipline: TrainingDiscipline
    public let durationMinutes: Double
    public let sRPE: Double                           // Foster sRPE: 1.0 ~ 10.0
    public let movementPatterns: [MovementPattern]    // 涉及之動作模式 (第 1 項視為主項)
    public let source: SessionSource                  // 資料來源溯源
    public let averageHeartRate: Double?              // 平均心率 (手錶客觀數據)
    public let zoneDurationsSeconds: [Int: Double]?   // 各 Zone 0~5 停留秒數
    public let requiresManualRPEConfirmation: Bool    // 心率中斷或異常時需手動確認
    
    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        discipline: TrainingDiscipline,
        durationMinutes: Double,
        sRPE: Double,
        movementPatterns: [MovementPattern] = [],
        source: SessionSource = .manualLog,
        averageHeartRate: Double? = nil,
        zoneDurationsSeconds: [Int: Double]? = nil,
        requiresManualRPEConfirmation: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.discipline = discipline
        self.durationMinutes = durationMinutes
        self.sRPE = sRPE
        self.movementPatterns = movementPatterns
        self.source = source
        self.averageHeartRate = averageHeartRate
        self.zoneDurationsSeconds = zoneDurationsSeconds
        self.requiresManualRPEConfirmation = requiresManualRPEConfirmation
    }
    
    /// 單次訓練負荷 (Arbitrary Units, AU) = Duration * sRPE
    public var loadAU: Double {
        return durationMinutes * sRPE
    }
}

/// 每日晨間生理快照 (PhysiologicalSnapshot)
public struct PhysiologicalSnapshot: Codable, Equatable, Sendable {
    public let date: Date
    public let hrvTodayMs: Double?               // 當日 SDNN 毫秒
    public let hrv14dMedianMs: Double?           // 14 天中位數
    public let hrv14dMADMs: Double?              // 14 天絕對離差中位數 (保底 2.0ms)
    public let sleepDurationHours: Double        // 昨夜去重總睡眠時數
    public let hasReportedPainOrInjury: Bool     // 傷病安全閘門
    public let morningSorenessRating: Double?    // 晨間整體 DOMS 痠痛評分 (1~5)
    
    public init(
        date: Date = Date(),
        hrvTodayMs: Double? = nil,
        hrv14dMedianMs: Double? = nil,
        hrv14dMADMs: Double? = nil,
        sleepDurationHours: Double,
        hasReportedPainOrInjury: Bool = false,
        morningSorenessRating: Double? = nil
    ) {
        self.date = date
        self.hrvTodayMs = hrvTodayMs
        self.hrv14dMedianMs = hrv14dMedianMs
        self.hrv14dMADMs = hrv14dMADMs
        self.sleepDurationHours = sleepDurationHours
        self.hasReportedPainOrInjury = hasReportedPainOrInjury
        self.morningSorenessRating = morningSorenessRating
    }
}

/// 肌群局部冷卻狀態模型
public struct MuscleCooldownStatus: Codable, Equatable, Sendable {
    public let pattern: MovementPattern
    public let remainingHours: Double           // 剩餘冷卻小時數 (連續浮點數)
    public let lastStimulatedDate: Date?        // 前次刺激時間點
    public let isFatigued: Bool                 // 是否處於修復期 (remainingHours > 0)
    
    public init(pattern: MovementPattern, remainingHours: Double, lastStimulatedDate: Date?) {
        self.pattern = pattern
        self.remainingHours = max(0.0, remainingHours)
        self.lastStimulatedDate = lastStimulatedDate
        self.isFatigued = remainingHours > 0.001
    }
}

/// 結構化課表步驟
public struct WorkoutStepItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let order: Int
    public let name: String                              // 如 "Zone 2 基底慢跑"
    public let durationSeconds: Int                      // 時長 (秒)
    public let targetHeartRateRangeMin: Double?          // 目標心率區間下限 (bpm)
    public let targetHeartRateRangeMax: Double?          // 目標心率區間上限 (bpm)
    public let stepDescription: String
    
    public init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        durationSeconds: Int,
        targetHeartRateRangeMin: Double? = nil,
        targetHeartRateRangeMax: Double? = nil,
        stepDescription: String = ""
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetHeartRateRangeMin = targetHeartRateRangeMin
        self.targetHeartRateRangeMax = targetHeartRateRangeMax
        self.stepDescription = stepDescription
    }
}

/// 具體推薦課表實體
public struct RecommendedWorkout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String                             // 如 "Zone 2 有氧基底跑"
    public let subtitle: String                          // 如 "目標 40 分鐘 · 預估負荷 140 AU"
    public let discipline: TrainingDiscipline
    public let runningType: RunningWorkoutType?
    public let targetPatterns: [MovementPattern]         // 涉及動作部位
    public let estimatedDurationMinutes: Double
    public let estimatedLoadAU: Double
    public let steps: [WorkoutStepItem]                  // 結構化步驟
    public let isLockedDueToFatigue: Bool                // 是否為受限降級版本
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        discipline: TrainingDiscipline,
        runningType: RunningWorkoutType? = nil,
        targetPatterns: [MovementPattern] = [],
        estimatedDurationMinutes: Double,
        estimatedLoadAU: Double,
        steps: [WorkoutStepItem] = [],
        isLockedDueToFatigue: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.discipline = discipline
        self.runningType = runningType
        self.targetPatterns = targetPatterns
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.estimatedLoadAU = estimatedLoadAU
        self.steps = steps
        self.isLockedDueToFatigue = isLockedDueToFatigue
    }
}

/// 當日決策體 (DailyDecision) —— Policy Engine 輸出的單一事實來源
public struct DailyDecision: Codable, Equatable, Sendable {
    public let date: Date
    public let readinessGrade: ReadinessGrade             // 綠 / 黃 / 紅 / 傷病
    public let readinessScore: Double                    // 0 ～ 100 分
    public let confidence: MetricConfidence              // 高 / 低 (是否降級)
    public let acwrRatio: Double                         // 當前 ACWR 比值
    public let atl: Double                               // 當前急性負荷 (AU/day)
    public let ctl: Double                               // 當前慢性負荷 (AU/day)
    public let cooldowns: [MuscleCooldownStatus]         // 各動作模式剩餘小時
    public let primaryRecommendation: RecommendedWorkout // 今日最佳主推薦
    public let safeAlternates: [RecommendedWorkout]      // 2~3 個運動學互補安全備選
    public let fatigueWarnings: [String]                 // 啟發式提醒文字清單
    
    public init(
        date: Date = Date(),
        readinessGrade: ReadinessGrade,
        readinessScore: Double,
        confidence: MetricConfidence,
        acwrRatio: Double,
        atl: Double,
        ctl: Double,
        cooldowns: [MuscleCooldownStatus],
        primaryRecommendation: RecommendedWorkout,
        safeAlternates: [RecommendedWorkout],
        fatigueWarnings: [String] = []
    ) {
        self.date = date
        self.readinessGrade = readinessGrade
        self.readinessScore = readinessScore
        self.confidence = confidence
        self.acwrRatio = acwrRatio
        self.atl = atl
        self.ctl = ctl
        self.cooldowns = cooldowns
        self.primaryRecommendation = primaryRecommendation
        self.safeAlternates = safeAlternates
        self.fatigueWarnings = fatigueWarnings
    }
}
