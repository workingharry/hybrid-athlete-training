import SwiftUI
import HybridTrainingCore

/// 首頁今日頂部微型營養膠囊 (NutritionCapsuleView)
/// 遵循 Apple HIG 原生風格與 frontend-design 減法原則：蛋白質為主、熱量為次、雙細膠囊進度條、微型情境引導
public struct NutritionCapsuleView: View {
    public let model: NutritionCapsuleViewModel
    public let phase: FuelingPhase
    public let onOpenDetail: () -> Void
    public let onTriggerCamera: () -> Void
    public let onTriggerCustomEntry: () -> Void
    public let onQuickAddProtein: () -> Void
    public let onQuickAddCarb: () -> Void
    public let onQuickAddWater: () -> Void
    
    @State private var toastMessage: String? = nil
    
    public init(
        model: NutritionCapsuleViewModel,
        phase: FuelingPhase,
        onOpenDetail: @escaping () -> Void,
        onTriggerCamera: @escaping () -> Void = {},
        onTriggerCustomEntry: @escaping () -> Void = {},
        onQuickAddProtein: @escaping () -> Void = {},
        onQuickAddCarb: @escaping () -> Void = {},
        onQuickAddWater: @escaping () -> Void = {}
    ) {
        self.model = model
        self.phase = phase
        self.onOpenDetail = onOpenDetail
        self.onTriggerCamera = onTriggerCamera
        self.onTriggerCustomEntry = onTriggerCustomEntry
        self.onQuickAddProtein = onQuickAddProtein
        self.onQuickAddCarb = onQuickAddCarb
        self.onQuickAddWater = onQuickAddWater
    }
    
    private var isUnlogged: Bool {
        model.mealsLoggedCount == 0
    }
    
    private var proteinRatio: Double {
        guard model.targetProteinGrams > 0 else { return 0 }
        return min(1.0, max(0.0, model.proteinGrams / model.targetProteinGrams))
    }
    
    private var kcalRatio: Double {
        guard model.targetKcal > 0 else { return 0 }
        return min(1.0, max(0.0, model.consumedKcal / model.targetKcal))
    }
    
    public var body: some View {
        Button(action: onOpenDetail) {
            VStack(alignment: .leading, spacing: 10) {
                // 1. 頂部狀態列與快速加點選單
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: phase.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: phase.hexColor))
                        Text(phase.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // 相機 AI 辨識按鈕
                    Button(action: onTriggerCamera) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "58A6FF"))
                            .frame(width: 26, height: 26)
                            .background(Color(hex: "21262D"))
                            .clipShape(Circle())
                    }
                    .highPriorityGesture(TapGesture().onEnded { onTriggerCamera() })
                    
                    // 1 秒極速加點 Menu
                    Menu {
                        Button {
                            onQuickAddProtein()
                            showToast("已快速補充 +30g 蛋白質")
                        } label: {
                            Label("補充蛋白質 +30g", systemImage: "flame.fill")
                        }
                        
                        Button {
                            onQuickAddCarb()
                            showToast("已快速補充 +50g 碳水化合物")
                        } label: {
                            Label("補充碳水 +50g", systemImage: "bolt.fill")
                        }
                        
                        Button {
                            onQuickAddWater()
                            showToast("已記錄飲水 +500ml")
                        } label: {
                            Label("飲水 +500ml", systemImage: "drop.fill")
                        }
                        
                        Divider()
                        
                        Button {
                            onTriggerCustomEntry()
                        } label: {
                            Label("自訂精細記錄 (熱量/蛋白質)...", systemImage: "square.and.pencil")
                        }
                        
                        Button(action: onOpenDetail) {
                            Label("開啟完整飲食面板...", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "21262D"))
                            .clipShape(Circle())
                    }
                    .highPriorityGesture(TapGesture()) // 避免觸發卡片點擊
                }
                
                // 2. 蛋白質 (主) 與 熱量 (次) 雙軌指標
                HStack(spacing: 20) {
                    // 蛋白質
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(isUnlogged ? "—" : "\(Int(model.proteinGrams))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ \(Int(model.targetProteinGrams))g")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "8B949E"))
                            Spacer()
                            Text("蛋白質")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        
                        // 細膠囊進度條
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "21262D"))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "58A6FF"), Color(hex: "79C0FF")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: max(0, geo.size.width * proteinRatio))
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 熱量
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(isUnlogged ? "—" : "\(Int(model.consumedKcal))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ ≈\(Int(model.targetKcal))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "8B949E"))
                            Spacer()
                            Text("卡路里")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        
                        // 細膠囊進度條
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "21262D"))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: phase.hexColor), Color(hex: phase.hexColor).opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: max(0, geo.size.width * kcalRatio))
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // 3. 底部引導行 (Toast 訊息或情境引導)
                if let toast = toastMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3FB950"))
                        Text(toast)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "3FB950"))
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8B949E"))
                        Text(guidanceText)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8B949E"))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(Color(hex: "161B22"))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: phase.hexColor).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var guidanceText: String {
        switch phase {
        case .morningEmpty:
            return "晨間尚未記錄・建議自早餐開始補充 35g 蛋白質"
        case .preWorkout(let min):
            return "距開練 \(min) 分鐘・補充 50g 易消化碳水與水份"
        case .postWorkoutGoldenWindow:
            return "修復黃金期・補充乳清蛋白與碳水促進肌糖原合成"
        case .activeFueling:
            return "蛋白質達標 \(Int(proteinRatio * 100))%・維持穩定能量供應"
        case .activeRestDay:
            return "主動修復日・維持低碳高蛋白，修護肌纖維"
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}
