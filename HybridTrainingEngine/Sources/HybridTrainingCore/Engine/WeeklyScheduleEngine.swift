import Foundation

/// 週週期課表生成與運動學衝突分析引擎 (WeeklyScheduleEngine)
public struct WeeklyScheduleEngine {

    /// 根據運動員側重偏好生成對應的一週週期課表
    public static func schedule(for focus: WeeklyFocusPreference) -> WeeklySchedulePlan {
        switch focus {
        case .hypertrophyPriority:
            return generateHypertrophyPlan()
        case .balanced:
            return generateBalancedPlan()
        case .runningPriority:
            return generateRunningPlan()
        }
    }

    // MARK: - 1. 增肌優先課表 (5天肌力 + 1天輔助跑 + 1天休息)
    private static func generateHypertrophyPlan() -> WeeklySchedulePlan {
        let items: [DailyScheduleItem] = [
            DailyScheduleItem(dayOfWeek: "一", title: "上肢推：胸、肩、三頭", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "二", title: "下肢腿：深蹲、前側鏈", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "三", title: "上肢拉：背、二頭", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "四", title: "輕鬆跑 35 分鐘 · Zone 2", category: .running, discipline: .running),
            DailyScheduleItem(dayOfWeek: "五", title: "下肢髖：硬舉、後側鏈", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "六", title: "上肢弱點與肩袖補強", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "日", title: "完全休息 · 筋膜伸展", category: .recovery, discipline: .rest)
        ]
        return WeeklySchedulePlan(focus: .hypertrophyPriority, items: items, softClashSuggestion: nil)
    }

    // MARK: - 2. 雙軌平衡課表 (3天肌力 + 2天跑步 + 2天休息)
    private static func generateBalancedPlan() -> WeeklySchedulePlan {
        let items: [DailyScheduleItem] = [
            DailyScheduleItem(dayOfWeek: "一", title: "推：胸、肩、三頭", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "二", title: "輕鬆跑 40 分鐘 · Zone 2", category: .running, discipline: .running),
            DailyScheduleItem(dayOfWeek: "三", title: "拉：背、二頭", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "四", title: "完全休息 · 活動度伸展", category: .recovery, discipline: .mobility),
            DailyScheduleItem(dayOfWeek: "五", title: "腿：深蹲、硬舉", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "六", title: "長跑 90 分鐘", category: .running, discipline: .running, tag: "需留意", hasWarning: true),
            DailyScheduleItem(dayOfWeek: "日", title: "完全休息", category: .recovery, discipline: .rest)
        ]

        let clash = SoftClashSuggestion(
            title: "週六長跑與週五腿日太近",
            badge: "軟性建議",
            explanation: "相隔不足 24 小時，長跑屬高腿部負荷。你可以縮短、改日，或直接維持原計劃，引擎會記住你的選擇。",
            optionShortenTitle: "縮短為 70 分鐘",
            optionMoveTitle: "移到週日"
        )

        return WeeklySchedulePlan(focus: .balanced, items: items, softClashSuggestion: clash)
    }

    // MARK: - 3. 跑步優先課表 (3-4天跑步 + 2天防護肌力 + 1-2天恢復)
    private static func generateRunningPlan() -> WeeklySchedulePlan {
        let items: [DailyScheduleItem] = [
            DailyScheduleItem(dayOfWeek: "一", title: "Zone 2 有氧基底跑 50 分鐘", category: .running, discipline: .running),
            DailyScheduleItem(dayOfWeek: "二", title: "混合跑者下肢防護與單腿力量", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "三", title: "乳酸閾值節奏跑 45 分鐘", category: .running, discipline: .running),
            DailyScheduleItem(dayOfWeek: "四", title: "完全休息 · 筋膜放鬆", category: .recovery, discipline: .rest),
            DailyScheduleItem(dayOfWeek: "五", title: "上肢推拉核心與抗旋轉維持", category: .strength, discipline: .strength),
            DailyScheduleItem(dayOfWeek: "六", title: "週末長距離耐力跑 120 分鐘", category: .running, discipline: .running),
            DailyScheduleItem(dayOfWeek: "日", title: "Zone 1 超慢恢復跑 30 分鐘", category: .running, discipline: .running)
        ]
        return WeeklySchedulePlan(focus: .runningPriority, items: items, softClashSuggestion: nil)
    }
}
