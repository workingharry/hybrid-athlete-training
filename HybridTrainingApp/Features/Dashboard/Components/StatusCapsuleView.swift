import SwiftUI
import HybridTrainingCore

/// 自律神經準備度與 7 天 ACWR 狀態藥丸
public struct StatusCapsuleView: View {
    public let decision: DailyDecision
    
    public init(decision: DailyDecision) {
        self.decision = decision
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 生理就緒藥丸
            HStack(spacing: 6) {
                Circle()
                    .fill(readinessColor)
                    .frame(width: 8, height: 8)
                Text(readinessText)
                    .font(HybridTheme.Typography.badge)
                    .foregroundColor(HybridTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(HybridTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(readinessColor.opacity(0.35), lineWidth: 1)
            )
            
            // ACWR 負荷比藥丸
            HStack(spacing: 6) {
                Circle()
                    .fill(acwrColor)
                    .frame(width: 8, height: 8)
                Text("7天 ACWR: \(String(format: "%.2f", decision.acwrRatio))")
                    .font(HybridTheme.Typography.badge)
                    .foregroundColor(HybridTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(HybridTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
            )
            
            Spacer()
        }
    }
    
    private var readinessColor: Color {
        switch decision.readinessGrade {
        case .ready: return HybridTheme.successGreen
        case .moderate: return HybridTheme.warningYellow
        case .fatigued, .injured: return HybridTheme.dangerRed
        }
    }
    
    private var readinessText: String {
        switch decision.readinessGrade {
        case .ready: return "恢復充足 (高就緒)"
        case .moderate: return "平緩適應"
        case .fatigued: return "神經或疲勞累積"
        case .injured: return "傷病防護啟動"
        }
    }
    
    private var acwrColor: Color {
        if decision.acwrRatio < 0.8 {
            return HybridTheme.textSecondary
        } else if decision.acwrRatio <= 1.3 {
            return HybridTheme.successGreen
        } else if decision.acwrRatio <= 1.5 {
            return HybridTheme.warningYellow
        } else {
            return HybridTheme.dangerRed
        }
    }
}
