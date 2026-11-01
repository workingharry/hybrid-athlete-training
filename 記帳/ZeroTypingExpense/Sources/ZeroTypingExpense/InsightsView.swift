import SwiftUI

public struct InsightsCategoryItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let amountMinor: Int64
    public let percentage: Int
    public let currency: String

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        amountMinor: Int64,
        percentage: Int,
        currency: String = "HKD"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.amountMinor = amountMinor
        self.percentage = percentage
        self.currency = currency
    }

    public var formattedAmount: String {
        return String(format: "%@$%.2f", currency, Double(amountMinor) / 100.0)
    }
}

public struct InsightsMerchantItem: Identifiable, Sendable {
    public let id: UUID
    public let rank: Int
    public let name: String
    public let count: Int
    public let totalAmountMinor: Int64
    public let currency: String

    public init(
        id: UUID = UUID(),
        rank: Int,
        name: String,
        count: Int,
        totalAmountMinor: Int64,
        currency: String = "HKD"
    ) {
        self.id = id
        self.rank = rank
        self.name = name
        self.count = count
        self.totalAmountMinor = totalAmountMinor
        self.currency = currency
    }

    public var formattedTotal: String {
        return String(format: "%@$%.2f", currency, Double(totalAmountMinor) / 100.0)
    }
}

public struct InsightsSourceItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let percentage: Int
    public let amountMinor: Int64
    public let currency: String

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        percentage: Int,
        amountMinor: Int64,
        currency: String = "HKD"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.percentage = percentage
        self.amountMinor = amountMinor
        self.currency = currency
    }

    public var formattedAmount: String {
        return String(format: "%@$%.2f", currency, Double(amountMinor) / 100.0)
    }
}

public struct InsightsView: View {
    @ObservedObject public var appState: AppState
    @State private var selectedTimeRange: Int = 1 // 0: 本週, 1: 本月
    @State private var reportData: InsightsReportData? = nil

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("時間範圍", selection: $selectedTimeRange) {
                        Text("本週").tag(0)
                        Text("本月").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    let totalSpent = reportData?.totalSpentMinor ?? 0
                    let currency = reportData?.currency ?? appState.baseCurrency

                    // Card 1: Total Spending in period
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedTimeRange == 0 ? "本週總支出" : "本月總支出")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                        Text(String(format: "%@$%.2f", currency, Double(totalSpent) / 100.0))
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        Text("自動歸戶 100% · 退款已即時抵減 · 轉帳/儲值已排除")
                            .font(.system(size: 12))
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

                    let categories = reportData?.categoryDistribution ?? []
                    // Card 2: Category Distribution
                    VStack(alignment: .leading, spacing: 14) {
                        Text("分類佔比")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        if categories.isEmpty {
                            Text("此期間尚無已確認的支出分類")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(categories) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(DesignTokens.Colors.accentLight)
                                            .frame(width: 24, height: 24)

                                        Text(item.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                                        Spacer()

                                        Text("\(item.percentage)% · \(item.formattedAmount)")
                                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                    }

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: "E8E5DD"))
                                                .frame(height: 6)

                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(DesignTokens.Colors.accentLight)
                                                .frame(width: geo.size.width * CGFloat(item.percentage) / 100.0, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
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

                    let merchants = reportData?.topMerchants ?? []
                    // Card 3: Top 5 Merchants
                    VStack(alignment: .leading, spacing: 14) {
                        Text("前五大消費商戶")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        if merchants.isEmpty {
                            Text("此期間尚無商戶消費紀錄")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(merchants) { merchant in
                                HStack {
                                    Text("\(merchant.rank)")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                        .frame(width: 24, height: 24)
                                        .background(DesignTokens.Colors.accentLight.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(merchant.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                        Text("\(merchant.count) 筆交易")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                    }

                                    Spacer()

                                    Text(merchant.formattedTotal)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                }
                                if merchant.rank < merchants.count {
                                    Divider()
                                        .background(DesignTokens.Colors.dividerLight)
                                }
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

                    let sources = reportData?.sourceDistribution ?? []
                    // Card 4: Source Distribution (Apple Pay iPhone vs Apple Watch)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("支付來源與設備分佈")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                        if sources.isEmpty {
                            Text("尚無設備支出紀錄")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(sources) { src in
                                HStack {
                                    Image(systemName: src.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                        .frame(width: 28, height: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(src.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                        Text("\(src.percentage)% 佔比")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                    }

                                    Spacer()

                                    Text(src.formattedAmount)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                                }
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
                .padding(.vertical, 16)
            }
            .background(DesignTokens.Colors.backgroundLight.ignoresSafeArea())
            .navigationTitle("分析")
            .task(id: selectedTimeRange) {
                await refreshData()
            }
            .onReceive(appState.$transactions) { _ in
                Task { await refreshData() }
            }
        }
    }

    private func refreshData() async {
        let range: InsightsTimeRange = (selectedTimeRange == 0) ? .week : .month
        reportData = await appState.getInsightsData(timeRange: range)
    }
}
