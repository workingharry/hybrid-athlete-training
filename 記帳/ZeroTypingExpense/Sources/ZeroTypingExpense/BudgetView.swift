import SwiftUI

public struct BudgetCategoryItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let spentAmountMinor: Int64
    public let budgetAmountMinor: Int64
    public let currency: String

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        spentAmountMinor: Int64,
        budgetAmountMinor: Int64,
        currency: String = "HKD"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.spentAmountMinor = spentAmountMinor
        self.budgetAmountMinor = budgetAmountMinor
        self.currency = currency
    }

    public var percentageUsed: Int {
        guard budgetAmountMinor > 0 else { return 0 }
        return Int(round(Double(spentAmountMinor) / Double(budgetAmountMinor) * 100))
    }

    public var isExceeded: Bool {
        return spentAmountMinor > budgetAmountMinor
    }

    public var formattedSpent: String {
        return String(format: "%@$%.2f", currency, Double(spentAmountMinor) / 100.0)
    }

    public var formattedBudget: String {
        return String(format: "%@$%.2f", currency, Double(budgetAmountMinor) / 100.0)
    }
}

public struct BudgetView: View {
    @ObservedObject public var appState: AppState
    @State private var showingEditBudgetSheet: Bool = false
    @State private var categories: [BudgetCategoryItem] = []

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var currency: String {
        appState.baseCurrency
    }

    private var monthlyBudgetTotalMinor: Int64 {
        appState.monthlyBudgetTotalMinor
    }

    private var netSpentMinor: Int64 {
        appState.monthlyNetSpentMinor
    }

    private var totalRefundsMinor: Int64 {
        appState.totalRefundsMinor
    }

    private var remainingMinor: Int64 {
        monthlyBudgetTotalMinor - netSpentMinor
    }

    private var totalPercentageUsed: Int {
        appState.budgetUsedPercentage
    }

    private var isOverBudget: Bool {
        netSpentMinor > monthlyBudgetTotalMinor
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("本月預算總覽")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Spacer()
                            Text("已用 \(totalPercentageUsed)%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isOverBudget ? DesignTokens.Colors.errorLight : DesignTokens.Colors.textPrimaryLight)
                        }

                        Text(String(format: "%@$%.2f", currency, Double(abs(remainingMinor)) / 100.0))
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundColor(isOverBudget ? DesignTokens.Colors.errorLight : DesignTokens.Colors.textPrimaryLight)

                        Text(isOverBudget ? "⚠️ 已超出總預算" : "剩餘可用預算")
                            .font(.system(size: 14, weight: isOverBudget ? .bold : .regular))
                            .foregroundColor(isOverBudget ? DesignTokens.Colors.errorLight : DesignTokens.Colors.textSecondaryLight)

                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "E8E5DD"))
                                    .frame(height: 12)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isOverBudget ? DesignTokens.Colors.errorLight : DesignTokens.Colors.accentLight)
                                    .frame(width: min(geometry.size.width, geometry.size.width * CGFloat(Double(netSpentMinor) / Double(max(1, monthlyBudgetTotalMinor)))), height: 12)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("實支: \(String(format: "%@$%.2f", currency, Double(netSpentMinor) / 100.0))")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                            Spacer()
                            Text("目標: \(String(format: "%@$%.2f", currency, Double(monthlyBudgetTotalMinor) / 100.0))")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        }

                        // Refund deduction pill badge per §A.4
                        if totalRefundsMinor > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .foregroundColor(DesignTokens.Colors.successLight)
                                    .font(.system(size: 13))
                                Text("退款已抵減: \(String(format: "%@$%.2f", currency, Double(totalRefundsMinor) / 100.0))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(DesignTokens.Colors.successLight)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DesignTokens.Colors.successLight.opacity(0.12))
                            .cornerRadius(12)
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

                    // Category Breakdown Cards
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("各類別預算使用進度")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            Spacer()
                            Button("調整預算") {
                                showingEditBudgetSheet = true
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.accentLight)
                        }

                        ForEach(categories) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(DesignTokens.Colors.accentLight)
                                        .frame(width: 28, height: 28)
                                        .background(DesignTokens.Colors.accentLight.opacity(0.12))
                                        .cornerRadius(8)

                                    Text(item.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                                    Spacer()

                                    Text("\(item.percentageUsed)%")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundColor(item.isExceeded ? DesignTokens.Colors.errorLight : (item.percentageUsed >= 80 ? DesignTokens.Colors.warningLight : DesignTokens.Colors.textPrimaryLight))
                                }

                                // Category Progress Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(hex: "E8E5DD"))
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(item.isExceeded ? DesignTokens.Colors.errorLight : (item.percentageUsed >= 80 ? DesignTokens.Colors.warningLight : DesignTokens.Colors.accentLight))
                                            .frame(width: min(geo.size.width, geo.size.width * CGFloat(Double(item.spentAmountMinor) / Double(max(1, item.budgetAmountMinor)))), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("已用 \(item.formattedSpent)")
                                        .font(.system(size: 13))
                                        .foregroundColor(item.isExceeded ? DesignTokens.Colors.errorLight : DesignTokens.Colors.textSecondaryLight)

                                    Spacer()

                                    Text("預算 \(item.formattedBudget)")
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                }
                            }
                            .padding(16)
                            .background(DesignTokens.Colors.surfaceLight)
                            .cornerRadius(DesignTokens.Layout.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                                    .stroke(item.isExceeded ? DesignTokens.Colors.errorLight.opacity(0.4) : DesignTokens.Colors.dividerLight, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(DesignTokens.Colors.backgroundLight.ignoresSafeArea())
            .navigationTitle("預算")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingEditBudgetSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    }
                    .accessibilityLabel("編輯預算上限")
                }
            }
            .sheet(isPresented: $showingEditBudgetSheet) {
                EditBudgetSheet(appState: appState)
            }
            .task {
                await refreshBudgets()
            }
            .onReceive(appState.$transactions) { _ in
                Task { await refreshBudgets() }
            }
            .onReceive(appState.$categoryBudgets) { _ in
                Task { await refreshBudgets() }
            }
            .onReceive(appState.$monthlyBudgetTotalMinor) { _ in
                Task { await refreshBudgets() }
            }
        }
    }

    private func refreshBudgets() async {
        categories = await appState.getBudgetCategories()
    }
}

