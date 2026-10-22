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
    
    @AppStorage("enable_nutrition_module") private var enableNutritionModule: Bool = false
    @AppStorage("app_theme_mode") private var themeModeRaw: String = AppThemeMode.system.rawValue
    
    @State private var isShowingAudit: Bool = false
    @State private var isShowingRoutineLibrary: Bool = false
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                
                Form {
                    // 0. App 外觀與主題切換 (日間 / 夜間 / 跟隨系統)
                    Section(header: Text("外觀風格與主題").foregroundColor(HybridTheme.textSecondary)) {
                        Picker("介面外觀", selection: $themeModeRaw) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.iconName)
                                    .tag(mode.rawValue)
                            }
                        }
                        .foregroundColor(HybridTheme.textPrimary)
                        .tint(HybridTheme.accentBlue)
                    }
                    .listRowBackground(HybridTheme.cardBackground)

                    // 1. 運動員生理心率基準
                    Section(header: Text("個人生理與心率基準").foregroundColor(HybridTheme.textSecondary)) {
                        HStack {
                            Text("靜息心率 (RHR)")
                                .foregroundColor(HybridTheme.textPrimary)
                            Spacer()
                            TextField("52", value: $restingHR, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(HybridTheme.accentBlue)
                            Text("bpm")
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                        
                        HStack {
                            Text("最大心率 (Max HR)")
                                .foregroundColor(HybridTheme.textPrimary)
                            Spacer()
                            TextField("188", value: $maxHR, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(HybridTheme.accentBlue)
                            Text("bpm")
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                    
                    // 2. 混合訓練目標偏好
                    Section(header: Text("訓練目標偏好").foregroundColor(HybridTheme.textSecondary)) {
                        Picker("核心側重", selection: $trainingFocus) {
                            Text("雙軌均衡 (Hybrid Balanced)").tag("balanced")
                            Text("力量優先 (Strength Priority)").tag("strength")
                            Text("耐力優先 (Endurance Priority)").tag("endurance")
                        }
                        .foregroundColor(HybridTheme.textPrimary)
                        .tint(HybridTheme.accentBlue)
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                    
                    // 3. 肌群疲勞冷卻客製
                    Section(header: Text("神經與肌群冷卻啟發式基準 (小時)").foregroundColor(HybridTheme.textSecondary)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("下肢深蹲基礎冷卻")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text("\(Int(customSquatCooldown)) 小時")
                                    .foregroundColor(HybridTheme.accentBlue)
                            }
                            Slider(value: $customSquatCooldown, in: 24...72, step: 6)
                                .tint(HybridTheme.accentBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("下肢硬舉基礎冷卻")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text("\(Int(customDeadliftCooldown)) 小時")
                                    .foregroundColor(HybridTheme.accentBlue)
                            }
                            Slider(value: $customDeadliftCooldown, in: 24...72, step: 6)
                                .tint(HybridTheme.accentBlue)
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                    
                    // 4. 課表庫、動作庫與診斷工具
                    Section(header: Text("訓練模組與課表管理").foregroundColor(HybridTheme.textSecondary)) {
                        Button {
                            isShowingRoutineLibrary = true
                        } label: {
                            HStack {
                                Label("常用課表庫與自訂範本", systemImage: "folder.fill")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                        }

                        NavigationLink {
                            ResistanceLibraryView()
                        } label: {
                            HStack {
                                Label("阻力訓練動作庫 (30+ 項)", systemImage: "dumbbell.fill")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                            }
                        }
                        
                        Button {
                            isShowingAudit = true
                        } label: {
                            HStack {
                                Label("開啟 Spike 探針與歷史回放", systemImage: "stethoscope")
                                    .foregroundColor(HybridTheme.accentBlue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)

                    // 5. 飲食與能量攝取模組 (選用 / 實驗中功能)
                    Section(header: Text("飲食與能量補給管理 (選用模組)").foregroundColor(HybridTheme.textSecondary),
                            footer: Text("啟用後可利用 iPhone 原生相機與 Siri AI 捷徑拍攝每日餐點紀錄攝取卡路里與蛋白質，完全遵循 Local-First 隱私原則。").foregroundColor(HybridTheme.textSecondary)) {
                        Toggle(isOn: $enableNutritionModule) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("啟用飲食與營養攝取追蹤")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Text("支援 Vision 原生拍照與熱量計算")
                                    .font(.system(size: 11))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                        }
                        .tint(HybridTheme.successGreen)
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                    
                    // 6. 隱私與法律免責聲明
                    Section(header: Text("隱私保證與法規宣告").foregroundColor(HybridTheme.textSecondary)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("100% Local-First 零上傳承諾", systemImage: "lock.shield.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(HybridTheme.successGreen)
                            Text("您的所有 HealthKit 心率、HRV、睡眠與訓練紀錄均嚴格保存在 iPhone 與 Apple Watch 本機，絕不上傳至任何外部雲端伺服器。")
                                .font(.system(size: 12))
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("非醫療器材免責聲明", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(HybridTheme.warningYellow)
                            Text("本 App 提供的恢復評分、ACWR 負荷與排課推薦僅供健康運動員自主訓練與疲勞管理參考，非醫療診斷或治療器材。若有身體不適請立即停止運動並諮詢專業醫療人員。")
                                .font(.system(size: 12))
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                    
                    // 7. 版本資訊
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(HybridTheme.textPrimary)
                            Spacer()
                            Text("Version 2.0.0 (Build 2026.10)")
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定與運動員配置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingAudit) {
                SpikeAuditView(healthKitAdapter: healthKitAdapter)
            }
            .sheet(isPresented: $isShowingRoutineLibrary) {
                RoutineLibrarySheet()
            }
        }
    }
}
