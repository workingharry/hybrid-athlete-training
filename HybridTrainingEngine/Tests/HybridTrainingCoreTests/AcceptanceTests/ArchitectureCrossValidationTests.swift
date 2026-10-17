import XCTest
@testable import HybridTrainingCore

final class ArchitectureCrossValidationTests: XCTestCase {
    
    /// 驗證 Gemini 審查指出的邊界：休息日不應扭曲 28 天 CTL 分母 (滿 28 天跨度)
    func test_restDaysDoNotCorrupt28DayCTL() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = ISO8601DateFormatter().date(from: "2026-10-17T08:00:00Z")!
        
        // 模擬過去 28 天內，每週練 4 天 (每次 280 AU)、休 3 天
        var sessions: [WorkoutSession] = []
        for dayOffset in stride(from: 0, to: 28, by: 2) {
            let start = calendar.date(byAdding: .day, value: -dayOffset, to: refDate)!
            sessions.append(WorkoutSession(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(3600),
                discipline: .running,
                durationMinutes: 40.0,
                sRPE: 7.0, // 280 AU
                movementPatterns: [],
                source: .manualLog
            ))
        }
        
        // 補上第 27 天前（最早一筆，保證跨滿 28 天）
        let earliestStart = calendar.date(byAdding: .day, value: -27, to: refDate)!
        sessions.append(WorkoutSession(
            id: UUID(),
            startDate: earliestStart,
            endDate: earliestStart.addingTimeInterval(3600),
            discipline: .running,
            durationMinutes: 40.0,
            sRPE: 7.0,
            movementPatterns: [],
            source: .manualLog
        ))
        
        let (_, ctl, _) = ACWRCalculator.calculate(
            sessions: sessions,
            referenceDate: refDate,
            calendar: calendar,
            baselineCTL: 85.0 // 即使傳入初階 baseline，滿 28 天日曆跨度後也不應受冷啟動權重干擾
        )
        
        let totalLoad = sessions.map { $0.loadAU }.reduce(0, +)
        let expectedCTL = totalLoad / 28.0
        XCTAssertEqual(ctl, expectedCTL, accuracy: 0.01, "滿 28 天日曆跨度後，休息日不得導致 CTL 分母縮水")
    }
    
    /// 驗證 Best-Fit 匹配：一日兩練緊鄰時，精準匹配重疊率最高的那一組
    func test_bestFitSmartMergeMatchesHighestOverlapPair() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let watchUUID1 = UUID()
        let watchUUID2 = UUID()
        
        // Watch 1: 10:00 ~ 11:00 (60m)
        let watch1 = WorkoutSession(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 5.0,
            source: .healthKitWorkout(hkUUID: watchUUID1)
        )
        // Watch 2: 15:00 ~ 16:00 (60m)
        let watch2 = WorkoutSession(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(5 * 3600),
            endDate: baseDate.addingTimeInterval(6 * 3600),
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 5.0,
            source: .healthKitWorkout(hkUUID: watchUUID2)
        )
        
        // Manual 1: 10:05 ~ 10:55 (50m, 與 Watch 1 重疊 50m / 50m = 100%)
        let manual1 = WorkoutSession(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(300),
            endDate: baseDate.addingTimeInterval(3300),
            discipline: .strength,
            durationMinutes: 50.0,
            sRPE: 8.0,
            movementPatterns: [.upperPush],
            source: .manualLog
        )
        
        // Manual 2: 15:00 ~ 15:30 (30m, 與 Watch 2 重疊 30m / 30m = 100%)
        let manual2 = WorkoutSession(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(5 * 3600),
            endDate: baseDate.addingTimeInterval(5 * 3600 + 1800),
            discipline: .strength,
            durationMinutes: 30.0,
            sRPE: 7.0,
            movementPatterns: [.lowerQuad],
            source: .manualLog
        )
        
        let merged = SmartMergeEngine.processAndDeduplicate(sessions: [watch1, watch2, manual1, manual2])
        XCTAssertEqual(merged.count, 2, "兩場訓練皆應精準 Best-Fit 合併為 2 筆會話")
        
        let pushSession = merged.first(where: { $0.movementPatterns == [.upperPush] })
        XCTAssertEqual(pushSession?.source, .smartMerged(hkUUID: watchUUID1), "Manual 1 應精確匹配 Watch 1")
        
        let quadSession = merged.first(where: { $0.movementPatterns == [.lowerQuad] })
        XCTAssertEqual(quadSession?.source, .smartMerged(hkUUID: watchUUID2), "Manual 2 應精確匹配 Watch 2")
    }
}
