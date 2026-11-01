import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

public enum InsightsTimeRange: String, CaseIterable, Sendable {
    case week = "本週"
    case month = "本月"
}

public struct InsightsReportData: Sendable {
    public let timeRange: InsightsTimeRange
    public let totalSpentMinor: Int64
    public let currency: String
    public let categoryDistribution: [InsightsCategoryItem]
    public let topMerchants: [InsightsMerchantItem]
    public let sourceDistribution: [InsightsSourceItem]

    public init(
        timeRange: InsightsTimeRange,
        totalSpentMinor: Int64,
        currency: String = "HKD",
        categoryDistribution: [InsightsCategoryItem],
        topMerchants: [InsightsMerchantItem],
        sourceDistribution: [InsightsSourceItem]
    ) {
        self.timeRange = timeRange
        self.totalSpentMinor = totalSpentMinor
        self.currency = currency
        self.categoryDistribution = categoryDistribution
        self.topMerchants = topMerchants
        self.sourceDistribution = sourceDistribution
    }
}

/// Central Reactive State & Persistence Coordinator (§5.1, §6.2-§6.4, §8.3-§8.8)
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState(engine: SharedTransactionEngine.shared)

    // MARK: - Cross-Process Notification Key
    public static let didIngestTransactionNotification = Notification.Name("com.zerotyping.expense.didIngestTransaction")

    // MARK: - Navigation State
    @Published public var selectedTab: Int = 0

    // MARK: - Standard Category UUIDs
    nonisolated public static let diningCategoryId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    nonisolated public static let transportCategoryId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    nonisolated public static let shoppingCategoryId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    nonisolated public static let billsCategoryId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    nonisolated public static let entertainmentCategoryId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    nonisolated public static let othersCategoryId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    // MARK: - Published Reactive State
    @Published public private(set) var transactions: [TransactionEntity] = []
    @Published public private(set) var refunds: [RefundEntity] = []
    @Published public private(set) var categories: [CategoryEntity] = []
    @Published public private(set) var categoryBudgets: [UUID: Int64] = [:]
    @Published public private(set) var monthlyBudgetTotalMinor: Int64 = 1_000_000 // HK$10,000.00
    @Published public var baseCurrency: String = "HKD"
    @Published public var showingOnboardingFromURL: Bool = false
    @Published public var urlActionToastMessage: String? = nil

    // Engine for fast actor-isolated calculations
    public let engine: TransactionEngine
    private let storageUrl: URL

    public init(
        storageUrl: URL? = nil,
        engine: TransactionEngine? = nil
    ) {
        let actualEngine = engine ?? TransactionEngine()
        self.engine = actualEngine
        self.storageUrl = storageUrl ?? ZeroTypingDiskStorage.defaultStorageURL

        self.categories = AppState.defaultCategories()
        self.categoryBudgets = AppState.defaultCategoryBudgets()
    }

    // MARK: - Default Factory Helpers

    nonisolated public static func defaultCategories() -> [CategoryEntity] {
        return [
            CategoryEntity(id: diningCategoryId, name: "餐飲", isDefault: true),
            CategoryEntity(id: transportCategoryId, name: "交通", isDefault: true),
            CategoryEntity(id: shoppingCategoryId, name: "購物", isDefault: true),
            CategoryEntity(id: billsCategoryId, name: "水電帳單", isDefault: true),
            CategoryEntity(id: entertainmentCategoryId, name: "休閒娛樂", isDefault: true),
            CategoryEntity(id: othersCategoryId, name: "其他", isDefault: true)
        ]
    }

    nonisolated public static func defaultCategoryBudgets() -> [UUID: Int64] {
        return [
            diningCategoryId: 350_000,        // HK$3,500.00
            shoppingCategoryId: 200_000,      // HK$2,000.00
            transportCategoryId: 100_000,     // HK$1,000.00
            billsCategoryId: 150_000,         // HK$1,500.00
            entertainmentCategoryId: 100_000, // HK$1,000.00
            othersCategoryId: 100_000         // HK$1,000.00
        ]
    }

    public static func categoryIcon(for categoryId: UUID?) -> String {
        guard let id = categoryId else { return "questionmark.circle" }
        switch id {
        case diningCategoryId: return "fork.knife"
        case transportCategoryId: return "tram.fill"
        case shoppingCategoryId: return "cart.fill"
        case billsCategoryId: return "doc.text.fill"
        case entertainmentCategoryId: return "film.fill"
        default: return "ellipsis.circle.fill"
        }
    }

    public static func categoryName(for categoryId: UUID?, in categories: [CategoryEntity]) -> String {
        guard let id = categoryId else { return "待分類" }
        return categories.first { $0.id == id }?.name ?? "其他"
    }

    // MARK: - Persistence Envelope


    public func load() async {
        if FileManager.default.fileExists(atPath: storageUrl.path) {
            do {
                let data = try Data(contentsOf: storageUrl)
                let envelope = try JSONDecoder().decode(AppStorageEnvelope.self, from: data)
                self.monthlyBudgetTotalMinor = envelope.monthlyBudgetTotalMinor
                self.categories = envelope.categories
                self.refunds = envelope.refunds
                self.transactions = envelope.transactions

                var restoredBudgets: [UUID: Int64] = [:]
                for (key, val) in envelope.categoryBudgets {
                    if let uuid = UUID(uuidString: key) {
                        restoredBudgets[uuid] = val
                    }
                }
                self.categoryBudgets = restoredBudgets

                // Sync into TransactionEngine
                _ = await engine.bulkImport(importedTransactions: envelope.transactions, overwrite: true)
                for ref in envelope.refunds {
                    try? await engine.addRefund(ref)
                }
                return
            } catch {
                print("Failed to load storage, resetting to default seeds: \(error)")
            }
        }

        // Seed initial data if file does not exist
        await seedDefaultData()
    }

    public func save() {
        var strBudgets: [String: Int64] = [:]
        for (k, v) in categoryBudgets {
            strBudgets[k.uuidString] = v
        }

        let envelope = AppStorageEnvelope(
            version: 1,
            monthlyBudgetTotalMinor: monthlyBudgetTotalMinor,
            categoryBudgets: strBudgets,
            categories: categories,
            transactions: transactions,
            refunds: refunds
        )

        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: storageUrl, options: .atomic)
        } catch {
            print("Failed to save storage envelope: \(error)")
        }
    }

    public func seedDefaultData() async {
        let now = Date()

        let initialTransactions: [TransactionEntity] = [
            TransactionEntity(
                idempotencyKey: "seed_1_mtr",
                provider: .applePay,
                captureChannel: .walletAutomation,
                deviceSource: .appleWatch,
                merchantRaw: "MTR",
                merchantCanonical: "港鐵 MTR",
                amountMinor: 1650, // HK$16.50
                currency: "HKD",
                categoryId: AppState.transportCategoryId,
                transactionDate: now.addingTimeInterval(-3600),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .payment
            ),
            TransactionEntity(
                idempotencyKey: "seed_2_cafe_de_coral",
                provider: .applePay,
                captureChannel: .walletAutomation,
                deviceSource: .iPhone,
                merchantRaw: "Café de Coral",
                merchantCanonical: "大家樂 Café de Coral",
                amountMinor: 5800, // HK$58.00
                currency: "HKD",
                categoryId: AppState.diningCategoryId,
                transactionDate: now.addingTimeInterval(-7200),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .payment
            ),
            TransactionEntity(
                idempotencyKey: "seed_3_wellcome",
                provider: .alipayHK,
                captureChannel: .backTap,
                deviceSource: .iPhone,
                merchantRaw: "Wellcome Supermarket",
                merchantCanonical: "惠康超級市場 Wellcome",
                amountMinor: 14200, // HK$142.00
                currency: "HKD",
                categoryId: AppState.shoppingCategoryId,
                transactionDate: now.addingTimeInterval(-18000),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .payment
            ),
            TransactionEntity(
                idempotencyKey: "seed_4_octopus_topup",
                provider: .applePay,
                captureChannel: .walletAutomation,
                deviceSource: .iPhone,
                merchantRaw: "Octopus TopUp",
                merchantCanonical: "八達通增值",
                amountMinor: 20000, // HK$200.00
                currency: "HKD",
                categoryId: nil,
                transactionDate: now.addingTimeInterval(-25000),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .topUp // Excluded from budget (§8.3)
            ),
            TransactionEntity(
                idempotencyKey: "seed_5_fps_transfer",
                provider: .other,
                captureChannel: .backTap,
                deviceSource: .iPhone,
                merchantRaw: "FPS Hang Seng",
                merchantCanonical: "跨行轉帳 Hang Seng",
                amountMinor: 50000, // HK$500.00
                currency: "HKD",
                categoryId: nil,
                transactionDate: now.addingTimeInterval(-40000),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .transfer // Excluded from budget (§8.3)
            ),
            TransactionEntity(
                idempotencyKey: "seed_6_electric_bill",
                provider: .applePay,
                captureChannel: .walletAutomation,
                deviceSource: .iPhone,
                merchantRaw: "HK Electric",
                merchantCanonical: "香港電燈 HK Electric",
                amountMinor: 45000, // HK$450.00
                currency: "HKD",
                categoryId: AppState.billsCategoryId,
                transactionDate: now.addingTimeInterval(-86400 * 2),
                reviewStatus: .confirmed,
                paymentStatus: .completed,
                transactionType: .payment
            ),
            TransactionEntity(
                idempotencyKey: "seed_7_pending_unknown",
                provider: .alipayHK,
                captureChannel: .backTap,
                deviceSource: .iPhone,
                merchantRaw: "Unknown Merchant",
                amountMinor: 8500, // HK$85.00
                currency: "HKD",
                categoryId: nil,
                transactionDate: now.addingTimeInterval(-1200),
                reviewStatus: .needsCategory, // Pending review
                paymentStatus: .completed,
                transactionType: .payment
            )
        ]

        self.transactions = initialTransactions
        _ = await engine.bulkImport(importedTransactions: initialTransactions, overwrite: true)
        save()
    }

    // MARK: - Ingestion & Mutation APIs

    public func ingestTransaction(_ entity: TransactionEntity) async throws {
        let storedTx = try await engine.ingestTransaction(entity)
        if let idx = transactions.firstIndex(where: { $0.id == storedTx.id }) {
            transactions[idx] = storedTx
        } else {
            transactions.insert(storedTx, at: 0)
        }
        save()
    }

    public func updateTransactionType(id: UUID, newType: TransactionType) async throws {
        try await engine.updateTransactionType(id: id, newType: newType)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].transactionType = newType
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    public func confirmCategory(id: UUID, categoryId: UUID, canonicalMerchant: String? = nil) async throws {
        try await engine.resolveCategory(id: id, categoryId: categoryId, canonicalMerchant: canonicalMerchant)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].categoryId = categoryId
            if let canon = canonicalMerchant {
                transactions[idx].merchantCanonical = canon
            }
            transactions[idx].reviewStatus = .confirmed
            transactions[idx].categoryConfidence = 1.0
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    public func hideTransaction(id: UUID) async throws {
        try await engine.hideTransaction(id: id)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].isHidden = true
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    public func unhideTransaction(id: UUID) async throws {
        try await engine.unhideTransaction(id: id)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].isHidden = false
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    public func revertCategory(id: UUID, toCategoryId: UUID? = nil) async throws {
        try await engine.revertCategory(id: id, toCategoryId: toCategoryId)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].categoryId = toCategoryId
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    public func returnToNeedsReview(id: UUID) async throws {
        try await engine.returnToNeedsReview(id: id)
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx].reviewStatus = .needsReview
            transactions[idx].updatedAt = Date()
        }
        save()
    }

    /// Hard deletes a transaction and any cascade-associated refunds
    public func deleteTransaction(id: UUID) async throws {
        try await engine.deleteTransaction(id: id)
        transactions.removeAll { $0.id == id }
        refunds.removeAll { $0.originalTransactionId == id }
        save()
    }

    /// Clears all transactions and refunds for a clean sandbox slate
    public func clearAllSandboxTransactions() async {
        try? await engine.clearAllTransactions(keepCategories: true)
        transactions.removeAll()
        refunds.removeAll()
        save()
    }

    /// Resets ledger state to original seed data
    public func resetToInitialSeed() async {
        try? await engine.clearAllTransactions(keepCategories: true)
        transactions.removeAll()
        refunds.removeAll()
        await seedDefaultData()
    }

    /// Ingest a sample / simulated transaction for interactive onboarding sandbox or testing
    public func addSampleTransaction(
        merchant: String,
        amountMinor: Int64,
        currency: String = "HKD",
        provider: PaymentProvider = .applePay,
        captureChannel: CaptureChannel = .walletAutomation,
        transactionType: TransactionType = .payment,
        isPending: Bool = false
    ) async throws -> TransactionEntity {
        let effectiveTxId = "SANDBOX-\(UUID().uuidString.prefix(8))"
        let idempotencyKey = "sandbox_\(effectiveTxId)_\(amountMinor)_\(Int(Date().timeIntervalSince1970))"

        let isZero = (amountMinor == 0)
        let reviewStatus: ReviewStatus = (isZero || isPending) ? .needsReview : .confirmed
        let paymentStatus: PaymentStatus = (isZero || isPending) ? .pending : .completed

        let tx = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: provider,
            captureChannel: captureChannel,
            deviceSource: .iPhone,
            sourceTransactionId: effectiveTxId,
            merchantRaw: merchant,
            merchantCanonical: merchant,
            amountMinor: amountMinor,
            currency: currency,
            ledgerAmountMinor: amountMinor,
            ledgerCurrency: currency,
            reviewStatus: reviewStatus,
            paymentStatus: paymentStatus,
            duplicateStatus: .unique,
            transactionType: transactionType,
            amountConfidence: 1.0,
            currencyConfidence: 1.0,
            merchantConfidence: 1.0
        )

        try await ingestTransaction(tx)
        return tx
    }

    /// Add a sample refund against an existing transaction (or the latest payment)
    public func addSampleRefund(
        amountMinor: Int64 = 4000,
        currency: String = "HKD"
    ) async throws {
        // Find latest eligible confirmed payment transaction
        if let targetTx = transactions.first(where: { $0.transactionType == .payment && ($0.amountMinor ?? 0) >= amountMinor && !$0.isHidden }) {
            let refund = RefundEntity(
                originalTransactionId: targetTx.id,
                amountMinor: amountMinor,
                currency: currency,
                kind: (amountMinor == targetTx.amountMinor) ? .full : .partial
            )
            try await engine.addRefund(refund)
            self.refunds.append(refund)
            save()
        } else {
            // If no matching transaction exists, create a sample parent payment first and then refund
            let parent = try await addSampleTransaction(
                merchant: "海港城 購物專櫃",
                amountMinor: max(amountMinor, 5000),
                currency: currency,
                provider: .applePay,
                captureChannel: .onlineApplePay
            )
            let refund = RefundEntity(
                originalTransactionId: parent.id,
                amountMinor: amountMinor,
                currency: currency,
                kind: (amountMinor == parent.amountMinor) ? .full : .partial
            )
            try await engine.addRefund(refund)
            self.refunds.append(refund)
            save()
        }
    }

    public func updateMonthlyBudgetTotal(amountMinor: Int64) {
        self.monthlyBudgetTotalMinor = max(0, amountMinor)
        save()
    }

    public func updateCategoryBudget(categoryId: UUID, amountMinor: Int64) {
        self.categoryBudgets[categoryId] = max(0, amountMinor)
        save()
    }

    /// Handles incoming zerotyping:// URLs from iOS Shortcuts, Safari, or Deep Links
    public func handleIncomingURL(_ url: URL) async -> URLHandleResult {
        guard let action = URLSchemeHandler.parse(url: url) else {
            self.urlActionToastMessage = "捷徑連結格式錯誤，無法入帳"
            return .error("無法辨識的捷徑連結：\(url.absoluteString)")
        }

        switch action {
        case .record(let amountMinor, let currency, let merchant, let categoryName, _):
            let effectiveTxId = "URL-\(UUID().uuidString.prefix(8))"
            let idempotencyKey = "url_\(effectiveTxId)_\(amountMinor)"
            let isZero = (amountMinor == 0)

            // Resolve category if matching name exists, default to othersCategoryId for zero-typing convenience
            var resolvedCatId: UUID = AppState.othersCategoryId
            if let catName = categoryName, !catName.isEmpty {
                if let found = categories.first(where: { $0.name == catName }) {
                    resolvedCatId = found.id
                }
            }

            let tx = TransactionEntity(
                idempotencyKey: idempotencyKey,
                provider: .applePay,
                captureChannel: .urlScheme,
                deviceSource: .iPhone,
                sourceTransactionId: effectiveTxId,
                merchantRaw: merchant,
                merchantCanonical: merchant,
                amountMinor: amountMinor,
                currency: currency,
                ledgerAmountMinor: amountMinor,
                ledgerCurrency: currency,
                categoryId: resolvedCatId,
                reviewStatus: isZero ? .needsReview : .confirmed,
                paymentStatus: isZero ? .pending : .completed,
                duplicateStatus: .unique,
                transactionType: .payment,
                amountConfidence: 1.0,
                currencyConfidence: 1.0,
                merchantConfidence: 1.0
            )

            do {
                try await ingestTransaction(tx)
                let displayAmount = String(format: "%.2f", Double(amountMinor) / 100.0)
                let banner = isZero
                    ? "已透過快捷連結建立待審核交易：\(merchant)"
                    : "已透過快捷連結入帳：\(currency)$\(displayAmount) 於 \(merchant)"
                self.urlActionToastMessage = banner
                return .recorded(tx)
            } catch {
                return .error("入帳失敗：\(error.localizedDescription)")
            }

        case .clipboard:
            #if canImport(UIKit)
            let clipText = UIPasteboard.general.string ?? ""
            if !clipText.isEmpty {
                let lines = clipText.components(separatedBy: .newlines)
                let ocrResult = VisionOCRService.shared.parseRecognizedStrings(lines)
                let minor = ocrResult.amountMinor ?? 0
                let effectiveTxId = ocrResult.sourceTransactionId ?? "CLIP-\(UUID().uuidString.prefix(8))"
                let tx = TransactionEntity(
                    idempotencyKey: "url_clip_\(effectiveTxId)_\(minor)",
                    provider: .applePay,
                    captureChannel: .urlScheme,
                    deviceSource: .iPhone,
                    sourceTransactionId: effectiveTxId,
                    merchantRaw: ocrResult.merchantRaw,
                    merchantCanonical: ocrResult.merchantRaw,
                    amountMinor: minor,
                    currency: ocrResult.currency,
                    ledgerAmountMinor: minor,
                    ledgerCurrency: ocrResult.currency,
                    reviewStatus: (minor == 0 || ocrResult.requiresManualReview) ? .needsReview : .confirmed,
                    paymentStatus: minor == 0 ? .pending : .completed,
                    duplicateStatus: .unique,
                    transactionType: .payment,
                    amountConfidence: ocrResult.amountConfidence,
                    currencyConfidence: 1.0,
                    merchantConfidence: ocrResult.merchantConfidence
                )
                try? await ingestTransaction(tx)
                let banner = "已自剪貼簿快速解析入帳：\(tx.merchantRaw ?? "商家")"
                self.urlActionToastMessage = banner
                return .clipboardParsed(tx)
            }
            #endif
            return .error("剪貼簿為空")

        case .screenshot:
            self.urlActionToastMessage = "請使用輕點背面或系統分享直接辨識截圖"
            return .openedOnboarding

        case .onboarding:
            self.showingOnboardingFromURL = true
            return .openedOnboarding

        case .reset:
            self.urlActionToastMessage = "為保障資料安全，不支援透過外部 URL 重置資料"
            return .error("為保障資料安全，不支援透過外部 URL 重置資料")

        case .unknown:
            return .error("未知的捷徑指令")
        }
    }

    // MARK: - Reactive Computed Properties

    public var visibleTransactions: [TransactionEntity] {
        transactions.filter { !$0.isHidden }
    }

    public var pendingTransactions: [TransactionEntity] {
        transactions.filter { !$0.isHidden && ($0.reviewStatus != .confirmed || $0.duplicateStatus == .possibleDuplicate) }
    }

    public var todaySpendingMinor: Int64 {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let confirmed = transactions.filter { tx in
            guard !tx.isHidden, tx.reviewStatus == .confirmed,
                  tx.duplicateStatus != .possibleDuplicate, tx.duplicateStatus != .confirmedDuplicate,
                  tx.transactionType == .payment || tx.transactionType == .fee else { return false }
            let d = tx.transactionDate ?? tx.capturedAt
            return d >= startOfDay
        }
        return confirmed.reduce(Int64(0)) { $0 + ($1.ledgerAmountMinor ?? $1.amountMinor ?? 0) }
    }

    public var monthlySpentTotalMinor: Int64 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components) ?? Date()

        let activeExpenses = transactions.filter { tx in
            guard !tx.isHidden, tx.reviewStatus == .confirmed,
                  tx.duplicateStatus != .possibleDuplicate, tx.duplicateStatus != .confirmedDuplicate,
                  tx.transactionType == .payment || tx.transactionType == .fee else { return false }
            let d = tx.transactionDate ?? tx.capturedAt
            return d >= startOfMonth
        }

        let total = activeExpenses.reduce(Int64(0)) { $0 + ($1.ledgerAmountMinor ?? $1.amountMinor ?? 0) }
        return max(0, total - totalRefundsMinor)
    }

    public var totalRefundsMinor: Int64 {
        refunds.reduce(Int64(0)) { $0 + $1.amountMinor }
    }

    public var monthlyNetSpentMinor: Int64 {
        return monthlySpentTotalMinor
    }

    public var monthlyBudgetRemainingMinor: Int64 {
        return max(0, monthlyBudgetTotalMinor - monthlyNetSpentMinor)
    }

    public var budgetUsedPercentage: Int {
        guard monthlyBudgetTotalMinor > 0 else { return 0 }
        return Int(round(Double(monthlyNetSpentMinor) / Double(monthlyBudgetTotalMinor) * 100))
    }

    // MARK: - Dynamic Insights Aggregation

    public func getInsightsData(timeRange: InsightsTimeRange) async -> InsightsReportData {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
        }

        let totalSpent = await engine.calculateActiveNetSpending(forCurrency: baseCurrency, start: startDate, end: now)
        let catSums = await engine.calculateSpendingByCategory(forCurrency: baseCurrency, start: startDate, end: now)
        let topM = await engine.getTopMerchants(forCurrency: baseCurrency, limit: 5, start: startDate, end: now)
        let deviceSums = await engine.getSpendingByDeviceSource(forCurrency: baseCurrency, start: startDate, end: now)

        // Build Category Items
        var catItems: [InsightsCategoryItem] = []
        for cat in categories {
            let spent = catSums[cat.id] ?? 0
            if spent > 0 {
                let pct = totalSpent > 0 ? Int(round(Double(spent) / Double(totalSpent) * 100)) : 0
                catItems.append(InsightsCategoryItem(
                    id: cat.id,
                    name: cat.name,
                    icon: AppState.categoryIcon(for: cat.id),
                    amountMinor: spent,
                    percentage: pct,
                    currency: baseCurrency
                ))
            }
        }
        catItems.sort { $0.amountMinor > $1.amountMinor }

        // Build Top Merchant Items
        var merchantItems: [InsightsMerchantItem] = []
        for (idx, m) in topM.enumerated() {
            merchantItems.append(InsightsMerchantItem(
                rank: idx + 1,
                name: m.merchant,
                count: m.count,
                totalAmountMinor: m.totalMinor,
                currency: baseCurrency
            ))
        }

        // Build Device Items
        var sourceItems: [InsightsSourceItem] = []
        let watchSpent = deviceSums[.appleWatch] ?? 0
        let phoneSpent = deviceSums[.iPhone] ?? 0
        let totalDev = watchSpent + phoneSpent

        if phoneSpent > 0 {
            let pct = totalDev > 0 ? Int(round(Double(phoneSpent) / Double(totalDev) * 100)) : 0
            sourceItems.append(InsightsSourceItem(
                name: "Apple Pay (iPhone)",
                icon: "iphone",
                percentage: pct,
                amountMinor: phoneSpent,
                currency: baseCurrency
            ))
        }
        if watchSpent > 0 {
            let pct = totalDev > 0 ? Int(round(Double(watchSpent) / Double(totalDev) * 100)) : 0
            sourceItems.append(InsightsSourceItem(
                name: "Apple Pay (Apple Watch)",
                icon: "applewatch",
                percentage: pct,
                amountMinor: watchSpent,
                currency: baseCurrency
            ))
        }

        return InsightsReportData(
            timeRange: timeRange,
            totalSpentMinor: totalSpent,
            currency: baseCurrency,
            categoryDistribution: catItems,
            topMerchants: merchantItems,
            sourceDistribution: sourceItems
        )
    }

    // MARK: - Dynamic Budget Data

    public func getBudgetCategories() async -> [BudgetCategoryItem] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components) ?? Date()

        let catSums = await engine.calculateSpendingByCategory(forCurrency: baseCurrency, start: startOfMonth, end: Date())

        return categories.map { cat in
            let spent = catSums[cat.id] ?? 0
            let limit = categoryBudgets[cat.id] ?? 100_000
            return BudgetCategoryItem(
                id: cat.id,
                name: cat.name,
                icon: AppState.categoryIcon(for: cat.id),
                spentAmountMinor: spent,
                budgetAmountMinor: limit,
                currency: baseCurrency
            )
        }
    }
}
