import XCTest
import Foundation
@testable import HybridTrainingCore

final class WeeklyScheduleEngineTests: XCTestCase {

    func testHypertrophyPriorityScheduleCharacteristics() {
        let plan = WeeklyScheduleEngine.schedule(for: .hypertrophyPriority)

        XCTAssertEqual(plan.items.count, 7)
        let strengthDays = plan.items.filter { $0.category == .strength }
        let runningDays = plan.items.filter { $0.category == .running }
        let recoveryDays = plan.items.filter { $0.category == .recovery }

        XCTAssertGreaterThanOrEqual(strengthDays.count, 5, "增肌優先應至少有 5 天肌力訓練")
        XCTAssertLessThanOrEqual(runningDays.count, 1, "增肌優先跑步應降至 1 天低強度輔助")
        XCTAssertGreaterThanOrEqual(recoveryDays.count, 1)
        XCTAssertTrue(plan.items.contains { $0.title.contains("推") })
        XCTAssertTrue(plan.items.contains { $0.title.contains("拉") })
        XCTAssertTrue(plan.items.contains { $0.title.contains("深蹲") || $0.title.contains("腿") })
    }

    func testBalancedScheduleCharacteristicsAndClashDetection() {
        let plan = WeeklyScheduleEngine.schedule(for: .balanced)

        XCTAssertEqual(plan.items.count, 7)
        let strengthDays = plan.items.filter { $0.category == .strength }
        let runningDays = plan.items.filter { $0.category == .running }

        XCTAssertEqual(strengthDays.count, 3, "平衡模式應有 3 天肌力訓練 (推/拉/腿)")
        XCTAssertEqual(runningDays.count, 2, "平衡模式應有 2 天跑步訓練 (輕鬆跑/長跑)")

        // 驗證週六長跑與週五腿日的軟性衝突偵測
        XCTAssertNotNil(plan.softClashSuggestion, "平衡模式應自動檢測週六長跑與週五腿日過近的運動學衝突")
        XCTAssertEqual(plan.softClashSuggestion?.title, "週六長跑與週五腿日太近")
        XCTAssertTrue(plan.items[5].hasWarning, "週六長跑項目應標註需留意警告")
    }

    func testRunningPriorityScheduleCharacteristics() {
        let plan = WeeklyScheduleEngine.schedule(for: .runningPriority)

        XCTAssertEqual(plan.items.count, 7)
        let runningDays = plan.items.filter { $0.category == .running }
        let strengthDays = plan.items.filter { $0.category == .strength }

        XCTAssertGreaterThanOrEqual(runningDays.count, 3, "跑步優先應至少有 3 天跑步訓練")
        XCTAssertTrue(plan.items.contains { $0.title.contains("長距離") || $0.title.contains("長跑") })
        XCTAssertTrue(plan.items.contains { $0.title.contains("間歇") || $0.title.contains("節奏") })
        XCTAssertLessThanOrEqual(strengthDays.count, 2, "跑步優先力量應集中於防護與核心維持")
    }

    func testSchedulesAreDistinctAcrossAllModes() {
        let hypertrophy = WeeklyScheduleEngine.schedule(for: .hypertrophyPriority)
        let balanced = WeeklyScheduleEngine.schedule(for: .balanced)
        let running = WeeklyScheduleEngine.schedule(for: .runningPriority)

        let hypertrophyTitles = hypertrophy.items.map(\.title)
        let balancedTitles = balanced.items.map(\.title)
        let runningTitles = running.items.map(\.title)

        XCTAssertNotEqual(hypertrophyTitles, balancedTitles, "增肌優先與平衡課表不應相同")
        XCTAssertNotEqual(balancedTitles, runningTitles, "平衡課表與跑步優先課表不應相同")
        XCTAssertNotEqual(hypertrophyTitles, runningTitles, "增肌優先與跑步優先課表不應相同")
    }
}
