import XCTest
@testable import HybridTrainingCore

final class ResistanceExerciseBankTests: XCTestCase {
    
    func test_exerciseBank_containsAllFourMovementPatterns() {
        let quadExercises = ResistanceExerciseBank.exercises(for: .lowerQuad)
        let posteriorExercises = ResistanceExerciseBank.exercises(for: .lowerPosterior)
        let pushExercises = ResistanceExerciseBank.exercises(for: .upperPush)
        let pullExercises = ResistanceExerciseBank.exercises(for: .upperPull)
        
        XCTAssertFalse(quadExercises.isEmpty, "下肢膝主導動作不應為空")
        XCTAssertFalse(posteriorExercises.isEmpty, "下肢髖主導動作不應為空")
        XCTAssertFalse(pushExercises.isEmpty, "上半身推動作不應為空")
        XCTAssertFalse(pullExercises.isEmpty, "上半身拉動作不應為空")
        
        XCTAssertTrue(quadExercises.contains { $0.name.contains("深蹲") })
        XCTAssertTrue(posteriorExercises.contains { $0.name.contains("硬舉") })
        XCTAssertTrue(pushExercises.contains { $0.name.contains("臥推") })
        XCTAssertTrue(pullExercises.contains { $0.name.contains("划船") })
    }
    
    func test_exerciseSearch_findsRelevantExercises() {
        let squatResults = ResistanceExerciseBank.search(query: "深蹲")
        XCTAssertTrue(squatResults.count >= 3)
        
        let barbellResults = ResistanceExerciseBank.search(query: "槓鈴")
        XCTAssertFalse(barbellResults.isEmpty)
    }
    
    func test_executedExerciseDetail_summaryFormat() {
        let detail = ExecutedExerciseDetail(
            exerciseName: "槓鈴後深蹲",
            pattern: .lowerQuad,
            sets: 4,
            reps: 8,
            weightKg: 100.0,
            rpe: 8.0
        )
        
        XCTAssertEqual(detail.summaryDescription, "4組 x 8次 @ 100kg")
        
        let session = WorkoutSession(
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            discipline: .strength,
            durationMinutes: 60,
            sRPE: 8.0,
            movementPatterns: [.lowerQuad],
            executedExercises: [detail]
        )
        
        XCTAssertEqual(session.executedExercises.count, 1)
        XCTAssertEqual(session.executedExercises.first?.exerciseName, "槓鈴後深蹲")
        XCTAssertEqual(session.loadAU, 480.0)
    }

    func test_exerciseBank_containsBicepCurlAndFarmerCarries() {
        let bicepCurlDumbbell = ResistanceExerciseBank.allExercises.first { $0.name == "啞鈴二頭彎舉" }
        XCTAssertNotNil(bicepCurlDumbbell, "動作庫應包含啞鈴二頭彎舉")
        XCTAssertEqual(bicepCurlDumbbell?.pattern, .upperPull)
        XCTAssertEqual(bicepCurlDumbbell?.equipment, .dumbbell)

        let bicepCurlBarbell = ResistanceExerciseBank.allExercises.first { $0.name == "槓鈴二頭彎舉" }
        XCTAssertNotNil(bicepCurlBarbell, "動作庫應包含槓鈴二頭彎舉")
        XCTAssertEqual(bicepCurlBarbell?.pattern, .upperPull)
        XCTAssertEqual(bicepCurlBarbell?.equipment, .barbell)

        let farmerHold = ResistanceExerciseBank.allExercises.first { $0.name == "農夫靜態持重 (Farmer Hold)" }
        XCTAssertNotNil(farmerHold, "動作庫應包含農夫靜態持重")
        XCTAssertEqual(farmerHold?.pattern, .lowerPosterior)
        XCTAssertEqual(farmerHold?.equipment, .dumbbell)

        let farmerWalk = ResistanceExerciseBank.allExercises.first { $0.name == "負重農夫行走 (Farmer Walk)" }
        XCTAssertNotNil(farmerWalk, "動作庫應包含負重農夫行走")
        XCTAssertEqual(farmerWalk?.pattern, .lowerPosterior)
        XCTAssertEqual(farmerWalk?.equipment, .dumbbell)
    }

    func test_quickLogDraft_minimumDurationIsFiveMinutes() {
        XCTAssertEqual(QuickLogDraft.minDurationMinutes, 5.0)

        var draft = QuickLogDraft(durationMinutes: 3.0)
        XCTAssertEqual(draft.durationMinutes, 5.0, "低於 5 分鐘應被自動夾止在 5 分鐘")

        draft.adjustDuration(by: -10.0)
        XCTAssertEqual(draft.durationMinutes, 5.0, "向下調節不得低於 5 分鐘")

        draft.durationMinutes = 5.0
        XCTAssertEqual(draft.durationMinutes, 5.0)
    }
}
