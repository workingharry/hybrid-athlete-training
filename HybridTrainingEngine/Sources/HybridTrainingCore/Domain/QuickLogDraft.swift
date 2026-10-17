import Foundation

/// 訓練結束時間偏移選項
public enum QuickLogTimeOffset: Int, CaseIterable, Identifiable, Sendable {
    case justNow = 0
    case twoHoursAgo = 1
    case lastNight = 2

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .justNow: return "剛剛結束"
        case .twoHoursAgo: return "2小時前"
        case .lastNight: return "昨晚"
        }
    }

    /// 根據基準時間計算實際結束時間
    public func resolveEndDate(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .justNow:
            return referenceDate
        case .twoHoursAgo:
            return referenceDate.addingTimeInterval(-2.0 * 3600.0)
        case .lastNight:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
                  let lastNightDate = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday) else {
                return referenceDate.addingTimeInterval(-12.0 * 3600.0)
            }
            return lastNightDate
        }
    }
}

/// 負責管理 QuickLogSheet 的表單狀態與 FITT 動作連動邏輯（純領域模型）
public struct QuickLogDraft: Equatable, Sendable {
    public var discipline: TrainingDiscipline
    public var selectedPatterns: Set<MovementPattern>
    public var selectedExercises: [ExecutedExerciseDetail]
    public var weightTextMap: [String: String]
    public var durationMinutes: Double
    public var sRPE: Double
    public var timeOffset: QuickLogTimeOffset

    public static let minDurationMinutes: Double = 15.0
    public static let maxDurationMinutes: Double = 180.0
    public static let minSRPE: Double = 1.0
    public static let maxSRPE: Double = 10.0
    public static let minSets: Int = 1
    public static let maxSets: Int = 20
    public static let minReps: Int = 1
    public static let maxReps: Int = 100
    public static let minRestSeconds: Int = 0
    public static let maxRestSeconds: Int = 300
    public static let maxWeightKg: Double = 1000.0

    public init(
        discipline: TrainingDiscipline = .strength,
        selectedPatterns: Set<MovementPattern> = [.lowerQuad],
        selectedExercises: [ExecutedExerciseDetail] = [],
        weightTextMap: [String: String] = [:],
        durationMinutes: Double = 45.0,
        sRPE: Double = 7.5,
        timeOffset: QuickLogTimeOffset = .justNow
    ) {
        self.discipline = discipline
        self.selectedPatterns = selectedPatterns
        self.selectedExercises = selectedExercises
        self.weightTextMap = weightTextMap
        self.durationMinutes = min(Self.maxDurationMinutes, max(Self.minDurationMinutes, durationMinutes))
        self.sRPE = min(Self.maxSRPE, max(Self.minSRPE, sRPE))
        self.timeOffset = timeOffset
    }

    /// 計算 Foster 運動負荷貨幣 (Session Load in Arbitrary Units)
    public var calculatedLoadAU: Double {
        durationMinutes * sRPE
    }

    /// 估算已完成總組數
    public var totalCompletedSets: Int {
        selectedExercises.reduce(0) { $0 + ($1.sets ?? 0) }
    }

    /// 估算總訓練容量 (Volume Load = Sets * Reps * Weight)
    public var totalVolumeKg: Double {
        selectedExercises.reduce(0.0) { acc, item in
            guard let s = item.sets, let r = item.reps, let w = item.weightKg, w > 0 else {
                return acc
            }
            return acc + (Double(s * r) * w)
        }
    }

    /// 根據目前選取的動作模式，依固定順序回傳可用動作清單
    public var availableExercisesByPattern: [(pattern: MovementPattern, exercises: [ResistanceExercise])] {
        let orderedPatterns: [MovementPattern] = [.upperPush, .upperPull, .lowerQuad, .lowerPosterior]
        return orderedPatterns.compactMap { pattern in
            guard selectedPatterns.contains(pattern) else { return nil }
            let list = ResistanceExerciseBank.exercises(for: pattern)
            return list.isEmpty ? nil : (pattern, list)
        }
    }

    /// 切換訓練部位（取消勾選時自動清理該部位已選動作，但強制保留至少 1 個訓練部位）
    public mutating func togglePattern(_ pattern: MovementPattern) {
        if selectedPatterns.contains(pattern) {
            guard selectedPatterns.count > 1 else { return }
            selectedPatterns.remove(pattern)
            let removedNames = selectedExercises
                .filter { $0.pattern == pattern }
                .map(\.exerciseName)
            selectedExercises.removeAll { $0.pattern == pattern }
            for name in removedNames {
                weightTextMap.removeValue(forKey: name)
            }
        } else {
            selectedPatterns.insert(pattern)
        }
    }

    /// 檢查特定動作是否已被選取
    public func isExerciseSelected(_ exercise: ResistanceExercise) -> Bool {
        selectedExercises.contains { $0.exerciseName == exercise.name }
    }

