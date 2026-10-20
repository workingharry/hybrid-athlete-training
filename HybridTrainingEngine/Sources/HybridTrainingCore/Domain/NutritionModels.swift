import Foundation

/// 每日飲食三大營養素與能量目標 (MacroTarget)
public struct MacroTarget: Equatable, Codable, Sendable {
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let waterMl: Double
    public let estimatedEA: Double            // 能量可用性 (kcal/kg FFM)
    public let isAnabolicEASafe: Bool         // 是否達到 EA >= 45 增肌充沛標準
    public let proteinPerMealSuggestionGrams: Double // 每餐建議蛋白質 (0.4~0.55 g/kg)
    public let recommendedMealCount: Int      // 建議餐次 (3~4 餐)
    public let guidanceNotes: [String]        // 循證引導說明
    
    public init(
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        waterMl: Double,
        estimatedEA: Double,
        isAnabolicEASafe: Bool,
        proteinPerMealSuggestionGrams: Double,
        recommendedMealCount: Int = 4,
        guidanceNotes: [String] = []
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.waterMl = waterMl
        self.estimatedEA = estimatedEA
        self.isAnabolicEASafe = isAnabolicEASafe
        self.proteinPerMealSuggestionGrams = proteinPerMealSuggestionGrams
        self.recommendedMealCount = recommendedMealCount
        self.guidanceNotes = guidanceNotes
    }
}

/// 訓練日型態 (決定碳水與能量補給需求)
public enum TrainingDayType: String, Codable, CaseIterable, Sendable {
    case heavyStrength   // 大重量肌力 (胸/背/腿)
    case longRun         // 週末長跑 (>=60 分鐘)
    case twoADaySession  // 雙練日 (力量 + 跑步)
    case easyRunZone2    // 輕鬆慢跑 / 恢復跑 (30~45 分鐘)
    case activeRest      // 完全休息日 / 活動度伸展
}

/// 運動員體態目標 (Goal)
public enum BodyCompositionGoal: String, Codable, CaseIterable, Sendable {
    case maximizeHypertrophy // 極大化增肌 (+5~10% 保守盈餘, 蛋白質 2.0g/kg, EA >= 45)
    case maintenance         // 體能維持 (能量平衡 0%, 蛋白質 1.8g/kg)
    case fatLossPreserve     // 減脂防掉肌 (-15% 赤字, 蛋白質 2.2~2.4g/kg, EA >= 30 護欄)
}

/// 餐點類別 (擴充練中果膠/補給)
public enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast    // 早餐
    case lunch        // 午餐
    case dinner       // 晚餐
    case snack        // 點心 / 加餐
    case preWorkout   // 練前補給 (1~2h 前)
    case intraWorkout // 練中能量膠 / 電解質水 (>60min)
    case postWorkout  // 練後黃金窗口 (30min 內)
}

/// 常用食物與餐點快照實體
public struct FoodItemSnapshot: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let sodiumMg: Double
    public let waterMl: Double
    public let isQuickAdd: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        sodiumMg: Double = 0,
        waterMl: Double = 0,
        isQuickAdd: Bool = false
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.sodiumMg = sodiumMg
        self.waterMl = waterMl
        self.isQuickAdd = isQuickAdd
    }
}
