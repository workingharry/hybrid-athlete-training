import SwiftUI
import PhotosUI
import HybridTrainingCore
import HybridTrainingStorage

public struct FoodRecognitionReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let initialResult: FoodRecognitionResult
    public let capturedImage: UIImage?
    public let onCommit: (FoodRecognitionResult) -> Void

    @State private var items: [EditableFoodItem]
    @State private var athleteAdvice: String?

    public init(
        initialResult: FoodRecognitionResult,
        capturedImage: UIImage? = nil,
        onCommit: @escaping (FoodRecognitionResult) -> Void
    ) {
        self.initialResult = initialResult
        self.capturedImage = capturedImage
        self.onCommit = onCommit
        self._items = State(initialValue: initialResult.items.map { EditableFoodItem(from: $0) })
        self._athleteAdvice = State(initialValue: initialResult.athleteAdvice)
    }

    private var totalCalories: Double {
        items.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        items.reduce(0) { $0 + $1.proteinGrams }
    }

    private var totalCarbs: Double {
        items.reduce(0) { $0 + $1.carbsGrams }
    }

    private var totalFat: Double {
        items.reduce(0) { $0 + $1.fatGrams }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 照片縮圖與整體熱量概覽
                        HStack(spacing: 14) {
                            if let image = capturedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "161B22"))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color(hex: "58A6FF"))
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI 視覺分析結果")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: "58A6FF"))

                                Text("\(Int(totalCalories)) kcal")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(.white)

                                HStack(spacing: 8) {
                                    nutrientPill(title: "蛋白", grams: totalProtein, colorHex: "58A6FF")
                                    nutrientPill(title: "碳水", grams: totalCarbs, colorHex: "FF9F0A")
                                    nutrientPill(title: "脂肪", grams: totalFat, colorHex: "3FB950")
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "161B22"))
                        .cornerRadius(14)

                        // 2. 混合運動員建議
                        if let advice = athleteAdvice, !advice.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "FF9F0A"))
                                    .padding(.top, 2)

                                Text(advice)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "C9D1D9"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "1C2128"))
                            .cornerRadius(10)
                        }

                        // 3. 食物項目明細與微調
                        VStack(alignment: .leading, spacing: 12) {
                            Text("辨識項目與數值微調")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)

                            ForEach($items) { $item in
                                itemEditorCard(item: $item)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("確認營養素記錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Color(hex: "8B949E"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("加入今日記錄") {
                        commitAndDismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "3FB950"))
                }
            }
        }
    }

    private func nutrientPill(title: String, grams: Double, colorHex: String) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "8B949E"))
            Text("\(Int(grams))g")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: colorHex))
        }
    }

    private func itemEditorCard(item: Binding<EditableFoodItem>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("食物名稱", text: item.foodName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(item.wrappedValue.estimatedPortion)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8B949E"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "21262D"))
                    .cornerRadius(4)
            }

            if !item.wrappedValue.reasoning.isEmpty {
                Text(item.wrappedValue.reasoning)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8B949E"))
            }

            Divider().background(Color(hex: "30363D"))

            // 數值調節列
            HStack(spacing: 12) {
                macroStepper(label: "熱量", unit: "kcal", value: item.calories, step: 20)
                macroStepper(label: "蛋白", unit: "g", value: item.proteinGrams, step: 5)
                macroStepper(label: "碳水", unit: "g", value: item.carbsGrams, step: 5)
                macroStepper(label: "脂肪", unit: "g", value: item.fatGrams, step: 2)
            }
        }
        .padding(14)
        .background(Color(hex: "161B22"))
        .cornerRadius(12)
    }

    private func macroStepper(label: String, unit: String, value: Binding<Double>, step: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "8B949E"))

            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Button(action: {
                    value.wrappedValue = max(0, value.wrappedValue - step)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: "21262D"))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    value.wrappedValue += step
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: "21262D"))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func commitAndDismiss() {
        let finalItems = items.map { item in
            FoodItemPrediction(
                foodName: item.foodName,
                estimatedPortion: item.estimatedPortion,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                confidence: item.confidence,
                reasoning: item.reasoning
            )
        }

        let finalResult = FoodRecognitionResult(
            items: finalItems,
            athleteAdvice: athleteAdvice
        )

        onCommit(finalResult)
        dismiss()
    }
}

public struct EditableFoodItem: Identifiable {
    public let id = UUID()
    public var foodName: String
    public var estimatedPortion: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double
    public var confidence: Double
    public var reasoning: String

    public init(from prediction: FoodItemPrediction) {
        self.foodName = prediction.foodName
        self.estimatedPortion = prediction.estimatedPortion
        self.calories = prediction.calories
        self.proteinGrams = prediction.proteinGrams
        self.carbsGrams = prediction.carbsGrams
        self.fatGrams = prediction.fatGrams
        self.confidence = prediction.confidence
        self.reasoning = prediction.reasoning
    }
}
