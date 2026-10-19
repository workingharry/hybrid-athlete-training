import Foundation

/// 週訓練側重模式 (WeeklyFocusPreference)
public enum WeeklyFocusPreference: Int, CaseIterable, Codable, Sendable {
    case hypertrophyPriority = 0  // 增肌優先 (4-5天力量 + 1天輔助低心率跑)
    case balanced = 1             // 雙軌平衡 (3天力量 + 2-3天跑步)
    case runningPriority = 2      // 跑步優先 (3-4天跑步 + 2天肌力防護)

    public var displayName: String {
        switch self {
        case .hypertrophyPriority: return "增肌優先"
        case .balanced: return "平衡"
        case .runningPriority: return "跑步優先"
        }
    }
}

/// 課表類別
public enum ScheduleCategory: String, Codable, Sendable {
    case strength = "力量"
    case running = "跑步"
    case recovery = "恢復"
}

/// 每日課表排程條目
public struct DailyScheduleItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var dayOfWeek: String          // e.g. "一", "二", "三"...
    public var title: String              // e.g. "推：胸、肩、三頭"
    public var category: ScheduleCategory // .strength, .running, .recovery
    public var discipline: TrainingDiscipline
    public var tag: String                // e.g. "力量", "跑步", "需留意"
    public var hasWarning: Bool

    public init(
        id: UUID = UUID(),
        dayOfWeek: String,
        title: String,
        category: ScheduleCategory,
        discipline: TrainingDiscipline,
        tag: String? = nil,
        hasWarning: Bool = false
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.title = title
        self.category = category
        self.discipline = discipline
        self.tag = tag ?? category.rawValue
        self.hasWarning = hasWarning
    }
}

/// 相鄰高衝擊/疲勞衝突軟性建議
public struct SoftClashSuggestion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var badge: String
    public var explanation: String
    public var optionShortenTitle: String
    public var optionMoveTitle: String

    public init(
        id: UUID = UUID(),
        title: String,
        badge: String = "軟性建議",
        explanation: String,
        optionShortenTitle: String = "縮短為 70 分鐘",
        optionMoveTitle: String = "移到週日"
    ) {
        self.id = id
        self.title = title
        self.badge = badge
        self.explanation = explanation
        self.optionShortenTitle = optionShortenTitle
        self.optionMoveTitle = optionMoveTitle
    }
}

/// 一週排程完整計畫
public struct WeeklySchedulePlan: Equatable, Sendable {
    public let focus: WeeklyFocusPreference
    public var items: [DailyScheduleItem]
    public var softClashSuggestion: SoftClashSuggestion?

    public init(
        focus: WeeklyFocusPreference,
        items: [DailyScheduleItem],
        softClashSuggestion: SoftClashSuggestion? = nil
    ) {
        self.focus = focus
        self.items = items
        self.softClashSuggestion = softClashSuggestion
    }
}
