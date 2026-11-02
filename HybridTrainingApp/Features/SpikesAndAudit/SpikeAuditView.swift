import SwiftUI
import HybridTrainingCore

public struct SpikeAuditView: View {
    @StateObject private var viewModel: SpikeAuditViewModel
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        _viewModel = StateObject(wrappedValue: SpikeAuditViewModel(healthKitAdapter: healthKitAdapter))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 頂部分頁切換
                    Picker("模式選擇", selection: $viewModel.selectedTab) {
                        Text("實機探針 (Gate 1~4)").tag(0)
                        Text("4~8週回放審查 (Gate 5)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(HybridTheme.cardBackground)
                    
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
                                .tint(HybridTheme.successGreen)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(HybridTheme.accentBlue)
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
                            .font(HybridTheme.Typography.cardTitle)
                            .foregroundColor(HybridTheme.textPrimary)
                        Text("檢驗雙向運動學冷卻與每日排課決策")
                            .font(HybridTheme.Typography.subheadline)
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                    Spacer()
                    if viewModel.violationCount == 0 {
                        Text("PASS · 零違規")
                            .font(HybridTheme.Typography.badge)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HybridTheme.successGreen.opacity(0.18))
                            .foregroundColor(HybridTheme.successGreen)
                            .cornerRadius(6)
                    } else {
                        Text("\(viewModel.violationCount) 項違規")
                            .font(HybridTheme.Typography.badge)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HybridTheme.dangerRed.opacity(0.18))
                            .foregroundColor(HybridTheme.dangerRed)
                            .cornerRadius(6)
                    }
                }
                
                Divider().background(HybridTheme.cardBorder)
                
                HStack(spacing: 16) {
                    metricColumn(title: "回放天數", value: "\(viewModel.totalReplayedDays) 天")
                    metricColumn(title: "違規次數", value: "\(viewModel.violationCount) 次", valueColor: viewModel.violationCount == 0 ? HybridTheme.successGreen : HybridTheme.dangerRed)
                    metricColumn(title: "下肢冷卻觸發", value: "\(viewModel.legCooldownActiveDays) 天")
                    metricColumn(title: "教練合理性", value: "\(Int(viewModel.plausibilityScorePercent))%", valueColor: HybridTheme.accentBlue)
                }
            }
            .padding(16)
            .background(HybridTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
            )
            
            // 違規細節警告
            if !viewModel.violationDetails.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("發現違規項目（需立即微調 TrainingConfiguration）：", systemImage: "exclamationmark.triangle.fill")
                        .font(HybridTheme.Typography.subheadline.weight(.bold))
                        .foregroundColor(HybridTheme.dangerRed)
                    ForEach(viewModel.violationDetails, id: \.self) { v in
                        Text("• \(v)")
                            .font(HybridTheme.Typography.subheadline)
                            .foregroundColor(HybridTheme.dangerRed)
                    }
                }
                .padding(12)
                .background(HybridTheme.dangerRed.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 逐日時間軸
            VStack(alignment: .leading, spacing: 10) {
                Text("逐日決策時間軸 (\(viewModel.replayResults.count) 天)")
                    .font(HybridTheme.Typography.subheadline.weight(.semibold))
                    .foregroundColor(HybridTheme.textSecondary)
                
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
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)
                Spacer()
                Text(report.isPass ? "PASS" : "FAIL / ADAPT")
                    .font(HybridTheme.Typography.badge)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((report.isPass ? HybridTheme.successGreen : HybridTheme.energyOrange).opacity(0.18))
                    .foregroundColor(report.isPass ? HybridTheme.successGreen : HybridTheme.energyOrange)
                    .cornerRadius(6)
            }
            Text(report.metricText)
                .font(HybridTheme.Typography.body)
                .foregroundColor(HybridTheme.textPrimary)
            Text(report.actionText)
                .font(HybridTheme.Typography.subheadline)
                .foregroundColor(HybridTheme.textSecondary)
        }
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }
    
    private func replayDayRow(item: HistoricalReplayDayResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(item.date))
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)
                
                // 生理狀態徽章
                gradeBadge(grade: item.decision.readinessGrade)
                
                // ACWR 標籤
                Text("ACWR \(String(format: "%.2f", item.decision.acwrRatio))")
                    .font(HybridTheme.Typography.chartAxis)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.textSecondary)
                    .cornerRadius(4)
                
                Spacer()
                
                if item.wasLegCooldownActive {
                    Text("下肢冷卻中")
                        .font(HybridTheme.Typography.badge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HybridTheme.energyOrange.opacity(0.18))
                        .foregroundColor(HybridTheme.energyOrange)
                        .cornerRadius(4)
                }
            }
            
            // 推薦課表
            HStack {
                Image(systemName: item.decision.primaryRecommendation.discipline == .running ? "figure.run" : "figure.strengthtraining.traditional")
                    .foregroundColor(HybridTheme.accentBlue)
                Text(item.decision.primaryRecommendation.title)
                    .font(HybridTheme.Typography.subheadline.weight(.semibold))
                    .foregroundColor(HybridTheme.accentBlue)
                Spacer()
                Text("\(Int(item.decision.primaryRecommendation.estimatedDurationMinutes))m · \(Int(item.decision.primaryRecommendation.estimatedLoadAU)) AU")
                    .font(HybridTheme.Typography.chartAxis)
                    .foregroundColor(HybridTheme.textSecondary)
            }
            
            // 當日真實進行的訓練
            if !item.actualWorkoutsPerformed.isEmpty {
                HStack(spacing: 4) {
                    Text("當日實際訓練:")
                        .font(HybridTheme.Typography.chartAxis)
                        .foregroundColor(HybridTheme.textSecondary)
                    ForEach(item.actualWorkoutsPerformed) { act in
                        Text("\(act.discipline == .running ? "跑步" : "重訓") \(Int(act.durationMinutes))m (sRPE \(String(format: "%.1f", act.sRPE)))")
                            .font(HybridTheme.Typography.chartAxis)
                            .foregroundColor(HybridTheme.textPrimary)
                    }
                }
            }
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }
    
    private func headerInfoCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HybridTheme.Typography.cardTitle)
                .foregroundColor(HybridTheme.textPrimary)
            Text(subtitle)
                .font(HybridTheme.Typography.subheadline)
                .foregroundColor(HybridTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }
    
    private func metricColumn(title: String, value: String, valueColor: Color = HybridTheme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HybridTheme.Typography.chartAxis)
                .foregroundColor(HybridTheme.textSecondary)
            Text(value)
                .font(HybridTheme.Typography.metricMedium)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func gradeBadge(grade: ReadinessGrade) -> some View {
        let (text, color) = switch grade {
        case .ready: ("綠燈就緒", HybridTheme.successGreen)
        case .moderate: ("黃燈平緩", HybridTheme.energyOrange)
        case .fatigued: ("紅燈疲勞", HybridTheme.dangerRed)
        case .injured: ("傷病鎖定", HybridTheme.dangerRed)
        }
        return Text(text)
            .font(HybridTheme.Typography.badge)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
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
