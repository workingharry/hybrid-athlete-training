import SwiftUI
import HybridTrainingCore

/// 營養與補給極簡詳情抽屜 (NutritionDetailSheet)
/// Apple 原生 .presentationDetents 抽屜面板，呈現三大營養素與快捷記錄
public struct NutritionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding public var model: NutritionCapsuleViewModel
    public var onTriggerCamera: () -> Void = {}
    public var onTriggerCustomEntry: () -> Void = {}
    
    public init(
        model: Binding<NutritionCapsuleViewModel>,
        onTriggerCamera: @escaping () -> Void = {},
        onTriggerCustomEntry: @escaping () -> Void = {}
    ) {
        self._model = model
        self.onTriggerCamera = onTriggerCamera
        self.onTriggerCustomEntry = onTriggerCustomEntry
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 今日核心三大營養素進度卡
                        VStack(alignment: .leading, spacing: 14) {
                            Text("今日三大營養素與熱量目標")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            macroRow(
                                title: "蛋白質 (肌纖維修復)",
                                current: model.proteinGrams,
                                target: model.targetProteinGrams,
                                unit: "g",
                                colorHex: "58A6FF"
                            )
                            
                            macroRow(
                                title: "碳水化合物 (肌糖原儲備)",
                                current: model.carbsGrams,
                                target: model.targetCarbsGrams,
                                unit: "g",
                                colorHex: "FF9F0A"
                            )
                            
                            macroRow(
                                title: "總熱量 (保守微幅盈餘 +8%)",
                                current: model.consumedKcal,
                                target: model.targetKcal,
                                unit: "kcal",
                                colorHex: "3FB950"
                            )
                        }
                        .padding(16)
                        .background(Color(hex: "161B22"))
                        .cornerRadius(14)
                        
                        // 2. 混合運動員能量可用性 (EA) 狀態
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "3FB950"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("能量可用性 (EA): 46.2 kcal/kg FFM")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("充沛增肌標準 (>= 45)，睪固酮與肌肥大代謝處於理想區間。")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                        }
                        .padding(14)
                        .background(Color(hex: "161B22"))
                        .cornerRadius(12)
                        
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
                                        .fill(Color(hex: "58A6FF").opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "58A6FF"))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("拍攝餐點 AI 視覺分析")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("自動估算食物熱量、蛋白質與碳水，支援手動微調")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8B949E"))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                            .padding(14)
                            .background(Color(hex: "161B22"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "58A6FF").opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // 3. 快捷記錄
                        VStack(alignment: .leading, spacing: 10) {
                            Text("快速補登")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 10) {
                                quickAddButton(title: "+ 30g 蛋白", subtitle: "乳清蛋白 / 雞胸") {
                                    model = NutritionCapsuleViewModel(
                                        consumedKcal: model.consumedKcal + 130,
                                        targetKcal: model.targetKcal,
                                        proteinGrams: model.proteinGrams + 30,
                                        targetProteinGrams: model.targetProteinGrams,
                                        carbsGrams: model.carbsGrams + 2,
                                        targetCarbsGrams: model.targetCarbsGrams,
                                        mealsLoggedCount: model.mealsLoggedCount + 1,
                                        dayType: model.dayType,
                                        goal: model.goal
                                    )
                                }
                                
                                quickAddButton(title: "+ 50g 碳水", subtitle: "能量棒 / 白飯") {
                                    model = NutritionCapsuleViewModel(
                                        consumedKcal: model.consumedKcal + 210,
                                        targetKcal: model.targetKcal,
                                        proteinGrams: model.proteinGrams + 3,
                                        targetProteinGrams: model.targetProteinGrams,
                                        carbsGrams: model.carbsGrams + 50,
                                        targetCarbsGrams: model.targetCarbsGrams,
                                        mealsLoggedCount: model.mealsLoggedCount + 1,
                                        dayType: model.dayType,
                                        goal: model.goal
                                    )
                                }
                            }
                            
                            // 3.5 自訂精確多營養素記錄按鈕
                            Button(action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onTriggerCustomEntry()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "58A6FF"))
                                    Text("自訂精細飲食記錄 (手動輸入熱量與蛋白質)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8B949E"))
                                }
                                .padding(12)
                                .background(Color(hex: "21262D"))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
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
                        .foregroundColor(Color(hex: "58A6FF"))
                }
            }
        }
    }
    
    private func macroRow(title: String, current: Double, target: Double, unit: String, colorHex: String) -> some View {
        let ratio = target > 0 ? min(1.0, max(0.0, current / target)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8B949E"))
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "21262D"))
                    Capsule().fill(Color(hex: colorHex))
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
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8B949E"))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "21262D"))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
