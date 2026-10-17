import Foundation

/// 4 大動作模式與下肢冷卻時鐘核心引擎
public struct MuscleCooldownEngine {
    
    /// 計算肌力訓練之單一部位基礎冷卻小時數
    public static func calculateStrengthCooldownHours(
        pattern: MovementPattern,
        sRPE: Double,
        isPrimary: Bool = true,
        secondaryDiscount: Double = 0.70
    ) -> Double {
        let baseHours: Double
        let isUpper = (pattern == .upperPush || pattern == .upperPull)
        
        if sRPE < 5.0 {
            baseHours = isUpper ? 12.0 : 18.0
        } else if sRPE < 7.0 {
            baseHours = isUpper ? 24.0 : 36.0
        } else if sRPE <= 8.5 {
            baseHours = isUpper ? 36.0 : 48.0
        } else {
            baseHours = isUpper ? 48.0 : 60.0
        }
        
        return isPrimary ? baseHours : (baseHours * secondaryDiscount)
    }
    
    /// 計算跑步對下肢肌群之衝擊冷卻時間 (多條件獨立取最大值，徹底消除順序遮蔽)
    public static func calculateRunningImpactCooldown(
        durationMinutes: Double,
        zoneDurationsSeconds: [Int: Double] = [:],
        longRunThresholdMinutes: Double = 75.0
    ) -> (quadHours: Double, posteriorHours: Double) {
        let zone3Seconds = zoneDurationsSeconds[3] ?? 0.0
        let zone4Seconds = zoneDurationsSeconds[4] ?? 0.0
        let zone5Seconds = zoneDurationsSeconds[5] ?? 0.0
        let highIntensitySeconds = zone4Seconds + zone5Seconds
        
        var maxQuad = 12.0
        var maxPosterior = 12.0
        
        // 條件 4: 標準有氧基底跑 (>= 45 分鐘)
        if durationMinutes >= 45.0 {
            maxQuad = max(maxQuad, 24.0)
            maxPosterior = max(maxPosterior, 24.0)
        }
        // 條件 3: 乳酸閾值節奏跑 (Zone 3 >= 20 分鐘)
        if zone3Seconds >= (20.0 * 60.0) {
            maxQuad = max(maxQuad, 36.0)
            maxPosterior = max(maxPosterior, 36.0)
        }
        // 條件 2: 高強度無氧間歇 / 衝刺 (Zone 4~5 >= 10 分鐘)
        if highIntensitySeconds >= (10.0 * 60.0) {
            maxQuad = max(maxQuad, 36.0)
            maxPosterior = max(maxPosterior, 48.0)
        }
        // 條件 1: 長距離耐力跑 (>= longRunThresholdMinutes)
        if durationMinutes >= longRunThresholdMinutes {
            maxQuad = max(maxQuad, 48.0)
            maxPosterior = max(maxPosterior, 48.0)
        }
        
        return (maxQuad, maxPosterior)
    }
    
    /// 計算所有歷史訓練截至指定時間點 (now) 之各部位剩餘冷卻狀態
    /// - Parameters:
    ///   - sessions: 歷史訓練會話清單
    ///   - now: 當前參考時間點（支援確定性注入）
    ///   - configuration: 啟發式參數配置 (預設 TrainingConfiguration.default)
    /// - Returns: [MovementPattern: MuscleCooldownStatus]
    public static func calculateCooldownStatuses(
        sessions: [WorkoutSession],
        now: Date = Date(),
        configuration: TrainingConfiguration = .default
    ) -> [MovementPattern: MuscleCooldownStatus] {
        var remainingMap: [MovementPattern: (remainingHours: Double, lastDate: Date?)] = [
            .upperPush: (0.0, nil),
            .upperPull: (0.0, nil),
            .lowerQuad: (0.0, nil),
            .lowerPosterior: (0.0, nil)
        ]
        
        // 防護：僅評估已經結束的歷史會話 (session.endDate <= now)，防止未來會話污染
        let validSessions = sessions
            .filter { $0.endDate <= now }
            .sorted(by: { $0.endDate < $1.endDate })
        
        for session in validSessions {
            let elapsedHours = max(0.0, now.timeIntervalSince(session.endDate) / 3600.0)
            
            if session.discipline == .running {
                let (quadImpact, posteriorImpact) = calculateRunningImpactCooldown(
                    durationMinutes: session.durationMinutes,
                    zoneDurationsSeconds: session.zoneDurationsSeconds ?? [:],
                    longRunThresholdMinutes: configuration.longRunThresholdMinutes
                )
                
                let quadRemaining = max(0.0, quadImpact - elapsedHours)
                if quadRemaining >= remainingMap[.lowerQuad]!.remainingHours && quadRemaining > 0 {
                    remainingMap[.lowerQuad] = (quadRemaining, session.endDate)
                } else if remainingMap[.lowerQuad]!.remainingHours == 0 {
                    remainingMap[.lowerQuad] = (0.0, session.endDate)
                }
                
                let posteriorRemaining = max(0.0, posteriorImpact - elapsedHours)
                if posteriorRemaining >= remainingMap[.lowerPosterior]!.remainingHours && posteriorRemaining > 0 {
                    remainingMap[.lowerPosterior] = (posteriorRemaining, session.endDate)
                } else if remainingMap[.lowerPosterior]!.remainingHours == 0 {
                    remainingMap[.lowerPosterior] = (0.0, session.endDate)
                }
            } else if session.discipline == .strength {
                for (index, pattern) in session.movementPatterns.enumerated() {
                    let isPrimary = (index == 0)
                    let totalHours = calculateStrengthCooldownHours(
                        pattern: pattern,
                        sRPE: session.sRPE,
                        isPrimary: isPrimary,
                        secondaryDiscount: configuration.secondaryPatternDiscount
                    )
                    let remaining = max(0.0, totalHours - elapsedHours)
                    if remaining >= remainingMap[pattern]!.remainingHours && remaining > 0 {
                        remainingMap[pattern] = (remaining, session.endDate)
                    } else if remainingMap[pattern]!.remainingHours == 0 {
                        remainingMap[pattern] = (0.0, session.endDate)
                    }
                }
            }
        }
        
        var result: [MovementPattern: MuscleCooldownStatus] = [:]
        for (pattern, data) in remainingMap {
            result[pattern] = MuscleCooldownStatus(
                pattern: pattern,
                remainingHours: data.remainingHours,
                lastStimulatedDate: data.lastDate
            )
        }
        return result
    }
}