// MARK: - Edit Budget Sheet

public struct EditBudgetSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var monthlyTotalString: String = ""
    @State private var localCategoryBudgets: [UUID: String] = [:]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("月度總預算")) {
                    HStack {
                        Text(appState.baseCurrency)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.accentLight)
                        #if os(iOS)
                        TextField("金額", text: $monthlyTotalString)
                            .keyboardType(.numberPad)
                        #else
                        TextField("金額", text: $monthlyTotalString)
                        #endif
                    }
                }

                Section(header: Text("各分類預算上限")) {
                    ForEach(appState.categories) { cat in
                        HStack {
                            Image(systemName: AppState.categoryIcon(for: cat.id))
                                .font(.system(size: 15))
                                .foregroundColor(DesignTokens.Colors.accentLight)
                                .frame(width: 24)

                            Text(cat.name)
                                .font(.system(size: 15))

                            Spacer()

                            #if os(iOS)
                            TextField("預算", text: Binding(
                                get: { localCategoryBudgets[cat.id] ?? "0" },
                                set: { localCategoryBudgets[cat.id] = $0 }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            #else
                            TextField("預算", text: Binding(
                                get: { localCategoryBudgets[cat.id] ?? "0" },
                                set: { localCategoryBudgets[cat.id] = $0 }
                            ))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            #endif
                        }
                    }
                }
            }
            .navigationTitle("設定預算")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveBudgets()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.accentLight)
                }
            }
            .onAppear {
                monthlyTotalString = String(appState.monthlyBudgetTotalMinor / 100)
                var map: [UUID: String] = [:]
                for cat in appState.categories {
                    let minor = appState.categoryBudgets[cat.id] ?? 0
                    map[cat.id] = String(minor / 100)
                }
                localCategoryBudgets = map
            }
        }
    }

    private func saveBudgets() {
        if let totalVal = Int64(monthlyTotalString), totalVal >= 0 {
            appState.updateMonthlyBudgetTotal(amountMinor: totalVal * 100)
        }
        for (catId, strVal) in localCategoryBudgets {
            if let val = Int64(strVal), val >= 0 {
                appState.updateCategoryBudget(categoryId: catId, amountMinor: val * 100)
            }
        }
    }
}
