import Foundation

public typealias ResistanceEquipment = EquipmentType

/// 課表動作項目 (TemplateExerciseItem)
public struct TemplateExerciseItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var exerciseName: String
    public var pattern: MovementPattern
    public var equipment: ResistanceEquipment
    public var targetSets: Int
    public var targetReps: Int
    public var targetWeightKg: Double?
    public var targetRestSeconds: Int

    public init(
        id: UUID = UUID(),
        exerciseName: String,
        pattern: MovementPattern,
        equipment: ResistanceEquipment,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetWeightKg: Double? = nil,
        targetRestSeconds: Int = 90
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.pattern = pattern
        self.equipment = equipment
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetRestSeconds = targetRestSeconds
    }

    /// 轉換為執行明細
    public func toExecutedDetail(rpe: Double? = nil) -> ExecutedExerciseDetail {
        ExecutedExerciseDetail(
            exerciseName: exerciseName,
            pattern: pattern,
            equipment: equipment,
            sets: targetSets,
            reps: targetReps,
            weightKg: targetWeightKg,
            restSeconds: targetRestSeconds,
            rpe: rpe
        )
    }
}

/// 自訂課表範本 (WorkoutRoutineTemplate)
public struct WorkoutRoutineTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var discipline: TrainingDiscipline
    public var targetPatterns: [MovementPattern]
    public var exercises: [TemplateExerciseItem]
    public var estimatedDurationMinutes: Double
    public var defaultSRPE: Double
    public var notes: String
    public var isBuiltIn: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        discipline: TrainingDiscipline = .strength,
        targetPatterns: [MovementPattern] = [],
        exercises: [TemplateExerciseItem] = [],
        estimatedDurationMinutes: Double = 45.0,
        defaultSRPE: Double = 7.5,
        notes: String = "",
        isBuiltIn: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.discipline = discipline
        self.targetPatterns = targetPatterns
        self.exercises = exercises
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.defaultSRPE = defaultSRPE
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    /// 總預估目標組數
    public var totalTargetSets: Int {
        exercises.reduce(0) { $0 + $1.targetSets }
    }

    /// 總預估容量（若有填寫重量）
    public var estimatedVolumeKg: Double {
        exercises.reduce(0.0) { acc, item in
            guard let w = item.targetWeightKg, w > 0 else { return acc }
            return acc + (Double(item.targetSets * item.targetReps) * w)
        }
    }

    // MARK: - 內建精選混合運動員課表範本
    public static let builtInTemplates: [WorkoutRoutineTemplate] = [
        WorkoutRoutineTemplate(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "混合跑者下肢防護與推進",
            discipline: .strength,
            targetPatterns: [.lowerQuad, .lowerPosterior],
            exercises: [
                TemplateExerciseItem(
                    exerciseName: "槓鈴背蹲舉 (Barbell Back Squat)",
                    pattern: .lowerQuad,
                    equipment: .barbell,
                    targetSets: 4,
                    targetReps: 6,
                    targetWeightKg: 80.0,
                    targetRestSeconds: 120
                ),
                TemplateExerciseItem(
                    exerciseName: "羅馬尼亞硬舉 (RDL)",
                    pattern: .lowerPosterior,
                    equipment: .barbell,
                    targetSets: 3,
                    targetReps: 8,
                    targetWeightKg: 70.0,
                    targetRestSeconds: 90
                ),
                TemplateExerciseItem(
                    exerciseName: "保加利亞單腿蹲 (Bulgarian Split Squat)",
                    pattern: .lowerQuad,
                    equipment: .dumbbell,
                    targetSets: 3,
                    targetReps: 10,
                    targetWeightKg: 16.0,
                    targetRestSeconds: 90
                ),
                TemplateExerciseItem(
                    exerciseName: "仰臥機械腿彎舉 (Lying Leg Curl)",
                    pattern: .lowerPosterior,
                    equipment: .machine,
                    targetSets: 3,
                    targetReps: 12,
                    targetWeightKg: 45.0,
                    targetRestSeconds: 60
                )
            ],
            estimatedDurationMinutes: 50.0,
            defaultSRPE: 7.5,
            notes: "強化單腿平衡、前側鏈推進與膕旁肌離心抗傷耐力，保護膝蓋與阿基里斯腱。",
            isBuiltIn: true
        ),
        WorkoutRoutineTemplate(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "上肢推拉均衡與肩袖穩定",
            discipline: .strength,
            targetPatterns: [.upperPush, .upperPull],
            exercises: [
                TemplateExerciseItem(
                    exerciseName: "槓鈴平躺臥推 (Bench Press)",
                    pattern: .upperPush,
                    equipment: .barbell,
                    targetSets: 4,
                    targetReps: 8,
                    targetWeightKg: 65.0,
                    targetRestSeconds: 90
                ),
                TemplateExerciseItem(
                    exerciseName: "滑輪下拉 (Lat Pulldown)",
                    pattern: .upperPull,
                    equipment: .cable,
                    targetSets: 4,
                    targetReps: 10,
                    targetWeightKg: 55.0,
                    targetRestSeconds: 75
                ),
                TemplateExerciseItem(
                    exerciseName: "標準伏地挺身 (Push-Up)",
                    pattern: .upperPush,
                    equipment: .bodyweight,
                    targetSets: 3,
                    targetReps: 15,
                    targetWeightKg: 0.0,
                    targetRestSeconds: 60
                ),
                TemplateExerciseItem(
                    exerciseName: "繩索肩外旋 (Cable Shoulder External Rotation)",
                    pattern: .upperPull,
                    equipment: .cable,
                    targetSets: 3,
                    targetReps: 15,
                    targetWeightKg: 5.0,
                    targetRestSeconds: 45
                )
            ],
            estimatedDurationMinutes: 45.0,
            defaultSRPE: 7.0,
            notes: "改善久坐前傾圓肩，強化肩袖肌群外旋穩定度與背闊肌核心張力。",
            isBuiltIn: true
        ),
        WorkoutRoutineTemplate(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "全身複合混合力量 (Full Body Hybrid)",
            discipline: .strength,
            targetPatterns: [.upperPush, .upperPull, .lowerQuad, .lowerPosterior],
            exercises: [
                TemplateExerciseItem(
                    exerciseName: "傳統槓鈴硬舉 (Deadlift)",
                    pattern: .lowerPosterior,
                    equipment: .barbell,
                    targetSets: 3,
                    targetReps: 5,
                    targetWeightKg: 100.0,
                    targetRestSeconds: 150
                ),
                TemplateExerciseItem(
                    exerciseName: "槓鈴高拉 (Barbell High Pull)",
                    pattern: .upperPull,
                    equipment: .barbell,
                    targetSets: 4,
                    targetReps: 6,
                    targetWeightKg: 50.0,
                    targetRestSeconds: 90
                ),
                TemplateExerciseItem(
                    exerciseName: "站姿槓鈴肩推 (Overhead Press)",
                    pattern: .upperPush,
                    equipment: .barbell,
                    targetSets: 3,
                    targetReps: 8,
                    targetWeightKg: 40.0,
                    targetRestSeconds: 90
                ),
                TemplateExerciseItem(
                    exerciseName: "45度腿推機 (Leg Press)",
                    pattern: .lowerQuad,
                    equipment: .machine,
                    targetSets: 3,
                    targetReps: 12,
                    targetWeightKg: 140.0,
                    targetRestSeconds: 90
                )
            ],
            estimatedDurationMinutes: 55.0,
            defaultSRPE: 8.0,
            notes: "一網打盡 4 大動作模式，刺激全身中樞神經神經徵召與後側鏈爆發力。",
            isBuiltIn: true
        )
    ]
}
