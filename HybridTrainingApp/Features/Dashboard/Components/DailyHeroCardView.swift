import SwiftUI
import HybridTrainingCore

/// 今日自適應推薦主卡片 (DailyHeroCardView)
/// 支援多學科自主切換選課：🏃‍♂️ 跑步課表 / 🏋️‍♂️ 阻力訓練 / 🚴‍♂️ 交叉訓練
public struct DailyHeroCardView: View {
    public let primaryWorkout: RecommendedWorkout
    public let runningOption: RecommendedWorkout?
    public let strengthOption: RecommendedWorkout?
    public let crossOption: RecommendedWorkout?
    public let isLockedDueToFatigue: Bool
    public let onScheduleToWatch: (RecommendedWorkout) -> Void
    public let onSelectAlternates: () -> Void
    
    @State private var selectedTab: Int = 0 // 0: 最佳主推, 1: 跑步專項, 2: 阻力專項, 3: 交叉訓練
    
    public init(
        workout: RecommendedWorkout,
        runningOption: RecommendedWorkout? = nil,
        strengthOption: RecommendedWorkout? = nil,
        crossOption: RecommendedWorkout? = nil,
        isLockedDueToFatigue: Bool = false,
        onScheduleToWatch: @escaping (RecommendedWorkout) -> Void,
        onSelectAlternates: @escaping () -> Void
    ) {
        self.primaryWorkout = workout
        self.runningOption = runningOption
        self.strengthOption = strengthOption
        self.crossOption = crossOption
        self.isLockedDueToFatigue = isLockedDueToFatigue
        self.onScheduleToWatch = onScheduleToWatch
        self.onSelectAlternates = onSelectAlternates
    }
    
    private var activeWorkout: RecommendedWorkout {
        switch selectedTab {
        case 1: return runningOption ?? primaryWorkout
        case 2: return strengthOption ?? primaryWorkout
        case 3: return crossOption ?? primaryWorkout
        default: return primaryWorkout
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 頂部標題與狀態
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: disciplineIcon(activeWorkout.discipline))
                        .foregroundColor(disciplineColor(activeWorkout.discipline))
                    Text(selectedTab == 0 ? "今日最佳自適應推薦" : "自主選課推薦")
                        .font(HybridTheme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(disciplineColor(activeWorkout.discipline))
                }
                Spacer()
                if isLockedDueToFatigue {
                    Text("疲勞受限保護")
                        .font(HybridTheme.Typography.badge)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(HybridTheme.warningYellow.opacity(0.15))
                        .foregroundColor(HybridTheme.warningYellow)
                        .cornerRadius(6)
                }
            }
            
            // 多軌選課切換晶片 (跑步 / 阻力 / 交叉)
            HStack(spacing: 8) {
                programTabChip(index: 0, title: "綜合主推", icon: "sparkles")
                if runningOption != nil {
                    programTabChip(index: 1, title: "跑步方案", icon: "figure.run")
                }
                if strengthOption != nil {
                    programTabChip(index: 2, title: "阻力方案", icon: "dumbbell.fill")
                }
                if crossOption != nil {
                    programTabChip(index: 3, title: "交叉方案", icon: "figure.outdoor.cycle")
                }
            }
            
            // 課表名稱與副標題
            VStack(alignment: .leading, spacing: 5) {
                Text(activeWorkout.title)
                    .font(HybridTheme.Typography.title2)
                    .foregroundColor(HybridTheme.textPrimary)
                Text(activeWorkout.subtitle)
                    .font(HybridTheme.Typography.subheadline)
                    .foregroundColor(HybridTheme.textSecondary)
            }
            
            // 核心數值 (時長與負荷)
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("預估時長")
                        .font(HybridTheme.Typography.badge.weight(.regular))
                        .foregroundColor(HybridTheme.textSecondary)
                    Text("\(Int(activeWorkout.estimatedDurationMinutes)) 分鐘")
                        .font(HybridTheme.Typography.metricMedium)
                        .foregroundColor(HybridTheme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("預估運動負荷")
                        .font(HybridTheme.Typography.badge.weight(.regular))
                        .foregroundColor(HybridTheme.textSecondary)
                    Text("\(Int(activeWorkout.estimatedLoadAU)) AU")
                        .font(HybridTheme.Typography.metricMedium)
                        .foregroundColor(HybridTheme.accentBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("訓練學科")
                        .font(HybridTheme.Typography.badge.weight(.regular))
                        .foregroundColor(HybridTheme.textSecondary)
                    Text(disciplineTitle(activeWorkout.discipline))
                        .font(HybridTheme.Typography.badge.weight(.semibold))
                        .foregroundColor(disciplineColor(activeWorkout.discipline))
                }
                Spacer()
            }
            
            Divider().background(HybridTheme.cardBorder)
            
            // 動作按鈕區
            HStack(spacing: 12) {
                Button {
                    onScheduleToWatch(activeWorkout)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                        Text("推播此課表至手錶")
                    }
                    .font(HybridTheme.Typography.cardTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HybridTheme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: onSelectAlternates) {
                    Text("更多備選")
                        .font(HybridTheme.Typography.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(HybridTheme.textPrimary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(18)
        .background(HybridTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }
    
    private func programTabChip(index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(HybridTheme.Typography.badge.weight(isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? HybridTheme.accentBlue : HybridTheme.surfaceElevated)
            .foregroundColor(isSelected ? .white : HybridTheme.textSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func disciplineIcon(_ d: TrainingDiscipline) -> String {
        switch d {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .rest: return "bed.double"
        }
    }
    
    private func disciplineColor(_ d: TrainingDiscipline) -> Color {
        switch d {
        case .running: return HybridTheme.accentBlue
        case .cycling: return HybridTheme.energyOrange
        case .swimming: return HybridTheme.healthTeal
        case .rowing: return HybridTheme.activityPurple
        case .strength: return HybridTheme.dangerRed
        case .mobility: return HybridTheme.successGreen
        case .rest: return HybridTheme.textSecondary
        }
    }
    
    private func disciplineTitle(_ d: TrainingDiscipline) -> String {
        switch d {
        case .running: return "路跑"
        case .cycling: return "自行車"
        case .swimming: return "游泳"
        case .rowing: return "划船"
        case .strength: return "肌力"
        case .mobility: return "活動度"
        case .rest: return "休息"
        }
    }
}
