import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 15 秒極簡重量訓練打卡視圖 (QuickLogSheet)
public struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedPatterns: Set<MovementPattern> = [.lowerQuad]
    @State private var durationMinutes: Double = 45.0
    @State private var sRPE: Double = 7.5
    @State private var timeOffsetIndex: Int = 0 // 0: 剛剛結束, 1: 2小時前, 2: 昨晚
    
    public let onSaved: (() -> Void)?
    
    public init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }
    
    private var calculatedLoadAU: Double {
        return durationMinutes * sRPE
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 1. 部位快速多選 (4 大動作模式)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 訓練部位 (可複選)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "8B949E"))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            patternCapsule(title: "上肢推 (Push)", pattern: .upperPush)
                            patternCapsule(title: "上肢拉 (Pull)", pattern: .upperPull)
                            patternCapsule(title: "深蹲/前側鏈 (Quad)", pattern: .lowerQuad)
                            patternCapsule(title: "硬舉/後側鏈 (Hinge)", pattern: .lowerPosterior)
                        }
                    }
                    
                    // 2. 訓練時間長度
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("2. 訓練時長")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "8B949E"))
                            Spacer()
                            Text("\(Int(durationMinutes)) 分鐘")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 12) {
                            Button("- 5m") {
                                durationMinutes = max(15.0, durationMinutes - 5.0)
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .tint(Color(hex: "58A6FF"))
                            
                            Slider(value: $durationMinutes, in: 15...120, step: 5)
                                .tint(Color(hex: "58A6FF"))
                            
                            Button("+ 5m") {
                                durationMinutes = min(120.0, durationMinutes + 5.0)
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .tint(Color(hex: "58A6FF"))
                        }
                    }
                    
                    // 3. Foster sRPE 自覺強度滑桿 (1.0 ~ 10.0)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("3. Foster sRPE 自覺強度")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "8B949E"))
                            Spacer()
                            Text(String(format: "%.1f", sRPE))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(rpeColor)
                            Text("(\(rpeDescription))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        
                        Slider(value: $sRPE, in: 1.0...10.0, step: 0.5)
                            .tint(rpeColor)
                    }
                    
                    // 運動負荷即時計算
                    HStack {
                        Text("累計肌力負荷貨幣:")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8B949E"))
                        Spacer()
                        Text("\(Int(calculatedLoadAU)) AU")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "58A6FF"))
                    }
                    .padding(12)
                    .background(Color(hex: "161B22"))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // 儲存打卡按鈕
                    Button(action: saveSession) {
                        Text("完成記錄 (寫入本機 SwiftData)")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "3FB950"))
                            .foregroundColor(Color(hex: "090C10"))
                            .cornerRadius(12)
                    }
                }
                .padding(20)
            }
            .navigationTitle("15 秒肌力打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "8B949E"))
                }
            }
        }
    }
    
    private func patternCapsule(title: String, pattern: MovementPattern) -> some View {
        let isSelected = selectedPatterns.contains(pattern)
        return Button {
            if isSelected {
                selectedPatterns.remove(pattern)
            } else {
                selectedPatterns.insert(pattern)
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color(hex: "58A6FF") : Color(hex: "161B22"))
                .foregroundColor(isSelected ? Color(hex: "090C10") : Color(hex: "C9D1D9"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: "58A6FF") : Color(hex: "30363D"), lineWidth: 1)
                )
        }
    }
    
    private var rpeColor: Color {
        if sRPE <= 4.0 { return Color(hex: "3FB950") }
        if sRPE <= 7.0 { return Color(hex: "E3B341") }
        return Color(hex: "F85149")
    }
    
    private var rpeDescription: String {
        switch sRPE {
        case ..<3.0: return "極輕鬆"
        case 3.0..<5.0: return "中等有感"
        case 5.0..<7.0: return "稍微吃力"
        case 7.0..<8.5: return "吃力 / 接近力竭"
        default: return "最大極限力竭"
        }
    }
    
    private func saveSession() {
        let now = Date()
        let endDate = now
        let startDate = endDate.addingTimeInterval(-durationMinutes * 60.0)
        
        let domainSession = WorkoutSession(
            startDate: startDate,
            endDate: endDate,
            discipline: .strength,
            durationMinutes: durationMinutes,
            sRPE: sRPE,
            movementPatterns: Array(selectedPatterns),
            source: .manualLog
        )
        
        let sdSession = SDWorkoutSession(domain: domainSession)
        modelContext.insert(sdSession)
        try? modelContext.save()
        
        onSaved?()
        dismiss()
    }
}
