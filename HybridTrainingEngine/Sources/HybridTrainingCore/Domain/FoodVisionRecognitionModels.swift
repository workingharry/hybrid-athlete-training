import Foundation

public struct FoodItemPrediction: Equatable, Codable, Sendable {
    public let foodName: String
    public let estimatedPortion: String
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let caffeineMg: Double
    public let confidence: Double
    public let reasoning: String

    public init(
        foodName: String,
        estimatedPortion: String = "1份",
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        caffeineMg: Double = 0.0,
        confidence: Double = 0.85,
        reasoning: String = ""
    ) {
        self.foodName = foodName
        self.estimatedPortion = estimatedPortion
        self.calories = max(0, calories)
        self.proteinGrams = max(0, proteinGrams)
        self.carbsGrams = max(0, carbsGrams)
        self.fatGrams = max(0, fatGrams)
        self.caffeineMg = max(0, caffeineMg)
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
    public let routedModel: String?      // 依據 free-router 規範：標註實際模型 (e.g. nvidia/nemotron-3.5-super-vl:free 或 Local Apple Vision)

    public init(
        items: [FoodItemPrediction],
        athleteAdvice: String? = nil,
        routedModel: String? = nil
    ) {
        self.items = items
        self.totalCalories = items.reduce(0) { $0 + $1.calories }
        self.totalProteinGrams = items.reduce(0) { $0 + $1.proteinGrams }
        self.totalCarbsGrams = items.reduce(0) { $0 + $1.carbsGrams }
        self.totalFatGrams = items.reduce(0) { $0 + $1.fatGrams }
        self.overallConfidence = items.isEmpty ? 0.0 : (items.reduce(0) { $0 + $1.confidence } / Double(items.count))
        self.athleteAdvice = athleteAdvice
        self.routedModel = routedModel
    }
}

/// 視覺分析引擎模式
public enum FoodVisionEngineMode: String, Sendable, Codable, CaseIterable {
    case autoHybrid       // 智慧混合 (優先調用 openrouter/free，壅塞/離線時自動降級本地 Apple Vision)
    case localOnly        // 100% 離線本地分析 (Apple Vision 神經引擎，完全免聯網)
    case customCloud      // 自訂雲端模型
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
