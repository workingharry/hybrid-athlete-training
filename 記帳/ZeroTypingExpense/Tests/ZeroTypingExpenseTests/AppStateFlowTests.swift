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

        let state = AppState(storageUrl: tempUrl, autoSeedIfEmpty: true)
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

    @Test("TDD 6: Backward Compatibility: Old schema JSON missing new fields decodes seamlessly without data loss or default seed overwrite")
    @MainActor
    func testLegacySchemaDecodingAndNoDataLoss() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        // Raw JSON simulating older version v1.4 (missing ingestionSource, isHoldCandidate, remainingBalanceMinor)
        let legacyJSON = """
        {
          "version": 1,
          "monthlyBudgetTotalMinor": 800000,
          "categoryBudgets": {},
          "categories": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "name": "Custom Old Category",
              "isDefault": false,
              "isHidden": false
            }
          ],
          "transactions": [
            {
              "id": "22222222-2222-2222-2222-222222222222",
              "idempotencyKey": "user_real_tx_prior_version",
              "provider": "applePay",
              "captureChannel": "walletAutomation",
              "deviceSource": "iPhone",
              "merchantRaw": "Real User Grocery Store",
              "merchantCanonical": "Real User Grocery",
              "amountMinor": 38900,
              "currency": "HKD",
              "capturedAt": 753300000.0,
              "reviewStatus": "confirmed",
              "paymentStatus": "completed",
              "duplicateStatus": "unique",
              "transactionType": "payment",
              "candidateAmountsMinor": [],
              "isHidden": false,
              "createdAt": 753300000.0,
              "updatedAt": 753300000.0
            }
          ],
          "refunds": [],
          "merchantRules": []
        }
        """

        try legacyJSON.data(using: .utf8)?.write(to: tempUrl)

        // Load into AppState (simulating app launch immediately after update)
        let state = AppState(storageUrl: tempUrl)
        await state.load()

        // MUST preserve the user's real transaction
        #expect(state.transactions.count == 1)
        #expect(state.transactions.first?.idempotencyKey == "user_real_tx_prior_version")
        #expect(state.transactions.first?.merchantRaw == "Real User Grocery Store")
        #expect(state.transactions.first?.amountMinor == 38900)
        #expect(state.transactions.first?.ingestionSource == .manual) // Gracefully defaulted
        #expect(state.transactions.first?.isHoldCandidate == false)   // Gracefully defaulted

        // MUST NOT have injected default seed records (seed_1_mtr, etc.)
        #expect(!state.transactions.contains { $0.idempotencyKey.starts(with: "seed_") })
    }

    @Test("TDD 7: Protection against seed overwrite: existing file with custom transactions is never replaced by default seed records")
    @MainActor
    func testNeverWipeWithSeedsWhenFileExists() async throws {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("user_store_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempUrl) }

        // Pre-create user database with 1 custom transaction
        let userTx = TransactionEntity(
            idempotencyKey: "unique_user_record_999",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "My Personal Coffee Shop",
            amountMinor: 4200,
            currency: "HKD",
            reviewStatus: .confirmed,
            transactionType: .payment
        )
        let envelope = AppStorageEnvelope(
            version: 1,
            monthlyBudgetTotalMinor: 500_000,
            categoryBudgets: [:],
            categories: AppState.defaultCategories(),
            transactions: [userTx],
            refunds: [],
            merchantRules: []
        )
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: tempUrl)

        // Simulate app update & multiple reload cycles
        for _ in 0..<3 {
            let reloadedState = AppState(storageUrl: tempUrl)
            await reloadedState.load()

            #expect(reloadedState.transactions.count == 1)
            #expect(reloadedState.transactions.first?.idempotencyKey == "unique_user_record_999")
            #expect(!reloadedState.transactions.contains { $0.idempotencyKey.starts(with: "seed_") })
        }
    }

    @Test("TDD 8: Corrupted non-object transaction array elements do not hang parser or cause infinite loops")
    func testCorruptedTransactionArrayElementsDoNotHang() throws {
        let corruptedJSON = """
        {
          "version": 1,
          "monthlyBudgetTotalMinor": 1000000,
          "categoryBudgets": {},
          "categories": [],
          "transactions": [
            12345,
            "corrupted_raw_string_element",
            {
              "id": "33333333-3333-3333-3333-333333333333",
              "idempotencyKey": "valid_tx_after_garbage",
              "merchantRaw": "Surviving Grocery",
              "amountMinor": 2500
            }
          ],
          "refunds": [],
          "merchantRules": []
        }
        """

        let data = corruptedJSON.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(AppStorageEnvelope.self, from: data)
        #expect(envelope.version == 1)
    }

    @Test("TDD 9: Multi-tier persistence: App data survives container reset via Keychain recovery")
    @MainActor
    func testAppDataSurvivesContainerResetViaKeychain() async throws {
        let testAccount = "test_keychain_resilience_\(UUID().uuidString)"
        defer { ZeroTypingDiskStorage.clearKeychain(account: testAccount) }

        // Prepare test payload
        let testTx = TransactionEntity(
            idempotencyKey: "keychain_resilience_test_tx",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Resilience Supermarket",
            amountMinor: 88800, // HK$888.00
            currency: "HKD",
            reviewStatus: .confirmed,
            transactionType: .payment
        )
        let envelope = AppStorageEnvelope(
            version: 1,
            monthlyBudgetTotalMinor: 2_000_000,
            categoryBudgets: [:],
            categories: AppState.defaultCategories(),
            transactions: [testTx],
            refunds: [],
            merchantRules: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)

        // Store directly to Keychain under isolated test account
        ZeroTypingDiskStorage.saveToKeychain(data: data, account: testAccount)

        // Verify loadEnvelope restores from Keychain when disk file is non-existent
        let storage = ZeroTypingDiskStorage()
        let nonExistentURL = FileManager.default.temporaryDirectory.appendingPathComponent("phantom_\(UUID().uuidString).json")
        let loadedEnvelope = try await storage.loadEnvelope(from: nonExistentURL, keychainAccount: testAccount)

        #expect(loadedEnvelope.transactions.contains { $0.idempotencyKey == "keychain_resilience_test_tx" })
        #expect(loadedEnvelope.transactions.first?.amountMinor == 88800)
        #expect(!loadedEnvelope.transactions.contains { $0.idempotencyKey.starts(with: "seed_") })
    }
}
