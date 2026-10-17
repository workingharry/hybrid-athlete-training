import XCTest
@testable import HybridTrainingCore

final class DirtyHeartRateTests: XCTestCase {
    
    /// Phase 6 BDD Case 3: 手錶心率脫落與超長暫停 (Dirty HealthKit Data) 防呆與自動填寫提醒
    func test_dirtyHeartRate_clampsDeltaT_andFlagsManualConfirmation() {
        let startTime = Date(timeIntervalSince1970: 1700000000)
        let totalWorkoutDurationSeconds: Double = 60 * 60 // 60 分鐘
        let maxHR: Double = 190.0
        
        var samples: [FosterLoadCalculator.HeartRateSample] = []
        
        // 1. 前 15 分鐘正常心率 (Zone 2, ~130 bpm, 每 5 秒一筆)
        for second in stride(from: 0, to: 15 * 60, by: 5) {
            samples.append(FosterLoadCalculator.HeartRateSample(
                date: startTime.addingTimeInterval(Double(second)),
                bpm: 130.0
            ))
        }
        
        // 2. 第 15~45 分鐘 (整整 30 分鐘) 心率脫落無任何樣本！
        // 3. 第 45 分鐘恢復了一筆 (Zone 2, 132 bpm)
        samples.append(FosterLoadCalculator.HeartRateSample(
            date: startTime.addingTimeInterval(45 * 60),
            bpm: 132.0
        ))
        
        // 執行積分推導
        let result = FosterLoadCalculator.calculateFromDiscreteHeartRateSamples(
            samples: samples,
            maxHR: maxHR,
            totalWorkoutDurationSeconds: totalWorkoutDurationSeconds,
            personalBias: 0.0
        )
        
        // Then 1 & 2: 有效心率覆蓋時間 < 50%，判定失真並標記需手動確認
        XCTAssertTrue(result.requiresManualConfirmation, "覆蓋率 < 50% 應標記需要手動確認體感 RPE")
        
        // Then 3: 降級以預設 Zone 2 RPE 3.5 暫存入帳
        XCTAssertEqual(result.derivedRPE, 3.5, accuracy: 0.1, "失真時應預設以 Zone 2 RPE 3.5 暫存")
    }
}
