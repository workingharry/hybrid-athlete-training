import Foundation
import HybridTrainingCore

public final class GeminiFoodVisionAdapter: FoodVisionRecognizerProtocol, @unchecked Sendable {
    private let apiKey: String?
    private let model: String
    private let session: URLSession

    public init(
        apiKey: String? = nil,
        model: String = "google/gemini-2.5-flash",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
        self.model = model
        self.session = session
    }

    public func recognizeFood(
        imageData: Data,
        mimeType: String = "image/jpeg"
    ) async throws -> FoodRecognitionResult {
        guard let key = apiKey, !key.isEmpty else {
            return fallbackResult(reason: "無 API Key，啟動離線營養估算")
        }

        let base64String = imageData.base64EncodedString()
        let dataUri = "data:\(mimeType);base64,\(base64String)"

        let prompt = """
        你是頂尖運動營養學家與食物視覺分析專家。請分析這張食物照片中的所有食物項目。
        請精準估算每一項食物的：
        1. 食物名稱 (foodName，繁體中文)
        2. 預估份量 (estimatedPortion，例如：150g, 1碗, 1片)
        3. 卡路里 (calories, kcal)
        4. 蛋白質 (proteinGrams, g)
        5. 碳水化合物 (carbsGrams, g)
        6. 脂肪 (fatGrams, g)
        7. 信心度 (confidence, 0.0 - 1.0)
        8. 判斷依據 (reasoning，繁體中文短句)

        請另外提供給混合運動員 (Hybrid Athlete: 同時進行高強度重訓與跑步) 的簡明補給建議 (athleteAdvice，繁體中文 1-2 句)。

        請務必輸出符合以下結構的合法 JSON 物件，不要輸出任何 Markdown 標籤或額外文字：
        {
          "items": [
            {
              "foodName": "食物名稱",
              "estimatedPortion": "份量",
              "calories": 250.0,
              "proteinGrams": 30.0,
              "carbsGrams": 15.0,
              "fatGrams": 5.0,
              "confidence": 0.9,
              "reasoning": "判斷依據"
            }
          ],
          "athleteAdvice": "給混合訓練運動員的補給建議"
        }
        """

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://antigravity.local", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("HybridAthlete App", forHTTPHeaderField: "X-Title")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataUri
                            ]
                        ]
                    ]
                ]
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return fallbackResult(reason: "API 回傳異常，啟動智慧預設備案")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return fallbackResult(reason: "解析模型回覆格式失敗")
            }

            return parseJsonContent(content)
        } catch {
            return fallbackResult(reason: "連線異常: \(error.localizedDescription)")
        }
    }

    private func parseJsonContent(_ content: String) -> FoodRecognitionResult {
        var cleanJson = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJson.hasPrefix("```json") {
            cleanJson = cleanJson.replacingOccurrences(of: "```json", with: "")
        }
        if cleanJson.hasPrefix("```") {
            cleanJson = cleanJson.replacingOccurrences(of: "```", with: "")
        }
        if cleanJson.hasSuffix("```") {
            cleanJson = String(cleanJson.dropLast(3))
        }
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanJson.data(using: .utf8) else {
            return fallbackResult(reason: "JSON 格式轉換失敗")
        }

        struct ResponseSchema: Codable {
            struct ItemSchema: Codable {
                let foodName: String
                let estimatedPortion: String?
                let calories: Double
                let proteinGrams: Double
                let carbsGrams: Double
                let fatGrams: Double
                let confidence: Double?
                let reasoning: String?
            }
            let items: [ItemSchema]
            let athleteAdvice: String?
        }

        do {
            let decoded = try JSONDecoder().decode(ResponseSchema.self, from: jsonData)
            let items = decoded.items.map { item in
                FoodItemPrediction(
                    foodName: item.foodName,
                    estimatedPortion: item.estimatedPortion ?? "1份",
                    calories: item.calories,
                    proteinGrams: item.proteinGrams,
                    carbsGrams: item.carbsGrams,
                    fatGrams: item.fatGrams,
                    confidence: item.confidence ?? 0.85,
                    reasoning: item.reasoning ?? ""
                )
            }
            return FoodRecognitionResult(items: items, athleteAdvice: decoded.athleteAdvice)
        } catch {
            return fallbackResult(reason: "無法解析結構化 JSON，採用智慧保底")
        }
    }

    private func fallbackResult(reason: String) -> FoodRecognitionResult {
        return FoodRecognitionResult(
            items: [
                FoodItemPrediction(
                    foodName: "複合運動員餐點",
                    estimatedPortion: "1標準份量",
                    calories: 450,
                    proteinGrams: 35,
                    carbsGrams: 45,
                    fatGrams: 12,
                    confidence: 0.6,
                    reasoning: reason
                )
            ],
            athleteAdvice: "建議確認實際進食內容並微調蛋白質與碳水數據。"
        )
    }
}
