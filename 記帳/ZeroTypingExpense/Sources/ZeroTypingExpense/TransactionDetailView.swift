import SwiftUI

public struct TransactionDetailView: View {
    @ObservedObject var appState: AppState
    let transactionId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var showingCategoryPicker: Bool = false
    @State private var showingDeleteAlert: Bool = false

    public init(appState: AppState = AppState.shared, transactionId: UUID) {
        self.appState = appState
        self.transactionId = transactionId
    }

    private var transaction: TransactionEntity? {
        appState.transactions.first { $0.id == transactionId }
    }

    private func formattedAmount(for tx: TransactionEntity) -> String {
        let amt = Double(tx.ledgerAmountMinor ?? tx.amountMinor ?? 0) / 100.0
        let cur = tx.ledgerCurrency ?? tx.currency ?? appState.baseCurrency
        return String(format: "%@$%.2f", cur, amt)
    }

    private func formattedDate(for tx: TransactionEntity) -> String {
        let date = tx.transactionDate ?? tx.capturedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func onReturnToReview(id: UUID) {
        Task { @MainActor in
            try? await appState.returnToNeedsReview(id: id)
            dismiss()
        }
    }

    private func onHideTransaction(id: UUID) {
        Task { @MainActor in
            try? await appState.hideTransaction(id: id)
            dismiss()
        }
    }

    private func onDeleteTransaction(id: UUID) {
        Task { @MainActor in
            try? await appState.deleteTransaction(id: id)
            dismiss()
        }
    }

    public var body: some View {
        NavigationStack {
            if let tx = transaction {
                ScrollView {
                    VStack(spacing: 24) {
                        headerCard(tx: tx)
                        statusDimensionsView(tx: tx)
                        typeSelectorView(tx: tx)
                        metadataGridView(tx: tx)
                        actionButtonsView(tx: tx)
                    }
                }
                .navigationTitle("交易詳情")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.accentLight)
                    }
                }
                .sheet(isPresented: $showingCategoryPicker) {
                    CategoryPickerSheet(appState: appState, transactionId: tx.id)
                }
            } else {
                VStack(spacing: 16) {
                    Text("找不到交易資料")
                        .font(.system(size: 18, weight: .semibold))
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-components

    @ViewBuilder
    private func headerCard(tx: TransactionEntity) -> some View {
        VStack(spacing: 8) {
            Image(systemName: tx.deviceSource == .appleWatch ? "applewatch" : "iphone")
                .font(.system(size: 28))
                .foregroundColor(DesignTokens.Colors.accentLight)
                .frame(width: 56, height: 56)
                .background(DesignTokens.Colors.accentLight.opacity(0.12))
                .clipShape(Circle())

            Text(tx.merchantCanonical ?? tx.merchantRaw ?? "未命名商戶")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                .multilineTextAlignment(.center)

            Text(formattedAmount(for: tx))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)

            if tx.merchantCanonical != nil, let raw = tx.merchantRaw, raw != tx.merchantCanonical {
                Text("原始商戶：\(raw)")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func statusDimensionsView(tx: TransactionEntity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("交易狀態維度")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)

            HStack(spacing: 10) {
                StatusPill(
                    title: reviewStatusText(tx.reviewStatus),
                    icon: tx.reviewStatus == .confirmed ? "checkmark.seal.fill" : "exclamationmark.circle.fill",
                    color: tx.reviewStatus == .confirmed ? DesignTokens.Colors.successLight : DesignTokens.Colors.warningLight
                )

                StatusPill(
                    title: paymentStatusText(tx.paymentStatus),
                    icon: "creditcard.fill",
                    color: tx.paymentStatus == .completed ? DesignTokens.Colors.accentLight : DesignTokens.Colors.warningLight
                )

                StatusPill(
                    title: duplicateStatusText(tx.duplicateStatus),
                    icon: "shield.checkered",
                    color: tx.duplicateStatus == .unique ? DesignTokens.Colors.successLight : DesignTokens.Colors.warningLight
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(DesignTokens.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func typeSelectorView(tx: TransactionEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("支出性質")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                Spacer()
                if tx.transactionType == .transfer || tx.transactionType == .topUp {
                    Text("不計入預算")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.accentLight)
                }
            }

            HStack(spacing: 8) {
                TypePillButton(title: "一般消費", isSelected: tx.transactionType == .payment) {
                    Task { try? await appState.updateTransactionType(id: tx.id, newType: .payment) }
                }
                TypePillButton(title: "轉帳", isSelected: tx.transactionType == .transfer) {
                    Task { try? await appState.updateTransactionType(id: tx.id, newType: .transfer) }
                }
                TypePillButton(title: "儲值", isSelected: tx.transactionType == .topUp) {
                    Task { try? await appState.updateTransactionType(id: tx.id, newType: .topUp) }
                }
                TypePillButton(title: "手續費", isSelected: tx.transactionType == .fee) {
                    Task { try? await appState.updateTransactionType(id: tx.id, newType: .fee) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(DesignTokens.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func metadataGridView(tx: TransactionEntity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("交易詳情")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)

            DetailRow(label: "消費分類", value: AppState.categoryName(for: tx.categoryId, in: appState.categories))
            DetailRow(label: "扣款管道", value: tx.provider.rawValue)
            DetailRow(label: "設備來源", value: tx.deviceSource == .appleWatch ? "Apple Watch" : "iPhone")
            DetailRow(label: "交易時間", value: formattedDate(for: tx))
            DetailRow(label: "去重憑證", value: tx.idempotencyKey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(DesignTokens.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func actionButtonsView(tx: TransactionEntity) -> some View {
        VStack(spacing: 12) {
            Button(action: { showingCategoryPicker = true }, label: {
                HStack {
                    Image(systemName: "tag.fill")
                    Text("變更分類")
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignTokens.Colors.accentLight)
                .foregroundColor(.white)
                .cornerRadius(DesignTokens.Layout.buttonCornerRadius)
            })

            if tx.reviewStatus == .confirmed {
                Button(action: { onReturnToReview(id: tx.id) }, label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("退回待審核 (§9.3)")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "E8E5DD"))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    .cornerRadius(DesignTokens.Layout.buttonCornerRadius)
                })
            }

            Button(action: { onHideTransaction(id: tx.id) }, label: {
                HStack {
                    Image(systemName: "eye.slash.fill")
                    Text("隱藏交易（軟刪除不丟失）")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .frame(height: 40)
            })

            Button(role: .destructive, action: { showingDeleteAlert = true }, label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("徹底刪除交易")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.dangerLight)
                .frame(height: 44)
            })
            .confirmationDialog("確認徹底刪除交易？", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
                Button("確認刪除", role: .destructive) {
                    onDeleteTransaction(id: tx.id)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作將永久移除此筆交易及其關聯紀錄，不可復原。")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private func reviewStatusText(_ s: ReviewStatus) -> String {
        switch s {
        case .confirmed: return "已確認"
        case .needsCategory: return "待分類"
        case .needsReview: return "待審核"
        }
    }

    private func paymentStatusText(_ s: PaymentStatus) -> String {
        switch s {
        case .completed: return "已完成"
        case .pending: return "待結算"
        case .cancelled: return "已取消"
        case .partiallyRefunded: return "部分退款"
        case .refunded: return "已全退"
        case .unknown: return "狀態未知"
        }
    }

    private func duplicateStatusText(_ s: DuplicateStatus) -> String {
        switch s {
        case .unique: return "唯一有效"
        case .possibleDuplicate: return "疑似重複"
        case .confirmedDuplicate: return "已標重複"
        }
    }
}

// MARK: - Subviews

private struct StatusPill: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct TypePillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimaryLight)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(isSelected ? DesignTokens.Colors.accentLight : Color(hex: "E8E5DD"))
                .cornerRadius(17)
        }
    }
}

private struct CategoryPickerSheet: View {
    @ObservedObject var appState: AppState
    let transactionId: UUID
    @Environment(\.dismiss) private var dismiss

    private func onSelectCategory(categoryId: UUID) {
        Task { @MainActor in
            try? await appState.confirmCategory(id: transactionId, categoryId: categoryId)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            List(appState.categories) { cat in
                Button(action: { onSelectCategory(categoryId: cat.id) }, label: {
                    HStack(spacing: 14) {
                        Image(systemName: AppState.categoryIcon(for: cat.id))
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.Colors.accentLight)
                            .frame(width: 32, height: 32)
                            .background(DesignTokens.Colors.accentLight.opacity(0.12))
                            .cornerRadius(8)

                        Text(cat.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        Spacer()
                    }
                })
            }
            .navigationTitle("選擇分類")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
