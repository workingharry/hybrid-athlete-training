import Foundation

/// 今日營養膠囊視圖輸入模型 (純 Swift Core，無 UI 依賴)
public struct NutritionCapsuleViewModel: Equatable, Sendable {
    public let consumedKcal: Double
    public let targetKcal: Double
    public let proteinGrams: Double
    public let targetProteinGrams: Double
    public let carbsGrams: Double
    public let targetCarbsGrams: Double
    public let mealsLoggedCount: Int
    public let dayType: TrainingDayType
    public let goal: BodyCompositionGoal
    
    public init(
        consumedKcal: Double = 0,
        targetKcal: Double = 2650,
        proteinGrams: Double = 0,
        targetProteinGrams: Double = 140,
        carbsGrams: Double = 0,
        targetCarbsGrams: Double = 280,
        mealsLoggedCount: Int = 0,
        dayType: TrainingDayType = .heavyStrength,
        goal: BodyCompositionGoal = .maximizeHypertrophy
    ) {
        self.consumedKcal = consumedKcal
        self.targetKcal = targetKcal
        self.proteinGrams = proteinGrams
        self.targetProteinGrams = targetProteinGrams
        self.carbsGrams = carbsGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.mealsLoggedCount = mealsLoggedCount
        self.dayType = dayType
        self.goal = goal
    }
}

/// 補給情境狀態 (FuelingPhase)
public enum FuelingPhase: Equatable, Sendable {
    case morningEmpty(dayTitle: String)       // 晨間未記錄 (0 餐)
    case preWorkout(minutesUntil: Int)        // 練前補給窗口 (4 小時內)
    case postWorkoutGoldenWindow(minutesRemaining: Int) // 雙練日或長跑後黃金修復期
    case activeFueling                        // 日常補給中 (有記錄)
    case activeRestDay                        // 休息日蛋白質修復
    
    public var title: String {
        switch self {
        case .morningEmpty(let dayTitle):
            return "今日補給 · \(dayTitle)"
        case .preWorkout(let min):
            return "練前補給 (距開練 \(min) 分鐘)"
        case .postWorkoutGoldenWindow(let min):
            return "修復黃金窗口 (剩餘 \(min) 分鐘)"
        case .activeFueling:
            return "今日能量與營養"
        case .activeRestDay:
            return "恢復日修復"
        }
    }
    
    public var iconName: String {
        switch self {
        case .morningEmpty: return "sunrise.fill"
        case .preWorkout: return "bolt.fill"
        case .postWorkoutGoldenWindow: return "figure.cooldown"
        case .activeFueling: return "fork.knife"
        case .activeRestDay: return "moon.zzz.fill"
        }
    }
    
    public var hexColor: String {
        switch self {
        case .morningEmpty: return "20B2AA" // Teal
        case .preWorkout: return "FF9F0A"   // Energy Orange
        case .postWorkoutGoldenWindow: return "3FB950" // Green
        case .activeFueling: return "58A6FF" // Accent Blue
        case .activeRestDay: return "79C0FF" // Soft Blue
        }
    }
}

/// 補給情境解析器 (FuelingPhaseResolver)
public enum FuelingPhaseResolver {
    public static func resolve(
        now: Date = Date(),
        dayType: TrainingDayType,
        mealsLogged: Int,
        isWithinTwoHoursPostWorkout: Bool = false,
        postWorkoutMinutesLeft: Int = 90,
        minutesUntilWorkout: Int? = nil
    ) -> FuelingPhase {
        if isWithinTwoHoursPostWorkout {
            return .postWorkoutGoldenWindow(minutesRemaining: postWorkoutMinutesLeft)
        }
        if let minUntil = minutesUntilWorkout, minUntil > 0 && minUntil <= 240 {
            return .preWorkout(minutesUntil: minUntil)
        }
        if mealsLogged == 0 {
            let dayName: String
            switch dayType {
            case .heavyStrength: dayName = "肌力增肌日"
            case .longRun: dayName = "高碳長跑日"
            case .twoADaySession: dayName = "雙練能量日"
            case .easyRunZone2: dayName = "基礎有氧日"
            case .activeRest: dayName = "主動修復日"
            }
            return .morningEmpty(dayTitle: dayName)
        }
        if dayType == .activeRest {
            return .activeRestDay
        }
        return .activeFueling
    }
}
