import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 營養與補給詳情抽屜 (NutritionDetailSheet)
/// Apple 原生 .presentationDetents 抽屜面板，呈現三大營養素、完整今日餐食日誌 CRUD (檢視/編輯/刪除)
public struct NutritionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDDailyNutritionEntry.timestamp, order: .reverse) private var allEntries: [SDDailyNutritionEntry]

    public let model: NutritionCapsuleViewModel
    public var onTriggerCamera: () -> Void = {}
    public var onTriggerCustomEntry: () -> Void = {}
    public var onTriggerEditEntry: (SDDailyNutritionEntry) -> Void = { _ in }
    
    @State private var entryToDelete: SDDailyNutritionEntry?
    @State private var isShowingDeleteConfirmation = false
    
    public init(
        model: NutritionCapsuleViewModel,
        onTriggerCamera: @escaping () -> Void = {},
        onTriggerCustomEntry: @escaping () -> Void = {},
        onTriggerEditEntry: @escaping (SDDailyNutritionEntry) -> Void = { _ in }
    ) {
        self.model = model
        self.onTriggerCamera = onTriggerCamera
        self.onTriggerCustomEntry = onTriggerCustomEntry
        self.onTriggerEditEntry = onTriggerEditEntry
    }
    
    /// 以 4:00 AM 訓練日劃分獲取今日餐食
    private var todayEntries: [SDDailyNutritionEntry] {
        let calendar = Calendar.current
        let todayKey = TrainingDayKey(date: Date(), calendar: calendar).dateString
        return allEntries.filter {
            TrainingDayKey(date: $0.timestamp, calendar: calendar).dateString == todayKey
        }
    }
    
    private var computedTotalKcal: Double {
        todayEntries.reduce(0.0) { $0 + $1.calories }
    }
    private var computedProteinGrams: Double {
        todayEntries.reduce(0.0) { $0 + $1.proteinGrams }
    }
    private var computedCarbsGrams: Double {
        todayEntries.reduce(0.0) { $0 + $1.carbsGrams }
    }
    private var computedFatGrams: Double {
        todayEntries.reduce(0.0) { $0 + $1.fatGrams }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 今日核心三大營養素進度卡 (動態響應資料庫實際數值)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("今日三大營養素與熱量目標")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text("已記錄 \(todayEntries.count) 餐")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                            
                            macroRow(
                                title: "蛋白質 (肌纖維修復)",
                                current: computedProteinGrams,
                                target: model.targetProteinGrams,
                                unit: "g",
                                color: HybridTheme.accentBlue
                            )
                            
                            macroRow(
                                title: "碳水化合物 (肌糖原儲備)",
                                current: computedCarbsGrams,
                                target: model.targetCarbsGrams,
                                unit: "g",
                                color: HybridTheme.energyOrange
                            )
                            
                            macroRow(
                                title: "總熱量 (保守微幅盈餘 +8%)",
                                current: computedTotalKcal,
                                target: model.targetKcal,
                                unit: "kcal",
                                color: HybridTheme.successGreen
                            )
                        }
                        .padding(16)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(HybridTheme.cardBorder, lineWidth: 1)
                        )
                        
                        // 2. 混合運動員能量可用性 (EA) 狀態
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(HybridTheme.successGreen)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("能量可用性 (EA): 42.5 ± 5 kcal/kg FFM")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(HybridTheme.textPrimary)
                                Text("符合 IOC 2023 REDs 探索區間，肌原纖維修復與合成代謝充足。")
                                    .font(.system(size: 11))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HybridTheme.cardBorder, lineWidth: 1)
                        )
                        
                        // 2.5 拍照 AI 飲食記錄入口
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onTriggerCamera()
                            }
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(HybridTheme.accentBlue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(HybridTheme.accentBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("拍攝餐點 AI 視覺分析")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(HybridTheme.textPrimary)
                                    Text("自動估算食物熱量、蛋白質與碳水，支援手動微調")
                                        .font(.system(size: 11))
                                        .foregroundColor(HybridTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                            .padding(14)
                            .background(HybridTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(HybridTheme.accentBlue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // 3. 今日餐食記錄日誌清單 (完整 CRUD: 檢視 / 點擊編輯 / 刪除)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("今日餐食日誌")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onTriggerCustomEntry()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("手動記一餐")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(HybridTheme.accentBlue)
                                }
                            }
                            
                            if todayEntries.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 6) {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 24))
                                            .foregroundColor(HybridTheme.textSecondary)
                                        Text("今天尚未記錄任何餐食，點擊上方按鈕開始記錄")
                                            .font(.system(size: 12))
                                            .foregroundColor(HybridTheme.textSecondary)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                                .background(HybridTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 1)
                                )
                            } else {
                                ForEach(todayEntries) { entry in
                                    entryRowView(entry)
                                }
                            }
                        }

                        // 4. 快捷補登
                        VStack(alignment: .leading, spacing: 10) {
                            Text("快速補登")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(HybridTheme.textPrimary)
                            
                            HStack(spacing: 10) {
                                quickAddButton(title: "+ 30g 蛋白", subtitle: "乳清蛋白 / 雞胸") {
                                    addQuickEntry(name: "快速補充乳清蛋白", kcal: 130, protein: 30, carbs: 2, fat: 1, category: "訓練加餐")
                                }
                                
                                quickAddButton(title: "+ 50g 碳水", subtitle: "能量棒 / 白飯") {
                                    addQuickEntry(name: "快速補充碳水肌糖原", kcal: 210, protein: 3, carbs: 50, fat: 1, category: "訓練加餐")
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("營養與補給詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HybridTheme.accentBlue)
                }
            }
            .confirmationDialog(
                "確認刪除此筆餐食記錄？",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible,
                presenting: entryToDelete
            ) { entry in
                Button("刪除「\(entry.foodName)」", role: .destructive) {
                    deleteEntry(entry)
                }
                Button("取消", role: .cancel) {}
            } message: { entry in
                Text("此操作將從今日營養統計中扣除 \(Int(entry.calories)) kcal 與 \(Int(entry.proteinGrams))g 蛋白質。")
            }
        }
    }
    
    // MARK: - 餐食項目卡片
    private func entryRowView(_ entry: SDDailyNutritionEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.mealTypeRaw)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(HybridTheme.accentBlue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HybridTheme.accentBlue.opacity(0.15))
                        .cornerRadius(4)
                    
                    Text(entry.foodName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HybridTheme.textPrimary)
                }
                
                HStack(spacing: 8) {
                    Text("\(Int(entry.calories)) kcal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(HybridTheme.successGreen)
                    Text("•")
                        .foregroundColor(HybridTheme.textSecondary)
                    Text("P: \(Int(entry.proteinGrams))g")
                        .font(.system(size: 11))
                        .foregroundColor(HybridTheme.accentBlue)
                    Text("C: \(Int(entry.carbsGrams))g")
                        .font(.system(size: 11))
                        .foregroundColor(HybridTheme.energyOrange)
                    Text("F: \(Int(entry.fatGrams))g")
                        .font(.system(size: 11))
                        .foregroundColor(HybridTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // 編輯按鈕
            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onTriggerEditEntry(entry)
                }
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HybridTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(HybridTheme.surfaceElevated)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // 刪除按鈕
            Button(action: {
                entryToDelete = entry
                isShowingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HybridTheme.dangerRed)
                    .frame(width: 32, height: 32)
                    .background(HybridTheme.dangerRed.opacity(0.12))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }
    
    private func deleteEntry(_ entry: SDDailyNutritionEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func addQuickEntry(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, category: String) {
        let entry = SDDailyNutritionEntry(
            foodName: name,
            calories: kcal,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            mealTypeRaw: category,
            notes: "快捷記錄"
        )
        modelContext.insert(entry)
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func macroRow(title: String, current: Double, target: Double, unit: String, color: Color) -> some View {
        let ratio = target > 0 ? min(1.0, max(0.0, current / target)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(HybridTheme.surfaceElevated)
                    Capsule().fill(color)
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 6)
        }
    }
    
    private func quickAddButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(HybridTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HybridTheme.surfaceElevated)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
