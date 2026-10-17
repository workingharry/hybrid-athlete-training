// File: HybridTrainingEngine/Tests/HybridTrainingTests/QuickLogSheetTests.swift

import XCTest
import SwiftData
@testable import HybridTrainingCore
@testable import HybridTrainingStorage

final class QuickLogSheetTests: XCTestCase {

    // MARK: - 1. Pattern & Exercise Cascade Tests

    func testDefaultDraftState() {
        let sets: Int = 4
        let reps: Int = 6
        let exercise = ResistanceExerciseBank.exercises(for: .lowerQuad).first!
        XCTAssertEqual(exercise.name, "槓鈴後深蹲")
        XCTAssertEqual(exercise.defaultSets, sets)
        XCTAssertEqual(exercise.defaultReps, reps)
    }

    func testToggleExercisePopulatesDefaultFITTAndRoundTripsToSDWorkoutSession() throws {
        // 1. 準備 In-Memory SwiftData 容器
        let schema = Schema([SDWorkoutSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        // 2. 選取「槓鈴後深蹲」與「平板槓鈴臥推」
        let squat = try XCTUnwrap(ResistanceExerciseBank.exercises(for: .lowerQuad).first { $0.name == "槓鈴後深蹲" })
        let bench = try XCTUnwrap(ResistanceExerciseBank.exercises(for: .upperPush).first { $0.name == "平板槓鈴臥推" })

        var squatDetail = ExecutedExerciseDetail(
            exerciseName: squat.name,
            pattern: squat.pattern,
            sets: squat.defaultSets,
            reps: squat.defaultReps,
            weightKg: 100.0,
            rpe: 8.0
        )
        squatDetail.sets = 5 // 模擬使用者按 +1 步進鈕

        let benchDetail = ExecutedExerciseDetail(
            exerciseName: bench.name,
            pattern: bench.pattern,
            sets: bench.defaultSets,
            reps: bench.defaultReps,
            weightKg: nil, // 模擬選填不輸入重量
            rpe: 8.0
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let durationMinutes = 50.0
        let sRPE = 8.0

        let domainSession = WorkoutSession(
            startDate: now.addingTimeInterval(-durationMinutes * 60.0),
            endDate: now,
            discipline: .strength,
            durationMinutes: durationMinutes,
            sRPE: sRPE,
            movementPatterns: [.lowerQuad, .upperPush],
            executedExercises: [squatDetail, benchDetail],
            source: .manualLog
        )

        // 3. 寫入 SwiftData SDWorkoutSession
        let sdSession = SDWorkoutSession(domain: domainSession)
        context.insert(sdSession)
        try context.save()

        // 4. 從 SwiftData 讀取並驗證 FITT 明細完整序列化與反序列化
        let descriptor = FetchDescriptor<SDWorkoutSession>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)

        let restoredDomain = fetched[0].toDomain()
        XCTAssertEqual(restoredDomain.discipline, .strength)
        XCTAssertEqual(restoredDomain.durationMinutes, 50.0, accuracy: 0.001)
        XCTAssertEqual(restoredDomain.sRPE, 8.0, accuracy: 0.001)
        XCTAssertEqual(restoredDomain.loadAU, 400.0, accuracy: 0.001)
        XCTAssertEqual(Set(restoredDomain.movementPatterns), Set([.lowerQuad, .upperPush]))
        XCTAssertEqual(restoredDomain.executedExercises.count, 2)

        let restoredSquat = try XCTUnwrap(restoredDomain.executedExercises.first { $0.exerciseName == "槓鈴後深蹲" })
        XCTAssertEqual(restoredSquat.sets, 5)
        XCTAssertEqual(restoredSquat.reps, 6)
        XCTAssertEqual(restoredSquat.weightKg, 100.0)
        XCTAssertEqual(restoredSquat.summaryDescription, "5組 x 6次 @ 100kg")

        let restoredBench = try XCTUnwrap(restoredDomain.executedExercises.first { $0.exerciseName == "平板槓鈴臥推" })
        XCTAssertEqual(restoredBench.sets, 4)
        XCTAssertEqual(restoredBench.reps, 8)
        XCTAssertNil(restoredBench.weightKg)
        XCTAssertEqual(restoredBench.summaryDescription, "4組 x 8次")
    }

    // MARK: - 2. Edge Cases & Defensive Engineering Tests

    func testExecutedExerciseDetailSummaryFormattingEdgeCases() {
        // 小數點重量格式化 (如 22.5kg)
        let fractionalWeight = ExecutedExerciseDetail(
            exerciseName: "上斜啞鈴臥推",
            pattern: .upperPush,
            sets: 3,
            reps: 10,
            weightKg: 22.5
        )
        XCTAssertEqual(fractionalWeight.summaryDescription, "3組 x 10次 @ 22.5kg")

        // 零或負數重量不應輸出 @ 0kg
        let zeroWeight = ExecutedExerciseDetail(
            exerciseName: "引體向上 (正手/反手)",
            pattern: .upperPull,
            sets: 4,
            reps: 8,
            weightKg: 0.0
        )
        XCTAssertEqual(zeroWeight.summaryDescription, "4組 x 8次")
    }

    func testResistanceExerciseBankCoverageAcrossAllMovementPatterns() {
        for pattern in [MovementPattern.lowerQuad, .lowerPosterior, .upperPush, .upperPull] {
            let exercises = ResistanceExerciseBank.exercises(for: pattern)
            XCTAssertFalse(exercises.isEmpty, "部位 \(pattern) 必須包含預設阻力訓練動作")
            for ex in exercises {
                XCTAssertEqual(ex.pattern, pattern)
                XCTAssertGreaterThan(ex.defaultSets, 0)
                XCTAssertGreaterThan(ex.defaultReps, 0)
                XCTAssertFalse(ex.techniqueCues.isEmpty)
            }
        }
    }
}

