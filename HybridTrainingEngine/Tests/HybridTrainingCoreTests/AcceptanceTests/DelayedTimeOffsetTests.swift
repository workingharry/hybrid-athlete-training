import XCTest
@testable import HybridTrainingCore

final class DelayedTimeOffsetTests: XCTestCase {
    
    /// Phase 6 BDD Case 4: 跨夜延遲補打卡 (Time Offset) 剩餘冷卻回推精確性
    func test_delayedLog_anchorsToHistoricalEndTime_calculatesRemainingHours() {
        let calendar = Calendar.current
        
        // Given: 週五晚上 20:00 完成大重量深蹲 (sRPE 8.0, 產生 48 小時基礎冷卻)
        let fridayNight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 20, minute: 0))!
        let squatSession = WorkoutSession(
            startDate: fridayNight.addingTimeInterval(-3600), // 19:00 ~ 20:00
            endDate: fridayNight,
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 8.0,
            movementPatterns: [.lowerQuad],
            source: .manualLog
        )
        
        // When: 週六中午 12:00 (整整過去 16 個小時)，使用者開啟 App 補打卡並選擇「昨晚 20:00」
        let saturdayNoon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 12, minute: 0))!
        let elapsedHours = saturdayNoon.timeIntervalSince(fridayNight) / 3600.0
        XCTAssertEqual(elapsedHours, 16.0, accuracy: 0.001, "已過去時間應精準為 16 小時")
        
        // Then: 剩餘冷卻時間應精準為 48 - 16 = 32 小時
        let cooldowns = MuscleCooldownEngine.calculateCooldownStatuses(
            sessions: [squatSession],
            now: saturdayNoon
        )
        
        let quadStatus = cooldowns[.lowerQuad]!
        XCTAssertTrue(quadStatus.isFatigued, "週六中午深蹲肌群仍在冷卻中")
        XCTAssertEqual(quadStatus.remainingHours, 32.0, accuracy: 0.01, "當前剩餘冷卻應精確為 32 小時，而非從週六中午重置起算 48 小時")
        XCTAssertEqual(quadStatus.lastStimulatedDate, fridayNight, "前次刺激錨點應為週五 20:00")
    }
}
