import SwiftUI

public struct LedgerView: View {
    @ObservedObject public var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var selectedFilterCategory: String = "全部"
    @State private var selectedTransactionId: UUID? = nil

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var textPrimary: Color {
        colorScheme == .dark ? DesignTokens.Colors.textPrimaryDark : DesignTokens.Colors.textPrimaryLight
    }

    private var textSecondary: Color {
        colorScheme == .dark ? DesignTokens.Colors.textSecondaryDark : DesignTokens.Colors.textSecondaryLight
    }

    private var surfaceBg: Color {
        colorScheme == .dark ? DesignTokens.Colors.surfaceDark : DesignTokens.Colors.surfaceLight
    }

    private var pillInactiveBg: Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(hex: "E8E5DD")
    }

    private var filteredTransactions: [TransactionEntity] {
        appState.transactions.filter { tx in
            guard !tx.isHidden else { return false }
            let merchant = tx.merchantCanonical ?? tx.merchantRaw ?? ""
            let catName = AppState.categoryName(for: tx.categoryId, in: appState.categories)

            let matchesSearch = searchText.isEmpty ||
                merchant.localizedCaseInsensitiveContains(searchText) ||
                catName.localizedCaseInsensitiveContains(searchText)

            let matchesCategory: Bool
            if selectedFilterCategory == "全部" {
                matchesCategory = true
            } else if selectedFilterCategory == "不計入預算" {
                matchesCategory = (tx.transactionType == .transfer || tx.transactionType == .topUp)
            } else {
                matchesCategory = (catName == selectedFilterCategory)
            }

            return matchesSearch && matchesCategory
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            let filterOptions = ["全部", "餐飲", "交通", "購物", "水電帳單", "休閒娛樂", "其他", "不計入預算"]
                            ForEach(filterOptions, id: \.self) { filter in
                                Button(action: { selectedFilterCategory = filter }) {
                                    Text(filter)
                                        .font(.system(size: 13, weight: selectedFilterCategory == filter ? .bold : .medium))
                                        .foregroundColor(selectedFilterCategory == filter ? .white : textPrimary)
                                        .padding(.horizontal, 14)
                                        .frame(height: 32)
                                        .background(selectedFilterCategory == filter ? DesignTokens.Colors.accentLight : pillInactiveBg)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if filteredTransactions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(textSecondary)
                        Text("無符合篩選條件的交易")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredTransactions) { tx in
                        let merchantName = tx.merchantCanonical ?? tx.merchantRaw ?? "未命名商戶"
                        let catName = AppState.categoryName(for: tx.categoryId, in: appState.categories)
                        let date = tx.transactionDate ?? tx.capturedAt
                        let dateStr = date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute())

                        let deviceIcon = tx.deviceSource == .appleWatch ? "applewatch" : "iphone"
                        let cur = tx.ledgerCurrency ?? tx.currency ?? appState.baseCurrency
                        let amt = Double(tx.ledgerAmountMinor ?? tx.amountMinor ?? 0) / 100.0

                        HStack(spacing: 12) {
                            Image(systemName: deviceIcon)
                                .font(.system(size: 16))
                                .foregroundColor(DesignTokens.Colors.accentLight)
                                .frame(width: 32, height: 32)
                                .background(DesignTokens.Colors.accentLight.opacity(0.15))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(merchantName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(textPrimary)

                                    if let badge = typeBadge(for: tx) {
                                        Text(badge)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(pillInactiveBg)
                                            .cornerRadius(6)
                                    }
                                }

                                Text("\(tx.provider.rawValue) · \(catName) · \(dateStr)")
                                    .font(.system(size: 12))
                                    .foregroundColor(textSecondary)
                            }

                            Spacer()

                            Text(String(format: "%@$%.2f", cur, amt))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(tx.transactionType == .transfer || tx.transactionType == .topUp ? textSecondary : textPrimary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransactionId = tx.id
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { try? await appState.deleteTransaction(id: tx.id) }
                            } label: {
                                Label("徹底刪除", systemImage: "trash.fill")
                            }

                            Button {
                                Task { try? await appState.hideTransaction(id: tx.id) }
                            } label: {
                                Label("隱藏", systemImage: "eye.slash")
                            }
                            .tint(.gray)

                            if tx.reviewStatus == .confirmed {
                                Button {
                                    Task { try? await appState.returnToNeedsReview(id: tx.id) }
                                } label: {
                                    Label("退回待核", systemImage: "arrow.uturn.backward")
                                }
                                .tint(DesignTokens.Colors.warningLight)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜尋商戶或分類")
            .navigationTitle("帳本")
            .sheet(item: Binding<IdentifiableUUID?>(
                get: { selectedTransactionId.map { IdentifiableUUID(id: $0) } },
                set: { selectedTransactionId = $0?.id }
            )) { wrapper in
                TransactionDetailView(appState: appState, transactionId: wrapper.id)
            }
        }
    }

    private func typeBadge(for tx: TransactionEntity) -> String? {
        switch tx.transactionType {
        case .transfer: return "轉帳"
        case .topUp: return "儲值"
        case .fee: return "手續費"
        case .refund: return "退款"
        case .adjustment: return "調整"
        case .payment, .unknown:
            if tx.paymentStatus == .pending {
                return "待結算"
            }
            return nil
        }
    }
}

private struct IdentifiableUUID: Identifiable {
    let id: UUID
}
