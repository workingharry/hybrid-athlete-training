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
                HybridTheme.background.ignoresSafeArea()

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
                                            .stroke(HybridTheme.cardBorder, lineWidth: 1)
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(HybridTheme.surfaceElevated)
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 28))
                                        .foregroundColor(HybridTheme.accentBlue)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text("AI 視覺分析結果")
                                        .font(HybridTheme.Typography.subheadline.weight(.bold))
                                        .foregroundColor(HybridTheme.accentBlue)
                                    
                                    if let model = initialResult.routedModel {
                                        Text(model)
                                            .font(HybridTheme.Typography.badge)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(HybridTheme.accentBlue.opacity(0.15))
                                            .foregroundColor(HybridTheme.accentBlue)
                                            .cornerRadius(6)
                                            .lineLimit(1)
                                    }
                                }

                                Text("\(Int(totalCalories)) kcal")
                                    .font(HybridTheme.Typography.metricHero)
                                    .foregroundColor(HybridTheme.textPrimary)

                                HStack(spacing: 8) {
                                    nutrientPill(title: "蛋白", grams: totalProtein, color: HybridTheme.accentBlue)
                                    nutrientPill(title: "碳水", grams: totalCarbs, color: HybridTheme.energyOrange)
                                    nutrientPill(title: "脂肪", grams: totalFat, color: HybridTheme.successGreen)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                        )

                        // 2. 混合運動員建議
                        if let advice = athleteAdvice, !advice.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(HybridTheme.energyOrange)
                                    .padding(.top, 2)

                                Text(advice)
                                    .font(HybridTheme.Typography.subheadline)
                                    .foregroundColor(HybridTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HybridTheme.surfaceElevated.opacity(0.6))
                            .cornerRadius(10)
                        }

                        // 3. 食物項目明細與微調
                        VStack(alignment: .leading, spacing: 12) {
                            Text("辨識項目與數值微調")
                                .font(HybridTheme.Typography.cardTitle)
                                .foregroundColor(HybridTheme.textPrimary)

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
                        .foregroundColor(HybridTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("加入今日記錄") {
                        commitAndDismiss()
                    }
                    .font(HybridTheme.Typography.badge.weight(.bold))
                    .foregroundColor(HybridTheme.successGreen)
                }
            }
        }
    }

    private func nutrientPill(title: String, grams: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(HybridTheme.Typography.badge)
                .foregroundColor(HybridTheme.textSecondary)
            Text("\(Int(grams))g")
                .font(HybridTheme.Typography.badge.weight(.bold))
                .foregroundColor(color)
        }
    }

    private func itemEditorCard(item: Binding<EditableFoodItem>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("食物名稱", text: item.foodName)
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)

                Spacer()

                Text(item.wrappedValue.estimatedPortion)
                    .font(HybridTheme.Typography.badge)
                    .foregroundColor(HybridTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HybridTheme.surfaceElevated)
                    .cornerRadius(4)
            }

            if !item.wrappedValue.reasoning.isEmpty {
                Text(item.wrappedValue.reasoning)
                    .font(HybridTheme.Typography.subheadline)
                    .foregroundColor(HybridTheme.textSecondary)
            }

            Divider().background(HybridTheme.cardBorder)

            // 數值調節列
            HStack(spacing: 12) {
                macroStepper(label: "熱量", unit: "kcal", value: item.calories, step: 20)
                macroStepper(label: "蛋白", unit: "g", value: item.proteinGrams, step: 5)
                macroStepper(label: "碳水", unit: "g", value: item.carbsGrams, step: 5)
                macroStepper(label: "脂肪", unit: "g", value: item.fatGrams, step: 2)
            }
        }
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private func macroStepper(label: String, unit: String, value: Binding<Double>, step: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(HybridTheme.Typography.chartAxis)
                .foregroundColor(HybridTheme.textSecondary)

            Text("\(Int(value.wrappedValue))")
                .font(HybridTheme.Typography.metricMedium)
                .foregroundColor(HybridTheme.textPrimary)

            HStack(spacing: 4) {
                Button(action: {
                    value.wrappedValue = max(0, value.wrappedValue - step)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(HybridTheme.textPrimary)
                        .clipShape(Circle())
                }

                Button(action: {
                    value.wrappedValue += step
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(HybridTheme.textPrimary)
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
