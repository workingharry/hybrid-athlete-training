import Foundation

public struct FoodItemPrediction: Equatable, Codable, Sendable {
    public let foodName: String
    public let estimatedPortion: String
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let confidence: Double
    public let reasoning: String

    public init(
        foodName: String,
        estimatedPortion: String = "1份",
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        confidence: Double = 0.85,
        reasoning: String = ""
    ) {
        self.foodName = foodName
        self.estimatedPortion = estimatedPortion
        self.calories = max(0, calories)
        self.proteinGrams = max(0, proteinGrams)
        self.carbsGrams = max(0, carbsGrams)
        self.fatGrams = max(0, fatGrams)
        self.confidence = min(max(0, confidence), 1.0)
        self.reasoning = reasoning
    }
}

public struct FoodRecognitionResult: Equatable, Codable, Sendable {
    public let items: [FoodItemPrediction]
    public let totalCalories: Double
    public let totalProteinGrams: Double
    public let totalCarbsGrams: Double
    public let totalFatGrams: Double
    public let overallConfidence: Double
    public let athleteAdvice: String?

    public init(
        items: [FoodItemPrediction],
        athleteAdvice: String? = nil
    ) {
        self.items = items
        self.totalCalories = items.reduce(0) { $0 + $1.calories }
        self.totalProteinGrams = items.reduce(0) { $0 + $1.proteinGrams }
        self.totalCarbsGrams = items.reduce(0) { $0 + $1.carbsGrams }
        self.totalFatGrams = items.reduce(0) { $0 + $1.fatGrams }
        self.overallConfidence = items.isEmpty ? 0.0 : (items.reduce(0) { $0 + $1.confidence } / Double(items.count))
        self.athleteAdvice = athleteAdvice
    }
}

public protocol FoodVisionRecognizerProtocol: Sendable {
    func recognizeFood(
        imageData: Data,
        mimeType: String
    ) async throws -> FoodRecognitionResult
}

public struct MockFoodVisionRecognizer: FoodVisionRecognizerProtocol {
    public let stubbedResult: FoodRecognitionResult

    public init(stubbedResult: FoodRecognitionResult) {
        self.stubbedResult = stubbedResult
    }

    public func recognizeFood(
        imageData: Data,
        mimeType: String
    ) async throws -> FoodRecognitionResult {
        return stubbedResult
    }
}
