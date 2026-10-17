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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "161B22"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(readinessColor.opacity(0.3), lineWidth: 1)
            )
            
            // ACWR 負荷比藥丸
            HStack(spacing: 6) {
                Circle()
                    .fill(acwrColor)
                    .frame(width: 8, height: 8)
                Text("7天 ACWR: \(String(format: "%.2f", decision.acwrRatio))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "C9D1D9"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "161B22"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "30363D"), lineWidth: 1)
            )
            
            Spacer()
        }
    }
    
    private var readinessColor: Color {
        switch decision.readinessGrade {
        case .ready: return Color(hex: "3FB950")
        case .moderate: return Color(hex: "E3B341")
        case .fatigued, .injured: return Color(hex: "F85149")
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
            return Color(hex: "8B949E")
        } else if decision.acwrRatio <= 1.3 {
            return Color(hex: "3FB950")
        } else if decision.acwrRatio <= 1.5 {
            return Color(hex: "E3B341")
        } else {
            return Color(hex: "F85149")
        }
    }
}
