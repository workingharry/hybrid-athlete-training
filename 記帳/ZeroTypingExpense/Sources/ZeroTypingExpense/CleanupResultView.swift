import SwiftUI

/// Screen S10: Cleanup Result Summary
/// Matches Page 6 of UI specification:
/// - Green checkmark circle icon
/// - Title: "已刪除 10 張截圖"
/// - Subtitle: "你的 10 筆支出紀錄仍完整保存在帳本，金額、商戶與分類都沒有改變。"
/// - Alert card 1 (Red triangle):
///   - Title: "1 張未能刪除"
///   - Item: "Pret A Manger, 10月19日 12:18, HK$78.00"
///   - Reason: "這張相片已不在你授權的範圍內，所以保留在相簿，不會標記為已刪除。下次清理時會再列出。"
/// - Alert card 2 (Lock shield):
///   - Title: "1 張由你保留"
///   - Item & Reason: "百佳超級市場 · HK$214.00 在預覽時已取消勾選，不會被刪除。"
/// - Action Buttons:
///   - Primary: "完成"
///   - Secondary: "查看清理紀錄"
public struct CleanupResultView: View {
    @Environment(\.dismiss) private var dismiss
    public let deletedCount: Int
    public let failedItems: [CleanupCandidate]
    public let keptItems: [CleanupCandidate]

    public init(
        deletedCount: Int = 10,
        failedItems: [CleanupCandidate] = [],
        keptItems: [CleanupCandidate] = []
    ) {
        self.deletedCount = deletedCount
        self.failedItems = failedItems
        self.keptItems = keptItems
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(DesignTokens.Colors.successLight)
                            .padding(.top, 28)

                        Text("已刪除 \(deletedCount) 張截圖")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        Text("你的 \(deletedCount) 筆支出紀錄仍完整保存在帳本，金額、商戶與分類都沒有改變。")
                            .font(.system(size: 15))
                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }

                    // Alert Card 1: Failed deletions
                    if !failedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignTokens.Colors.errorLight)

                                Text("\(failedItems.count) 張未能刪除")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            }

                            ForEach(failedItems) { item in
                                Text("\(item.merchantName), \(formatDate(item.date)), \(item.amountFormatted)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            }

                            Text("這張相片已不在你授權的範圍內，所以保留在相簿，不會標記為已刪除。下次清理時會再列出。")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0xFD/255.0, green: 0xF2/255.0, blue: 0xF2/255.0))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0xF8/255.0, green: 0xD7/255.0, blue: 0xDA/255.0), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }

                    // Alert Card 2: Kept by user
                    if !keptItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                                Text("\(keptItems.count) 張由你保留")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            }

                            ForEach(keptItems) { item in
                                Text("\(item.merchantName) · \(item.amountFormatted) 在預覽時已取消勾選，不會被刪除。")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.Colors.surfaceLight)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }

            Spacer()

            // Bottom Buttons
            VStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    HStack {
                        Spacer()
                        Text("完成")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 52)
                    .background(DesignTokens.Colors.accentLight)
                    .cornerRadius(26)
                }

                Button(action: { dismiss() }) {
                    HStack {
                        Spacer()
                        Text("查看清理紀錄")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                        Spacer()
                    }
                    .frame(height: 52)
                    .background(Color(red: 0xEE/255.0, green: 0xEC/255.0, blue: 0xE4/255.0))
                    .cornerRadius(26)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(DesignTokens.Colors.bgLight)
        }
        .background(DesignTokens.Colors.bgLight.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_HK")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
