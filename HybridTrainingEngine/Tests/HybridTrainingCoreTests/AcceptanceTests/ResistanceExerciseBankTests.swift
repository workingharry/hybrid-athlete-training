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
}
