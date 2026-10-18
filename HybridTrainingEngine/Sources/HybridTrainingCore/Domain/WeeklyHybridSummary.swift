import Foundation

/// 週週期混合訓練平衡度總結 (WeeklyHybridSummary)
public struct WeeklyHybridSummary: Equatable, Sendable {
    public let weeklyEnduranceKm: Double
    public let weeklyEnduranceDurationMinutes: Double
    public let weeklyEnduranceSessionsCount: Int
    public let enduranceTargetKm: Double
    public let enduranceProgressRatio: Double

    public let weeklyStrengthTonnageKg: Double
    public let weeklyStrengthSetsCount: Int
    public let weeklyStrengthSessionsCount: Int
    public let strengthTargetSets: Int
    public let strengthProgressRatio: Double

    public let coveredPatterns: Set<MovementPattern>
    public let patternCoverageRatio: Double

    public let balanceScore: Double // 0 ~ 100
    public let balanceStatus: String
    public let primaryFeedback: String

    public init(
        weeklyEnduranceKm: Double,
        weeklyEnduranceDurationMinutes: Double,
        weeklyEnduranceSessionsCount: Int,
        enduranceTargetKm: Double = 30.0,
        weeklyStrengthTonnageKg: Double,
        weeklyStrengthSetsCount: Int,
        weeklyStrengthSessionsCount: Int,
        strengthTargetSets: Int = 32,
        coveredPatterns: Set<MovementPattern>,
        balanceScore: Double,
        balanceStatus: String,
        primaryFeedback: String
    ) {
        self.weeklyEnduranceKm = weeklyEnduranceKm
        self.weeklyEnduranceDurationMinutes = weeklyEnduranceDurationMinutes
        self.weeklyEnduranceSessionsCount = weeklyEnduranceSessionsCount
        self.enduranceTargetKm = enduranceTargetKm
        self.enduranceProgressRatio = enduranceTargetKm > 0 ? min(2.0, weeklyEnduranceKm / enduranceTargetKm) : 0.0

        self.weeklyStrengthTonnageKg = weeklyStrengthTonnageKg
        self.weeklyStrengthSetsCount = weeklyStrengthSetsCount
        self.weeklyStrengthSessionsCount = weeklyStrengthSessionsCount
        self.strengthTargetSets = strengthTargetSets
        self.strengthProgressRatio = strengthTargetSets > 0 ? min(2.0, Double(weeklyStrengthSetsCount) / Double(strengthTargetSets)) : 0.0

        self.coveredPatterns = coveredPatterns
        self.patternCoverageRatio = Double(coveredPatterns.count) / 4.0

        self.balanceScore = balanceScore
        self.balanceStatus = balanceStatus
        self.primaryFeedback = primaryFeedback
    }

