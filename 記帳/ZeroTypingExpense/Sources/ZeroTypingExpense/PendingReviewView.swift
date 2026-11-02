import SwiftUI

public struct PendingReviewView: View {
    @ObservedObject public var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingScreenshotSheet: Bool = false
    @State private var selectedExpenditureTypes: [UUID: TransactionType] = [:]

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var pendingItems: [TransactionEntity] {
        appState.pendingTransactions
    }

    private var effectiveRemainingCount: Int {
        pendingItems.count
    }

    private func formattedDate(_ tx: TransactionEntity) -> String {
        let date = tx.transactionDate ?? tx.capturedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Subtitle (§5.5 & Page 2)
                    HStack {
                        Text("\(effectiveRemainingCount) 項需要你判斷。確認前不會計入已用預算。")
                            .font(.system(size: 15))
                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    if effectiveRemainingCount == 0 {
                        // All completed empty state (§A.7)
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(DesignTokens.Colors.successLight)
                            Text("全部完成")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            Text("目前沒有需要確認的項目，所有交易已歸檔至帳本與預算。")
                                .font(.system(size: 15))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(pendingItems, id: \.id) { tx in
                            pendingCard(for: tx)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(DesignTokens.Colors.backgroundLight.ignoresSafeArea())
            .navigationTitle("待確認")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text("總覽")
                        }
                        .foregroundColor(DesignTokens.Colors.accentLight)
                    }
                }
            }
            .sheet(isPresented: $showingScreenshotSheet) {
                ScreenshotPreviewModalView()
            }
        }
    }

    // MARK: - Transaction Review Cards

    @ViewBuilder
    private func pendingCard(for tx: TransactionEntity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if tx.duplicateStatus == .possibleDuplicate {
                duplicateCardContent(for: tx)
            } else if (tx.amountMinor ?? 0) == 0 || (tx.amountConfidence ?? 1.0) < 0.9 {
                amountReviewCardContent(for: tx)
            } else {
                categorizationCardContent(for: tx)
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

    // Sub-card 1: Categorization
    @ViewBuilder
    private func categorizationCardContent(for tx: TransactionEntity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.warningLight)
            Text("待分類")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.warningLight)
        }

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.merchantCanonical ?? tx.merchantRaw ?? "Unknown Merchant")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Text("\(tx.provider.rawValue) · \(tx.captureChannel.rawValue) · \(formattedDate(tx))")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }
            Spacer()
            Text(String(format: "%@$%.2f", tx.currency ?? appState.baseCurrency, Double(tx.ledgerAmountMinor ?? tx.amountMinor ?? 0) / 100.0))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
        }

        Text("金額與幣別可靠，只需選擇分類與支出類型")
            .font(.system(size: 14))
            .foregroundColor(DesignTokens.Colors.textSecondaryLight)

        // Expenditure Type Pills
        let currentType = selectedExpenditureTypes[tx.id] ?? tx.transactionType
        VStack(alignment: .leading, spacing: 6) {
            Text("支出類型")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ExpenditureTypePill(
                        title: "一般消費",
                        isSelected: currentType == .payment
                    ) {
                        selectedExpenditureTypes[tx.id] = .payment
                        Task { try? await appState.updateTransactionType(id: tx.id, newType: .payment) }
                    }

                    ExpenditureTypePill(
                        title: "轉帳 (不計入預算)",
                        isSelected: currentType == .transfer
                    ) {
                        selectedExpenditureTypes[tx.id] = .transfer
                        Task { try? await appState.updateTransactionType(id: tx.id, newType: .transfer) }
                    }

                    ExpenditureTypePill(
                        title: "儲值 (不計入預算)",
                        isSelected: currentType == .topUp
                    ) {
                        selectedExpenditureTypes[tx.id] = .topUp
                        Task { try? await appState.updateTransactionType(id: tx.id, newType: .topUp) }
                    }

                    ExpenditureTypePill(
                        title: "手續費",
                        isSelected: currentType == .fee
                    ) {
                        selectedExpenditureTypes[tx.id] = .fee
                        Task { try? await appState.updateTransactionType(id: tx.id, newType: .fee) }
                    }
                }
            }
        }

        // Quick Category Pills
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickPillButton(title: "餐飲") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.diningCategoryId) }
                }
                QuickPillButton(title: "交通") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.transportCategoryId) }
                }
                QuickPillButton(title: "購物") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.shoppingCategoryId) }
                }
                QuickPillButton(title: "水電帳單") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.billsCategoryId) }
                }
                QuickPillButton(title: "休閒娛樂") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.entertainmentCategoryId) }
                }
                QuickPillButton(title: "其他") {
                    Task { try? await appState.confirmCategory(id: tx.id, categoryId: AppState.othersCategoryId) }
                }
            }
        }

        Divider()
            .background(DesignTokens.Colors.dividerLight)

        Text("選定後會記住此商戶的分類與類型，之後自動套用。")
            .font(.system(size: 13))
            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
    }

    // Sub-card 2: Amount Review
    @ViewBuilder
    private func amountReviewCardContent(for tx: TransactionEntity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.accentLight)
            Text("金額需核對")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.accentLight)
        }

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.merchantCanonical ?? tx.merchantRaw ?? "待確認商戶")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Text("\(tx.provider.rawValue) · \(tx.captureChannel.rawValue) · \(formattedDate(tx))")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }
            Spacer()
            let amt = tx.ledgerAmountMinor ?? tx.amountMinor ?? 0
            Text(amt == 0 ? "$0 (待結算預授權)" : String(format: "%@$%.2f", tx.currency ?? appState.baseCurrency, Double(amt) / 100.0))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(amt == 0 ? DesignTokens.Colors.warningLight : DesignTokens.Colors.textPrimaryLight)
        }

        Text("交易金額待結算或需核對，請點選確認處理方式：")
            .font(.system(size: 14))
            .foregroundColor(DesignTokens.Colors.textSecondaryLight)

        if !tx.candidateAmountsMinor.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("辨識到多個候選金額，點選直接採用：")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tx.candidateAmountsMinor, id: \.self) { minor in
                            CandidateAmountButton(
                                title: String(format: "%@$%.2f", tx.currency ?? appState.baseCurrency, Double(minor) / 100.0)
                            ) {
                                Task {
                                    try? await appState.updateTransactionAmount(id: tx.id, newAmountMinor: minor)
                                    let catId = (tx.merchantRaw?.localizedCaseInsensitiveContains("mtr") == true || tx.merchantRaw?.contains("港鐵") == true)
                                        ? AppState.transportCategoryId
                                        : AppState.othersCategoryId
                                    try? await appState.confirmCategory(id: tx.id, categoryId: catId)
                                }
                            }
                        }
                    }
                }
            }
        }

        HStack(spacing: 12) {
            Button(action: {
                Task {
                    let catId = (tx.merchantRaw?.localizedCaseInsensitiveContains("mtr") == true || tx.merchantRaw?.contains("港鐵") == true)
                        ? AppState.transportCategoryId
                        : AppState.othersCategoryId
                    try? await appState.confirmCategory(id: tx.id, categoryId: catId)
                }
            }) {
                Text("確認此筆入帳")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(DesignTokens.Colors.accentLight)
                    .cornerRadius(22)
            }

            Button(action: {
                showingScreenshotSheet = true
            }) {
                Text("查看截圖")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    .frame(width: 100)
                    .frame(height: 44)
                    .background(Color(hex: "E8E5DD"))
                    .cornerRadius(22)
            }
        }
    }

    // Sub-card 3: Duplicate Resolution
    @ViewBuilder
    private func duplicateCardContent(for tx: TransactionEntity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "square.on.square")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.accentLight)
            Text("疑似重複")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.Colors.accentLight)
        }

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.merchantCanonical ?? tx.merchantRaw ?? "McDonald's")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Text("\(tx.provider.rawValue) · \(tx.captureChannel.rawValue) · \(formattedDate(tx))")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }
            Spacer()
            Text(String(format: "%@$%.2f", tx.currency ?? appState.baseCurrency, Double(tx.ledgerAmountMinor ?? tx.amountMinor ?? 0) / 100.0))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
        }

        Text("系統在 60 秒內偵測到兩筆完全相同的金額與商戶。")
            .font(.system(size: 14))
            .foregroundColor(DesignTokens.Colors.textSecondaryLight)

        HStack(spacing: 12) {
            Button(action: {
                Task {
                    try? await appState.deleteTransaction(id: tx.id)
                }
            }) {
                Text("是同一筆，合併")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DesignTokens.Colors.accentLight)
                    .cornerRadius(24)
            }

            Button(action: {
                Task {
                    try? await appState.confirmCategory(id: tx.id, categoryId: tx.categoryId ?? AppState.othersCategoryId)
                }
            }) {
                Text("不是，另外記帳")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "E8E5DD"))
                    .cornerRadius(24)
            }
        }
    }
}

