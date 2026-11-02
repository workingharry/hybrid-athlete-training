import SwiftUI
import HybridTrainingCore

/// 週週期混合訓練平衡環卡片 (WeeklyRingsCardView)
public struct WeeklyRingsCardView: View {
    public let summary: WeeklyHybridSummary

    public init(summary: WeeklyHybridSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 標題與平衡得分
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(HybridTheme.accentBlue)
                        Text("週週期雙軌平衡環")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HybridTheme.textPrimary)
                    }
                    Text(summary.balanceStatus)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(badgeColor)
                }

                Spacer()

                // 平衡指數標籤
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(summary.balanceScore))")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(badgeColor)
                        Text("/100")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                    Text("雙軌平衡指數")
                        .font(.system(size: 10))
                        .foregroundColor(HybridTheme.textSecondary)
                }
            }

            // 雙軌三重進度環與指標解說
            HStack(spacing: 18) {
                // 三重同心環
                ZStack {
                    // 外環：耐力跑量 (Blue)
                    RingProgressView(
                        progress: summary.enduranceProgressRatio,
                        ringColor: HybridTheme.accentBlue,
                        ringWidth: 8,
                        diameter: 86
                    )

                    // 中環：肌力有效組數 (Orange)
                    RingProgressView(
                        progress: summary.strengthProgressRatio,
                        ringColor: HybridTheme.energyOrange,
                        ringWidth: 8,
                        diameter: 66
                    )

                    // 內環：4大動作模式覆蓋 (Green)
                    RingProgressView(
                        progress: summary.patternCoverageRatio,
                        ringColor: HybridTheme.successGreen,
                        ringWidth: 8,
                        diameter: 46
                    )

                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(HybridTheme.textPrimary)
                }
                .frame(width: 90, height: 90)

                // 數值細項列表
                VStack(alignment: .leading, spacing: 8) {
                    // 耐力指標
                    metricRow(
                        color: HybridTheme.accentBlue,
                        title: "耐力跑量",
                        current: String(format: "%.1f", summary.weeklyEnduranceKm),
                        target: "\(Int(summary.enduranceTargetKm)) km",
                        subtitle: "\(summary.weeklyEnduranceSessionsCount) 場 · \(Int(summary.weeklyEnduranceDurationMinutes)) 分鐘"
                    )

                    // 肌力指標
                    metricRow(
                        color: HybridTheme.energyOrange,
                        title: "肌力組數",
                        current: "\(summary.weeklyStrengthSetsCount)",
                        target: "\(summary.strengthTargetSets) 組",
                        subtitle: "\(summary.weeklyStrengthSessionsCount) 場 · 總重 \(Int(summary.weeklyStrengthTonnageKg)) kg"
                    )

                    // 模式覆蓋
                    metricRow(
                        color: HybridTheme.successGreen,
                        title: "模式覆蓋",
                        current: "\(summary.coveredPatterns.count)",
                        target: "4 模式",
                        subtitle: patternCoverageText
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 週期教練智慧反饋
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.system(size: 11))
                    .foregroundColor(badgeColor)
                    .padding(.top, 2)
                Text(summary.primaryFeedback)
                    .font(.system(size: 12))
                    .foregroundColor(HybridTheme.textPrimary)
                    .lineSpacing(3)
                Spacer()
            }
            .padding(10)
            .background(HybridTheme.surfaceElevated)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(badgeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }

    private func metricRow(color: Color, title: String, current: String, target: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text(current)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
                Text("/ \(target)")
                    .font(.system(size: 11))
                    .foregroundColor(HybridTheme.textSecondary)
            }
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(HybridTheme.textSecondary)
                .padding(.leading, 12)
        }
    }

    private var patternCoverageText: String {
        if summary.coveredPatterns.count == 4 {
            return "推/拉/蹲/鉸鏈 全覆蓋"
        }
        let missing = Set<MovementPattern>([.upperPush, .upperPull, .lowerQuad, .lowerPosterior]).subtracting(summary.coveredPatterns)
        return "缺 \(missing.count) 項主要模式"
    }

    private var badgeColor: Color {
        if summary.balanceScore >= 75.0 {
            return HybridTheme.successGreen
        } else if summary.balanceScore >= 50.0 {
            return HybridTheme.warningYellow
        } else {
            return HybridTheme.accentBlue
        }
    }
}

/// 獨立進度圓環組件
private struct RingProgressView: View {
    let progress: Double
    let ringColor: Color
    let ringWidth: CGFloat
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // 底環
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: ringWidth)
                .frame(width: diameter, height: diameter)

            // 進度環
            Circle()
                .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, progress))))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
        }
    }
}