    /// 切換特定阻力訓練動作晶片（選取時自動帶入 FITT 預設組數、次數、器材與預設休息秒數）
    public mutating func toggleExercise(_ exercise: ResistanceExercise) {
        if let index = selectedExercises.firstIndex(where: { $0.exerciseName == exercise.name }) {
            selectedExercises.remove(at: index)
            weightTextMap.removeValue(forKey: exercise.name)
        } else {
            selectedPatterns.insert(exercise.pattern)
            let detail = ExecutedExerciseDetail(
                exerciseName: exercise.name,
                pattern: exercise.pattern,
                equipment: exercise.equipment,
                sets: exercise.defaultSets,
                reps: exercise.defaultReps,
                weightKg: nil,
                restSeconds: exercise.defaultRestSeconds,
                rpe: sRPE
            )
            selectedExercises.append(detail)
        }
    }

    /// 調整特定動作的組數 (FITT: Sets)
    public mutating func adjustSets(for exerciseName: String, delta: Int) {
        guard let idx = selectedExercises.firstIndex(where: { $0.exerciseName == exerciseName }) else { return }
        let current = selectedExercises[idx].sets ?? 3
        let clamped = min(Self.maxSets, max(Self.minSets, current + delta))
        selectedExercises[idx].sets = clamped
    }

    /// 調整特定動作的次數 (FITT: Reps)
    public mutating func adjustReps(for exerciseName: String, delta: Int) {
        guard let idx = selectedExercises.firstIndex(where: { $0.exerciseName == exerciseName }) else { return }
        let current = selectedExercises[idx].reps ?? 10
        let clamped = min(Self.maxReps, max(Self.minReps, current + delta))
        selectedExercises[idx].reps = clamped
    }

    /// 調整特定動作的組間休息秒數 (FITT: Rest Time in seconds)
    public mutating func adjustRestSeconds(for exerciseName: String, delta: Int) {
        guard let idx = selectedExercises.firstIndex(where: { $0.exerciseName == exerciseName }) else { return }
        let current = selectedExercises[idx].restSeconds ?? 90
        let clamped = min(Self.maxRestSeconds, max(Self.minRestSeconds, current + delta))
        selectedExercises[idx].restSeconds = clamped
    }

    /// 更新特定動作的負重文字與數值 (支援選填、小數點、防呆負數與超大值過濾)
    public mutating func updateWeightText(_ rawText: String, for exerciseName: String) {
        weightTextMap[exerciseName] = rawText
        guard let idx = selectedExercises.firstIndex(where: { $0.exerciseName == exerciseName }) else { return }

        let sanitized = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !sanitized.isEmpty, let parsed = Double(sanitized), parsed.isFinite, parsed > 0 else {
            selectedExercises[idx].weightKg = nil
            return
        }

        let clamped = min(Self.maxWeightKg, (parsed * 10.0).rounded() / 10.0)
        selectedExercises[idx].weightKg = clamped
    }

    /// 調整訓練時長（步進防呆）
    public mutating func adjustDuration(by delta: Double) {
        let next = durationMinutes + delta
        durationMinutes = min(Self.maxDurationMinutes, max(Self.minDurationMinutes, next))
    }

    /// 更新整場 sRPE 並同步至各動作明細
    public mutating func updateSRPE(_ newValue: Double) {
        let clamped = min(Self.maxSRPE, max(Self.minSRPE, newValue))
        sRPE = clamped
        for index in selectedExercises.indices {
            selectedExercises[index].rpe = clamped
        }
    }

    /// 建構最終領域實體 `WorkoutSession`
    public func buildWorkoutSession(referenceDate: Date = Date(), calendar: Calendar = .current) -> WorkoutSession {
        let endDate = timeOffset.resolveEndDate(from: referenceDate, calendar: calendar)
        let clampedDuration = min(Self.maxDurationMinutes, max(Self.minDurationMinutes, durationMinutes))
        let startDate = endDate.addingTimeInterval(-clampedDuration * 60.0)

        let activePatternsFromExercises = Set(selectedExercises.map(\.pattern))
        let combinedPatterns = selectedPatterns.union(activePatternsFromExercises)
        let finalPatterns: [MovementPattern] = (discipline == .strength)
            ? (combinedPatterns.isEmpty ? [.lowerQuad] : Array(combinedPatterns).sorted { $0.rawValue < $1.rawValue })
            : []

        let finalizedExercises: [ExecutedExerciseDetail] = (discipline == .strength)
            ? selectedExercises.map { detail in
                var copy = detail
                if copy.rpe == nil {
                    copy.rpe = sRPE
                }
                return copy
            }
            : []

        return WorkoutSession(
            startDate: startDate,
            endDate: endDate,
            discipline: discipline,
            durationMinutes: clampedDuration,
            sRPE: sRPE,
            movementPatterns: finalPatterns,
            executedExercises: finalizedExercises,
            source: .manualLog
        )
    }
}
