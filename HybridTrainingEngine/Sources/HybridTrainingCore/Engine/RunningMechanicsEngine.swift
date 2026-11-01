import Foundation

/// 跑步生物力學與下肢伸展-收縮循環 (SSC) 疲勞評估引擎
/// 專門解析腿部大重量肌力訓練（深蹲、硬舉）對跑步步態的影響，破除靜態晨檢（HRV/RHR）無法偵測下肢周邊剛性疲勞的盲區。
public struct RunningMechanicsEngine: Sendable {
    
    public init() {}
    
    /// 評估最近一次跑步力學，對比歷史基線與近期腿部重訓記錄
    /// - Parameters:
    ///   - latestRun: 最近一次跑步力學樣本
    ///   - historyRuns: 過去 28 天乾淨跑步樣本
    ///   - recentWorkouts: 最近 48 小時訓練記錄 (用於比對是否為 leg-day 腿部深蹲/硬舉)
    /// - Returns: 跑步力學與防傷評估結果
    public func evaluate(
        latestRun: RunningMechanicsSample?,
        historyRuns: [RunningMechanicsSample],
        recentWorkouts: [WorkoutSession] = []
    ) -> RunningMechanicsAssessment {
        guard let current = latestRun, current.isValidBiomechanicsSample else {
            return RunningMechanicsAssessment(status: .insufficientBaseline)
        }
        
        let validHistory = historyRuns.filter { $0.isValidBiomechanicsSample }
        guard validHistory.count >= 3 else {
            return RunningMechanicsAssessment(status: .insufficientBaseline)
        }
        
        // 1. 計算同配速帶 (Speed-Matched ±15%) 之歷史觸地時間 (GCT) 基準中位數
        let speedTolerance = current.averageSpeedMetersPerSecond * 0.15
        let matchedRuns = validHistory.filter {
            abs($0.averageSpeedMetersPerSecond - current.averageSpeedMetersPerSecond) <= speedTolerance
        }
        
        let baselineRuns = matchedRuns.isEmpty ? validHistory : matchedRuns
        let historyGCTs = baselineRuns.compactMap { $0.groundContactTimeMs }
        let medianGCT = RobustZScoreCalculator.median(of: historyGCTs) ?? 240.0
        
        // GCT 殘差 (正值代表觸地拖沓、下肢剛性衰退)
        let currentGCT = current.groundContactTimeMs ?? medianGCT
        let gctDelta = currentGCT - medianGCT
        
        // 2. 下肢垂直剛性衰減評估 (Vertical Stiffness Loss)
        let historyStiffnesses = baselineRuns.compactMap { $0.verticalStiffnessKiloNewtonsPerMeter }
        let medianStiffness = RobustZScoreCalculator.median(of: historyStiffnesses) ?? 25.0
        
        let currentStiffness = current.verticalStiffnessKiloNewtonsPerMeter ?? medianStiffness
        let stiffnessLossPercent: Double = medianStiffness > 0 ? max(0.0, ((medianStiffness - currentStiffness) / medianStiffness) * 100.0) : 0.0
        
        // 3. 跑步經濟性衰退 (Power / Speed 異常升高)
        let historyCosts = baselineRuns.compactMap { $0.costOfPowerWattsPerSpeed }
        let medianCost = RobustZScoreCalculator.median(of: historyCosts) ?? 70.0
        let currentCost = current.costOfPowerWattsPerSpeed ?? medianCost
        let isEconomyDegraded = medianCost > 0 ? (currentCost / medianCost) > 1.08 : false
        
        // 4. 檢查最近 36 小時內是否有腿部重訓 (Quad / Posterior)
        let recentLegWorkouts = recentWorkouts.filter { workout in
            guard workout.discipline == .strength else { return false }
            let hoursAgo = current.date.timeIntervalSince(workout.endDate) / 3600.0
            let isRecent = hoursAgo >= 0 && hoursAgo <= 36.0
            let hitsLegs = workout.movementPatterns.contains(.lowerQuad) || workout.movementPatterns.contains(.lowerPosterior)
            return isRecent && hitsLegs
        }
        let hasRecentLegDay = !recentLegWorkouts.isEmpty
        
        // 5. 綜合判決與狀態歸類
        var directives: [String] = []
        let status: SSCFatigueStatus
        let isSquatDecoupled: Bool
        
        if gctDelta >= 15.0 || stiffnessLossPercent >= 12.0 {
            status = .severeDecoupled
            isSquatDecoupled = hasRecentLegDay
            directives.append("🚨 下肢觸地時間延長 +\(Int(gctDelta))ms，伸展收縮剛性顯著衰竭！")
            directives.append("強烈建議 48 小時內暫緩速度衝刺與高衝擊路跑，避免引發阿基里斯腱與髕骨肌腱損傷。")
            if hasRecentLegDay {
                directives.append("💡 偵測到腿部大重量重訓後神經肌肉殘留疲勞，可維持上肢肌力訓練或改為室內單車/划船等低衝擊有氧。")
            }
        } else if gctDelta >= 8.0 || stiffnessLossPercent >= 6.0 || isEconomyDegraded {
            status = .mildStiffnessLoss
            isSquatDecoupled = hasRecentLegDay
            directives.append("⚠️ 下肢彈性能量微幅衰減 (觸地 +\(Int(gctDelta))ms)，步態稍顯代償。")
            directives.append("建議控制跑步強度於 Zone 2 輕鬆跑，增加滾筒筋膜放鬆與小腿動態伸展。")
        } else {
            status = .nominal
            isSquatDecoupled = false
            directives.append("✅ 跑步生物力學與剛性正常，牽張縮短循環 (SSC) 儲能效率優良。")
        }
        
        return RunningMechanicsAssessment(
            status: status,
            groundContactTimeDeltaMs: gctDelta,
            verticalStiffnessLossPercent: stiffnessLossPercent,
            runningEconomyDegraded: isEconomyDegraded,
            isSquatLegDayDecoupled: isSquatDecoupled,
            injuryMitigationDirectives: directives
        )
    }
}
