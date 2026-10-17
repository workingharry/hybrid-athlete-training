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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(disciplineColor(activeWorkout.discipline))
                }
                Spacer()
                if isLockedDueToFatigue {
                    Text("疲勞受限保護")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "E3B341").opacity(0.2))
                        .foregroundColor(Color(hex: "E3B341"))
                        .cornerRadius(4)
                }
            }
            
            // 多軌選課切換晶片 (跑步 / 阻力 / 交叉)
            HStack(spacing: 6) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(activeWorkout.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(activeWorkout.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8B949E"))
            }
            
            // 核心數值 (時長與負荷)
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估時長")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    Text("\(Int(activeWorkout.estimatedDurationMinutes)) 分鐘")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估運動負荷")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    Text("\(Int(activeWorkout.estimatedLoadAU)) AU")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "58A6FF"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("訓練學科")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    Text(disciplineTitle(activeWorkout.discipline))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(disciplineColor(activeWorkout.discipline))
                }
                Spacer()
            }
            
            Divider().background(Color(hex: "30363D"))
            
            // 動作按鈕區
            HStack(spacing: 12) {
                Button {
                    onScheduleToWatch(activeWorkout)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                        Text("推播此課表至手錶")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "58A6FF"))
                    .foregroundColor(Color(hex: "090C10"))
                    .cornerRadius(8)
                }
                
                Button(action: onSelectAlternates) {
                    Text("更多備選")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "21262D"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(18)
        .background(Color(hex: "161B22"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }
    
    private func programTabChip(index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color(hex: "58A6FF") : Color(hex: "21262D"))
            .foregroundColor(isSelected ? Color(hex: "090C10") : Color(hex: "8B949E"))
            .cornerRadius(6)
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
        case .running: return Color(hex: "58A6FF")
        case .cycling: return Color(hex: "D29922")
        case .swimming: return Color(hex: "39C5BB")
        case .rowing: return Color(hex: "A371F7")
        case .strength: return Color(hex: "F85149")
        case .mobility: return Color(hex: "3FB950")
        case .rest: return Color(hex: "8B949E")
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
