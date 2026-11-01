import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("TransactionEngine Analytics & Category Seams (TDD Loop)")
struct TransactionEngineAnalyticsTests {

    // MARK: - Seam 1: Category Spending Aggregation (§6.3 & §8.3)

    @Test("TDD Seam 1: calculateSpendingByCategory aggregates net spending per category with refund deduction")
    func testCategorySpendingAggregation() async throws {
        let engine = TransactionEngine()
        let diningCatId = UUID()
        let transportCatId = UUID()

        let txDining1 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "dining_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Café de Coral",
            amountMinor: 6200, // HK$62.00
            currency: "HKD",
            categoryId: diningCatId,
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment
        )

        let txDining2 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "dining_2",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "大家樂",
            amountMinor: 3800, // HK$38.00
            currency: "HKD",
            categoryId: diningCatId,
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment
        )

        let txTransport = TransactionEntity(
            id: UUID(),
            idempotencyKey: "transport_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "MTR",
            amountMinor: 1650, // HK$16.50
            currency: "HKD",
            categoryId: transportCatId,
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment
        )

        // Unconfirmed should NOT be counted in category spending (§8.3)
        let txUnconfirmed = TransactionEntity(
            id: UUID(),
            idempotencyKey: "unconfirmed_1",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantRaw: "Unknown Dining",
            amountMinor: 8500,
            currency: "HKD",
            categoryId: diningCatId,
            reviewStatus: .needsCategory // Excluded!
        )

        _ = try await engine.ingestTransaction(txDining1)
        _ = try await engine.ingestTransaction(txDining2)
        _ = try await engine.ingestTransaction(txTransport)
        _ = try await engine.ingestTransaction(txUnconfirmed)

        // Add partial refund on dining 1 (HK$12.00)
        let refund = RefundEntity(
            originalTransactionId: txDining1.id,
            amountMinor: 1200,
            currency: "HKD",
            kind: .partial
        )
        try await engine.addRefund(refund)

        let categorySums = await engine.calculateSpendingByCategory(forCurrency: "HKD")

        // Dining: (6200 - 1200) + 3800 = 8800
        #expect(categorySums[diningCatId] == 8800)
        // Transport: 1650
        #expect(categorySums[transportCatId] == 1650)
    }

    // MARK: - Seam 2: Top Merchants Leaderboard (§6.2 Insights S06)

    @Test("TDD Seam 2: getTopMerchants ranks merchants by total spend and counts transactions accurately")
    func testTopMerchantsLeaderboard() async throws {
        let engine = TransactionEngine()

        // 3 transactions for Wellcome ($150, $200, $50 -> Total $400)
        for i in 1...3 {
            let amount: Int64 = (i == 1 ? 15000 : (i == 2 ? 20000 : 5000))
            let tx = TransactionEntity(
                idempotencyKey: "wellcome_\(i)",
                provider: .applePay,
                captureChannel: .walletAutomation,
                merchantRaw: "Wellcome",
                merchantCanonical: "Wellcome Supermarket",
                amountMinor: amount,
                currency: "HKD",
                reviewStatus: .confirmed
            )
            _ = try await engine.ingestTransaction(tx)
        }

        // 1 transaction for Apple Store ($1200 -> Rank 1)
        let appleTx = TransactionEntity(
            idempotencyKey: "apple_store_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Apple Store",
            merchantCanonical: "Apple",
            amountMinor: 120000,
            currency: "HKD",
            reviewStatus: .confirmed
        )
        _ = try await engine.ingestTransaction(appleTx)

        let leaders = await engine.getTopMerchants(forCurrency: "HKD", limit: 5)

        #expect(leaders.count == 2)
        #expect(leaders[0].merchant == "Apple")
        #expect(leaders[0].totalMinor == 120000)
        #expect(leaders[0].count == 1)

        #expect(leaders[1].merchant == "Wellcome Supermarket")
        #expect(leaders[1].totalMinor == 40000)
        #expect(leaders[1].count == 3)
    }

    // MARK: - Seam 3: Device Source & Provider Distribution (§6.2 & §1.3)

    @Test("TDD Seam 3: getSpendingByDeviceSource splits Apple Watch vs iPhone spend accurately")
    func testSpendingByDeviceSource() async throws {
        let engine = TransactionEngine()

        let phoneTx = TransactionEntity(
            idempotencyKey: "dev_phone",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            amountMinor: 25000,
            currency: "HKD",
            reviewStatus: .confirmed
        )

        let watchTx = TransactionEntity(
            idempotencyKey: "dev_watch",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            amountMinor: 1450,
            currency: "HKD",
            reviewStatus: .confirmed
        )

        _ = try await engine.ingestTransaction(phoneTx)
        _ = try await engine.ingestTransaction(watchTx)

        let distribution = await engine.getSpendingByDeviceSource(forCurrency: "HKD")
        #expect(distribution[.iPhone] == 25000)
        #expect(distribution[.appleWatch] == 1450)
    }

    // MARK: - Seam 4: Foreign Currency Isolation (§8.8)

    @Test("TDD Seam 4: calculateUnconvertedForeignSpending isolates foreign transactions without mixing")
    func testForeignCurrencyIsolation() async throws {
        let engine = TransactionEngine()

        let jpyTx = TransactionEntity(
            idempotencyKey: "fx_jpy",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Tokyo Metro",
            amountMinor: 35000, // 350 JPY
            currency: "JPY",
            reviewStatus: .confirmed
        )

        let hkdTx = TransactionEntity(
            idempotencyKey: "local_hkd",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "7-Eleven HK",
            amountMinor: 2000, // HK$20.00
            currency: "HKD",
            reviewStatus: .confirmed
        )

        _ = try await engine.ingestTransaction(jpyTx)
        _ = try await engine.ingestTransaction(hkdTx)

        // Base HKD spending must not mix JPY
        let hkdTotal = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(hkdTotal == 2000)

        // Isolated foreign currencies (§8.8)
        let foreignTotals = await engine.calculateUnconvertedForeignSpending(baseCurrency: "HKD")
        #expect(foreignTotals["JPY"] == 35000)
        #expect(foreignTotals["HKD"] == nil)
    }
}
