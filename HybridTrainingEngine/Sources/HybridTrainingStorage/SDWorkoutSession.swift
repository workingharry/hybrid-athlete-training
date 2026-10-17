import Foundation
import SwiftData
import HybridTrainingCore

/// 本機 SwiftData 持久化實體 (SDWorkoutSession)
@Model
public final class SDWorkoutSession {
    @Attribute(.unique) public var id: UUID
    public var startDate: Date
    public var endDate: Date
    public var disciplineRaw: String
    public var durationMinutes: Double
    public var sRPE: Double
    public var movementPatternsRaw: [String]
    public var sourceRaw: String
    public var sourceUUIDString: String?
    public var averageHeartRate: Double?
    public var loadAU: Double
    public var requiresManualRPEConfirmation: Bool
    public var executedExercisesJSON: Data?
    
    public init(domain: WorkoutSession) {
        self.id = domain.id
        self.startDate = domain.startDate
        self.endDate = domain.endDate
        self.disciplineRaw = domain.discipline.rawValue
        self.durationMinutes = domain.durationMinutes
        self.sRPE = domain.sRPE
        self.movementPatternsRaw = domain.movementPatterns.map { $0.rawValue }
        self.averageHeartRate = domain.averageHeartRate
        self.loadAU = domain.loadAU
        self.requiresManualRPEConfirmation = domain.requiresManualRPEConfirmation
        self.executedExercisesJSON = try? JSONEncoder().encode(domain.executedExercises)
        
        switch domain.source {
        case .healthKitWorkout(let uuid):
            self.sourceRaw = "healthKitWorkout"
            self.sourceUUIDString = uuid.uuidString
        case .manualLog:
            self.sourceRaw = "manualLog"
            self.sourceUUIDString = nil
        case .smartMerged(let uuid):
            self.sourceRaw = "smartMerged"
            self.sourceUUIDString = uuid.uuidString
        }
    }
    
    /// 轉換回純領域模型
    public func toDomain() -> WorkoutSession {
        let discipline = TrainingDiscipline(rawValue: disciplineRaw) ?? .running
        let patterns = movementPatternsRaw.compactMap { MovementPattern(rawValue: $0) }
        let executedExercises = (executedExercisesJSON.flatMap { try? JSONDecoder().decode([ExecutedExerciseDetail].self, from: $0) }) ?? []
        
        let source: SessionSource
        if let uuidStr = sourceUUIDString, let uuid = UUID(uuidString: uuidStr) {
            source = (sourceRaw == "smartMerged") ? .smartMerged(hkUUID: uuid) : .healthKitWorkout(hkUUID: uuid)
        } else {
            source = .manualLog
        }
        
        return WorkoutSession(
            id: id,
            startDate: startDate,
            endDate: endDate,
            discipline: discipline,
            durationMinutes: durationMinutes,
            sRPE: sRPE,
            movementPatterns: patterns,
            executedExercises: executedExercises,
            source: source,
            averageHeartRate: averageHeartRate,
            requiresManualRPEConfirmation: requiresManualRPEConfirmation
        )
    }
}
