import SwiftUI
import HybridTrainingCore

/// Version 2: 運動員個人配置、法規免責與隱私設定 (SettingsView)
public struct SettingsView: View {
    let healthKitAdapter: HealthKitAdapter
    
    @AppStorage("athlete_resting_hr") private var restingHR: Double = 52.0
    @AppStorage("athlete_max_hr") private var maxHR: Double = 188.0
    @AppStorage("athlete_focus") private var trainingFocus: String = "balanced"
    @AppStorage("custom_squat_cooldown") private var customSquatCooldown: Double = 48.0
    @AppStorage("custom_deadlift_cooldown") private var customDeadliftCooldown: Double = 48.0
    
    @State private var isShowingAudit: Bool = false
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                Form {
                    // 1. 運動員生理心率基準
                    Section(header: Text("個人生理與心率基準").foregroundColor(Color(hex: "8B949E"))) {
                        HStack {
                            Text("靜息心率 (RHR)")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("52", value: $restingHR, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color(hex: "58A6FF"))
                            Text("bpm")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        
                        HStack {
                            Text("最大心率 (Max HR)")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("188", value: $maxHR, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color(hex: "58A6FF"))
                            Text("bpm")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                    }
                    .listRowBackground(Color(hex: "161B22"))
                    
                    // 2. 混合訓練目標偏好
                    Section(header: Text("訓練目標偏好").foregroundColor(Color(hex: "8B949E"))) {
                        Picker("核心側重", selection: $trainingFocus) {
                            Text("雙軌均衡 (Hybrid Balanced)").tag("balanced")
                            Text("力量優先 (Strength Priority)").tag("strength")
                            Text("耐力優先 (Endurance Priority)").tag("endurance")
                        }
                        .foregroundColor(.white)
                        .tint(Color(hex: "58A6FF"))
                    }
                    .listRowBackground(Color(hex: "161B22"))
                    
                    // 3. 肌群疲勞冷卻客製
                    Section(header: Text("神經與肌群冷卻啟發式基準 (小時)").foregroundColor(Color(hex: "8B949E"))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("下肢深蹲基礎冷卻")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(customSquatCooldown)) 小時")
                                    .foregroundColor(Color(hex: "58A6FF"))
                            }
                            Slider(value: $customSquatCooldown, in: 24...72, step: 6)
                                .tint(Color(hex: "58A6FF"))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("下肢硬舉基礎冷卻")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(customDeadliftCooldown)) 小時")
                                    .foregroundColor(Color(hex: "58A6FF"))
                            }
                            Slider(value: $customDeadliftCooldown, in: 24...72, step: 6)
                                .tint(Color(hex: "58A6FF"))
                        }
                    }
                    .listRowBackground(Color(hex: "161B22"))
                    
                    // 4. 硬體探針與動作庫
                    Section(header: Text("動作庫與診斷工具").foregroundColor(Color(hex: "8B949E"))) {
                        NavigationLink {
                            ResistanceLibraryView()
                        } label: {
                            HStack {
                                Label("阻力訓練動作庫 (20+ 項)", systemImage: "dumbbell.fill")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                        
                        Button {
                            isShowingAudit = true
                        } label: {
                            HStack {
                                Label("開啟 Spike 探針與歷史回放", systemImage: "stethoscope")
                                    .foregroundColor(Color(hex: "58A6FF"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "161B22"))
                    
                    // 5. 隱私與法律免責聲明
                    Section(header: Text("隱私保證與法規宣告").foregroundColor(Color(hex: "8B949E"))) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("100% Local-First 零上傳承諾", systemImage: "lock.shield.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "3FB950"))
                            Text("您的所有 HealthKit 心率、HRV、睡眠與訓練紀錄均嚴格保存在 iPhone 與 Apple Watch 本機，絕不上傳至任何外部雲端伺服器。")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("非醫療器材免責聲明", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "D29922"))
                            Text("本 App 提供的恢復評分、ACWR 負荷與排課推薦僅供健康運動員自主訓練與疲勞管理參考，非醫療診斷或治療器材。若有身體不適請立即停止運動並諮詢專業醫療人員。")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "161B22"))
                    
                    // 6. 版本資訊
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(.white)
                            Spacer()
                            Text("Version 2.0.0 (Build 2026.10)")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                    }
                    .listRowBackground(Color(hex: "161B22"))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定與運動員配置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingAudit) {
                SpikeAuditView(healthKitAdapter: healthKitAdapter)
            }
        }
    }
}