private struct ExpenditureTypePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimaryLight)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(isSelected ? DesignTokens.Colors.accentLight : Color(hex: "F0EFEA"))
                .cornerRadius(17)
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(isSelected ? Color.clear : DesignTokens.Colors.dividerLight, lineWidth: 1)
                )
        }
        .accessibilityLabel("選擇支出類型 \(title)")
    }
}

private struct QuickPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(Color(hex: "F0EFEA"))
                .cornerRadius(19)
        }
        .accessibilityLabel("分類為 \(title)")
    }
}

private struct CandidateAmountButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(hex: "F0EFEA"))
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
                )
        }
        .accessibilityLabel("選擇金額 \(title)")
    }
}

private struct ScreenshotPreviewModalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "E5E2DA"))
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.image")
                                .font(.system(size: 48))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Text("茶記 Cafe 付款截圖")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            Text("總計: HK$85.00  |  會員扣減: -HK$27.00\n實付: HK$58.00")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .multilineTextAlignment(.center)
                        }
                    )
                    .padding(.horizontal, 20)

                Text("本機 OCR 辨識出原價 HK$85.00 與實付 HK$58.00，請選擇實際付款金額。")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("原始截圖預覽")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") { dismiss() }
                        .foregroundColor(DesignTokens.Colors.accentLight)
                }
            }
        }
    }
}
