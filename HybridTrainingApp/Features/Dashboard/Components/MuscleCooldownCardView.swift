import SwiftUI
import HybridTrainingCore

/// 4 大動作模式冷卻時鐘卡片 (MuscleCooldownCardView)
public struct MuscleCooldownCardView: View {
    public let cooldowns: [MuscleCooldownStatus]
    
    public init(cooldowns: [MuscleCooldownStatus]) {
        self.cooldowns = cooldowns
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("動作模式冷卻時鐘 (4大肌群)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(HybridTheme.textSecondary)
            }
            
            VStack(spacing: 8) {
                patternRow(name: "上肢推 (Push)", pattern: .upperPush)
                patternRow(name: "上肢拉 (Pull)", pattern: .upperPull)
                patternRow(name: "下肢前側/深蹲 (Quad)", pattern: .lowerQuad)
                patternRow(name: "下肢後側/硬舉 (Hinge)", pattern: .lowerPosterior)
            }
        }
        .padding(16)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }
    
    private func patternRow(name: String, pattern: MovementPattern) -> some View {
        let status = cooldowns.first { $0.pattern == pattern }
        let hours = status?.remainingHours ?? 0.0
        let isFatigued = hours > 0.001
        
        return HStack {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HybridTheme.textPrimary)
            Spacer()
            if isFatigued {
                Text("剩餘 \(String(format: "%.1f", hours)) 小時")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.warningYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HybridTheme.warningYellow.opacity(0.15))
                    .cornerRadius(4)
            } else {
                Text("已就緒 (Fresh)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.successGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HybridTheme.successGreen.opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }
}
