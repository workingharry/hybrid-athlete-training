import Foundation

/// 穩健生理統計與綜合準備度計算器
public struct RobustZScoreCalculator {
    
    /// 計算中位數
    public static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    /// 計算絕對離差中位數 (Median Absolute Deviation, MAD)
    public static func mad(of values: [Double], medianVal: Double) -> Double {
        guard !values.isEmpty else { return 2.0 }
        let absoluteDeviations = values.map { abs($0 - medianVal) }
        return median(of: absoluteDeviations) ?? 2.0
    }
    
    /// 計算 HRV 穩健 Z-score（設 2.0ms 保護下限）
    public static func calculateRobustHRVZScore(todayMs: Double, median14d: Double, mad14d: Double) -> Double {
        let effectiveMAD = max(mad14d, 2.0)
        let standardError = 1.4826 * effectiveMAD
        guard standardError > 0 else { return 0.0 }
        return (todayMs - median14d) / standardError
    }
    
    /// 昨夜睡眠總時長評分 (排除 inBed 後之純睡眠時長)
    public static func calculateSleepScore(durationHours: Double) -> Double {
        if durationHours >= 7.5 {
            return 100.0
        } else if durationHours >= 6.5 {
            return 80.0
        } else if durationHours >= 5.0 {
            return 55.0
        } else {
            return 30.0
        }
    }
    
    /// 綜合生理準備度雙層分數計算 (0~100 分與三色燈號)
    /// 依據 ADR 0005 與 Garmin 對標，在缺少 HRV 時動態放大睡眠權重
    public static func evaluateReadiness(
        snapshot: PhysiologicalSnapshot,
        acwr: Double
    ) -> (score: Double, grade: ReadinessGrade, confidence: MetricConfidence) {
        if snapshot.hasReportedPainOrInjury {
            return (0.0, .injured, .high)
        }
        
        let sleepScore = calculateSleepScore(durationHours: snapshot.sleepDurationHours)
        let confidence: MetricConfidence
        let hrvContribution: Double
        let sleepFactor: Double
        
        if let todayHRV = snapshot.hrvTodayMs,
           let medianHRV = snapshot.hrv14dMedianMs,
           let madHRV = snapshot.hrv14dMADMs {
            confidence = .high
            let zHRV = calculateRobustHRVZScore(todayMs: todayHRV, median14d: medianHRV, mad14d: madHRV)
            let clampedZ = min(max(zHRV, -2.5), 2.5)
            hrvContribution = 20.0 * clampedZ
            sleepFactor = 0.35
        } else {
            // 低信心度降級：HRV 項置零，睡眠權重動態重分配至 0.70 (對標 Garmin Fallback)
            confidence = .low
            hrvContribution = 0.0
            sleepFactor = 0.70
        }
        
        // DOMS 晨間自覺痠痛補償 (1: 極好 ~ 5: 極痛)
        var sorenessAdjustment = 0.0
        if let soreness = snapshot.morningSorenessRating {
            sorenessAdjustment = (3.0 - soreness) * 3.0 // 1分:+6分, 5分:-6分
        }
        
        let rawScore = 50.0 + hrvContribution + (sleepFactor * (sleepScore - 70.0)) - (15.0 * (acwr - 1.0)) + sorenessAdjustment
        let score = min(max(rawScore, 0.0), 100.0)
        
        let grade: ReadinessGrade
        if score >= 70.0 {
            grade = .ready
        } else if score >= 45.0 {
            grade = .moderate
        } else {
            grade = .fatigued
        }
        
        return (score, grade, confidence)
    }
}
