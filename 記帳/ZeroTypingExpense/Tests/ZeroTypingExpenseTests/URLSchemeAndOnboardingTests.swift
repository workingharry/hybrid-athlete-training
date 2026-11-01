import Testing
import Foundation
#if canImport(AppIntents)
import AppIntents
#endif
@testable import ZeroTypingExpense

@Suite("URL Scheme & Shortcuts Minimal Input Workflow Tests")
struct URLSchemeAndOnboardingTests {

    @Test("Parse valid zerotyping://record with amount and merchant")
    func testParseValidRecordURL() async throws {
        let url = URL(string: "zerotyping://record?amount=48.50&merchant=Starbucks&currency=HKD&category=餐飲")!
        let action = URLSchemeHandler.parse(url: url)

        guard case let .record(amountMinor, currency, merchant, categoryName, _) = action else {
            Issue.record("Expected .record action but got \(String(describing: action))")
            return
        }

        #expect(amountMinor == 4850)
        #expect(currency == "HKD")
        #expect(merchant == "Starbucks")
        #expect(categoryName == "餐飲")
    }

    @Test("Formula injection in URL scheme parameters is neutralized")
    func testFormulaInjectionNeutralizedInURL() async throws {
        let maliciousUrl = URL(string: "zerotyping://record?amount=100&merchant=%3Dcmd%7C%27+%2FC+calc%27%21A0&currency=HKD")!
        let action = URLSchemeHandler.parse(url: maliciousUrl)

        guard case let .record(_, _, merchant, _, _) = action else {
            Issue.record("Expected .record action")
            return
        }

        // Should not start with =, +, -, @, |, cmd
        #expect(!merchant.hasPrefix("="))
        #expect(!merchant.hasPrefix("+"))
        #expect(!merchant.hasPrefix("-"))
        #expect(!merchant.hasPrefix("@"))
        #expect(!merchant.hasPrefix("|"))
        #expect(!merchant.hasPrefix("cmd"))
    }

    @Test("Parse zerotyping://clip and zerotyping://onboarding")
    func testParseSystemActionURLs() async throws {
        let clipUrl = URL(string: "zerotyping://clip")!
        let onboardUrl = URL(string: "zerotyping://onboarding")!
        let resetUrl = URL(string: "zerotyping://reset")!

        #expect(URLSchemeHandler.parse(url: clipUrl) == .clipboard)
        #expect(URLSchemeHandler.parse(url: onboardUrl) == .onboarding)
        #expect(URLSchemeHandler.parse(url: resetUrl) == .reset)
    }

    @Test("AppState handles incoming zerotyping://record URL end-to-end")
    func testAppStateHandlesIncomingRecordURL() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("test_url_storage.json")
        let engine = TransactionEngine()

        let appState = await AppState(storageUrl: storageUrl, engine: engine)
        await appState.clearAllSandboxTransactions()

        let url = URL(string: "zerotyping://record?amount=88.00&merchant=Uniqlo&currency=HKD")!
        let result = await appState.handleIncomingURL(url)

        switch result {
        case .recorded(let tx):
            #expect(tx.merchantRaw == "Uniqlo")
            #expect(tx.amountMinor == 8800)
            #expect(tx.captureChannel == .urlScheme)
            #expect(tx.reviewStatus == .confirmed)
            #expect(tx.paymentStatus == .completed)
        default:
            Issue.record("Expected .recorded result but got \(result)")
        }

