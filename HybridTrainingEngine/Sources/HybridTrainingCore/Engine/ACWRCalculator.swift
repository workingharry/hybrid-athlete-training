import Foundation

/// 急性與慢性負荷統計計算器 (7d Acute Load / 28d Chronic Load / ACWR)
public struct ACWRCalculator {
    
    /// CTL 最小保護下限 (AU/day)，防止除以零或冷啟動/中斷重啟暴衝
    public static let ctlFloor: Double = 30.0
    
    /// 計算給定參考時間點的 ATL、CTL 與 ACWR
    /// - Parameters:
    ///   - sessions: 訓練歷史會話清單
    ///   - referenceDate: 當前參考日期（支援時間注入以進行確定性測試）
    ///   - calendar: 日曆設定（預設本地日曆）
    ///   - baselineCTL: 冷啟動問卷基準（初階 85, 中階 170, 進階 255；若為 nil 則純依賴真實歷史）
    ///   - configuration: 啟發式參數配置 (預設 TrainingConfiguration.default)
    /// - Returns: (atl, ctl, acwr)
    public static func calculate(
        sessions: [WorkoutSession],
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        baselineCTL: Double? = nil,
        configuration: TrainingConfiguration = .default
    ) -> (atl: Double, ctl: Double, acwr: Double) {
        let normalizedRefDate = calendar.startOfDay(for: referenceDate)
        guard let endOfRefDay = calendar.date(byAdding: .day, value: 1, to: normalizedRefDate) else {
            return (0.0, configuration.ctlFloor, 0.0)
        }
        
        // 防護 1：嚴格過濾未來會話，杜絕歷史回測時發生 Data Leakage
        let validSessions = sessions.filter { $0.startDate < endOfRefDay }
        
        // 1. 將 Session 依日曆天分桶加總當日負荷
        var dailyLoadMap: [Date: Double] = [:]
        var earliestSessionDay: Date?
        
        for session in validSessions {
            let sessionDay = calendar.startOfDay(for: session.startDate)
            dailyLoadMap[sessionDay, default: 0.0] += session.loadAU
            if let currentEarliest = earliestSessionDay {
                if sessionDay < currentEarliest { earliestSessionDay = sessionDay }
            } else {
                earliestSessionDay = sessionDay
            }
        }
        
        // 2. 累加近 7 天單日總負荷 (含 referenceDate 當日)
        var last7DaysSum = 0.0
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: normalizedRefDate) {
                last7DaysSum += dailyLoadMap[date, default: 0.0]
            }
        }
        let atl = last7DaysSum / 7.0
        
        // 3. 累加近 28 天單日總負荷
        var last28DaysSum = 0.0
        for dayOffset in 0..<28 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: normalizedRefDate) {
                last28DaysSum += dailyLoadMap[date, default: 0.0]
            }
        }
        
        // 防護 2：以首筆紀錄距今的日曆跨度天數 (含休息日) 計算冷啟動權重 n
        let rawCTL: Double
        if let baseline = baselineCTL, let earliest = earliestSessionDay {
            let daysSinceFirstSession = (calendar.dateComponents([.day], from: earliest, to: normalizedRefDate).day ?? 0) + 1
            let activeSpanDays = min(max(daysSinceFirstSession, 1), 28)
            
            if activeSpanDays < 28 {
                let n = Double(activeSpanDays)
                let spanDailyAvg = last28DaysSum / n
                rawCTL = spanDailyAvg * (n / 28.0) + baseline * ((28.0 - n) / 28.0)
            } else {
                rawCTL = last28DaysSum / 28.0
            }
        } else if let baseline = baselineCTL, validSessions.isEmpty {
            rawCTL = baseline
        } else {
            rawCTL = last28DaysSum / 28.0
        }
        
        // 應用 CTL 保底機制
        let effectiveFloor = configuration.ctlFloor
        let ctl = max(rawCTL, effectiveFloor)
        let acwr = atl / ctl
        
        return (atl, ctl, acwr)
    }
}
