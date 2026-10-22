import XCTest
import Foundation
import SwiftData
@testable import HybridTrainingCore
@testable import HybridTrainingStorage

final class TrainingSessionStorageTests: XCTestCase {
    
    // MARK: - 1. 完整領域模型與 SwiftData 實體雙向保真 (Round-trip Fidelity)
    func testWorkoutSessionToSDWorkoutSessionRoundTrip() throws {
        let sessionID = UUID()
        let hkUUID = UUID()
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        
        let set1 = ExerciseSetEntry(
            setNumber: 1,
            previousDescription: "80kg x 8",
            weightKg: 85.0,
            reps: 8,
            rir: 2,
            isCompleted: true,
            completedAt: startDate.addingTimeInterval(600)
        )
        let set2 = ExerciseSetEntry(
            setNumber: 2,
            previousDescription: "80kg x 8",
            weightKg: 85.0,
            reps: 7,
            rir: 1,
            isCompleted: true,
            completedAt: startDate.addingTimeInterval(900)
        )
        
        let exerciseDetail = ExecutedExerciseDetail(
            exerciseName: "槓鈴臥推 (Barbell Bench Press)",
            pattern: .upperPush,
            equipment: .barbell,
            restSeconds: 120,
            setsList: [set1, set2]
        )
        
        let originalSession = WorkoutSession(
            id: sessionID,
            startDate: startDate,
            endDate: endDate,
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 8.5,
            movementPatterns: [.upperPush, .upperPull],
            executedExercises: [exerciseDetail],
            source: .smartMerged(hkUUID: hkUUID),
            averageHeartRate: 135.0,
            zoneDurationsSeconds: [1: 600.0, 2: 1800.0, 3: 1200.0],
            requiresManualRPEConfirmation: true
        )
        
        // 儲存至 SwiftData 實體
        let sdSession = SDWorkoutSession(domain: originalSession)
        
        XCTAssertEqual(sdSession.id, sessionID)
        XCTAssertEqual(sdSession.disciplineRaw, "strength")
        XCTAssertEqual(sdSession.durationMinutes, 60.0)
        XCTAssertEqual(sdSession.sRPE, 8.5)
        XCTAssertEqual(sdSession.loadAU, 510.0) // 60 * 8.5
        XCTAssertEqual(sdSession.sourceRaw, "smartMerged")
        XCTAssertEqual(sdSession.sourceUUIDString, hkUUID.uuidString)
        XCTAssertEqual(sdSession.averageHeartRate, 135.0)
        XCTAssertTrue(sdSession.requiresManualRPEConfirmation)
        XCTAssertNotNil(sdSession.executedExercisesJSON)
        XCTAssertNotNil(sdSession.zoneDurationsJSON)
        
        // 從 SwiftData 還原回 Domain 實體
        let restoredSession = sdSession.toDomain()
        
        XCTAssertEqual(restoredSession.id, originalSession.id)
        XCTAssertEqual(restoredSession.startDate, originalSession.startDate)
        XCTAssertEqual(restoredSession.endDate, originalSession.endDate)
        XCTAssertEqual(restoredSession.discipline, .strength)
        XCTAssertEqual(restoredSession.durationMinutes, 60.0)
        XCTAssertEqual(restoredSession.sRPE, 8.5)
        XCTAssertEqual(restoredSession.loadAU, 510.0)
        XCTAssertEqual(restoredSession.movementPatterns, [.upperPush, .upperPull])
        XCTAssertEqual(restoredSession.source, .smartMerged(hkUUID: hkUUID))
        XCTAssertEqual(restoredSession.averageHeartRate, 135.0)
        XCTAssertEqual(restoredSession.requiresManualRPEConfirmation, true)
        XCTAssertEqual(restoredSession.zoneDurationsSeconds?[2], 1800.0)
        
        // 驗證動作明細及組數
        XCTAssertEqual(restoredSession.executedExercises.count, 1)
        let restoredExercise = restoredSession.executedExercises[0]
        XCTAssertEqual(restoredExercise.exerciseName, "槓鈴臥推 (Barbell Bench Press)")
        XCTAssertEqual(restoredExercise.pattern, .upperPush)
        XCTAssertEqual(restoredExercise.equipment, .barbell)
        XCTAssertEqual(restoredExercise.restSeconds, 120)
        let sets = try XCTUnwrap(restoredExercise.setsList)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets[0].weightKg, 85.0)
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertEqual(sets[0].rir, 2)
        XCTAssertTrue(sets[0].isCompleted)
        XCTAssertEqual(sets[1].reps, 7)
    }
    
    // MARK: - 2. 記憶體內 SwiftData 容器 CRUD 完整流程
    @MainActor
    func testSwiftDataInMemoryContainerCRUD() throws {
        let schema = Schema([SDWorkoutSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        
        let now = Date()
        
        // Session 1: 力量訓練
        let session1 = WorkoutSession(
            id: UUID(),
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            discipline: .strength,
            durationMinutes: 60.0,
            sRPE: 7.0,
            movementPatterns: [.lowerQuad],
            executedExercises: [
                ExecutedExerciseDetail(
                    exerciseName: "槓鈴深蹲",
                    pattern: .lowerQuad,
                    equipment: .barbell,
                    restSeconds: 180,
                    setsList: [
                        ExerciseSetEntry(setNumber: 1, weightKg: 100, reps: 5, rir: 2, isCompleted: true)
                    ]
                )
            ],
            source: .manualLog
        )
        
        // Session 2: 節奏跑
        let session2 = WorkoutSession(
            id: UUID(),
            startDate: now.addingTimeInterval(-3600),
            endDate: now,
            discipline: .running,
            durationMinutes: 45.0,
            sRPE: 8.0,
            source: .healthKitWorkout(hkUUID: UUID()),
            averageHeartRate: 162.0
        )
        
        let sd1 = SDWorkoutSession(domain: session1)
        let sd2 = SDWorkoutSession(domain: session2)
        
        // 寫入 Context
        context.insert(sd1)
        context.insert(sd2)
        try context.save()
        
        // 查詢驗證
        let descriptor = FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let fetchedSessions = try context.fetch(descriptor)
        
        XCTAssertEqual(fetchedSessions.count, 2)
        // 最新結束的 session2 應排在前面
        XCTAssertEqual(fetchedSessions.first?.disciplineRaw, "running")
        XCTAssertEqual(fetchedSessions.last?.disciplineRaw, "strength")
        
        // 刪除操作
        if let toDelete = fetchedSessions.first(where: { $0.id == session1.id }) {
            context.delete(toDelete)
            try context.save()
        }
        
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, session2.id)
    }
    
    // MARK: - 3. 本機儲存訓練會話與 HealthKit 智慧合併防丟失
    func testSmartMergeIntegratesStoredManualSessionWithoutLoss() {
        let baseDate = Date().addingTimeInterval(-86400)
        
        // 手動記錄的力量訓練
        let manualSession = WorkoutSession(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            discipline: .strength,
            durationMinutes: 60,
            sRPE: 8.0,
            movementPatterns: [.upperPush],
            executedExercises: [
                ExecutedExerciseDetail(exerciseName: "臥推", pattern: .upperPush, equipment: .barbell)
            ],
            source: .manualLog
        )
        
        // 模擬手錶抓到的當日跑步
        let watchRunSession = WorkoutSession(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(7200),
            endDate: baseDate.addingTimeInterval(10800),
            discipline: .running,
            durationMinutes: 60,
            sRPE: 6.0,
            source: .healthKitWorkout(hkUUID: UUID()),
            averageHeartRate: 145.0
        )
        
        let sdManual = SDWorkoutSession(domain: manualSession)
        
        // 模擬 Logbook / Dashboard 從 SwiftData 取出後與 HealthKit 進行 SmartMerge
        let localSessions = [sdManual.toDomain()]
        let allSessions = localSessions + [watchRunSession]
        
        let merged = SmartMergeEngine.processAndDeduplicate(sessions: allSessions)
        
        // 兩者時間未重疊，兩場皆應完整保留
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.contains { $0.discipline == .strength && $0.executedExercises.first?.exerciseName == "臥推" })
        XCTAssertTrue(merged.contains { $0.discipline == .running && $0.averageHeartRate == 145.0 })
    }
    
    // MARK: - 4. 容錯性：損毀 JSON 或空欄位優雅降級
    func testCorruptedJSONGracefulDegradation() {
        let emptySession = SDWorkoutSession(
            domain: WorkoutSession(
                startDate: Date(),
                endDate: Date(),
                discipline: .mobility,
                durationMinutes: 20,
                sRPE: 3.0
            )
        )
        // 刻意將 JSON 欄位置空或無效
        emptySession.executedExercisesJSON = "invalid_data".data(using: .utf8)
        emptySession.zoneDurationsJSON = nil
        emptySession.sourceRaw = "unknown_source_string"
        emptySession.sourceUUIDString = nil
        
        let domain = emptySession.toDomain()
        
        XCTAssertEqual(domain.discipline, .mobility)
        XCTAssertEqual(domain.executedExercises, [])
        XCTAssertNil(domain.zoneDurationsSeconds)
        XCTAssertEqual(domain.source, .manualLog) // 優雅降級為 manualLog
    }
}
