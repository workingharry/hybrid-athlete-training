import SwiftUI
import HybridTrainingCore
import HybridTrainingStorage

public enum MealCategory: String, CaseIterable, Identifiable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case prePostWorkout = "訓練加餐"
    case snack = "點心零食"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .prePostWorkout: return "bolt.shield.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }
}

public struct PreciseNutritionEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    public let initialFoodName: String
    public let initialCalories: Double
    public let initialProtein: Double
    public let initialCarbs: Double
    public let initialFat: Double
    public let initialCaffeineMg: Double
    public let initialPortion: String
    public let initialCategory: MealCategory
    public let athleteNote: String?
    public let photoImage: UIImage?
    public let onCommit: (FoodItemPrediction, MealCategory) -> Void

    @State private var foodName: String
    @State private var portionDescription: String
    @State private var selectedCategory: MealCategory
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var caffeineMg: Double
    @State private var notes: String

    @FocusState private var focusedField: NutritionField?

    private enum NutritionField {
        case foodName, portion, calories, protein, carbs, fat, caffeine, notes
    }

    public init(
        initialFoodName: String = "",
        initialCalories: Double = 0,
        initialProtein: Double = 0,
        initialCarbs: Double = 0,
        initialFat: Double = 0,
        initialCaffeineMg: Double = 0,
        initialPortion: String = "1份",
        initialCategory: MealCategory = .lunch,
        athleteNote: String? = nil,
        photoImage: UIImage? = nil,
        onCommit: @escaping (FoodItemPrediction, MealCategory) -> Void
    ) {
        self.initialFoodName = initialFoodName
        self.initialCalories = initialCalories
        self.initialProtein = initialProtein
        self.initialCarbs = initialCarbs
        self.initialFat = initialFat
        self.initialCaffeineMg = initialCaffeineMg
        self.initialPortion = initialPortion
        self.initialCategory = initialCategory
        self.athleteNote = athleteNote
        self.photoImage = photoImage
        self.onCommit = onCommit

        self._foodName = State(initialValue: initialFoodName)
        self._portionDescription = State(initialValue: initialPortion)
        self._selectedCategory = State(initialValue: initialCategory)
        self._calories = State(initialValue: initialCalories)
        self._protein = State(initialValue: initialProtein)
        self._carbs = State(initialValue: initialCarbs)
        self._fat = State(initialValue: initialFat)
        self._caffeineMg = State(initialValue: initialCaffeineMg)
        self._notes = State(initialValue: athleteNote ?? "")
    }

    private var calculatedCalories: Double {
        (protein * 4) + (carbs * 4) + (fat * 9)
    }

    private var totalMacroCalories: Double {
        max(1, calculatedCalories)
    }

    private var proteinPercent: Double {
        ((protein * 4) / totalMacroCalories) * 100
    }

    private var carbsPercent: Double {
        ((carbs * 4) / totalMacroCalories) * 100
    }

    private var fatPercent: Double {
        ((fat * 9) / totalMacroCalories) * 100
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 照片縮圖與餐別選擇
                        HStack(spacing: 14) {
                            if let img = photoImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(HybridTheme.surfaceElevated)
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 24))
                                        .foregroundColor(HybridTheme.accentBlue)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("餐別分類")
                                    .font(HybridTheme.Typography.badge)
                                    .foregroundColor(HybridTheme.textSecondary)

                                Picker("餐別", selection: $selectedCategory) {
                                    ForEach(MealCategory.allCases) { cat in
                                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(HybridTheme.accentBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(HybridTheme.surfaceElevated)
                                .cornerRadius(8)
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

                        // 2. 食物名稱與份量輸入
                        VStack(alignment: .leading, spacing: 10) {
                            Text("食物基本資訊")
                                .font(HybridTheme.Typography.subheadline.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("食物名稱")
                                        .font(HybridTheme.Typography.body.weight(.semibold))
                                        .foregroundColor(HybridTheme.textPrimary)
                                        .frame(width: 80, alignment: .leading)
                                    TextField("例如：舒肥牛排、乳清蛋白", text: $foodName)
                                        .focused($focusedField, equals: .foodName)
                                        .foregroundColor(HybridTheme.textPrimary)
                                }
                                Divider().background(HybridTheme.cardBorder)
                                HStack {
                                    Text("份量描述")
                                        .font(HybridTheme.Typography.body.weight(.semibold))
                                        .foregroundColor(HybridTheme.textPrimary)
                                        .frame(width: 80, alignment: .leading)
                                    TextField("例如：1塊 (200g)、1碗", text: $portionDescription)
                                        .focused($focusedField, equals: .portion)
                                        .foregroundColor(HybridTheme.textPrimary)
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

                        // 3. 巨量營養素精細輸入格 (點擊數字彈出鍵盤，支援微調步進按鈕)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("三大營養素與熱量")
                                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                                    .foregroundColor(HybridTheme.textSecondary)
                                Spacer()
                                Button("依三大營養素自動換算熱量") {
                                    calories = round(calculatedCalories)
                                }
                                .font(HybridTheme.Typography.badge.weight(.semibold))
                                .foregroundColor(HybridTheme.accentBlue)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                nutrientInputCard(
                                    title: "總熱量",
                                    unit: "kcal",
                                    value: $calories,
                                    step: 50,
                                    color: HybridTheme.successGreen,
                                    field: .calories
                                )
                                nutrientInputCard(
                                    title: "蛋白質",
                                    unit: "g",
                                    value: $protein,
                                    step: 5,
                                    color: HybridTheme.accentBlue,
                                    field: .protein
                                )
                                nutrientInputCard(
                                    title: "碳水化合物",
                                    unit: "g",
                                    value: $carbs,
                                    step: 10,
                                    color: HybridTheme.energyOrange,
                                    field: .carbs
                                )
                                nutrientInputCard(
                                    title: "脂肪",
                                    unit: "g",
                                    value: $fat,
                                    step: 2,
                                    color: HybridTheme.warningYellow,
                                    field: .fat
                                )
                                nutrientInputCard(
                                    title: "咖啡因",
                                    unit: "mg",
                                    value: $caffeineMg,
                                    step: 25,
                                    color: HybridTheme.caffeineBrown,
                                    field: .caffeine
                                )
                            }
                        }

                        // 4. 即時巨量營養素熱量比例條 (Macro Energy Ratio)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("巨量熱量佔比 (P : C : F)")
                                .font(HybridTheme.Typography.badge.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    Rectangle()
                                        .fill(HybridTheme.accentBlue)
                                        .frame(width: max(0, geo.size.width * (proteinPercent / 100)))
                                    Rectangle()
                                        .fill(HybridTheme.energyOrange)
                                        .frame(width: max(0, geo.size.width * (carbsPercent / 100)))
                                    Rectangle()
                                        .fill(HybridTheme.warningYellow)
                                        .frame(width: max(0, geo.size.width * (fatPercent / 100)))
                                }
                                .clipShape(Capsule())
                            }
                            .frame(height: 8)

                            HStack {
                                macroLegend(label: "蛋白 \(Int(proteinPercent))%", color: HybridTheme.accentBlue)
                                Spacer()
                                macroLegend(label: "碳水 \(Int(carbsPercent))%", color: HybridTheme.energyOrange)
                                Spacer()
                                macroLegend(label: "脂肪 \(Int(fatPercent))%", color: HybridTheme.warningYellow)
                            }
                            .padding(.top, 4)
                        }
                        .padding(14)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                        )

                        // 5. 備註筆記
                        VStack(alignment: .leading, spacing: 8) {
                            Text("備註與心得")
                                .font(HybridTheme.Typography.subheadline.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            TextField("例如：重訓結束後 30 分鐘攝取", text: $notes)
                                .focused($focusedField, equals: .notes)
                                .foregroundColor(HybridTheme.textPrimary)
                                .padding(12)
                                .background(HybridTheme.cardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                                )
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("精細飲食記錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(HybridTheme.textSecondary)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成輸入") {
                        focusedField = nil
                    }
                    .foregroundColor(HybridTheme.accentBlue)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成入庫") {
                        saveEntry()
                    }
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.successGreen)
                    .disabled(foodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func nutrientInputCard(
        title: String,
        unit: String,
        value: Binding<Double>,
        step: Double,
        color: Color,
        field: NutritionField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(HybridTheme.Typography.chartAxis)
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text(unit)
                    .font(HybridTheme.Typography.badge.weight(.bold))
                    .foregroundColor(color)
            }

            HStack(alignment: .firstTextBaseline) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .font(HybridTheme.Typography.metricHero)
                    .foregroundColor(HybridTheme.textPrimary)
            }

            // 步進按鈕微調列
            HStack(spacing: 8) {
                Button(action: {
                    value.wrappedValue = max(0, value.wrappedValue - step)
                }) {
                    Text("-\(Int(step))")
                        .font(HybridTheme.Typography.badge.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(HybridTheme.textPrimary)
                        .cornerRadius(6)
                }

                Button(action: {
                    value.wrappedValue += step
                }) {
                    Text("+\(Int(step))")
                        .font(HybridTheme.Typography.badge.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(color)
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private func macroLegend(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(HybridTheme.Typography.badge)
                .foregroundColor(HybridTheme.textSecondary)
        }
    }

    private func saveEntry() {
        let finalItem = FoodItemPrediction(
            foodName: foodName.isEmpty ? "自訂餐點" : foodName,
            estimatedPortion: portionDescription.isEmpty ? "1份" : portionDescription,
            calories: max(0, calories),
            proteinGrams: max(0, protein),
            carbsGrams: max(0, carbs),
            fatGrams: max(0, fat),
            caffeineMg: max(0, caffeineMg),
            confidence: 1.0,
            reasoning: notes
        )
        onCommit(finalItem, selectedCategory)
        dismiss()
    }
}
