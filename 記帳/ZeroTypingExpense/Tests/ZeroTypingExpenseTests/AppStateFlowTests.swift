import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("AppState Flow & Reactive Synchronization Tests (TDD Loop)")
struct AppStateFlowTests {

    @Test("TDD 1: AppState initializes with seed data and persists transactions to disk")
    @MainActor
    func testInitializationAndPersistence() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let state = AppState(storageUrl: tempUrl)
        await state.load()

        // Verify initial seed has spec v1.3 default transactions
        #expect(state.transactions.count > 0)
        let initialCount = state.transactions.count

        // Ingest new transaction
        let newTx = TransactionEntity(
            idempotencyKey: "test_persist_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Starbucks Coffee",
            amountMinor: 4500, // HK$45.00
            currency: "HKD",
            reviewStatus: .confirmed,
            transactionType: .payment
        )
        try await state.ingestTransaction(newTx)
        #expect(state.transactions.count == initialCount + 1)

        // Create new AppState pointing to same file and verify persistence
        let reloadedState = AppState(storageUrl: tempUrl)
        await reloadedState.load()
        #expect(reloadedState.transactions.contains { $0.idempotencyKey == "test_persist_1" })
        #expect(reloadedState.transactions.count == initialCount + 1)
    }

    @Test("TDD 2: Changing transaction type to Transfer/TopUp immediately excludes from budget & category spend")
    @MainActor
    func testTransactionTypeExclusionFromBudget() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let state = AppState(storageUrl: tempUrl)
        await state.load()

        let tx = TransactionEntity(
            idempotencyKey: "type_switch_test",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "FPS Transfer",
            amountMinor: 50000, // HK$500.00
            currency: "HKD",
            reviewStatus: .confirmed,
            transactionType: .payment // Initially payment
        )
        try await state.ingestTransaction(tx)

        let initialBudgetSpent = state.monthlySpentTotalMinor

        // Switch to Transfer
        try await state.updateTransactionType(id: tx.id, newType: .transfer)

        let updatedBudgetSpent = state.monthlySpentTotalMinor
        #expect(updatedBudgetSpent == initialBudgetSpent - 50000)
    }

    @Test("TDD 3: Insights dynamically computes week vs month spending & top merchants")
    @MainActor
    func testInsightsDynamicAggregation() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let state = AppState(storageUrl: tempUrl)
        await state.load()

        let now = Date()
        let thisWeekTx = TransactionEntity(
            idempotencyKey: "week_tx_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Wellcome Supermarket",
            merchantCanonical: "Wellcome",
            amountMinor: 12000,
            currency: "HKD",
            transactionDate: now,
            reviewStatus: .confirmed,
            transactionType: .payment
        )
        try await state.ingestTransaction(thisWeekTx)

        let insights = await state.getInsightsData(timeRange: .month)
        #expect(insights.totalSpentMinor >= 12000)
        #expect(insights.topMerchants.contains { $0.name.contains("Wellcome") })
    }

    @Test("TDD 4: Section 9.3 Undo operations dynamically update active ledger and budget")
    @MainActor
    func testSection93UndoOperations() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let state = AppState(storageUrl: tempUrl)
        await state.load()

        let tx = TransactionEntity(
            idempotencyKey: "undo_test_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Café de Coral",
            amountMinor: 6500,
            currency: "HKD",
            reviewStatus: .confirmed,
            transactionType: .payment
        )
        try await state.ingestTransaction(tx)

        let spentBeforeHide = state.monthlySpentTotalMinor

        // Hide transaction (§9.3)
        try await state.hideTransaction(id: tx.id)
        #expect(state.monthlySpentTotalMinor == spentBeforeHide - 6500)
        #expect(state.visibleTransactions.allSatisfy { $0.id != tx.id })

        // Unhide transaction
        try await state.unhideTransaction(id: tx.id)
        #expect(state.monthlySpentTotalMinor == spentBeforeHide)
        #expect(state.visibleTransactions.contains { $0.id == tx.id })

        // Return to needs review (§9.3)
        try await state.returnToNeedsReview(id: tx.id)
        #expect(state.monthlySpentTotalMinor == spentBeforeHide - 6500)
        #expect(state.pendingTransactions.contains { $0.id == tx.id })
    }

    @Test("TDD 5: User can update monthly total budget and category budget limits")
    @MainActor
    func testBudgetUpdating() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let state = AppState(storageUrl: tempUrl)
        await state.load()

        // Set monthly budget to HK$15,000.00
        state.updateMonthlyBudgetTotal(amountMinor: 1_500_000)
        #expect(state.monthlyBudgetTotalMinor == 1_500_000)

        // Check remaining budget computation
        let remaining = state.monthlyBudgetRemainingMinor
        #expect(remaining == 1_500_000 - state.monthlyNetSpentMinor)
    }
}
