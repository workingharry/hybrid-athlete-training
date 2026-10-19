import XCTest
import Foundation
@testable import HybridTrainingCore

final class SetBySetLoggingTests: XCTestCase {

    func testExerciseSetEntryInitializationAndEncoding() throws {
        let set1 = ExerciseSetEntry(
            setNumber: 1,
            previousDescription: "80 × 8",
            weightKg: 82.5,
            reps: 8,
            rir: 2,
            isCompleted: true
        )

        XCTAssertEqual(set1.setNumber, 1)
        XCTAssertEqual(set1.previousDescription, "80 × 8")
        XCTAssertEqual(set1.weightKg, 82.5)
        XCTAssertEqual(set1.reps, 8)
        XCTAssertEqual(set1.rir, 2)
        XCTAssertTrue(set1.isCompleted)

        let data = try JSONEncoder().encode(set1)
        let decoded = try JSONDecoder().decode(ExerciseSetEntry.self, from: data)
        XCTAssertEqual(decoded, set1)
    }

    func testExecutedExerciseDetailWithSetsList() {
        let sets = [
            ExerciseSetEntry(setNumber: 1, previousDescription: "80 × 8", weightKg: 82.5, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 2, previousDescription: "80 × 8", weightKg: 82.5, reps: 8, rir: 1, isCompleted: true),
            ExerciseSetEntry(setNumber: 3, previousDescription: "80 × 8", weightKg: 82.5, reps: 7, rir: 0, isCompleted: true)
        ]

        let detail = ExecutedExerciseDetail(
            exerciseName: "槓鈴平躺臥推",
            pattern: .upperPush,
            equipment: .barbell,
            setsList: sets
        )

        XCTAssertEqual(detail.sets, 3)
        XCTAssertEqual(detail.completedSetsCount, 3)
        XCTAssertEqual(detail.totalVolumeLoadKg, 82.5 * 8 + 82.5 * 8 + 82.5 * 7)
    }

    func testPrefillFromHistoricalSessions() {
        let pastDate = Date().addingTimeInterval(-86400 * 3)
        let pastSets = [
            ExerciseSetEntry(setNumber: 1, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 2, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 3, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 4, weightKg: 80.0, reps: 8, rir: 1, isCompleted: true)
        ]

        let pastDetail = ExecutedExerciseDetail(
            exerciseName: "槓鈴平躺臥推",
            pattern: .upperPush,
            equipment: .barbell,
            setsList: pastSets
        )

        let pastSession = WorkoutSession(
            startDate: pastDate,
            endDate: pastDate.addingTimeInterval(3600),
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 7.5,
            movementPatterns: [.upperPush],
            executedExercises: [pastDetail],
            source: .manualLog
        )

        let prefilledSets = SetLogPrefillEngine.prefillSets(
            for: "槓鈴平躺臥推",
            targetSetsCount: 4,
            defaultWeightKg: 60.0,
            defaultReps: 10,
            history: [pastSession]
        )

        XCTAssertEqual(prefilledSets.count, 4)
        XCTAssertEqual(prefilledSets[0].weightKg, 80.0)
        XCTAssertEqual(prefilledSets[0].reps, 8)
        XCTAssertEqual(prefilledSets[0].previousDescription, "80 × 8")
        XCTAssertFalse(prefilledSets[0].isCompleted)
    }

    func testDoubleProgressionSuggestion() {
        let pastSets = [
            ExerciseSetEntry(setNumber: 1, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 2, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 3, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true),
            ExerciseSetEntry(setNumber: 4, weightKg: 80.0, reps: 8, rir: 2, isCompleted: true)
        ]

        let suggestion = SetLogPrefillEngine.calculateProgression(
            exerciseName: "槓鈴平躺臥推",
            targetRepUpper: 8,
            pastSets: pastSets
        )

        XCTAssertTrue(suggestion.shouldIncreaseWeight)
        XCTAssertEqual(suggestion.suggestedWeightKg, 82.5)
        XCTAssertEqual(suggestion.targetReps, 8)
    }
}
