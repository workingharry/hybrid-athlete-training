import Foundation

/// 單日營養與活動量輸入模型 (純 Swift DTO，解耦 SwiftData)
public struct DailyNutritionLogInput: Sendable, Codable, Equatable {
    public let date: Date
    public let intakeKcal: Double
    public let loggedMealSlotsCount: Int
    public let isDayFinalized: Bool
    public let workoutActiveKcal: Double
    public let totalActiveKcal: Double

    public init(
        date: Date,
        intakeKcal: Double,
        loggedMealSlotsCount: Int,
        isDayFinalized: Bool = false,
        workoutActiveKcal: Double = 0.0,
        totalActiveKcal: Double = 0.0
    ) {
        self.date = date
        self.intakeKcal = intakeKcal
        self.loggedMealSlotsCount = loggedMealSlotsCount
        self.isDayFinalized = isDayFinalized
        self.workoutActiveKcal = workoutActiveKcal
        self.totalActiveKcal = totalActiveKcal
    }
}

/// 單日記錄完整性判定結果
public struct DayCompletenessResult: Sendable, Equatable {
    public let isComplete: Bool
    public let reason: String

    public init(isComplete: Bool, reason: String) {
        self.isComplete = isComplete
        self.reason = reason
    }
}

/// 符合 2023 IOC REDs CAT2 指南之滾動能量可用性計算器 (RollingEACalculator)
public struct RollingEACalculator: Sendable {

    public init() {}

    /// 計算有效運動能量消耗 (Effective EEE)
    /// 區分「結構化訓練 (HKWorkout)」與「非運動日常消耗 (NEAT)」，避免將走路逛街完全扣除導致過度低估 EA
    public func computeEffectiveEEE(workoutActiveKcal: Double, totalActiveKcal: Double) -> Double {
        let neatActiveKcal = max(0.0, totalActiveKcal - workoutActiveKcal)
        return workoutActiveKcal + 0.35 * neatActiveKcal
    }

    /// 評估單日飲食記錄是否完整 (Completeness Gate)
    /// 防止因用戶漏記晚餐或晚記導致 EA 瞬間崩跌觸發虛假的 RED-S 降載
    public func evaluateCompleteness(
        day: DailyNutritionLogInput,
        estimatedBMRKcal: Double,
        isIntermittentFastingEnabled: Bool
    ) -> DayCompletenessResult {
        if day.isDayFinalized {
            return DayCompletenessResult(isComplete: true, reason: "使用者主動標記當日記錄完畢/斷食")
        }

        let bmrThreshold = 0.75 * estimatedBMRKcal

        if isIntermittentFastingEnabled {
            // 一日一餐 (OMAD) 或間歇性斷食模式：只需總熱量達到基本門檻
            if day.intakeKcal >= bmrThreshold {
                return DayCompletenessResult(isComplete: true, reason: "符合間歇性斷食單餐熱量標準")
            } else {
                return DayCompletenessResult(isComplete: false, reason: "斷食日熱量低於 0.75x BMR 且未標記完成")
            }
        } else {
            // 標準模式：需至少記錄 2 個餐次且總熱量達 0.75x BMR
            if day.intakeKcal >= bmrThreshold && day.loggedMealSlotsCount >= 2 {
                return DayCompletenessResult(isComplete: true, reason: "滿足常規多餐覆蓋率與熱量門檻")
            } else {
                return DayCompletenessResult(isComplete: false, reason: "餐次少於2餐或熱量明顯偏低，疑為未完整記錄")
            }
        }
    }

    /// 計算過去至多 7 日之滾動能量可用性 (Rolling EA)
    /// 排除不完整記錄日，避免殘缺數據污染分母
    public func computeRollingEA(
        pastDays: [DailyNutritionLogInput],
        fatFreeMassKg: Double,
        estimatedBMRKcal: Double,
        isIntermittentFastingEnabled: Bool
    ) -> EAEstimate {
        guard fatFreeMassKg > 20.0 else {
            return EAEstimate(state: .insufficientDays, point: nil, completeDays: 0, excludedDays: pastDays.count)
        }

        var validDays: [DailyNutritionLogInput] = []
        var excludedCount = 0

        for day in pastDays {
            let completeness = evaluateCompleteness(
                day: day,
                estimatedBMRKcal: estimatedBMRKcal,
                isIntermittentFastingEnabled: isIntermittentFastingEnabled
            )
            if completeness.isComplete {
                validDays.append(day)
            } else {
                excludedCount += 1
            }
        }

        guard validDays.count >= 4 else {
            return EAEstimate(
                state: .insufficientDays,
                point: nil,
                completeDays: validDays.count,
                excludedDays: excludedCount
            )
        }

        var totalNetEnergy = 0.0
        for day in validDays {
            let effectiveEEE = computeEffectiveEEE(
                workoutActiveKcal: day.workoutActiveKcal,
                totalActiveKcal: day.totalActiveKcal
            )
            totalNetEnergy += max(0.0, day.intakeKcal - effectiveEEE)
        }

        let avgNetEnergy = totalNetEnergy / Double(validDays.count)
        let eaPoint = avgNetEnergy / fatFreeMassKg

        return EAEstimate(
            state: .estimated,
            point: eaPoint,
            lower: max(0.0, eaPoint - 5.0),
            upper: eaPoint + 5.0,
            completeDays: validDays.count,
            excludedDays: excludedCount
        )
    }
}
