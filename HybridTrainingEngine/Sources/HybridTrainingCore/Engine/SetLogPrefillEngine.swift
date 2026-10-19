import Foundation

/// 雙重進階建議模型
public struct DoubleProgressionSuggestion: Equatable, Sendable {
    public let shouldIncreaseWeight: Bool
    public let suggestedWeightKg: Double
    public let targetReps: Int
    public let explanation: String

    public init(
        shouldIncreaseWeight: Bool,
        suggestedWeightKg: Double,
        targetReps: Int,
        explanation: String
    ) {
        self.shouldIncreaseWeight = shouldIncreaseWeight
        self.suggestedWeightKg = suggestedWeightKg
        self.targetReps = targetReps
        self.explanation = explanation
    }
}

/// 歷史組數預填與雙重進階推算引擎 (SetLogPrefillEngine)
public struct SetLogPrefillEngine {

    /// 根據運動員過往歷史紀錄預填本次動作的逐組數值
    public static func prefillSets(
        for exerciseName: String,
        targetSetsCount: Int = 4,
        defaultWeightKg: Double = 60.0,
        defaultReps: Int = 8,
        history: [WorkoutSession]
    ) -> [ExerciseSetEntry] {
        // 依時間由新到舊排序
        let sortedHistory = history.sorted { $0.startDate > $1.startDate }

        // 搜尋最近一次包含該動作的訓練
        for session in sortedHistory {
            if let matched = session.executedExercises.first(where: { $0.exerciseName == exerciseName }) {
                // 1. 若上次有完整逐組紀錄
                if let pastSetsList = matched.setsList, !pastSetsList.isEmpty {
                    let completedPast = pastSetsList.filter(\.isCompleted)
                    let sourceSets = completedPast.isEmpty ? pastSetsList : completedPast

                    var result: [ExerciseSetEntry] = []
                    for idx in 0..<targetSetsCount {
                        let pastItem = idx < sourceSets.count ? sourceSets[idx] : sourceSets.last!
                        let weightStr = (pastItem.weightKg.truncatingRemainder(dividingBy: 1) == 0)
                            ? "\(Int(pastItem.weightKg))"
                            : String(format: "%.1f", pastItem.weightKg)
                        let desc = "\(weightStr) × \(pastItem.reps)"

                        result.append(
                            ExerciseSetEntry(
                                setNumber: idx + 1,
                                previousDescription: desc,
                                weightKg: pastItem.weightKg,
                                reps: pastItem.reps,
                                rir: nil,
                                isCompleted: false
                            )
                        )
                    }
                    return result
                }

                // 2. 若上次只有概要 FITT 數值
                if let w = matched.weightKg, let r = matched.reps {
                    let weightStr = (w.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(w))" : String(format: "%.1f", w)
                    let desc = "\(weightStr) × \(r)"

                    return (0..<targetSetsCount).map { idx in
                        ExerciseSetEntry(
                            setNumber: idx + 1,
                            previousDescription: desc,
                            weightKg: w,
                            reps: r,
                            rir: nil,
                            isCompleted: false
                        )
                    }
                }
            }
        }

        // 3. 無歷史紀錄時使用預設值
        return (0..<targetSetsCount).map { idx in
            ExerciseSetEntry(
                setNumber: idx + 1,
                previousDescription: nil,
                weightKg: defaultWeightKg,
                reps: defaultReps,
                rir: nil,
                isCompleted: false
            )
        }
    }

    /// 計算雙重進階建議 (Double Progression Rule)
    public static func calculateProgression(
        exerciseName: String,
        targetRepUpper: Int = 8,
        pastSets: [ExerciseSetEntry]
    ) -> DoubleProgressionSuggestion {
        guard !pastSets.isEmpty else {
            return DoubleProgressionSuggestion(
                shouldIncreaseWeight: false,
                suggestedWeightKg: 60.0,
                targetReps: targetRepUpper,
                explanation: "首次執行此動作，建立神經動作模式基線。"
            )
        }

        let completed = pastSets.filter(\.isCompleted)
        let setsToCheck = completed.isEmpty ? pastSets : completed
        let allHitUpperLimit = setsToCheck.allSatisfy { $0.reps >= targetRepUpper }
        let baseWeight = setsToCheck.map(\.weightKg).max() ?? 60.0

        if allHitUpperLimit {
            // 上次所有組數皆達到次數上限，觸發增重
            let weightStep: Double = (exerciseName.contains("硬舉") || exerciseName.contains("深蹲")) ? 5.0 : 2.5
            let newWeight = baseWeight + weightStep
            let weightStr = (baseWeight.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(baseWeight))" : String(format: "%.1f", baseWeight)
            let newWeightStr = (newWeight.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(newWeight))" : String(format: "%.1f", newWeight)

            return DoubleProgressionSuggestion(
                shouldIncreaseWeight: true,
                suggestedWeightKg: newWeight,
                targetReps: targetRepUpper,
                explanation: "上次 \(setsToCheck.count) × \(targetRepUpper) @ \(weightStr) kg，今天試 \(newWeightStr) kg，目標 \(targetRepUpper) 次"
            )
        } else {
            // 維持原重量，目標補足次數
            let weightStr = (baseWeight.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(baseWeight))" : String(format: "%.1f", baseWeight)
            return DoubleProgressionSuggestion(
                shouldIncreaseWeight: false,
                suggestedWeightKg: baseWeight,
                targetReps: targetRepUpper,
                explanation: "維持 \(weightStr) kg，目標將每組次數推滿至 \(targetRepUpper) 次。"
            )
        }
    }
}
