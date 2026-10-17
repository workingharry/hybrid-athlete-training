import XCTest
@testable import HybridTrainingCore

final class MultiDisciplineExerciseBankTests: XCTestCase {

    func testExerciseBankContainsPushUpAndHighPullAndExternalRotation() {
        let pushUp = ResistanceExerciseBank.allExercises.first { $0.name == "標準伏地挺身" }
        XCTAssertNotNil(pushUp, "動作庫必須包含標準伏地挺身")
        XCTAssertEqual(pushUp?.equipment, .bodyweight)
        XCTAssertEqual(pushUp?.pattern, .upperPush)

        let highPull = ResistanceExerciseBank.allExercises.first { $0.name == "槓鈴高拉 (肩部高提拉)" }
        XCTAssertNotNil(highPull, "動作庫必須包含槓鈴高拉")
        XCTAssertEqual(highPull?.equipment, .barbell)
        XCTAssertEqual(highPull?.pattern, .upperPull)

        let externalRotation = ResistanceExerciseBank.allExercises.first { $0.name.contains("肩外旋") }
        XCTAssertNotNil(externalRotation, "動作庫必須包含肩外旋訓練")
    }

    func testExerciseBankDifferentiatesFreeWeightAndMachine() {
        let legPress = ResistanceExerciseBank.allExercises.first { $0.name.contains("腿推機") }
        XCTAssertNotNil(legPress)
        XCTAssertEqual(legPress?.equipment, .machine)

        let backSquat = ResistanceExerciseBank.allExercises.first { $0.name == "槓鈴後深蹲" }
        XCTAssertNotNil(backSquat)
        XCTAssertEqual(backSquat?.equipment, .barbell)

        let chestPressMachine = ResistanceExerciseBank.allExercises.first { $0.name.contains("坐姿器械推胸") }
        XCTAssertNotNil(chestPressMachine)
        XCTAssertEqual(chestPressMachine?.equipment, .machine)

        let benchPress = ResistanceExerciseBank.allExercises.first { $0.name == "平板槓鈴臥推" }
        XCTAssertNotNil(benchPress)
        XCTAssertEqual(benchPress?.equipment, .barbell)
    }

    func testFITTExecutionDetailWithRestTimeAndEquipment() {
        let detail = ExecutedExerciseDetail(
            exerciseName: "45度腿推機 (器械)",
            pattern: .lowerQuad,
            equipment: .machine,
            sets: 4,
            reps: 12,
            weightKg: 160.0,
            restSeconds: 90
        )
        XCTAssertEqual(detail.summaryDescription, "4組 x 12次 @ 160kg (休90s)")
    }

    func testQuickLogDraftMultiDisciplineSessionCreation() {
        var cyclingDraft = QuickLogDraft(
            discipline: .cycling,
            durationMinutes: 45.0,
            sRPE: 6.0
        )
        let session = cyclingDraft.buildWorkoutSession()
        XCTAssertEqual(session.discipline, .cycling)
        XCTAssertEqual(session.durationMinutes, 45.0)
        XCTAssertEqual(session.sRPE, 6.0)
        XCTAssertEqual(session.loadAU, 270.0)
    }
}
