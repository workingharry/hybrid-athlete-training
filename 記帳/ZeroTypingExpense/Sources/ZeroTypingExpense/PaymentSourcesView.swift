import SwiftUI

public struct PaymentSourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingApplePayGuide: Bool = false
    @State private var showingTestAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Item 1: Apple Pay
                    PaymentSourceCard(
                        title: "Apple Pay",
                        levelBadge: "L0 自動",
                        statusText: "已啟用",
                        statusIcon: "checkmark.circle",
                        statusColor: DesignTokens.Colors.successLight,
                        detailText: "最近一筆：今天 11:40",
                        buttonTitle: nil,
                        action: nil
                    )

                    // Item 2: AlipayHK
                    PaymentSourceCard(
                        title: "AlipayHK",
                        levelBadge: "L1 一鍵",
                        statusText: "已啟用",
                        statusIcon: "checkmark.circle",
                        statusColor: DesignTokens.Colors.successLight,
                        detailText: "最近一筆：今天 12:05 · Back Tap 觸發",
                        buttonTitle: nil,
                        action: nil
                    )

                    // Item 3: Alipay China
                    PaymentSourceCard(
                        title: "Alipay China",
                        levelBadge: "L1 一鍵",
                        statusText: "近期無新交易",
                        statusIcon: "clock",
                        statusColor: DesignTokens.Colors.warningLight,
                        detailText: "上一筆在 16 天前。沒有付款不代表設定出錯，需要時可手動測試。",
                        buttonTitle: "測試一筆",
                        action: { showingTestAlert = true }
                    )

                    // Item 4: 其他錢包
                    PaymentSourceCard(
                        title: "其他錢包",
                        levelBadge: "L1 分享",
                        statusText: "未設定",
                        statusIcon: "minus.circle",
                        statusColor: DesignTokens.Colors.textSecondaryLight,
                        detailText: "可用分享選單匯入付款截圖，不需完整相簿權限。",
                        buttonTitle: "開始設定",
                        action: { showingApplePayGuide = true }
                    )

                    // Footer Link: 權限
                    HStack {
                        Button("權限說明與隱私政策") {
                            // Link
                        }
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
            .background(DesignTokens.Colors.bgLight.ignoresSafeArea())
            .navigationTitle("支付來源")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text("設定")
                        }
                        .foregroundColor(DesignTokens.Colors.accentLight)
                    }
                }
            }
            .alert("測試記錄完成", isPresented: $showingTestAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text("已成功發送測試交易信號，Alipay China 來源狀態已更新。")
            }
            .sheet(isPresented: $showingApplePayGuide) {
                ApplePayOnboardingView()
            }
        }
    }
}

private struct PaymentSourceCard: View {
    let title: String
    let levelBadge: String
    let statusText: String
    let statusIcon: String
    let statusColor: Color
    let detailText: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Spacer()
                Text(levelBadge)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0xEC/255.0, green: 0xE9/255.0, blue: 0xE1/255.0))
                    .cornerRadius(12)
            }

            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            Text(detailText)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .lineSpacing(3)

            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(buttonTitle == "開始設定" ? .white : DesignTokens.Colors.textPrimaryLight)
                        .frame(height: 40)
                        .padding(.horizontal, 20)
                        .background(buttonTitle == "開始設定" ? DesignTokens.Colors.accentLight : Color(red: 0xE8/255.0, green: 0xE5/255.0, blue: 0xDD/255.0))
                        .cornerRadius(20)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(DesignTokens.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
