import SwiftUI

public struct DashboardView: View {
    @ObservedObject public var appState: AppState

    @State private var showingPendingReview: Bool = false
    @State private var showingSettingsMenu: Bool = false
    @State private var showingPaymentSources: Bool = false
    @State private var showingCleanupSettings: Bool = false
    @State private var showingBackupExport: Bool = false
    @State private var showingApplePayGuide: Bool = false

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var todaySpending: String {
        String(format: "%@$%.2f", appState.baseCurrency, Double(appState.todaySpendingMinor) / 100.0)
    }

    private var confirmedTransactionsCount: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return appState.transactions.filter { tx in
            guard !tx.isHidden, tx.reviewStatus == .confirmed,
                  tx.duplicateStatus != .possibleDuplicate, tx.duplicateStatus != .confirmedDuplicate,
                  tx.transactionType == .payment || tx.transactionType == .fee else { return false }
            return (tx.transactionDate ?? tx.capturedAt) >= startOfDay
        }.count
    }

    private var sourcesCount: Int {
        let providers = Set(appState.visibleTransactions.map { $0.provider })
        return max(1, providers.count)
    }

    private var monthlyBudgetRemaining: String {
        String(format: "%@$%.2f", appState.baseCurrency, Double(appState.monthlyBudgetRemainingMinor) / 100.0)
    }

    private var budgetUsedPercentage: Int {
        appState.budgetUsedPercentage
    }

    private var budgetUsedAmount: String {
        String(format: "%@$%.2f", appState.baseCurrency, Double(appState.monthlyNetSpentMinor) / 100.0)
    }

    private var totalBudgetAmount: String {
        String(format: "%@$%.2f", appState.baseCurrency, Double(appState.monthlyBudgetTotalMinor) / 100.0)
    }

    private var pendingCount: Int {
        appState.pendingTransactions.count
    }

    private var pendingCategorizationAmount: String {
        let total = appState.pendingTransactions.reduce(Int64(0)) { $0 + ($1.ledgerAmountMinor ?? $1.amountMinor ?? 0) }
        return String(format: "%@$%.2f", appState.baseCurrency, Double(total) / 100.0)
    }

    private var headerDateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private func formattedTxTime(_ tx: TransactionEntity) -> String {
        let date = tx.transactionDate ?? tx.capturedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: date)) 擷取"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(headerDateFormatted)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Text("總覽")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                        }
                        Spacer()
                        Button(action: { showingSettingsMenu = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                .frame(width: 48, height: 48)
                        }
                        .accessibilityLabel("設定")
                    }
                    .padding(.horizontal, 20)

                    // Card 1: Today's Auto-Captured Spending
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TODAY'S AUTO-CAPTURED SPENDING")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                        Text(todaySpending)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        Text("\(sourcesCount) 個來源 · \(confirmedTransactionsCount) 筆已確認交易")
                            .font(.system(size: 15))
                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(DesignTokens.Colors.surfaceLight)
                    .cornerRadius(DesignTokens.Layout.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                            .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Card 2: Monthly Budget Remaining
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("MONTHLY BUDGET REMAINING")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Spacer()
                            Text("已用 \(budgetUsedPercentage)%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        }

                        Text(monthlyBudgetRemaining)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        // Budget Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.dividerLight)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.successLight)
                                    .frame(width: proxy.size.width * CGFloat(budgetUsedPercentage) / 100.0, height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("\(budgetUsedAmount) / \(totalBudgetAmount)")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Spacer()
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(DesignTokens.Colors.warningLight)
                            Text("\(pendingCategorizationAmount) 待分類，未計入已用")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(DesignTokens.Colors.surfaceLight)
                    .cornerRadius(DesignTokens.Layout.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                            .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Card 3: Pending Review Prompt (§5.5 & Page 1 Design)
                    if pendingCount > 0, let topPending = appState.pendingTransactions.first {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                    Text("待確認 \(pendingCount)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                }
                                Spacer()
                                Button(action: { showingPendingReview = true }) {
                                    Text("查看全部")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                }
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topPending.merchantCanonical ?? topPending.merchantRaw ?? "待確認商戶")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                    Text("\(topPending.provider.rawValue) · \(topPending.captureChannel.rawValue) · \(formattedTxTime(topPending))")
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                }
                                Spacer()
                                Text(String(format: "%@$%.2f", topPending.currency ?? appState.baseCurrency, Double(topPending.ledgerAmountMinor ?? topPending.amountMinor ?? 0) / 100.0))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            }

                            Text("選擇分類以確認")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                            HStack(spacing: 8) {
                                CategoryButton(title: "餐飲") {
                                    Task { try? await appState.confirmCategory(id: topPending.id, categoryId: AppState.diningCategoryId) }
                                }
                                CategoryButton(title: "交通") {
                                    Task { try? await appState.confirmCategory(id: topPending.id, categoryId: AppState.transportCategoryId) }
                                }
                                CategoryButton(title: "購物") {
                                    Task { try? await appState.confirmCategory(id: topPending.id, categoryId: AppState.shoppingCategoryId) }
                                }
                                CategoryButton(title: "更多", isMore: true) {
                                    showingPendingReview = true
                                }
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

                    // Recent Transactions Header
                    HStack {
                        Text("近期交易")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                        Spacer()
                        Button(action: {
                            appState.selectedTab = 3
                        }) {
                            Text("帳本")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Recent Transaction Rows (Dynamically bound to AppState)
                    VStack(spacing: 12) {
                        let recent = Array(appState.visibleTransactions.prefix(5))
                        if recent.isEmpty {
                            Text("尚無近期交易紀錄")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                                if index > 0 {
                                    Divider()
                                        .padding(.horizontal, 20)
                                }
                                TransactionRow(
                                    avatarInitial: String((tx.merchantCanonical ?? tx.merchantRaw ?? "市").prefix(1)),
                                    merchant: tx.merchantCanonical ?? tx.merchantRaw ?? "消費",
                                    categoryAndChannel: "\(AppState.categoryName(for: tx.categoryId, in: appState.categories)) · \(tx.provider.rawValue)",
                                    amount: String(format: "%@$%.2f", tx.currency ?? appState.baseCurrency, Double(tx.ledgerAmountMinor ?? tx.amountMinor ?? 0) / 100.0),
                                    time: formattedTxTime(tx)
                                )
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .background(DesignTokens.Colors.surfaceLight)
                    .cornerRadius(DesignTokens.Layout.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                            .stroke(DesignTokens.Colors.dividerLight, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 80)
                }
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(DesignTokens.Colors.bgLight.ignoresSafeArea())
            .sheet(isPresented: $showingPendingReview) {
                PendingReviewView(appState: appState)
            }
            .sheet(isPresented: $showingPaymentSources) {
                PaymentSourcesView()
            }
            .sheet(isPresented: $showingCleanupSettings) {
                CleanupSettingsView()
            }
            .sheet(isPresented: $showingBackupExport) {
                BackupExportView()
            }
            .sheet(isPresented: $showingApplePayGuide) {
                ApplePayOnboardingView()
            }
            .confirmationDialog("設定", isPresented: $showingSettingsMenu, titleVisibility: .visible) {
                Button("支付來源管理 (Screen S03)") { showingPaymentSources = true }
                Button("每週截圖清理 (Screen S09)") { showingCleanupSettings = true }
                Button("備份與匯出 (Screen S12)") { showingBackupExport = true }
                Button("Apple Pay 自動化設定教學 (Screen S02)") { showingApplePayGuide = true }
                Button("清除所有測試帳單 (清空沙盒)", role: .destructive) {
                    Task { await appState.clearAllSandboxTransactions() }
                }
                Button("還原預設範例帳單") {
                    Task { await appState.resetToInitialSeed() }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    var isMore: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isMore ? DesignTokens.Colors.textSecondaryLight : DesignTokens.Colors.textPrimaryLight)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(isMore ? Color.clear : DesignTokens.Colors.bgLight)
                .cornerRadius(19)
                .overlay(
                    RoundedRectangle(cornerRadius: 19)
                        .stroke(DesignTokens.Colors.dividerLight, lineWidth: isMore ? 1 : 0)
                )
        }
    }
}

struct TransactionRow: View {
    let avatarInitial: String
    let merchant: String
    let categoryAndChannel: String
    let amount: String
    let time: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(DesignTokens.Colors.bgLight)
                .frame(width: 42, height: 42)
                .overlay(
                    Text(avatarInitial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(merchant)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Text(categoryAndChannel)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Text(time)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
            }
        }
        .padding(.horizontal, 20)
    }
}
