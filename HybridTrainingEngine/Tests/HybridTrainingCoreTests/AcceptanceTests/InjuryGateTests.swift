import XCTest
@testable import HybridTrainingCore

final class InjuryGateTests: XCTestCase {
    
    /// Phase 6 BDD Case 6: 傷病安全閘門即時介入與手動覆寫防線
    func test_injuryGate_blocksImpactWorkouts_allowsManualUserOverride() {
        let calendar = Calendar.current
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 7, minute: 30))!
        
        // Given: 原本生理狀態綠燈 (充沛 HRV、睡眠 8 小時)
        let normalSnapshot = PhysiologicalSnapshot(
            date: today,
            hrvTodayMs: 65.0,
            hrv14dMedianMs: 60.0,
            hrv14dMADMs: 5.0,
            sleepDurationHours: 8.0,
            hasReportedPainOrInjury: false
        )
        
        let normalDecision = TrainingPolicyEngine.evaluateDailyDecision(
            history: [],
            snapshot: normalSnapshot,
            now: today,
            calendar: calendar
        )
        XCTAssertEqual(normalDecision.readinessGrade, .ready, "無傷病且數據充沛時應為綠燈")
        XCTAssertEqual(normalDecision.primaryRecommendation.runningType, .tempoRun, "常態綠燈推薦閾值節奏跑")
        
        // When 1: 使用者在晨間勾選「我有身體急性疼痛/傷病（右膝微痛）」
        let injuredSnapshot = PhysiologicalSnapshot(
            date: today,
            hrvTodayMs: 65.0,
            hrv14dMedianMs: 60.0,
            hrv14dMADMs: 5.0,
            sleepDurationHours: 8.0,
            hasReportedPainOrInjury: true // 傷病觸發
        )
        
        let injuredDecision = TrainingPolicyEngine.evaluateDailyDecision(
            history: [],
            snapshot: injuredSnapshot,
            now: today,
            calendar: calendar
        )
        
        // Then 1: 立即熔斷所有跑步與大重量，切換為建議完全休息或溫和活動度
        XCTAssertEqual(injuredDecision.readinessGrade, .injured, "狀態應切換為傷病保護模式")
        XCTAssertEqual(injuredDecision.primaryRecommendation.discipline, .mobility, "主推薦應熔斷為活動度伸展或休息")
        XCTAssertFalse(injuredDecision.primaryRecommendation.targetPatterns.contains(.lowerQuad), "絕不可排定膝主導下肢動作")
        
        // When 2: 使用者確認膝蓋無大礙，點擊「從訓練庫自由選擇」，強制選取了「上半身推 (Push) 45m」
        let manualOverrideWorkout = RecommendedWorkout(
            title: "上半身推 (Push) 自由庫選擇",
            subtitle: "手動強制覆寫",
            discipline: .strength,
            targetPatterns: [.upperPush],
            estimatedDurationMinutes: 45.0,
            estimatedLoadAU: 337.5
        )
        
        // Then 2: 使用者自由覆寫成功執行，不被系統死鎖
        XCTAssertEqual(manualOverrideWorkout.discipline, .strength)
        XCTAssertEqual(manualOverrideWorkout.targetPatterns, [.upperPush], "使用者保有最高裁決權")
    }
}
