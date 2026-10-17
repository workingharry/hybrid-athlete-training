import XCTest
@testable import HybridTrainingCore

final class TwoADayTests: XCTestCase {
    
    /// Phase 6 BDD Case 1: 一日兩練 (Two-a-Day Workouts) 雙軌累計與獨立冷卻
    func test_twoADay_accumulatesLoad_andMaintainsIndependentCooldown() {
        let calendar = Calendar.current
        let saturdayMorning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 8, minute: 0))!
        let saturdayAfternoon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 16, minute: 0))!
        
        // 1. 早上 08:00 長跑 (75分鐘, Zone 2, sRPE 4.0, 負荷 300 AU)
        let morningRun = WorkoutSession(
            startDate: saturdayMorning,
            endDate: saturdayMorning.addingTimeInterval(75 * 60),
            discipline: .running,
            durationMinutes: 75.0,
            sRPE: 4.0,
            movementPatterns: [.lowerQuad, .lowerPosterior],
            source: .healthKitWorkout(hkUUID: UUID()),
            zoneDurationsSeconds: [2: 75 * 60]
        )
        XCTAssertEqual(morningRun.loadAU, 300.0, "早晨跑步負荷應為 300 AU")
        
        // 2. 下午 16:00 (經過 8 小時) 完成上半身推 (45分鐘, sRPE 7.5, 負荷 337.5 AU)
        let afternoonPush = WorkoutSession(
            startDate: saturdayAfternoon.addingTimeInterval(-45 * 60),
            endDate: saturdayAfternoon,
            discipline: .strength,
            durationMinutes: 45.0,
            sRPE: 7.5,
            movementPatterns: [.upperPush],
            source: .manualLog
        )
        XCTAssertEqual(afternoonPush.loadAU, 337.5, "下午肌力負荷應為 337.5 AU")
        
        let sessions = [morningRun, afternoonPush]
        
        // Then 1: 當日總負荷累計
        let (atl, _, _) = ACWRCalculator.calculate(sessions: sessions, referenceDate: saturdayAfternoon, calendar: calendar)
        let saturdayDayLoad = sessions.map { $0.loadAU }.reduce(0, +)
        XCTAssertEqual(saturdayDayLoad, 637.5, accuracy: 0.001, "週六單日總負荷應精準累加為 637.5 AU")
        XCTAssertEqual(atl, 637.5 / 7.0, accuracy: 0.001, "7天 ATL 應採週六 637.5 AU 均分")
        
        // Then 2 & 3: 獨立冷卻時鐘計算 (於下午 16:00 檢視)
        let cooldowns = MuscleCooldownEngine.calculateCooldownStatuses(sessions: sessions, now: saturdayAfternoon)
        
        // 下午推舉產生 36 小時冷卻
        let pushRemaining = cooldowns[.upperPush]!.remainingHours
        XCTAssertEqual(pushRemaining, 36.0, accuracy: 0.1, "下午打卡 upperPush 應產生約 36 小時冷卻")
        
        // 早上長跑 75m 產生 48 小時冷卻，經過 8 小時後，剩餘冷卻應為 48 - 8 = 40 小時 (絕對不可被重置)
        let quadRemaining = cooldowns[.lowerQuad]!.remainingHours
        let posteriorRemaining = cooldowns[.lowerPosterior]!.remainingHours
        XCTAssertEqual(quadRemaining, 40.0, accuracy: 1.5, "lowerQuad 剩餘冷卻應保留約 40 小時")
        XCTAssertEqual(posteriorRemaining, 40.0, accuracy: 1.5, "lowerPosterior 剩餘冷卻應保留約 40 小時")
    }
}
