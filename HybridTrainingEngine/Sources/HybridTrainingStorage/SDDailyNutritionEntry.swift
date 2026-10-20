import Foundation
import SwiftData

@Model
public final class SDDailyNutritionEntry {
    public var id: UUID
    public var timestamp: Date
    public var foodName: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double
    public var mealTypeRaw: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        foodName: String,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        mealTypeRaw: String = "general",
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.foodName = foodName
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.mealTypeRaw = mealTypeRaw
        self.notes = notes
    }
}
