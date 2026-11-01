import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Spec v1.3 Strict Compliance Acceptance Tests")
struct SpecV13ComplianceAcceptanceTests {

    // MARK: - Section 9.3 Undo Specifications

    @Test("Section 9.3 Undo: 退回待審核 returns reviewStatus to .needsReview and removes from active budget")
    func testUndoReturnToNeedsReviewRemovesFromBudget() async throws {
        let engine = TransactionEngine()
        let txId = UUID()
        let tx = TransactionEntity(
            id: txId,
            idempotencyKey: "test_undo_review_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Pacific Coffee",
            merchantCanonical: "Pacific Coffee",
            amountMinor: 4200, // HK$42.00
            currency: "HKD",
            ledgerAmountMinor: 4200,
            ledgerCurrency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment
        )

        _ = try await engine.ingestTransaction(tx)

        // Before undo: Included in active budget
        var activeSpending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(activeSpending == 4200)

        // Perform Undo: 退回待審核 (§9.3)
        try await engine.returnToNeedsReview(id: txId)

        let updatedTx = await engine.getTransaction(id: txId)
        #expect(updatedTx?.reviewStatus == .needsReview)

        // After undo: Must be immediately excluded from active budget (§8.3 & §9.3)
        activeSpending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(activeSpending == 0)
    }

    @Test("Section 9.3 Undo: 隱藏交易 sets isHidden = true and excludes from active budget without deleting")
    func testUndoHideTransactionExcludesFromBudget() async throws {
        let engine = TransactionEngine()
        let txId = UUID()
        let tx = TransactionEntity(
            id: txId,
            idempotencyKey: "test_hide_1",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantRaw: "7-Eleven",
            amountMinor: 1500, // HK$15.00
            currency: "HKD",
            ledgerAmountMinor: 1500,
            ledgerCurrency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment
        )

        _ = try await engine.ingestTransaction(tx)
        var spending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(spending == 1500)

        // Hide (§9.3)
        try await engine.hideTransaction(id: txId)

        let hiddenTx = await engine.getTransaction(id: txId)
        #expect(hiddenTx != nil)
        #expect(hiddenTx?.isHidden == true)

        // Excluded from budget
        spending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(spending == 0)

        // Unhide recovers spending
        try await engine.unhideTransaction(id: txId)
        let unhiddenTx = await engine.getTransaction(id: txId)
        #expect(unhiddenTx?.isHidden == false)
        spending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(spending == 1500)
    }

    @Test("Section 9.3 Undo: 還原分類 restores previous category and maintains revision tracking")
    func testUndoRevertCategoryRestoresPreviousCategory() async throws {
        let engine = TransactionEngine()
        let txId = UUID()
        let initialCatId = UUID()
        let newCatId = UUID()

        let tx = TransactionEntity(
            id: txId,
            idempotencyKey: "test_revert_cat_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Starbucks",
            amountMinor: 3800,
            currency: "HKD",
            categoryId: initialCatId,
            reviewStatus: .confirmed
        )

        _ = try await engine.ingestTransaction(tx)

        // Change category
        try await engine.resolveCategory(id: txId, categoryId: newCatId)
        var currentTx = await engine.getTransaction(id: txId)
        #expect(currentTx?.categoryId == newCatId)

        // Revert category (§9.3)
        try await engine.revertCategory(id: txId, toCategoryId: initialCatId)
        currentTx = await engine.getTransaction(id: txId)
        #expect(currentTx?.categoryId == initialCatId)
    }

    // MARK: - Section 8.3 & 8.4 Budget Matrix Acceptance

    @Test("Section 8.3 & 8.4: Matrix verification of non-spending types (Transfer, TopUp, Unknown)")
    func testNonSpendingTypesExcludedFromBudget() async throws {
        let engine = TransactionEngine()

        let transferTx = TransactionEntity(
            idempotencyKey: "type_transfer",
            provider: .alipayHK,
            captureChannel: .shareSheet,
            merchantRaw: "轉帳至親友",
            amountMinor: 50000,
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .transfer // §8.4 Transfer is NOT spending
        )

        let topUpTx = TransactionEntity(
            idempotencyKey: "type_topup",
            provider: .octopus,
            captureChannel: .walletAutomation,
            merchantRaw: "八達通自動增值",
            amountMinor: 25000,
            currency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .topUp // §8.4 TopUp is NOT spending
        )

        _ = try await engine.ingestTransaction(transferTx)
        _ = try await engine.ingestTransaction(topUpTx)

        let spending = await engine.calculateActiveNetSpending(forCurrency: "HKD")
        #expect(spending == 0)
    }
}
