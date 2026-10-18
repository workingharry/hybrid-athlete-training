import XCTest
import Foundation
@testable import HybridTrainingCore

final class WorkoutRoutineTemplateTests: XCTestCase {

    func testBuiltInTemplatesIntegrityAndEstimates() {
        let templates = WorkoutRoutineTemplate.builtInTemplates
        XCTAssertEqual(templates.count, 3, "應有 3 個預設內建範本")

        let lowerBody = templates[0]
        XCTAssertEqual(lowerBody.name, "混合跑者下肢防護與推進")
        XCTAssertEqual(lowerBody.discipline, .strength)
        XCTAssertTrue(lowerBody.isBuiltIn)
        XCTAssertEqual(lowerBody.exercises.count, 4)
        XCTAssertEqual(lowerBody.totalTargetSets, 13) // 4 + 3 + 3 + 3
        XCTAssertGreaterThan(lowerBody.estimatedVolumeKg, 1000.0)
    }

    func testApplyTemplateToQuickLogDraftPopulatesFITTAndState() {
        guard let template = WorkoutRoutineTemplate.builtInTemplates.first(where: { $0.name.contains("上肢推拉") }) else {
            XCTFail("找不到上肢推拉範本")
            return
        }

        var draft = QuickLogDraft()
        draft.applyTemplate(template)

        XCTAssertEqual(draft.discipline, .strength)
        XCTAssertEqual(draft.durationMinutes, template.estimatedDurationMinutes)
        XCTAssertEqual(draft.sRPE, template.defaultSRPE)
        XCTAssertEqual(draft.selectedExercises.count, template.exercises.count)
        XCTAssertTrue(draft.selectedPatterns.contains(.upperPush))
        XCTAssertTrue(draft.selectedPatterns.contains(.upperPull))

        // 驗證重量文字字典
        XCTAssertEqual(draft.weightTextMap["槓鈴平躺臥推 (Bench Press)"], "65")

        // 驗證生成的 WorkoutSession
        let session = draft.buildWorkoutSession()
        XCTAssertEqual(session.discipline, .strength)
        XCTAssertEqual(session.executedExercises.count, 4)
        XCTAssertEqual(session.durationMinutes, 45.0)
    }

    func testWeeklyHybridSummaryCalculation() {
        let calendar = Calendar.current
        let now = Date()

        // 模擬過去 7 天的訓練
        let run1 = WorkoutSession(
            startDate: now.addingTimeInterval(-86400 * 2),
            endDate: now.addingTimeInterval(-86400 * 2 + 3600),
            discipline: .running,
            durationMinutes: 60.0, // 估算 10 km
            sRPE: 7.0,
            movementPatterns: [],
            source: .manualLog
        )
        let run2 = WorkoutSession(
            startDate: now.addingTimeInterval(-86400 * 4),
            endDate: now.addingTimeInterval(-86400 * 4 + 3600),
            discipline: .running,
            durationMinutes: 60.0, // 估算 10 km
            sRPE: 7.0,
            movementPatterns: [],
            source: .manualLog
        )
        let strength1 = WorkoutSession(
            startDate: now.addingTimeInterval(-86400 * 1),
            endDate: now.addingTimeInterval(-86400 * 1 + 3000),
            discipline: .strength,
            durationMinutes: 50.0,
            sRPE: 8.0,
            movementPatterns: [.lowerQuad, .lowerPosterior],
            executedExercises: [
                ExecutedExerciseDetail(exerciseName: "Squat", pattern: .lowerQuad, equipment: .barbell, sets: 4, reps: 6, weightKg: 80.0),
                ExecutedExerciseDetail(exerciseName: "Deadlift", pattern: .lowerPosterior, equipment: .barbell, sets: 4, reps: 5, weightKg: 100.0)
            ],
            source: .manualLog
        )
        let strength2 = WorkoutSession(
            startDate: now.addingTimeInterval(-86400 * 3),
            endDate: now.addingTimeInterval(-86400 * 3 + 3000),
            discipline: .strength,
            durationMinutes: 45.0,
            sRPE: 7.5,
            movementPatterns: [.upperPush, .upperPull],
            executedExercises: [
                ExecutedExerciseDetail(exerciseName: "Bench Press", pattern: .upperPush, equipment: .barbell, sets: 4, reps: 8, weightKg: 60.0),
                ExecutedExerciseDetail(exerciseName: "Lat Pull", pattern: .upperPull, equipment: .cable, sets: 4, reps: 10, weightKg: 50.0)
            ],
            source: .manualLog
        )

        let summary = WeeklyHybridSummary.calculate(
            sessions: [run1, run2, strength1, strength2],
            referenceDate: now,
            calendar: calendar,
            enduranceTargetKm: 30.0,
            strengthTargetSets: 16
        )

        XCTAssertEqual(summary.weeklyEnduranceSessionsCount, 2)
        XCTAssertEqual(summary.weeklyEnduranceKm, 20.0)
        XCTAssertEqual(summary.weeklyStrengthSessionsCount, 2)
        XCTAssertEqual(summary.weeklyStrengthSetsCount, 16)
        XCTAssertEqual(summary.coveredPatterns.count, 4, "4大動作模式應全數覆蓋")
        XCTAssertEqual(summary.patternCoverageRatio, 1.0)
        XCTAssertGreaterThan(summary.weeklyStrengthTonnageKg, 5000.0)
        XCTAssertGreaterThanOrEqual(summary.balanceScore, 75.0)
    }
}
