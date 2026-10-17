import Foundation

/// 訓練器材種類
public enum EquipmentType: String, Codable, CaseIterable, Sendable {
    case barbell     // 槓鈴
    case dumbbell    // 啞鈴
    case cable       // 滑輪纜繩
    case machine     // 固定器械
    case bodyweight  // 自重 / 負重自重
    
    public var displayName: String {
        switch self {
        case .barbell: return "槓鈴"
        case .dumbbell: return "啞鈴"
        case .cable: return "滑輪纜繩"
        case .machine: return "固定器械"
        case .bodyweight: return "自重"
        }
    }
}

/// 阻力重量訓練具體動作實體
public struct ResistanceExercise: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String                              // 中文名稱 (如 "槓鈴後深蹲")
    public let englishName: String                       // 英文名稱 (如 "Barbell Back Squat")
    public let pattern: MovementPattern                  // 4 大動作模式
    public let equipment: EquipmentType                  // 主要器材
    public let primaryMuscles: [String]                  // 主要訓練肌群 (如 ["股四頭肌", "臀大肌"])
    public let techniqueCues: String                     // 動作核心提示
    public let defaultSets: Int                          // FITT 預設組數 (如 4)
    public let defaultReps: Int                          // FITT 預設次數 (如 8)
    public let defaultRepRange: String                   // FITT 建議區間 (如 "3-5 組 x 6-8 次")
    
    public init(
        id: UUID = UUID(),
        name: String,
        englishName: String,
        pattern: MovementPattern,
        equipment: EquipmentType,
        primaryMuscles: [String],
        techniqueCues: String,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultRepRange: String = "3-4 組 x 8-12 次"
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.pattern = pattern
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.techniqueCues = techniqueCues
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultRepRange = defaultRepRange
    }
}
