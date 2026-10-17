import Foundation

/// 手錶與 App 雙重寫入之 50% 重疊智慧合併去重引擎
public struct SmartMergeEngine {
    
    /// 計算兩時間區間之重疊率
    public static func calculateOverlapRatio(
        startA: Date,
        endA: Date,
        startB: Date,
        endB: Date
    ) -> Double {
        let durA = max(0.0, endA.timeIntervalSince(startA))
        let durB = max(0.0, endB.timeIntervalSince(startB))
        let minDur = min(durA, durB)
        guard minDur > 0 else { return 0.0 }
        
        let overlapStart = max(startA, startB)
        let overlapEnd = min(endA, endB)
        let overlapDur = max(0.0, overlapEnd.timeIntervalSince(overlapStart))
        
        return overlapDur / minDur
    }
    
    /// 嘗試將 Apple Watch 體能訓練與 App 手動打卡進行智慧合併
    public static func mergeIfOverlapping(
        watchSession: WorkoutSession,
        manualSession: WorkoutSession
    ) -> WorkoutSession? {
        let ratio = calculateOverlapRatio(
            startA: watchSession.startDate,
            endA: watchSession.endDate,
            startB: manualSession.startDate,
            endB: manualSession.endDate
        )
        
        guard ratio >= 0.50 else { return nil }
        
        let watchUUID: UUID
        switch watchSession.source {
        case .healthKitWorkout(let id), .smartMerged(let id):
            watchUUID = id
        case .manualLog:
            watchUUID = watchSession.id
        }
        
        return WorkoutSession(
            id: UUID(),
            startDate: watchSession.startDate,
            endDate: watchSession.endDate,
            discipline: manualSession.discipline != .running ? manualSession.discipline : watchSession.discipline,
            durationMinutes: watchSession.durationMinutes,
            sRPE: manualSession.sRPE,
            movementPatterns: manualSession.movementPatterns,
            source: .smartMerged(hkUUID: watchUUID),
            averageHeartRate: watchSession.averageHeartRate,
            zoneDurationsSeconds: watchSession.zoneDurationsSeconds,
            requiresManualRPEConfirmation: false
        )
    }
    
    /// 對整批會話進行 Best-Fit 最佳重疊率優先去重與智慧合併處理
    public static func processAndDeduplicate(sessions: [WorkoutSession]) -> [WorkoutSession] {
        var watchSessions: [WorkoutSession] = []
        var manualSessions: [WorkoutSession] = []
        var others: [WorkoutSession] = []
        
        for s in sessions {
            switch s.source {
            case .healthKitWorkout:
                watchSessions.append(s)
            case .manualLog:
                manualSessions.append(s)
            case .smartMerged:
                others.append(s)
            }
        }
        
        struct CandidatePair {
            let watchIndex: Int
            let manualIndex: Int
            let ratio: Double
        }
        
        var candidates: [CandidatePair] = []
        for (wIdx, watch) in watchSessions.enumerated() {
            for (mIdx, manual) in manualSessions.enumerated() {
                let ratio = calculateOverlapRatio(
                    startA: watch.startDate, endA: watch.endDate,
                    startB: manual.startDate, endB: manual.endDate
                )
                if ratio >= 0.50 {
                    candidates.append(CandidatePair(watchIndex: wIdx, manualIndex: mIdx, ratio: ratio))
                }
            }
        }
        
        // 依重疊率由高至低排序，確保最佳匹配優先
        candidates.sort { $0.ratio > $1.ratio }
        
        var consumedWatchIndices = Set<Int>()
        var consumedManualIndices = Set<Int>()
        var mergedResults: [WorkoutSession] = others
        
        for candidate in candidates {
            guard !consumedWatchIndices.contains(candidate.watchIndex),
                  !consumedManualIndices.contains(candidate.manualIndex) else { continue }
            
            if let merged = mergeIfOverlapping(
                watchSession: watchSessions[candidate.watchIndex],
                manualSession: manualSessions[candidate.manualIndex]
            ) {
                mergedResults.append(merged)
                consumedWatchIndices.insert(candidate.watchIndex)
                consumedManualIndices.insert(candidate.manualIndex)
            }
        }
        
        for (wIdx, watch) in watchSessions.enumerated() where !consumedWatchIndices.contains(wIdx) {
            mergedResults.append(watch)
        }
        for (mIdx, manual) in manualSessions.enumerated() where !consumedManualIndices.contains(mIdx) {
            mergedResults.append(manual)
        }
        
        return mergedResults.sorted(by: { $0.startDate < $1.startDate })
    }
}
