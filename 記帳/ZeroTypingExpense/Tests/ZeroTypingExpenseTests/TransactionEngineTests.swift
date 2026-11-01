import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("TransactionEngine Double-Layer Idempotency & Budget Tests")
struct TransactionEngineTests {

    @Test("Event-level Idempotency: exact same idempotency key produces no duplicate")
    func testEventLevelIdempotency() async throws {
        let engine = TransactionEngine()

        let tx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_applepay_12345",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantCanonical: "Wellcome",
            amountMinor: 15800,
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            transactionType: .payment
        )

        let first = try await engine.ingestTransaction(tx)
        let second = try await engine.ingestTransaction(tx)

        #expect(first.id == second.id)
        let all = await engine.getAllTransactions()
        #expect(all.count == 1)
    }

    @Test("Transaction-level Duplicate Detection: identical merchant and amount within time window marked PossibleDuplicate")
    func testTransactionLevelDuplicate() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let tx1 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_manual_1",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantCanonical: "McDonald's",
            amountMinor: 4800,
            currency: "HKD",
            capturedAt: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            transactionType: .payment
        )

        let tx2 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_manual_2",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantCanonical: "McDonald's",
            amountMinor: 4800,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(30), // 30s later
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            transactionType: .payment
        )

        let res1 = try await engine.ingestTransaction(tx1)
        let res2 = try await engine.ingestTransaction(tx2)

        #expect(res1.duplicateStatus == .unique)
        #expect(res2.duplicateStatus == .possibleDuplicate)
        #expect(res2.reviewStatus == .needsReview) // downgraded to review
    }

    @Test("Budget Calculation Section 8.3: Refunds subtract, unconfirmed excluded")
    func testBudgetCalculations() async throws {
        let engine = TransactionEngine()

        // Confirmed payment: HK$ 100.00
        let tx1 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "tx_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            amountMinor: 10000,
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            transactionType: .payment
        )

        // NeedsCategory payment: HK$ 50.00 (should be excluded from confirmed net spending)
        let tx2 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "tx_2",
            provider: .alipayHK,
            captureChannel: .shortcut,
            amountMinor: 5000,
            currency: "HKD",
            reviewStatus: .needsCategory,
            paymentStatus: .completed,
            transactionType: .payment
        )

        _ = try await engine.ingestTransaction(tx1)
        _ = try await engine.ingestTransaction(tx2)

        var net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 10000)

        // Add partial refund HK$ 30.00 to tx1
        let refund = RefundEntity(
            originalTransactionId: tx1.id,
            amountMinor: 3000,
            currency: "HKD",
            kind: .partial
        )
        try await engine.addRefund(refund)

        net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 7000) // 100 - 30 = 70 HKD

        let updatedTx1 = await engine.getTransaction(id: tx1.id)
        #expect(updatedTx1?.paymentStatus == .partiallyRefunded)
    }

    @Test("Transit Hold: $0 Apple Pay tap ingestion marks pending status and excludes from active budget")
    func testZeroTransitHoldIngestion() async throws {
        let engine = TransactionEngine()

        let transitHold = TransactionEntity(
            id: UUID(),
            idempotencyKey: "transit_tap_in_mtr",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            sourceTransactionId: "ap_mtr_hold_001",
            merchantRaw: "港鐵 MTR",
            merchantCanonical: "港鐵 MTR",
            amountMinor: 0,
            currency: "HKD",
            transactionType: .payment
        )

        let ingested = try await engine.ingestTransaction(transitHold)
        #expect(ingested.amountMinor == 0)
        #expect(ingested.paymentStatus == .pending)
        #expect(ingested.reviewStatus == .needsReview)
        #expect(ingested.deviceSource == .appleWatch)

        // $0 pending hold should NOT affect confirmed budget
        let net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 0)
    }

    @Test("Transit Settlement: $0 tap-in hold paired with subsequent settled fare within 24 hours")
    func testTransitSettlementPairing() async throws {
        let engine = TransactionEngine()
        let tapInTime = Date()

        // 1. Initial $0 tap-in from Apple Watch
        let holdTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "transit_tap_in_123",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            sourceTransactionId: "ap_transit_hold_123",
            merchantRaw: "MTR",
            merchantCanonical: "港鐵 MTR",
            amountMinor: 0,
            currency: "HKD",
            transactionDate: tapInTime,
            transactionType: .payment
        )
        let holdResult = try await engine.ingestTransaction(holdTx)
        #expect(holdResult.paymentStatus == .pending)

        // 2. Final settled fare arrives 45 mins later for HK$ 16.50
        let settleTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "transit_tap_out_settle_123",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            sourceTransactionId: "ap_transit_settle_123",
            merchantRaw: "MTR",
            merchantCanonical: "港鐵 MTR",
            amountMinor: 1650, // HK$ 16.50
            currency: "HKD",
            transactionDate: tapInTime.addingTimeInterval(2700),
            transactionType: .payment
        )
        let settledResult = try await engine.ingestTransaction(settleTx)

        // Must update the existing hold ID rather than creating an unrelated second transaction
        #expect(settledResult.id == holdResult.id)
        #expect(settledResult.amountMinor == 1650)
        #expect(settledResult.paymentStatus == .completed)
        #expect(settledResult.reviewStatus == .confirmed)

        let all = await engine.getAllTransactions()
        #expect(all.count == 1)

        // Now active budget reflects HK$ 16.50
        let net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 1650)
    }

    @Test("Update Transaction Type: Switching to Transfer/TopUp immediately recalculates budget")
    func testUpdateTransactionTypeRecalculatesBudget() async throws {
        let engine = TransactionEngine()

        let tx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "tx_topup_switch",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            amountMinor: 20000, // HK$ 200.00
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            transactionType: .payment
        )
        _ = try await engine.ingestTransaction(tx)

        // Initially counts as payment spending
        var net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 20000)

        // Switch to .topUp (儲值)
        try await engine.updateTransactionType(id: tx.id, newType: .topUp)
        net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 0) // Top-ups are excluded from spending

        // Switch to .fee (手續費)
        try await engine.updateTransactionType(id: tx.id, newType: .fee)
        net = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(net == 20000) // Fees are counted as spending
    }

    @Test("Device Source Attribution: iPhone vs Apple Watch tagging verified")
    func testDeviceSourceAttribution() async throws {
        let engine = TransactionEngine()

        let phoneTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "tx_phone_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            amountMinor: 5000,
            currency: "HKD"
        )

        let watchTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "tx_watch_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            amountMinor: 3000,
            currency: "HKD"
        )

        let rPhone = try await engine.ingestTransaction(phoneTx)
        let rWatch = try await engine.ingestTransaction(watchTx)

        #expect(rPhone.deviceSource == .iPhone)
        #expect(rWatch.deviceSource == .appleWatch)
    }

    @Test("Transit Settlement: Multiple holds in 24 hours pair with the chronologically closest hold")
    func testMultipleTransitHoldsPairWithClosest() async throws {
        let engine = TransactionEngine()
        let calendar = Calendar.current
        let baseTime = Date()

        // Morning Hold at 08:00
        let morningHold = TransactionEntity(
            id: UUID(),
            idempotencyKey: "hold_morning",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            merchantRaw: "MTR Corporation Limited",
            amountMinor: 0,
            currency: "HKD",
            transactionDate: baseTime
        )
        let ingestedMorning = try await engine.ingestTransaction(morningHold)

        // Evening Hold at 17:00 (9 hours later)
        let eveningTime = calendar.date(byAdding: .hour, value: 9, to: baseTime)!
        let eveningHold = TransactionEntity(
            id: UUID(),
            idempotencyKey: "hold_evening",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            merchantRaw: "MTR",
            amountMinor: 0,
            currency: "HKD",
            transactionDate: eveningTime
        )
        let ingestedEvening = try await engine.ingestTransaction(eveningHold)

        // Settlement for morning trip arrives at 08:30 (30 mins after morning hold)
        let settleMorningTime = calendar.date(byAdding: .minute, value: 30, to: baseTime)!
        let settleMorning = TransactionEntity(
            idempotencyKey: "settle_morning",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            merchantRaw: "MTR",
            amountMinor: 1450,
            currency: "HKD",
            transactionDate: settleMorningTime
        )

        let settled = try await engine.ingestTransaction(settleMorning)

        // Must pair with morning hold (closest in time), NOT evening hold!
        #expect(settled.id == ingestedMorning.id)
        #expect(settled.amountMinor == 1450)
        #expect(settled.paymentStatus == .completed)

        // Evening hold remains pending
        let currentEvening = await engine.getTransaction(id: ingestedEvening.id)
        #expect(currentEvening?.amountMinor == 0)
        #expect(currentEvening?.paymentStatus == .pending)
    }
}
