import XCTest
@testable import HybridTrainingCore

final class FoodVisionRecognizerTests: XCTestCase {

    func test_foodItemPrediction_clampingAndNonNegativeValues() {
        let item = FoodItemPrediction(
            foodName: "香煎牛排",
            estimatedPortion: "200g",
            calories: -100,
            proteinGrams: -20,
            carbsGrams: -5,
            fatGrams: -10,
            confidence: 1.5,
            reasoning: "優質蛋白質"
        )

        XCTAssertEqual(item.calories, 0)
        XCTAssertEqual(item.proteinGrams, 0)
        XCTAssertEqual(item.carbsGrams, 0)
        XCTAssertEqual(item.fatGrams, 0)
        XCTAssertEqual(item.confidence, 1.0)
    }

    func test_foodRecognitionResult_aggregatesTotalsAndAveragesConfidence() {
        let items = [
            FoodItemPrediction(
                foodName: "雞胸肉",
                estimatedPortion: "150g",
                calories: 250,
                proteinGrams: 45,
                carbsGrams: 0,
                fatGrams: 4,
                confidence: 0.9,
                reasoning: "去皮低脂白肉"
            ),
            FoodItemPrediction(
                foodName: "糙米飯",
                estimatedPortion: "1碗 (200g)",
                calories: 220,
                proteinGrams: 5,
                carbsGrams: 46,
                fatGrams: 2,
                confidence: 0.8,
                reasoning: "複合碳水"
            )
        ]

        let result = FoodRecognitionResult(
            items: items,
            athleteAdvice: "訓練後高蛋白與充沛碳水補充，有助於肝醣回補與肌肉合成。"
        )

        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.totalCalories, 470, accuracy: 0.001)
        XCTAssertEqual(result.totalProteinGrams, 50, accuracy: 0.001)
        XCTAssertEqual(result.totalCarbsGrams, 46, accuracy: 0.001)
        XCTAssertEqual(result.totalFatGrams, 6, accuracy: 0.001)
        XCTAssertEqual(result.overallConfidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(result.athleteAdvice, "訓練後高蛋白與充沛碳水補充，有助於肝醣回補與肌肉合成。")
    }

    func test_mockFoodVisionRecognizer_decodesAndReturnsExpectedResult() async throws {
        let mockRecognizer = MockFoodVisionRecognizer(
            stubbedResult: FoodRecognitionResult(
                items: [
                    FoodItemPrediction(
                        foodName: "希臘優格佐藍莓",
                        estimatedPortion: "200g",
                        calories: 180,
                        proteinGrams: 20,
                        carbsGrams: 18,
                        fatGrams: 3,
                        confidence: 0.95,
                        reasoning: "富含酪蛋白與抗氧化花青素"
                    )
                ],
                athleteAdvice: "適合夜間補充的酪蛋白。"
            )
        )

        let dummyData = "fake_image_data".data(using: .utf8)!
        let result = try await mockRecognizer.recognizeFood(imageData: dummyData, mimeType: "image/jpeg")

        XCTAssertEqual(result.items.first?.foodName, "希臘優格佐藍莓")
        XCTAssertEqual(result.totalProteinGrams, 20)
        XCTAssertEqual(result.totalCalories, 180)
    }
}
