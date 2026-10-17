import XCTest
@testable import HybridTrainingCore

final class DetrainingResetTests: XCTestCase {
    
    /// Phase 6 BDD Case 2: 長時間中斷重啟 (Detraining / Reset) 與 CTL 保護下限
    func test_detrainingReset_appliesCTLFloor_preventsDivisionByZero() {
        let calendar = Calendar.current
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 10, minute: 0))!
        
        // Given: 連續 28 天沒有任何運動 (Load = 0 AU)
        // When: 重啟訓練第一天，執行高強度訓練 (60m, sRPE 8.0, 負荷 480 AU)
        let restartWorkout = WorkoutSession(
            startDate: today.addingTimeInterval(-3600),
            endDate: today,
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 8.0,
            movementPatterns: [.lowerQuad],
            source: .manualLog
        )
        XCTAssertEqual(restartWorkout.loadAU, 480.0)
        
        let sessions = [restartWorkout]
        let (atl, ctl, acwr) = ACWRCalculator.calculate(
            sessions: sessions,
            referenceDate: today,
            calendar: calendar
        )
        
        // Then 1: CTL 保護下限生效 (CTL >= 30.0)
        let expectedATL = 480.0 / 7.0 // ~68.57 AU/day
        XCTAssertEqual(atl, expectedATL, accuracy: 0.01)
        XCTAssertEqual(ctl, 30.0, accuracy: 0.01, "CTL 應觸發 30.0 AU/day 保護下限常數")
        
        let expectedACWR = expectedATL / 30.0 // ~2.2857
        XCTAssertEqual(acwr, expectedACWR, accuracy: 0.05, "ACWR 應為 ~2.29 而非無限大或除以零")
        XCTAssertFalse(acwr.isInfinite, "ACWR 絕不可為無窮大")
        XCTAssertFalse(acwr.isNaN, "ACWR 絕不可為 NaN")
        
        // Then 2: Policy Engine 啟發式提醒生成
        let snapshot = PhysiologicalSnapshot(sleepDurationHours: 7.5)
        let decision = TrainingPolicyEngine.evaluateDailyDecision(
            history: sessions,
            snapshot: snapshot,
            now: today,
            calendar: calendar
        )
        
        XCTAssertTrue(decision.fatigueWarnings.contains(where: { $0.contains("ACWR") }), "應發出 ACWR 顯著偏高警告")
    }
}
