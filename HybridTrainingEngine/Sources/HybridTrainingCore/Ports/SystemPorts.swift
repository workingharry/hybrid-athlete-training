import Foundation

/// 生理數據讀取端口協議 (HealthKit Port)
public protocol HealthKitPort: Sendable {
    /// 檢查 HealthKit 在當前設備是否可用
    var isHealthDataAvailable: Bool { get }
    
    /// 請求必要的讀取權限
    func requestAuthorization() async throws
    
    /// 查詢指定日期晨間之生理快照 (包含 14天 HRV 穩健 Z-score、昨夜去重睡眠時數)
    func fetchPhysiologicalSnapshot(date: Date) async throws -> PhysiologicalSnapshot
    
    /// 查詢指定時間範圍內之歷史訓練記錄
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession]
}

/// 課表手錶排程推送端口協議 (WorkoutKit Port)
public protocol WorkoutKitPort: Sendable {
    /// 檢查當前設備與手錶是否支援 WorkoutKit 排程
    var isWorkoutKitAvailable: Bool { get }
    
    /// 將推薦課表推送至 Apple Watch 內建體能訓練 App
    func scheduleWorkout(workout: RecommendedWorkout, at date: Date) async throws -> WorkoutScheduleResult
    
    /// 移除已排程但未執行的課表
    func removeScheduledWorkout(id: UUID) async throws
}

/// 課表排程結果狀態
public enum WorkoutScheduleResult: Sendable, Equatable {
    case scheduled(planId: UUID)
    case pendingSync(planId: UUID)
    case failed(reason: String)
}

/// 歷史回放與離線審查端口協議 (Historical Replay Port)
public protocol HistoricalReplayPort: Sendable {
    /// 匯入受測者 4~8 週真實健康資料並進行逐日決策回放
    func replayHistoricalDays(
        history: [WorkoutSession],
        snapshots: [Date: PhysiologicalSnapshot],
        configuration: TrainingConfiguration
    ) -> [HistoricalReplayDayResult]
}

/// 單日回放結果實體
public struct HistoricalReplayDayResult: Sendable {
    public let date: Date
    public let decision: DailyDecision
    public let actualWorkoutsPerformed: [WorkoutSession]
    public let wasLegCooldownActive: Bool
    public let recommendationSummary: String
    
    public init(
        date: Date,
        decision: DailyDecision,
        actualWorkoutsPerformed: [WorkoutSession],
        wasLegCooldownActive: Bool,
        recommendationSummary: String
    ) {
        self.date = date
        self.decision = decision
        self.actualWorkoutsPerformed = actualWorkoutsPerformed
        self.wasLegCooldownActive = wasLegCooldownActive
        self.recommendationSummary = recommendationSummary
    }
}
