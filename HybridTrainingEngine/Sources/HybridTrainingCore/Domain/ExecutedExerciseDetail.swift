import Foundation

/// 動作級 FITT 執行明細記錄 (Frequency, Intensity, Time, Type)
public struct ExecutedExerciseDetail: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let exerciseName: String                      // 動作名稱 (如 "槓鈴後深蹲")
    public let pattern: MovementPattern                  // 所屬動作模式
    public let equipment: EquipmentType                  // 器材種類 (如 .barbell, .machine, .cable)
    public var sets: Int?                                // FITT: 組數 (如 4)
    public var reps: Int?                                // FITT: 每組次數 (如 8)
    public var weightKg: Double?                         // FITT: 負重重量 (如 100.0 kg)
    public var restSeconds: Int?                         // FITT: 組間休息秒數 (如 90)
    public var rpe: Double?                              // FITT: 動作級自覺強度 (如 8.0)
    
    public init(
        id: UUID = UUID(),
        exerciseName: String,
        pattern: MovementPattern,
        equipment: EquipmentType = .barbell,
        sets: Int? = 3,
        reps: Int? = 10,
        weightKg: Double? = nil,
        restSeconds: Int? = nil,
        rpe: Double? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.pattern = pattern
        self.equipment = equipment
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.restSeconds = restSeconds
        self.rpe = rpe
    }
    
    /// 簡潔格式化字串 (如 "槓鈴後深蹲 [槓鈴] 4組 x 8次 @ 100kg (休90s)")
    public var summaryDescription: String {
        var parts: [String] = []
        if let s = sets, let r = reps {
            parts.append("\(s)組 x \(r)次")
        } else if let s = sets {
            parts.append("\(s)組")
        } else if let r = reps {
            parts.append("\(r)次")
        }
        
        if let w = weightKg, w > 0 {
            let weightStr = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))kg" : String(format: "%.1fkg", w)
            parts.append("@ \(weightStr)")
        }
        
        if let rest = restSeconds, rest > 0 {
            parts.append("(休\(rest)s)")
        }
        
        return parts.joined(separator: " ")
    }
}
