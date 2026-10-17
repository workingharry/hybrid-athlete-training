import XCTest
@testable import HybridTrainingCore

final class HistoricalReplayEngineTests: XCTestCase {
    
    /// 驗證 Phase 1 核心功能：4~8 週逐日離線歷史回放與決策生成
    func test_historicalReplayEngineGeneratesSensibleDailyDecisions() {
        let calendar = Calendar.current
        // 2026-09-01 是一個星期二 (weekday == 3)
        let tuesdayStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 18, minute: 0))!
        
        // 模擬 4 週 (28 天) 混合訓練歷史：每週二練深蹲 (lowerQuad), 每週四練推 (upperPush), 每週六長跑 (running)
        var history: [WorkoutSession] = []
        for week in 0..<4 {
            // 週二 18:00~19:00 深蹲 (sRPE 8.0, 48h 基礎冷卻)
            let tuesday = calendar.date(byAdding: .day, value: week * 7, to: tuesdayStart)!
            history.append(WorkoutSession(
                id: UUID(),
                startDate: tuesday,
                endDate: tuesday.addingTimeInterval(3600),
                discipline: .strength,
                durationMinutes: 60.0,
                sRPE: 8.0,
                movementPatterns: [.lowerQuad],
                source: .manualLog
            ))
            
            // 週四 18:00~18:45 上半身推 (sRPE 7.5, 36h 基礎冷卻)
            let thursday = calendar.date(byAdding: .day, value: week * 7 + 2, to: tuesdayStart)!
            history.append(WorkoutSession(
                id: UUID(),
                startDate: thursday,
                endDate: thursday.addingTimeInterval(2700),
                discipline: .strength,
                durationMinutes: 45.0,
                sRPE: 7.5,
                movementPatterns: [.upperPush],
                source: .manualLog
            ))
            
            // 週六 08:00~09:20 長跑 (80分鐘, Zone 2, 48h 冷卻)
            let saturday = calendar.date(byAdding: .day, value: week * 7 + 4, to: tuesdayStart)!
            history.append(WorkoutSession(
                id: UUID(),
                startDate: saturday,
                endDate: saturday.addingTimeInterval(4800),
                discipline: .running,
                durationMinutes: 80.0,
                sRPE: 4.0,
                movementPatterns: [.lowerQuad, .lowerPosterior],
                source: .healthKitWorkout(hkUUID: UUID()),
                zoneDurationsSeconds: [2: 4800]
            ))
        }
        
        // 補上第 28 天的一筆輕度活動，確保覆蓋滿 28 天日曆跨度
        let finalDay = calendar.date(byAdding: .day, value: 27, to: tuesdayStart)!
        history.append(WorkoutSession(
            id: UUID(),
            startDate: finalDay,
            endDate: finalDay.addingTimeInterval(1800),
            discipline: .mobility,
            durationMinutes: 30.0,
            sRPE: 3.0,
            source: .manualLog
        ))
        
        let engine = HistoricalReplayEngine()
        let results = engine.replayHistoricalDays(history: history)
        
        XCTAssertGreaterThanOrEqual(results.count, 28, "4 週回放應至少包含 28 個決策日")
        
        // 驗證週二深蹲隔日 (週三早晨 07:00，經過 13 小時)：下肢必須處於冷卻中，且決策不能推薦高強度間歇跑
        let wednesdayResults = results.filter { result in
            let weekday = calendar.component(.weekday, from: result.date)
            return weekday == 4 // 週三
        }
        
        XCTAssertFalse(wednesdayResults.isEmpty, "應包含週三決策日")
        
        for wed in wednesdayResults {
            XCTAssertTrue(wed.wasLegCooldownActive, "深蹲隔日早晨下肢必須處於修復冷卻中")
            XCTAssertNotEqual(wed.decision.primaryRecommendation.runningType, .tempoRun, "下肢冷卻中不得推薦閾值節奏跑")
            XCTAssertNotEqual(wed.decision.primaryRecommendation.runningType, .intervalRun, "下肢冷卻中不得推薦高強度間歇衝刺")
        }
    }
}
