import SwiftUI
import HybridTrainingCore

/// 今日自適應推薦主卡片 (DailyHeroCardView)
public struct DailyHeroCardView: View {
    public let workout: RecommendedWorkout
    public let isLockedDueToFatigue: Bool
    public let onScheduleToWatch: () -> Void
    public let onSelectAlternates: () -> Void
    
    public init(
        workout: RecommendedWorkout,
        isLockedDueToFatigue: Bool = false,
        onScheduleToWatch: @escaping () -> Void,
        onSelectAlternates: @escaping () -> Void
    ) {
        self.workout = workout
        self.isLockedDueToFatigue = isLockedDueToFatigue
        self.onScheduleToWatch = onScheduleToWatch
        self.onSelectAlternates = onSelectAlternates
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 標題與類型
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: workout.discipline == .running ? "figure.run" : "figure.strengthtraining.traditional")
                        .foregroundColor(Color(hex: "58A6FF"))
                    Text("今日自適應推薦")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "58A6FF"))
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
            
            // 課表名稱
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(workout.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8B949E"))
            }
            
            // 核心數值
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估時長")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    Text("\(Int(workout.estimatedDurationMinutes)) 分鐘")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估運動負荷")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8B949E"))
                    Text("\(Int(workout.estimatedLoadAU)) AU")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "58A6FF"))
                }
                Spacer()
            }
            
            Divider().background(Color(hex: "30363D"))
            
            // 動作按鈕區
            HStack(spacing: 12) {
                Button(action: onScheduleToWatch) {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                        Text("推播至手錶排程")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "58A6FF"))
                    .foregroundColor(Color(hex: "090C10"))
                    .cornerRadius(8)
                }
                
                Button(action: onSelectAlternates) {
                    Text("換課備選")
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
}
