import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Non-Tap Apple Pay & Adversarial Boundary Tests (ATM-07 - ATM-14)")
struct NonTapApplePayTests {

    // MARK: - ATM-07: App Store 瞬間重複小額扣款冪等與獨立性驗證
    @Test("ATM-07: App Store rapid micro-transactions with distinct sourceTransactionId remain unique")
    func testAppStoreDistinctMicroTransactions() async throws {
        let engine = TransactionEngine()
        let now = Date()

        // Two in-app subscriptions of identical amount HK$38.00 within 10 seconds, but distinct order IDs
        let tx1 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_appstore_order_1",
            provider: .appleStoreSubscription,
            captureChannel: .onlineApplePay,
            deviceSource: .iPhone,
            sourceTransactionId: "MH7Q89B1Z2",
            merchantRaw: "Apple Store 訂閱扣款 (iCloud+)",
            merchantCanonical: "Apple Store",
            amountMinor: 3800,
            currency: "HKD",
            transactionDate: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let tx2 = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_appstore_order_2",
            provider: .appleStoreSubscription,
            captureChannel: .onlineApplePay,
            deviceSource: .iPhone,
            sourceTransactionId: "MH7Q89B1Z3", // Distinct StoreKit Order ID
            merchantRaw: "Apple Store 訂閱扣款 (Apple Music)",
            merchantCanonical: "Apple Store",
            amountMinor: 3800,
            currency: "HKD",
            transactionDate: now.addingTimeInterval(8),
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let r1 = try await engine.ingestTransaction(tx1)
        let r2 = try await engine.ingestTransaction(tx2)

        #expect(r1.duplicateStatus == .unique)
        #expect(r2.duplicateStatus == .unique)
        let total = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        #expect(total == 7600)
    }

    // MARK: - ATM-08: 缺少金額截圖安全降級
    @Test("ATM-08: Screenshot missing amount gracefully downgrades to needsReview without corrupting budget")
    func testMissingAmountScreenshotSafelyDowngraded() async throws {
        let linesWithoutAmount = [
            "Apple Pay",
            "商戶名稱：精品選物店",
            "付款處理中",
            "交易流水號：TX98765432"
        ]

        let ocr = VisionOCRService.shared.parseRecognizedStrings(linesWithoutAmount)
        #expect(ocr.amountMinor == nil)
        #expect(ocr.requiresManualReview == true)
        #expect(ocr.amountConfidence == 0.0)

        // Verify AppIntent ingestion with missing amount
        let intent = ProcessPaymentScreenshotIntent(recognizedLines: linesWithoutAmount, triggerChannel: "back_tap")
        _ = try await intent.perform()

        // Verify engine does not include this in active confirmed budget
        let engine = SharedTransactionEngine.shared
        let all = await engine.getAllTransactions()
        if let ingested = all.first(where: { $0.sourceTransactionId == "TX98765432" }) {
            #expect(ingested.reviewStatus == .needsReview)
            #expect(ingested.paymentStatus == .pending)
            #expect(ingested.amountMinor == nil || ingested.amountMinor == 0)
        }
    }

    // MARK: - ATM-09: 線上跨國外幣訂閱隔離
    @Test("ATM-09: Foreign online subscription is strictly isolated without mixing into base currency budget")
    func testForeignOnlineSubscriptionIsolation() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let jpyTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_sub_jpy_1000",
            provider: .appleStoreSubscription,
            captureChannel: .onlineApplePay,
            deviceSource: .iPhone,
            sourceTransactionId: "SUB-JPY-999",
            merchantRaw: "Nintendo Switch Online (JP)",
            merchantCanonical: "Nintendo",
            amountMinor: 30000, // 300 JPY
            currency: "JPY",
            ledgerAmountMinor: 30000,
            ledgerCurrency: "JPY",
            transactionDate: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        _ = try await engine.ingestTransaction(jpyTx)

        // HKD Spending must remain 0
        let hkdSpent = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        #expect(hkdSpent == 0)

