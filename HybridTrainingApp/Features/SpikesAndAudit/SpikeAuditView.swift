import SwiftUI
import HybridTrainingCore

/// Phase 1: 實機探針與 4～8 週歷史回放審查畫面 (SpikeAuditView)
public struct SpikeAuditView: View {
    @StateObject private var viewModel: SpikeAuditViewModel
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        _viewModel = StateObject(wrappedValue: SpikeAuditViewModel(healthKitAdapter: healthKitAdapter))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 頂部分頁切換
                    Picker("模式選擇", selection: $viewModel.selectedTab) {
                        Text("實機探針 (Gate 1~4)").tag(0)
                        Text("4~8週回放審查 (Gate 5)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "161B22"))
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.selectedTab == 0 {
                                hardwareProbesSection
                            } else {
                                historicalReplaySection
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Phase 1 探針與回放審查")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if viewModel.selectedTab == 0 {
                                await viewModel.runHardwareProbes()
                            } else {
                                await viewModel.runHistoricalReplayAudit()
                            }
                        }
                    } label: {
                        if viewModel.isRunningProbe {
                            ProgressView()
                                .tint(Color(hex: "3FB950"))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color(hex: "58A6FF"))
                        }
                    }
                }
            }
            .task {
                await viewModel.runHardwareProbes()
                await viewModel.runHistoricalReplayAudit()
            }
        }
    }
    
    // MARK: - Gate 1~4 探針視圖
    private var hardwareProbesSection: some View {
        VStack(spacing: 14) {
            headerInfoCard(
                title: "實體設備與 HealthKit 邊界驗證",
                subtitle: "檢驗 Apple Watch HRV 取樣頻率、離散心率箝位積分與睡眠去重"
            )
            
            if let g1 = viewModel.gate1HRVReport {
                gateCard(report: g1)
            }
            if let g2 = viewModel.gate2HeartRateReport {
                gateCard(report: g2)
            }
            if let g3 = viewModel.gate3SleepReport {
                gateCard(report: g3)
            }
            if let g4 = viewModel.gate4WorkoutKitReport {
                gateCard(report: g4)
            }
        }
    }
    
    // MARK: - Gate 5: 歷史回放視圖
    private var historicalReplaySection: some View {
        VStack(spacing: 14) {
            // 審查結果主卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("4～8 週真實數據回放審查")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Text("檢驗雙向運動學冷卻與每日排課決策")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8B949E"))
                    }
                    Spacer()
                    if viewModel.violationCount == 0 {
                        Text("PASS · 零違規")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "3FB950").opacity(0.2))
                            .foregroundColor(Color(hex: "3FB950"))
                            .cornerRadius(6)
                    } else {
                        Text("\(viewModel.violationCount) 項違規")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "F85149").opacity(0.2))
                            .foregroundColor(Color(hex: "F85149"))
                            .cornerRadius(6)
                    }
                }
                
                Divider().background(Color(hex: "30363D"))
                
                HStack(spacing: 16) {
                    metricColumn(title: "回放天數", value: "\(viewModel.totalReplayedDays) 天")
                    metricColumn(title: "違規次數", value: "\(viewModel.violationCount) 次", valueColor: viewModel.violationCount == 0 ? Color(hex: "3FB950") : Color(hex: "F85149"))
                    metricColumn(title: "下肢冷卻觸發", value: "\(viewModel.legCooldownActiveDays) 天")
                    metricColumn(title: "教練合理性", value: "\(Int(viewModel.plausibilityScorePercent))%", valueColor: Color(hex: "58A6FF"))
                }
            }
            .padding(16)
            .background(Color(hex: "161B22"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "30363D"), lineWidth: 1)
            )
            
            // 違規細節警告
            if !viewModel.violationDetails.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("發現違規項目（需立即微調 TrainingConfiguration）：", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "F85149"))
                    ForEach(viewModel.violationDetails, id: \.self) { v in
                        Text("• \(v)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "F85149"))
                    }
                }
                .padding(12)
                .background(Color(hex: "F85149").opacity(0.1))
                .cornerRadius(8)
            }
            
            // 逐日時間軸
            VStack(alignment: .leading, spacing: 10) {
                Text("逐日決策時間軸 (\(viewModel.replayResults.count) 天)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "8B949E"))
                
                ForEach(viewModel.replayResults, id: \.date) { item in
                    replayDayRow(item: item)
                }
            }
        }
    }
    
    // MARK: - 輔助卡片組件
    private func gateCard(report: GateResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(report.isPass ? "PASS" : "FAIL / ADAPT")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((report.isPass ? Color(hex: "3FB950") : Color(hex: "E3B341")).opacity(0.2))
                    .foregroundColor(report.isPass ? Color(hex: "3FB950") : Color(hex: "E3B341"))
                    .cornerRadius(6)
            }
            Text(report.metricText)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "C9D1D9"))
            Text(report.actionText)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8B949E"))
        }
        .padding(14)
        .background(Color(hex: "161B22"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }
    
    private func replayDayRow(item: HistoricalReplayDayResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(item.date))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                // 生理狀態徽章
                gradeBadge(grade: item.decision.readinessGrade)
                
                // ACWR 標籤
                Text("ACWR \(String(format: "%.2f", item.decision.acwrRatio))")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "21262D"))
                    .foregroundColor(Color(hex: "8B949E"))
                    .cornerRadius(4)
                
                Spacer()
                
                if item.wasLegCooldownActive {
                    Text("下肢冷卻中")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "E3B341").opacity(0.2))
                        .foregroundColor(Color(hex: "E3B341"))
                        .cornerRadius(4)
                }
            }
            
            // 推薦課表
            HStack {
                Image(systemName: item.decision.primaryRecommendation.discipline == .running ? "figure.run" : "figure.strengthtraining.traditional")
                    .foregroundColor(Color(hex: "58A6FF"))
                Text(item.decision.primaryRecommendation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "58A6FF"))
                Spacer()
                Text("\(Int(item.decision.primaryRecommendation.estimatedDurationMinutes))m · \(Int(item.decision.primaryRecommendation.estimatedLoadAU)) AU")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8B949E"))
            }
            
            // 當日真實進行的訓練
            if !item.actualWorkoutsPerformed.isEmpty {
                HStack(spacing: 4) {
                    Text("當日實際訓練:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    ForEach(item.actualWorkoutsPerformed) { act in
                        Text("\(act.discipline == .running ? "跑步" : "重訓") \(Int(act.durationMinutes))m (sRPE \(String(format: "%.1f", act.sRPE)))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "C9D1D9"))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: "161B22"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "21262D"), lineWidth: 1)
        )
    }
    
    private func headerInfoCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8B949E"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "161B22"))
        .cornerRadius(10)
    }
    
    private func metricColumn(title: String, value: String, valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8B949E"))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func gradeBadge(grade: ReadinessGrade) -> some View {
        let (text, color) = switch grade {
        case .ready: ("綠燈就緒", Color(hex: "3FB950"))
        case .moderate: ("黃燈平緩", Color(hex: "E3B341"))
        case .fatigued: ("紅燈疲勞", Color(hex: "F85149"))
        case .injured: ("傷病鎖定", Color(hex: "F85149"))
        }
        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd (E)"
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter.string(from: date)
    }
}

// 顏色擴充工具
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
