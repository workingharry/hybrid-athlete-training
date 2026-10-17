import Foundation

/// Foster 統一運動負荷計算器
public struct FosterLoadCalculator {
    
    /// 各心率區間預設 Base RPE 對照 (包含 Zone 0 恢復區間)
    public static let baseRPEMap: [Int: Double] = [
        0: 1.0, // < 50% MaxHR: 熱身/動態恢復/步行
        1: 2.0, // 50% ~ 60% MaxHR: 極輕鬆恢復跑
        2: 3.5, // 60% ~ 70% MaxHR: 有氧基底耐力跑
        3: 5.5, // 70% ~ 80% MaxHR: 節奏跑 (Tempo)
        4: 7.5, // 80% ~ 90% MaxHR: 閾值/間歇衝刺 (Threshold)
        5: 9.5  // > 90% MaxHR: 無氧極限衝刺 (VO2 Max)
    ]
    
    /// 由各區間停留秒數推導加權 sRPE
    /// - Parameters:
    ///   - zoneDurationsSeconds: 字典 [Zone: 秒數]
    ///   - personalBias: 個人偏差校正項 (預設 0.0, 箝位於 -1.5 ~ +1.5)
    /// - Returns: 推導出的 sRPE (1.0 ~ 10.0)
    public static func deriveRunningRPE(
        zoneDurationsSeconds: [Int: Double],
        personalBias: Double = 0.0
    ) -> Double {
        let clampedBias = min(max(personalBias, -1.5), 1.5)
        let totalSeconds = zoneDurationsSeconds.values.reduce(0.0, +)
        guard totalSeconds > 0 else {
            return min(max(3.5 + clampedBias, 1.0), 10.0)
        }
        
        var weightedSum = 0.0
        for (zone, seconds) in zoneDurationsSeconds {
            let rpe = baseRPEMap[zone] ?? 3.5
            weightedSum += seconds * rpe
        }
        
        let baseDerivedRPE = weightedSum / totalSeconds
        let finalRPE = min(max(baseDerivedRPE + clampedBias, 1.0), 10.0)
        return finalRPE
    }
    
    /// 心率採樣資料結構
    public struct HeartRateSample: Sendable {
        public let date: Date
        public let bpm: Double
        
        public init(date: Date, bpm: Double) {
            self.date = date
            self.bpm = bpm
        }
    }
    
    /// 由離散心率樣本積分推導區間秒數與 sRPE（含 Case 3 脫落防呆與時間間隔箝位）
    /// - Parameters:
    ///   - samples: 心率採樣序列
    ///   - maxHR: 使用者最大心率
    ///   - totalWorkoutDurationSeconds: 手錶記錄的有效運動總秒數
    ///   - personalBias: 個人校正偏差
    /// - Returns: (推導 sRPE, 各區間秒數, 是否需手動確認)
    public static func calculateFromDiscreteHeartRateSamples(
        samples: [HeartRateSample],
        maxHR: Double,
        totalWorkoutDurationSeconds: Double,
        personalBias: Double = 0.0
    ) -> (derivedRPE: Double, zoneDurations: [Int: Double], requiresManualConfirmation: Bool) {
        guard !samples.isEmpty, maxHR > 0 else {
            return (3.5, [2: totalWorkoutDurationSeconds], true)
        }
        
        let sortedSamples = samples.sorted(by: { $0.date < $1.date })
        var zoneDurations: [Int: Double] = [0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        var totalCoveredSeconds = 0.0
        
        for i in 0..<(sortedSamples.count - 1) {
            let current = sortedSamples[i]
            let next = sortedSamples[i + 1]
            let rawDelta = next.date.timeIntervalSince(current.date)
            guard rawDelta > 0 else { continue }
            
            // 防呆上限箝位：單個間隔強制箝位 min(Δt, 15.0s)
            let deltaT = min(rawDelta, 15.0)
            totalCoveredSeconds += deltaT
            
            let hrPercentage = current.bpm / maxHR
            let zone = determineZone(for: hrPercentage)
            zoneDurations[zone, default: 0] += deltaT
        }
        
        // 有效心率覆蓋率檢驗：若有效覆蓋時間 < 50% 總時長，視為心率中斷失真
        let coverageRatio = totalWorkoutDurationSeconds > 0 ? (totalCoveredSeconds / totalWorkoutDurationSeconds) : 0.0
        let requiresManualConfirmation = coverageRatio < 0.50
        
        let finalRPE: Double
        if requiresManualConfirmation {
            // 降級以預設 Zone 2 RPE 3.5 暫存
            finalRPE = 3.5
        } else {
            finalRPE = deriveRunningRPE(zoneDurationsSeconds: zoneDurations, personalBias: personalBias)
        }
        
        return (finalRPE, zoneDurations, requiresManualConfirmation)
    }
    
    private static func determineZone(for hrPercentage: Double) -> Int {
        if hrPercentage < 0.50 { return 0 }
        if hrPercentage < 0.60 { return 1 }
        if hrPercentage < 0.70 { return 2 }
        if hrPercentage < 0.80 { return 3 }
        if hrPercentage < 0.90 { return 4 }
        return 5
    }
    
    /// 更新個人偏差 (近 10 次誤差之中位數，箝位於 -1.5 ~ +1.5)
    public static func updatePersonalBias(historicalErrors: [Double]) -> Double {
        guard historicalErrors.count >= 5 else { return 0.0 }
        let recentErrors = Array(historicalErrors.suffix(10)).sorted()
        let median: Double
        let count = recentErrors.count
        if count % 2 == 0 {
            median = (recentErrors[count / 2 - 1] + recentErrors[count / 2]) / 2.0
        } else {
            median = recentErrors[count / 2]
        }
        return min(max(median, -1.5), 1.5)
    }
}