    /// 純函數：從過去 7 天的訓練紀錄計算週平衡度指標
    public static func calculate(
        sessions: [WorkoutSession],
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        enduranceTargetKm: Double = 30.0,
        strengthTargetSets: Int = 32
    ) -> WeeklyHybridSummary {
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate

        // 過濾最近 7 天內的訓練
        let recentSessions = sessions.filter { $0.startDate >= sevenDaysAgo && $0.startDate <= referenceDate }

        var totalEnduranceKm: Double = 0.0
        var totalEnduranceDuration: Double = 0.0
        var enduranceCount = 0

        var totalStrengthTonnage: Double = 0.0
        var totalStrengthSets = 0
        var strengthCount = 0
        var covered = Set<MovementPattern>()

        for session in recentSessions {
            switch session.discipline {
            case .running:
                enduranceCount += 1
                totalEnduranceDuration += session.durationMinutes
                // 若無精確距離，以 10 km/h (6 分速) 估算距離
                let estimatedKm = (session.durationMinutes / 60.0) * 10.0
                totalEnduranceKm += estimatedKm

            case .cycling:
                enduranceCount += 1
                totalEnduranceDuration += session.durationMinutes
                // 單車以 22 km/h 估算，折合約 1/2 跑量等效
                let rawKm = (session.durationMinutes / 60.0) * 22.0
                totalEnduranceKm += (rawKm * 0.45)

            case .swimming:
                enduranceCount += 1
                totalEnduranceDuration += session.durationMinutes
                // 游泳折合約 4 倍等效跑量
                let rawKm = (session.durationMinutes / 60.0) * 2.0
                totalEnduranceKm += (rawKm * 3.5)

            case .strength:
                strengthCount += 1
                for pattern in session.movementPatterns {
                    covered.insert(pattern)
                }
                for item in session.executedExercises {
                    covered.insert(item.pattern)
                    let sets = item.sets ?? 3
                    totalStrengthSets += sets
                    if let reps = item.reps, let weight = item.weightKg, weight > 0 {
                        totalStrengthTonnage += (Double(sets * reps) * weight)
                    }
                }
                // 若無細項，預設一場 12 組
                if session.executedExercises.isEmpty {
                    totalStrengthSets += 12
                }

            case .rowing:
                enduranceCount += 1
                totalEnduranceDuration += session.durationMinutes
                let rawKm = (session.durationMinutes / 60.0) * 12.0
                totalEnduranceKm += (rawKm * 0.8)

            case .mobility, .rest:
                break
            }
        }

        // 計算平衡得分
        let enduranceScore = min(1.0, totalEnduranceKm / max(1.0, enduranceTargetKm)) * 35.0
        let strengthSetsScore = min(1.0, Double(totalStrengthSets) / Double(max(1, strengthTargetSets))) * 35.0
        let patternScore = (Double(covered.count) / 4.0) * 30.0
        let rawScore = enduranceScore + strengthSetsScore + patternScore
        let finalScore = min(100.0, max(0.0, (rawScore * 10.0).rounded() / 10.0))

        // 狀態描述與指導反饋
        let status: String
        let feedback: String

        if finalScore >= 80.0 && covered.count == 4 {
            status = "黃金混合雙軌平衡"
            feedback = "耐力與肌力雙軌負荷兼備，4大肌力動作模式無死角，神經適應絕佳。"
        } else if covered.count < 3 && strengthCount > 0 {
            let missing = Set<MovementPattern>([.upperPush, .upperPull, .lowerQuad, .lowerPosterior]).subtracting(covered)
            let missingNames = missing.map { $0.chineseName }.joined(separator: "、")
            status = "肌力肌群分佈不均"
            feedback = "本週尚缺少「\(missingNames)」動作模式，建議補強以預防運動傷害。"
        } else if totalEnduranceKm < (enduranceTargetKm * 0.5) && totalStrengthSets >= (strengthTargetSets / 2) {
            status = "力量偏重 · 耐力待補"
            feedback = "本週重訓組數扎實，但有氧跑量落後，建議安排一場低強度 Zone 2 輕鬆跑。"
        } else if totalEnduranceKm >= (enduranceTargetKm * 0.7) && totalStrengthSets < (strengthTargetSets / 2) {
            status = "耐力充沛 · 肌力待補"
            feedback = "耐力跑量進度理想，請安排下肢防護或上肢抗衡訓練維持骨質與肌肉張力。"
        } else {
            status = "本週週期推進中"
            feedback = "持續累積訓練里程與組數，保持適當組間休息與規律作息。"
        }

        return WeeklyHybridSummary(
            weeklyEnduranceKm: (totalEnduranceKm * 10.0).rounded() / 10.0,
            weeklyEnduranceDurationMinutes: totalEnduranceDuration,
            weeklyEnduranceSessionsCount: enduranceCount,
            enduranceTargetKm: enduranceTargetKm,
            weeklyStrengthTonnageKg: totalStrengthTonnage,
            weeklyStrengthSetsCount: totalStrengthSets,
            weeklyStrengthSessionsCount: strengthCount,
            strengthTargetSets: strengthTargetSets,
            coveredPatterns: covered,
            balanceScore: finalScore,
            balanceStatus: status,
            primaryFeedback: feedback
        )
    }
}

private extension MovementPattern {
    var chineseName: String {
        switch self {
        case .upperPush: return "上肢推"
        case .upperPull: return "上肢拉"
        case .lowerQuad: return "前側鏈/深蹲"
        case .lowerPosterior: return "後側鏈/硬舉"
        }
    }
}
