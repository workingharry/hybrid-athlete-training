import Foundation

/// 運動科學啟發式參數配置體 (可自訂且具備預設值)
public struct TrainingConfiguration: Codable, Equatable, Sendable {
    
    /// CTL 最小保護下限 (AU/day)
    public var ctlFloor: Double
    
    /// ACWR 啟發式提醒閾值 (增量注意, 顯著高負荷)
    public var acwrWarningThreshold: Double
    public var acwrHighLoadThreshold: Double
    
    /// 多部位打卡輔項折減係數
    public var secondaryPatternDiscount: Double
    
    /// 跑步對下肢長跑門檻分鐘數
    public var longRunThresholdMinutes: Double
    
    public init(
        ctlFloor: Double = 30.0,
        acwrWarningThreshold: Double = 1.3,
        acwrHighLoadThreshold: Double = 1.5,
        secondaryPatternDiscount: Double = 0.70,
        longRunThresholdMinutes: Double = 75.0
    ) {
        self.ctlFloor = ctlFloor
        self.acwrWarningThreshold = acwrWarningThreshold
        self.acwrHighLoadThreshold = acwrHighLoadThreshold
        self.secondaryPatternDiscount = secondaryPatternDiscount
        self.longRunThresholdMinutes = longRunThresholdMinutes
    }
    
    /// 預設工程啟發式參數 (Default Heuristics)
    public static let `default` = TrainingConfiguration()
}
