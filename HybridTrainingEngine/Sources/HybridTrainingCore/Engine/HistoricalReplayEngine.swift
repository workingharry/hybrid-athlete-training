import Foundation

/// 歷史回放與離線決策審查引擎 (HistoricalReplayEngine)
public struct HistoricalReplayEngine: HistoricalReplayPort {
    
    public init() {}
    
    /// 匯入受測者 4~8 週真實健康資料進行逐日離線回放
    /// - Parameters:
    ///   - history: 完整歷史訓練紀錄
    ///   - snapshots: 各日曆天之晨間快照對照表 [startOfDay: Snapshot]
    ///   - configuration: 啟發式參數配置
    /// - Returns: [HistoricalReplayDayResult] 逐日回放結果清單
    public func replayHistoricalDays(
        history: [WorkoutSession],
        snapshots: [Date: PhysiologicalSnapshot] = [:],
        configuration: TrainingConfiguration = .default
    ) -> [HistoricalReplayDayResult] {
        let calendar = Calendar.current
        
        // 找出歷史紀錄的最早與最晚日期
        let allDates = history.map { $0.startDate } + Array(snapshots.keys)
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            return []
        }
        
        var results: [HistoricalReplayDayResult] = []
        var currentDate = calendar.startOfDay(for: minDate)
        let lastDate = calendar.startOfDay(for: maxDate)
        
        // 逐日遞增模擬晨間 07:00 決策觸發
        while currentDate <= lastDate {
            guard let morningCheckTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: currentDate) else {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? lastDate.addingTimeInterval(1)
                continue
            }
            
            // 截至當日早晨 07:00 已經發生的歷史會話
            let pastSessions = history.filter { $0.endDate <= morningCheckTime }
            
            // 當日真實進行的訓練
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? morningCheckTime
            let todaysActualWorkouts = history.filter { $0.startDate >= currentDate && $0.startDate < dayEnd }
            
            // 取得或合成當日生理快照
            let snapshot = snapshots[currentDate] ?? PhysiologicalSnapshot(
                date: morningCheckTime,
                sleepDurationHours: 7.5,
                hasReportedPainOrInjury: false
            )
            
            // 執行當日決策仲裁
            let decision = TrainingPolicyEngine.evaluateDailyDecision(
                history: pastSessions,
                snapshot: snapshot,
                now: morningCheckTime,
                calendar: calendar,
                configuration: configuration
            )
            
            let legCooldownActive = decision.cooldowns.contains { status in
                (status.pattern == .lowerQuad || status.pattern == .lowerPosterior) && status.remainingHours > 0
            }
            
            let summary = "\(decision.readinessGrade) | 主推薦: \(decision.primaryRecommendation.title) (\(Int(decision.primaryRecommendation.estimatedDurationMinutes))m, \(Int(decision.primaryRecommendation.estimatedLoadAU)) AU)"
            
            results.append(HistoricalReplayDayResult(
                date: morningCheckTime,
                decision: decision,
                actualWorkoutsPerformed: todaysActualWorkouts,
                wasLegCooldownActive: legCooldownActive,
                recommendationSummary: summary
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? lastDate.addingTimeInterval(1)
        }
        
        return results
    }
}
