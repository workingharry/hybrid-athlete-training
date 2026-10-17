import XCTest
@testable import HybridTrainingCore

final class SmartMergeTests: XCTestCase {
    
    /// Phase 6 BDD Case 5: 雙重寫入 (Apple Watch + App 打卡) 50% 智慧合併去重
    func test_smartMerge_overlapsAbove50Percent_unifiesIntoSingleSession() {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 18, minute: 0))!
        let watchUUID = UUID()
        
        // Given: 18:00 ~ 18:50 手錶記錄傳統肌力 (50 分鐘, 平均心率 118 bpm)
        let watchSession = WorkoutSession(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(50 * 60),
            discipline: .strength,
            durationMinutes: 50.0,
            sRPE: 5.0, // 手錶無精準 RPE
            movementPatterns: [],
            source: .healthKitWorkout(hkUUID: watchUUID),
            averageHeartRate: 118.0
        )
        
        // When: 18:52 App 手動打卡 18:00 ~ 18:50 下肢後側鏈硬舉 (lowerPosterior, sRPE 8.0)
        let manualSession = WorkoutSession(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(50 * 60),
            discipline: .strength,
            durationMinutes: 50.0,
            sRPE: 8.0,
            movementPatterns: [.lowerPosterior],
            source: .manualLog
        )
        
        // Then 1: 重疊率為 100% >= 50%，觸發智慧合併
        let ratio = SmartMergeEngine.calculateOverlapRatio(
            startA: watchSession.startDate,
            endA: watchSession.endDate,
            startB: manualSession.startDate,
            endB: manualSession.endDate
        )
        XCTAssertEqual(ratio, 1.0, accuracy: 0.001)
        
        let merged = SmartMergeEngine.mergeIfOverlapping(
            watchSession: watchSession,
            manualSession: manualSession
        )
        XCTAssertNotNil(merged, "應成功合併")
        
        // Then 2: 來源溯源標記為 .smartMerged(hkUUID)
        XCTAssertEqual(merged?.source, .smartMerged(hkUUID: watchUUID))
        
        // Then 3: 負荷計算採手錶 50 分鐘 * App sRPE 8.0 = 400 AU，單一入帳
        XCTAssertEqual(merged?.durationMinutes, 50.0)
        XCTAssertEqual(merged?.sRPE, 8.0)
        XCTAssertEqual(merged?.loadAU, 400.0, "負荷應精準為 50m * 8.0 = 400 AU")
        XCTAssertEqual(merged?.movementPatterns, [.lowerPosterior], "應保留手動打卡之動作部位")
        XCTAssertEqual(merged?.averageHeartRate, 118.0, "應保留手錶之客觀心率")
        
        // 批次去重測試：最終去重清單中僅存在單一筆 400 AU 會話
        let deduplicated = SmartMergeEngine.processAndDeduplicate(sessions: [watchSession, manualSession])
        XCTAssertEqual(deduplicated.count, 1, "去重後歷史紀錄中僅能存在一筆訓練會話")
        XCTAssertEqual(deduplicated.first?.loadAU, 400.0, "單一會話負荷為 400 AU，絕不雙重累加")
    }
}
