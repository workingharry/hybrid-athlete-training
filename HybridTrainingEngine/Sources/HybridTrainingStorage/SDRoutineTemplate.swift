import Foundation
import SwiftData
import HybridTrainingCore

/// 課表範本 SwiftData 持久化實體 (SDRoutineTemplate)
@Model
public final class SDRoutineTemplate {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var disciplineRaw: String
    public var targetPatternsRaw: [String]
    public var exercisesJSON: Data?
    public var estimatedDurationMinutes: Double
    public var defaultSRPE: Double
    public var notes: String
    public var isBuiltIn: Bool
    public var createdAt: Date

    public init(domain: WorkoutRoutineTemplate) {
        self.id = domain.id
        self.name = domain.name
        self.disciplineRaw = domain.discipline.rawValue
        self.targetPatternsRaw = domain.targetPatterns.map { $0.rawValue }
        self.exercisesJSON = try? JSONEncoder().encode(domain.exercises)
        self.estimatedDurationMinutes = domain.estimatedDurationMinutes
        self.defaultSRPE = domain.defaultSRPE
        self.notes = domain.notes
        self.isBuiltIn = domain.isBuiltIn
        self.createdAt = domain.createdAt
    }

    /// 轉換為純領域實體
    public func toDomain() -> WorkoutRoutineTemplate {
        let discipline = TrainingDiscipline(rawValue: disciplineRaw) ?? .strength
        let patterns = targetPatternsRaw.compactMap { MovementPattern(rawValue: $0) }
        let exercises = (exercisesJSON.flatMap { try? JSONDecoder().decode([TemplateExerciseItem].self, from: $0) }) ?? []

        return WorkoutRoutineTemplate(
            id: id,
            name: name,
            discipline: discipline,
            targetPatterns: patterns,
            exercises: exercises,
            estimatedDurationMinutes: estimatedDurationMinutes,
            defaultSRPE: defaultSRPE,
            notes: notes,
            isBuiltIn: isBuiltIn,
            createdAt: createdAt
        )
    }
}
