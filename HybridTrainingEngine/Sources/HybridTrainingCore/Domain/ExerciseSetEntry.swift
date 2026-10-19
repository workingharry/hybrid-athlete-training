import Foundation

/// 動作單組執行數據 (ExerciseSetEntry)
public struct ExerciseSetEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var setNumber: Int
    public var previousDescription: String?
    public var weightKg: Double
    public var reps: Int
    public var rir: Int?
    public var isCompleted: Bool
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        setNumber: Int,
        previousDescription: String? = nil,
        weightKg: Double = 0.0,
        reps: Int = 10,
        rir: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.previousDescription = previousDescription
        self.weightKg = weightKg
        self.reps = reps
        self.rir = rir
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    /// 估算單組容量 (Volume = Weight × Reps)
    public var volumeKg: Double {
        weightKg * Double(reps)
    }
}
