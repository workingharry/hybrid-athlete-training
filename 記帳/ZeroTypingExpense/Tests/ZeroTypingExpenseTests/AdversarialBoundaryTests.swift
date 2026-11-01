import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Adversarial Stress & Boundary Vector Tests (ATM-01 - ATM-06)")
struct AdversarialBoundaryTests {

    @Test("ATM-01: Rapid Same-Price Purchases with distinct sourceTransactionId remain unique")
    func testDistinctCoffeePurchases() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let tx1 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_coffee_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            sourceTransactionId: "ap_trx_9001",
            merchantCanonical: "Blue Bottle Coffee",
            amountMinor: 3800,
            currency: "HKD",
            transactionDate: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let tx2 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_coffee_2",
            provider: .applePay,
            captureChannel: .walletAutomation,
            sourceTransactionId: "ap_trx_9002", // distinct Apple Pay transaction ID
            merchantCanonical: "Blue Bottle Coffee",
            amountMinor: 3800,
            currency: "HKD",
            transactionDate: now.addingTimeInterval(45), // 45 seconds later
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let r1 = try await engine.ingestTransaction(tx1)
        let r2 = try await engine.ingestTransaction(tx2)

        #expect(r1.duplicateStatus == .unique)
        #expect(r2.duplicateStatus == .unique) // Not flagged as duplicate because sourceTransactionId is distinct
    }

    @Test("ATM-02: Negative Amounts Rejected")
    func testNegativeAmountRejected() async throws {
        let engine = TransactionEngine()

        let corruptTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_corrupt_neg",
            provider: .alipayHK,
            captureChannel: .shortcut,
            amountMinor: -500,
            currency: "HKD"
        )

        await #expect(throws: TransactionEngine.EngineError.invalidAmount) {
            _ = try await engine.ingestTransaction(corruptTx)
        }
    }

    @Test("ATM-03: Currency Mismatch on Refund Throws Error")
    func testCurrencyMismatchRefund() async throws {
        let engine = TransactionEngine()
        let tx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_hkd_tx",
            provider: .applePay,
            captureChannel: .walletAutomation,
            amountMinor: 50000,
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )
        _ = try await engine.ingestTransaction(tx)

        // Foreign refund without matching currency
        let foreignRefund = RefundEntity(
            originalTransactionId: tx.id,
            amountMinor: 10000,
            currency: "USD",
            kind: .partial
        )

        await #expect(throws: TransactionEngine.EngineError.currencyMismatch) {
            try await engine.addRefund(foreignRefund)
        }
    }

    @Test("ATM-04: Refund Exceeding Original Amount Throws Error")
    func testOverRefundThrows() async throws {
        let engine = TransactionEngine()
        let tx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_100_tx",
            provider: .applePay,
            captureChannel: .walletAutomation,
            amountMinor: 10000, // 100 HKD
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )
        _ = try await engine.ingestTransaction(tx)

        let refund1 = RefundEntity(
            originalTransactionId: tx.id,
            amountMinor: 6000,
            currency: "HKD",
            kind: .partial
        )
        try await engine.addRefund(refund1)

        let refund2Exceeding = RefundEntity(
            originalTransactionId: tx.id,
            amountMinor: 5000, // 60 + 50 = 110 > 100
            currency: "HKD",
            kind: .partial
        )

        await #expect(throws: TransactionEngine.EngineError.refundExceedsOriginal) {
            try await engine.addRefund(refund2Exceeding)
        }
    }

    @Test("ATM-05: Concurrent Ingestion Thread Safety")
    func testConcurrentIngestion() async throws {
        let engine = TransactionEngine()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let tx = TransactionEntity(
                        id: UUID(),
                        idempotencyKey: "concurrent_key_\(i)",
                        provider: .applePay,
                        captureChannel: .walletAutomation,
                        amountMinor: Int64(1000 + i),
                        currency: "HKD",
                        reviewStatus: .confirmed,
                        paymentStatus: .completed
                    )
                    _ = try? await engine.ingestTransaction(tx)
                }
            }
        }

        let all = await engine.getAllTransactions()
        #expect(all.count == 100)
    }

    @Test("ATM-06: Greedy Longest Substring Match in Merchant Engine")
    func testGreedyMerchantMatching() async throws {
        let engine = MerchantLearningEngine()
        let cafeCatId = UUID()
        let groceryCatId = UUID()

        let shortRule = MerchantRule(
            canonicalName: "Coffee",
            aliases: [],
            defaultCategoryId: groceryCatId
        )
        let longRule = MerchantRule(
            canonicalName: "Pacific Coffee",
            aliases: [],
            defaultCategoryId: cafeCatId
        )

        await engine.registerRule(shortRule)
        await engine.registerRule(longRule)

        let match = await engine.matchCategory(forMerchantRaw: "Pacific Coffee Central Tower")
        // Must match "Pacific Coffee", not "Coffee"
        #expect(match?.canonicalName == "Pacific Coffee")
        #expect(match?.categoryId == cafeCatId)
    }
}