        let transactions = await appState.transactions
        #expect(transactions.count == 1)
        #expect(transactions.first?.merchantRaw == "Uniqlo")
    }

    @Test("AppState handles incoming URL with missing or zero amount safely")
    func testAppStateHandlesMissingAmountURL() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("test_url_storage_zero.json")
        let engine = TransactionEngine()

        let appState = await AppState(storageUrl: storageUrl, engine: engine)
        await appState.clearAllSandboxTransactions()

        let url = URL(string: "zerotyping://record?merchant=MTR%20Entry&amount=0")!
        let result = await appState.handleIncomingURL(url)

        switch result {
        case .recorded(let tx):
            #expect(tx.amountMinor == 0)
            #expect(tx.reviewStatus == .needsReview)
            #expect(tx.paymentStatus == .pending)
        default:
            Issue.record("Expected .recorded result for zero amount hold")
        }
    }

    @Test("RecordExpenseIntent fallback parsing when amount is zero but notes contains amount")
    func testRecordExpenseIntentFallbackNotesParsing() async throws {
        let intent = RecordExpenseIntent(
            amount: 0.0,
            currency: "HKD",
            merchant: "7-Eleven 繳費",
            sourceTransactionId: "FALLBACK-01",
            notes: "消費 HK$35.50 於 7-Eleven"
        )

        _ = try await intent.perform()

        let engine = SharedTransactionEngine.shared
        let allTx = await engine.getAllTransactions()
        let ingested = allTx.first { $0.sourceTransactionId == "FALLBACK-01" }

        #expect(ingested != nil)
        #expect(ingested?.amountMinor == 3550)
    }

    @Test("ShortcutFileGenerator creates valid .shortcut plist file")
    func testShortcutFileGenerator() throws {
        let plistData = ShortcutFileGenerator.makeShortcutPlistData()
        #expect(plistData != nil)
        #expect((plistData?.count ?? 0) > 100)

        let fileURL = ShortcutFileGenerator.generateShortcutFile()
        #expect(fileURL != nil)
        #expect(fileURL?.pathExtension == "shortcut")
        #expect(FileManager.default.fileExists(atPath: fileURL?.path ?? ""))
    }

    @Test("RecordExpenseIntent parses amount and merchant from single rawInput parameter")
    func testRecordExpenseIntentSingleRawInput() async throws {
        let intent = RecordExpenseIntent(
            amount: 0.0,
            currency: "HKD",
            merchant: "Unknown Merchant",
            sourceTransactionId: "RAWINPUT-01",
            rawInput: "HK$68.00 於 Pacific Coffee"
        )

        _ = try await intent.perform()

        let engine = SharedTransactionEngine.shared
        let allTx = await engine.getAllTransactions()
        let ingested = allTx.first { $0.sourceTransactionId == "RAWINPUT-01" }

        #expect(ingested != nil)
        #expect(ingested?.amountMinor == 6800)
    }

    @Test("End-to-End pending transaction categorization and budget recalculation")
    @MainActor
    func testPendingTransactionCategorizationAndBudget() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("test_pending_budget.json")
        let engine = TransactionEngine()

        let appState = AppState(storageUrl: storageUrl, engine: engine)
        await appState.clearAllSandboxTransactions()

        // 1. Ingest pending transaction
        let tx = try await appState.addSampleTransaction(
            merchant: "Pacific Coffee",
            amountMinor: 4500,
            currency: "HKD",
            isPending: true
        )
        #expect(appState.pendingTransactions.count == 1)
        #expect(appState.monthlyNetSpentMinor == 0) // Pending not counted in budget

        // 2. Confirm category to dining
        try await appState.confirmCategory(id: tx.id, categoryId: AppState.diningCategoryId)
        #expect(appState.pendingTransactions.count == 0)
        #expect(appState.monthlyNetSpentMinor == 4500) // Now counted
    }

    @Test("Security fix: zerotyping://reset does not wipe transactions")
    @MainActor
    func testResetURLSchemeDoesNotWipeData() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("test_reset_security.json")
        let engine = TransactionEngine()

        let appState = AppState(storageUrl: storageUrl, engine: engine)
        await appState.clearAllSandboxTransactions()

        _ = try await appState.addSampleTransaction(merchant: "Safe Merchant", amountMinor: 2000, currency: "HKD")
        #expect(appState.transactions.count == 1)

        let resetUrl = URL(string: "zerotyping://reset")!
        let result = await appState.handleIncomingURL(resetUrl)

        switch result {
        case .error(let msg):
            #expect(msg.contains("為保障資料安全"))
        default:
            Issue.record("Expected error when unauthenticated reset URL is invoked")
        }

        #expect(appState.transactions.count == 1)
        #expect(appState.transactions.first?.merchantRaw == "Safe Merchant")
    }

    @Test("URLSchemeHandler extracts amount and merchant from notes when missing")
    func testURLSchemeNotesFallback() {
        let url1 = URL(string: "zerotyping://record?notes=amount:%2010%20hkd,%20merchant:%20seven%20eleven")!
        let action1 = URLSchemeHandler.parse(url: url1)

        switch action1 {
        case .record(let amountMinor, let currency, let merchant, _, _):
            #expect(amountMinor == 1000)
            #expect(currency == "HKD")
            #expect(merchant == "seven eleven")
        default:
            Issue.record("Expected .record action from notes parsing")
        }

        let url2 = URL(string: "zerotyping://record?amount=45&notes=payee:%20Starbucks")!
        let action2 = URLSchemeHandler.parse(url: url2)

        switch action2 {
        case .record(let amountMinor, _, let merchant, _, _):
            #expect(amountMinor == 4500)
            #expect(merchant == "Starbucks")
        default:
            Issue.record("Expected .record action with amount and merchant from notes")
        }
    }

    @Test("ParseAIExpenseIntent parses single text parameter and writes to engine and disk")
    func testParseAIExpenseIntent() async throws {
        let intent = ParseAIExpenseIntent(text: "amount: 10 hkd, merchant: seven eleven")
        _ = try await intent.perform()

        let engine = SharedTransactionEngine.shared
        let allTx = await engine.getAllTransactions()
        let matching = allTx.first { $0.captureChannel == .appleIntelligence && $0.amountMinor == 1000 }

        #expect(matching != nil)
        #expect(matching?.merchantRaw == "seven eleven")
        #expect(matching?.currency == "HKD")

        // Verify disk persistence
        let storageURL = ZeroTypingDiskStorage.defaultStorageURL
        #expect(FileManager.default.fileExists(atPath: storageURL.path))
        let envelope = try await ZeroTypingDiskStorage.shared.loadEnvelope(from: storageURL)
        #expect(envelope.transactions.contains { $0.captureChannel == .appleIntelligence && $0.amountMinor == 1000 })
    }

    @Test("ZeroTypingDiskStorage concurrent atomic persistence")
    func testZeroTypingDiskStorageConcurrency() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("test_concurrency_storage.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let diskStorage = ZeroTypingDiskStorage()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let tx = TransactionEntity(
                        idempotencyKey: "concurrent_tx_\(i)",
                        provider: .applePay,
                        captureChannel: .shortcut,
                        merchantRaw: "Merchant \(i)",
                        amountMinor: Int64(i * 100),
                        currency: "HKD"
                    )
                    try await diskStorage.persistTransaction(tx, to: storageUrl)
                }
            }
            try await group.waitForAll()
        }

        let loaded = try await diskStorage.loadEnvelope(from: storageUrl)
        #expect(loaded.transactions.count == 10)
    }

    @Test("Apple Intelligence onboarding scenario configuration")
    func testAppleIntelligenceOnboardingScenario() {
        let scenario = OnboardingScenario.appleIntelligence
        #expect(scenario.rawValue == "Apple Intelligence 提示詞")
        #expect(scenario.icon == "sparkles")
    }

    @Test("ParseAIExpenseIntent deduplication and idempotency on duplicate run")
    func testParseAIExpenseIntentIdempotency() async throws {
        let text = "amount: 10 hkd, merchant: seven eleven"
        let intent1 = ParseAIExpenseIntent(text: text)
        _ = try await intent1.perform()

        let intent2 = ParseAIExpenseIntent(text: text)
        _ = try await intent2.perform()

        let engine = SharedTransactionEngine.shared
        let allTx = await engine.getAllTransactions()
        let matching = allTx.filter { $0.captureChannel == .appleIntelligence && $0.amountMinor == 1000 && $0.merchantRaw == "seven eleven" }
        #expect(matching.count == 1)
    }

    @Test("RecordExpenseIntent extracts merchant and amount from rawInput")
    func testRecordExpenseIntentExtractsMerchantFromRawInput() async throws {
        let intent = RecordExpenseIntent(
            amount: 0.0,
            currency: "HKD",
            merchant: "Unknown Merchant",
            sourceTransactionId: "RAW-CONNECTIVE-01",
            rawInput: "HK$68.00 於 Pacific Coffee"
        )
        _ = try await intent.perform()

        let engine = SharedTransactionEngine.shared
        let allTx = await engine.getAllTransactions()
        let matching = allTx.first { $0.sourceTransactionId == "RAW-CONNECTIVE-01" }

        #expect(matching != nil)
        #expect(matching?.amountMinor == 6800)
        #expect(matching?.merchantRaw == "Pacific Coffee")
    }

    @Test("ZeroTypingDiskStorage rejects corrupted file without overwriting")
    func testZeroTypingDiskStorageRejectsCorruptedFileWithoutOverwriting() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("corrupted_storage.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write corrupt JSON
        let corruptData = Data("INVALID_JSON_CONTENT{{{".utf8)
        try corruptData.write(to: storageUrl)

        let diskStorage = ZeroTypingDiskStorage()
        let tx = TransactionEntity(
            idempotencyKey: "test_tx_corrupt",
            provider: .applePay,
            captureChannel: .shortcut,
            merchantRaw: "Test Merchant",
            amountMinor: 500,
            currency: "HKD"
        )

        // Persist must throw decoding error rather than silently overwriting the corrupted file
        do {
            try await diskStorage.persistTransaction(tx, to: storageUrl)
            Issue.record("Expected persistTransaction to throw decoding error on corrupted file")
        } catch {
            #expect(error is DecodingError)
        }

        // Verify the original corrupted file content was NOT overwritten
        let currentContent = try String(contentsOf: storageUrl, encoding: .utf8)
        #expect(currentContent == "INVALID_JSON_CONTENT{{{")
    }

    @Test("ParseAIExpenseIntent returns ParsedExpenseEntity with amount, merchant, currency, and payment method")
    func testParseAIExpenseIntentReturnsEntity() async throws {
        let conversationalPrompt = """
        好的！根據您的截圖，為您整理扣款資訊如下：
        商戶：Pacific Coffee
        金額：45.00 HKD
        付款方式：八達通
        希望這對您有幫助，祝您有美好的一天！
        """

        let intent = ParseAIExpenseIntent(text: conversationalPrompt)
        let result = try await intent.perform()
        let entity = try #require(result.value)

        #expect(entity.amount == 45.0)
        #expect(entity.merchant == "Pacific Coffee")
        #expect(entity.currency == "HKD")
        #expect(entity.paymentMethod == "octopus")
        #expect(entity.needsReview == false)
    }

    @Test("ProcessPaymentScreenshotIntent handles imageFile and returns ParsedExpenseEntity")
    func testProcessPaymentScreenshotIntentWithData() async throws {
        // Test with empty/dummy file data - should gracefully downgrade to unknown without crashing
        let emptyFile = IntentFile(data: Data(), filename: "test.png")
        let intent = ProcessPaymentScreenshotIntent(screenshotFile: emptyFile, triggerChannel: "back_tap")
        let result = try await intent.perform()
        let entity = try #require(result.value)

        #expect(entity.amount == 0.0)
        #expect(entity.merchant == "Unknown Merchant")
        #expect(entity.needsReview == true)
    }

    @Test("VisionOCRService cleans natural language salutations and trailing punctuation verbs")
    func testVisionOCRNaturalLanguageCleaning() {
        let sample1 = ["好的！已為您識別：商戶是 麥當勞 消費了 HK$ 38.50。"]
        let res1 = VisionOCRService.shared.parseRecognizedStrings(sample1)
        #expect(res1.merchantRaw == "麥當勞")
        #expect(res1.amountMinor == 3850)

        let sample2 = ["amount: 65 hkd, merchant: 大家樂快餐"]
        let res2 = VisionOCRService.shared.parseRecognizedStrings(sample2)
        #expect(res2.merchantRaw == "大家樂快餐")
        #expect(res2.amountMinor == 6500)

        let sample3 = ["八達通銀包 扣款成功 港鐵 HK$ 12.50"]
        let res3 = VisionOCRService.shared.parseRecognizedStrings(sample3)
        #expect(res3.provider == .octopus)
        #expect(res3.amountMinor == 1250)
    }
}