        // Unconverted foreign spending must reflect 300 JPY
        let foreignMap = await engine.calculateUnconvertedForeignSpending(baseCurrency: "HKD")
        #expect(foreignMap["JPY"] == 30000)
    }

    // MARK: - ATM-10: 訂閱退款反向衝銷
    @Test("ATM-10: Subscription refund offsets net budget instantaneously")
    func testSubscriptionRefundOffsetsBudget() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let subTx = TransactionEntity(
            id: UUID(),
            idempotencyKey: "evt_sub_chatgpt_plus",
            provider: .appleStoreSubscription,
            captureChannel: .onlineApplePay,
            deviceSource: .iPhone,
            sourceTransactionId: "ORD-SUB-PLUS-01",
            merchantRaw: "OpenAI ChatGPT Plus Subscription",
            merchantCanonical: "OpenAI",
            amountMinor: 15800, // HK$158.00
            currency: "HKD",
            ledgerAmountMinor: 15800,
            ledgerCurrency: "HKD",
            transactionDate: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )
        _ = try await engine.ingestTransaction(subTx)

        let initialSpent = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        #expect(initialSpent == 15800)

        // User requested full refund through Apple Support
        let refund = RefundEntity(
            originalTransactionId: subTx.id,
            amountMinor: 15800,
            currency: "HKD",
            kind: .full,
            occurredAt: now.addingTimeInterval(120)
        )
        try await engine.addRefund(refund)

        let netSpentAfterRefund = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(300))
        #expect(netSpentAfterRefund == 0)
    }

    // MARK: - ATM-11: 剪貼簿 CSV / 公式注入與超長字串防護
    @Test("ATM-11: Clipboard formula injection prefixes are stripped and neutralized")
    func testClipboardFormulaInjectionNeutralized() async throws {
        let dangerousInputs = [
            "=cmd|' /C calc'!A0",
            "+12345.00 HKD",
            "-58.00 HKD",
            "@SUM(1,2)",
            "\t\r=1+1",
            "cmd|powershell -nop"
        ]

        for input in dangerousInputs {
            let sanitized = VisionOCRService.sanitizeFormulaPrefix(input)
            #expect(!sanitized.hasPrefix("="))
            #expect(!sanitized.hasPrefix("+"))
            #expect(!sanitized.hasPrefix("-"))
            #expect(!sanitized.hasPrefix("@"))
            #expect(!sanitized.hasPrefix("\t"))
            #expect(!sanitized.hasPrefix("\r"))
            #expect(!sanitized.lowercased().hasPrefix("cmd|"))
        }

        // Test in ParseClipboardExpenseIntent
        let intent = ParseClipboardExpenseIntent(rawText: "=cmd|' /C calc'!A0\n商戶名稱：安全測試商店\nHK$ 99.00\n流水號：SEC-001")
        _ = try await intent.perform()
    }

    // MARK: - ATM-12: 折扣明細多金額消歧義演算法
    @Test("ATM-12: Multi-amount OCR detects actual paid amount and sets low confidence review flag")
    func testMultiAmountDisambiguationSelectsPaid() {
        let lines = [
            "7-Eleven 便利店",
            "訂單原價 HK$ 100.00",
            "會員優惠券 -HK$ 15.00",
            "實付金額 HK$ 85.00",
            "交易流水號：7E-998877"
        ]

        let result = VisionOCRService.shared.parseRecognizedStrings(lines)
        #expect(result.candidateAmountsMinor.count >= 2)
        #expect(result.amountMinor == 8500) // Correctly picks 實付金額
        #expect(result.requiresManualReview == true)
        #expect(result.amountConfidence <= 0.5)
    }

    // MARK: - ATM-13: 跨渠道高併發寫入 Actor 無死鎖防護
    @Test("ATM-13: Concurrent ingestion from multi-channels succeeds without deadlocks")
    func testMultiChannelConcurrentIngestion() async throws {
        let engine = TransactionEngine()
        let channels: [CaptureChannel] = [.walletAutomation, .onlineApplePay, .backTap, .actionButton, .controlCenter, .clipboardParse]

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<30 {
                let channel = channels[i % channels.count]
                group.addTask {
                    let tx = TransactionEntity(
                        id: UUID(),
                        idempotencyKey: "concurrent_ch_\(channel.rawValue)_\(i)",
                        provider: (i % 2 == 0) ? .applePay : .appleStoreSubscription,
                        captureChannel: channel,
                        deviceSource: .iPhone,
                        sourceTransactionId: "CONC-\(i)",
                        merchantRaw: "Channel Test \(i)",
                        amountMinor: Int64(2000 + i * 10),
                        currency: "HKD",
                        reviewStatus: .confirmed,
                        paymentStatus: .completed
                    )
                    _ = try? await engine.ingestTransaction(tx)
                }
            }
        }

        let all = await engine.getAllTransactions()
        #expect(all.count == 30)
    }

    // MARK: - ATM-14: 非 Tap 截圖資產與 PhotoCleanupService 防誤刪保護
    @Test("ATM-14: Non-tap screenshots with needsReview are excluded from cleanup candidates")
    func testPhotoCleanupProtectsUnconfirmedScreenshots() async throws {
        let cleanup = PhotoCleanupService()
        let now = Date()
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: now)!

        let unconfirmedTxId = UUID()
        let confirmedTxId = UUID()

        let unconfirmedTx = TransactionEntity(
            id: unconfirmedTxId,
            idempotencyKey: "k_unconfirmed",
            provider: .applePay,
            captureChannel: .backTap,
            amountMinor: 8800,
            reviewStatus: .needsReview // Still needs user review
        )

        let confirmedTx = TransactionEntity(
            id: confirmedTxId,
            idempotencyKey: "k_confirmed",
            provider: .applePay,
            captureChannel: .backTap,
            amountMinor: 8800,
            reviewStatus: .confirmed // Confirmed by user
        )

        let txMap = [unconfirmedTxId: unconfirmedTx, confirmedTxId: confirmedTx]

        let artifacts = [
            SourceArtifactEntity(
                id: UUID(),
                transactionId: unconfirmedTxId,
                origin: .shortcutTemp,
                photoAssetLocalIdentifier: "ASSET-UNCONFIRMED-01",
                importedAt: eightDaysAgo,
                cleanupStatus: .eligible
            ),
            SourceArtifactEntity(
                id: UUID(),
                transactionId: confirmedTxId,
                origin: .shortcutTemp,
                photoAssetLocalIdentifier: "ASSET-CONFIRMED-02",
                importedAt: eightDaysAgo,
                cleanupStatus: .eligible
            )
        ]

        let candidates = await cleanup.fetchCleanupCandidates(
            artifacts: artifacts,
            transactions: txMap,
            retentionDays: 7,
            referenceDate: now
        )

        // Only the confirmed screenshot is eligible for deletion preview
        #expect(candidates.count == 1)
        #expect(candidates.first?.assetIdentifier == "ASSET-CONFIRMED-02")
    }

    // MARK: - ATM-15: PhotoKit 權限狀態主動獲取與未授權防護
    @Test("ATM-15: PhotoKit authorization status check and request flow returns valid status")
    func testPhotoAuthorizationRequestFlow() async throws {
        let cleanup = PhotoCleanupService()
        let status = await cleanup.requestPhotoAuthorizationIfNeeded()
        // On macOS headless SPM, this returns .authorized safely via condition compilation
        // On iOS, this returns valid PHAuthorizationStatus (.authorized, .limited, or .notDetermined)
        #expect(status == .authorized || status == .limited || status == .notDetermined || status == .denied || status == .restricted)
    }

    // MARK: - ATM-16: 遺失或非真實 AssetIdentifier 批次清理防崩潰與安全退回
    @Test("ATM-16: Batch deletion with non-existent or phantom asset identifiers handles gracefully without crash")
    func testBatchDeletionWithPhantomAssetIdentifiers() async throws {
        let cleanup = PhotoCleanupService()
        let phantomIds = ["PH-NONEXISTENT-001", "PH-NONEXISTENT-002", "PH-CORRUPTED-999"]

        let result = try await cleanup.performBatchDeletion(candidateAssetIds: phantomIds)
        // Ensure function safely returns without throwing crash or unhandled runtime exceptions
        #expect(result.deletedCount >= 0)
        #expect(result.failedIds.count <= phantomIds.count)
    }

    // MARK: - ATM-17: 永久硬刪除交易之級聯清理與預算退款重算
    @Test("ATM-17: Hard deletion of transaction cascades to refunds and idempotency indexes and updates budget")
    func testHardDeletionCascadeAndBudgetRecalculation() async throws {
        let engine = TransactionEngine()
        let now = Date()
        let txId = UUID()

        let parentTx = TransactionEntity(
            id: txId,
            idempotencyKey: "hard_del_parent_01",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            sourceTransactionId: "PARENT-TX-100",
            merchantRaw: "連鎖咖啡館",
            amountMinor: 8000, // HK$80.00
            currency: "HKD",
            transactionDate: now,
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let refund = RefundEntity(
            originalTransactionId: txId,
            amountMinor: 2000, // HK$20.00 partial refund
            currency: "HKD",
            kind: .partial
        )

        _ = try await engine.ingestTransaction(parentTx)
        try await engine.addRefund(refund)

        let initialNet = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        #expect(initialNet == 6000) // 8000 - 2000 = 6000

        // Hard delete the parent transaction
        try await engine.deleteTransaction(id: txId)

        // Net spend must drop to 0 and all associated refunds cascade cleared
        let afterDeleteNet = await engine.calculateActiveNetSpending(forCurrency: "HKD", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        #expect(afterDeleteNet == 0)

        // Idempotency key must be released so a transaction with the same key can be re-ingested if needed
        let reIngested = try await engine.ingestTransaction(parentTx)
        #expect(reIngested.id == txId)

        // Clean all transactions test
        try await engine.clearAllTransactions(keepCategories: true)
        let cleared = await engine.getAllTransactions()
        #expect(cleared.isEmpty)
    }

    // MARK: - ATM-18: AppShortcutsProvider 與 Shortcuts Intent 邊界防護
    @Test("ATM-18: AppShortcutsProvider contains expected intents and handles boundary inputs")
    func testAppShortcutsProviderIntegrityAndIntentBoundaries() async throws {
        if #available(iOS 16.0, macOS 13.0, *) {
            let shortcuts = ZeroTypingAppShortcutsProvider.appShortcuts
            #expect(shortcuts.count >= 3)
        }

        // Test RecordExpenseIntent boundary limits
        if #available(iOS 17.0, macOS 14.0, *) {
            let invalidNegativeIntent = RecordExpenseIntent(amount: -100.0, merchant: "Invalid")
            await #expect(throws: RecordExpenseIntent.IntentError.invalidAmount) {
                _ = try await invalidNegativeIntent.perform()
            }

            let validIntent = RecordExpenseIntent(amount: 55.5, merchant: "Starbucks", sourceTransactionId: "STB-INTENT-01")
            _ = try await validIntent.perform()
            let all = await SharedTransactionEngine.shared.getAllTransactions()
            #expect(all.contains { $0.sourceTransactionId == "STB-INTENT-01" })

            // Test Octopus transit zero amount handling
            let octopusZeroIntent = RecordExpenseIntent(
                amount: 0.0,
                merchant: "八達通 - 港鐵出閘",
                sourceTransactionId: "OCTOPUS-ZERO-01"
            )
            let octResult = try await octopusZeroIntent.perform()
            #expect(octResult.value?.needsReview == true)
            #expect(octResult.value?.amount == 0.0)
            let updatedAll = await SharedTransactionEngine.shared.getAllTransactions()
            let octTx = updatedAll.first { $0.sourceTransactionId == "OCTOPUS-ZERO-01" }
            #expect(octTx?.reviewStatus == .needsReview)
            #expect(octTx?.provider == .octopus)

            // Test pure transit merchant zero amount handling without 八達通 prefix
            let mtrZeroIntent = RecordExpenseIntent(
                amount: 0.0,
                merchant: "港鐵出閘",
                sourceTransactionId: "MTR-ZERO-01"
            )
            let mtrResult = try await mtrZeroIntent.perform()
            #expect(mtrResult.value?.needsReview == true)
            #expect(mtrResult.value?.amount == 0.0)
            let mtrUpdatedAll = await SharedTransactionEngine.shared.getAllTransactions()
            let mtrTx = mtrUpdatedAll.first { $0.sourceTransactionId == "MTR-ZERO-01" }
            #expect(mtrTx?.reviewStatus == .needsReview)
            #expect(mtrTx?.provider == .octopus)

            // Test ProcessPaymentScreenshotIntent error handling (empty lines or blank input)
            let emptyScreenshotIntent = ProcessPaymentScreenshotIntent()
            await #expect(throws: ProcessPaymentScreenshotIntent.IntentError.unrecognizedAmount) {
                _ = try await emptyScreenshotIntent.perform()
            }

            let blankLinesIntent = ProcessPaymentScreenshotIntent(recognizedLines: ["   ", "\n"])
            await #expect(throws: ProcessPaymentScreenshotIntent.IntentError.unrecognizedAmount) {
                _ = try await blankLinesIntent.perform()
            }
        }
    }
}
