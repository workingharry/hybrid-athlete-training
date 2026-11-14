import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Notification Intent & Octopus Recovery Tests")
struct NotificationIntentAndOctopusRecoveryTests {
    let ocrService = VisionOCRService.shared

    // MARK: - 1. Clause Segmentation & Hybrid Intent Gate Tests

    @Test("Stage 0: Drops loan promotion ad and extracts real expenditure in notification")
    func testDropLoanOfferAdAndKeepExpenditure() {
        let text = "您已於 7-Eleven 消費 HK$35.00。立即申請現金分期高達 HK$500,000！"
        let result = ocrService.parseRecognizedStrings([text])

        #expect(result.intent == NotificationIntent.confirmedExpenditure)
        #expect(result.amountMinor == 3500)
        #expect(result.isHypotheticalOrConditional == false)
        #expect(result.merchantRaw?.contains("7-Eleven") == true)
        #expect(!result.candidateAmountsMinor.contains(50000000))
    }

    @Test("Stage 0: Pure loan pre-approval offer returns nil amount and loan intent")
    func testPureLoanOfferClassification() {
        let text = "尊敬的客戶，您的分期貸款已預批高達 HK$300,000，月平息低至0.12%，立即申請！"
        let result = ocrService.parseRecognizedStrings([text])

        #expect(result.intent == NotificationIntent.loanOrPromoOffer)
        #expect(result.amountMinor == nil)
        #expect(result.isHypotheticalOrConditional == true)
        #expect(result.requiresManualReview == true)
    }

    @Test("Stage 0: 3DS OTP notification returns otp intent and drops OTP number from expense")
    func testOTPNotificationClassification() {
        let text = "您的中銀信用卡一次性驗證碼 OTP 是 948215，用於網上交易，有效時間為 5 分鐘。"
        let result = ocrService.parseRecognizedStrings([text])

        #expect(result.intent == NotificationIntent.otpOrAuthAttempt)
        #expect(result.amountMinor == nil)
        #expect(result.isHypotheticalOrConditional == true)
    }

    // MARK: - 2. Role-Anchored Dual Extraction (DualNumberRoleExtractor) Tests

    @Test("Dual Extraction: Single-line Octopus alert correctly extracts spent and balance")
    func testSingleLineOctopusSpentAndBalance() {
        let text = "已從您的八達通扣除 HK$15.50，餘額為 HK$234.50。"
        let result = ocrService.parseRecognizedStrings([text])

        #expect(result.amountMinor == 1550)
        #expect(result.remainingBalanceMinor == 23450)
        #expect(result.provider == PaymentProvider.octopus)
        #expect(result.intent == NotificationIntent.confirmedExpenditure)
    }

    @Test("Dual Extraction: English MTR alert correctly extracts fare and remaining value")
    func testEnglishMTRSpentAndRemainingValue() {
        let text = "Paid HK$15.50 at MTR. Remaining value: HK$234.50"
        let result = ocrService.parseRecognizedStrings([text])

        #expect(result.amountMinor == 1550)
        #expect(result.remainingBalanceMinor == 23450)
        #expect(result.provider == PaymentProvider.octopus)
        #expect(result.merchantRaw == "港鐵")
    }

    @Test("Dual Extraction: Balance Candidate Self-Correction overrides misidentified amount")
    func testDualExtractionSelfCorrection() {
        let dual = VisionOCRService.extractDualNumberRoles("扣除 HK$22.00，現時卡片餘額為 HK$388.50")
        #expect(dual.spentMinor == 2200)
        #expect(dual.balanceMinor == 38850)
    }

    // MARK: - 3. Stateful BalanceLedger & Octopus Recovery Tests

    @Test("BalanceLedger: Ledger-verified match sets amount confidence to 1.0")
    func testOctopusLedgerVerifiedMatch() async throws {
        let engine = TransactionEngine()

        // Seed previous balance at HK$300.00
        await engine.setBalanceSnapshot(key: "octopus:default", snapshot: TransactionEngine.BalanceSnapshot(balanceMinor: 30000, updatedAt: Date()))

        let tx = TransactionEntity(
            idempotencyKey: "oct_tx_verify_01",
            provider: .octopus,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            sourceTransactionId: "OCT-V01",
            merchantRaw: "港鐵",
            merchantCanonical: "港鐵",
            amountMinor: 1550,
            remainingBalanceMinor: 28450, // 30000 - 1550 = 28450
            currency: "HKD",
            reviewStatus: .needsReview,
            paymentStatus: .completed
        )

        let ingested = try await engine.ingestTransaction(tx)
        #expect(ingested.amountConfidence == 1.0)

        let snapshot = await engine.getBalanceSnapshot(key: "octopus:default")
        #expect(snapshot?.balanceMinor == 28450)
    }

    @Test("BalanceLedger: Inferred spent recovery from balance notification when amount is zero")
    func testOctopusInferredSpentFromBalanceDelta() async throws {
        let engine = TransactionEngine()

        // Previous balance HK$500.00
        await engine.setBalanceSnapshot(key: "octopus:default", snapshot: TransactionEngine.BalanceSnapshot(balanceMinor: 50000, updatedAt: Date()))

        // New notification only has balance HK$465.00 (spent HK$35.00 missing)
        let tx = TransactionEntity(
            idempotencyKey: "oct_tx_infer_01",
            provider: .octopus,
            captureChannel: .appleIntelligence,
            deviceSource: .iPhone,
            ingestionSource: .notificationOCR,
            sourceTransactionId: "OCT-INF01",
            merchantRaw: "八達通",
            merchantCanonical: "八達通",
            amountMinor: 0,
            remainingBalanceMinor: 46500,
            isHoldCandidate: true,
            currency: "HKD"
        )

        let ingested = try await engine.ingestTransaction(tx)
        #expect(ingested.amountMinor == 3500)
        #expect(ingested.paymentStatus == PaymentStatus.completed)

        let snapshot = await engine.getBalanceSnapshot(key: "octopus:default")
        #expect(snapshot?.balanceMinor == 46500)
    }

    @Test("BalanceLedger: Silent Top-Up AAVS detection updates baseline without recording negative spend")
    func testOctopusSilentTopUpDetection() async throws {
        let engine = TransactionEngine()

        // Previous balance HK$25.00
        await engine.setBalanceSnapshot(key: "octopus:default", snapshot: TransactionEngine.BalanceSnapshot(balanceMinor: 2500, updatedAt: Date()))

        // Balance increased to HK$525.00 (Auto reload HK$500)
        let tx = TransactionEntity(
            idempotencyKey: "oct_tx_topup_01",
            provider: .octopus,
            captureChannel: .appleIntelligence,
            deviceSource: .iPhone,
            ingestionSource: .notificationOCR,
            sourceTransactionId: "OCT-TOPUP01",
            merchantRaw: "八達通自動增值",
            merchantCanonical: "八達通增值",
            amountMinor: 0,
            remainingBalanceMinor: 52500,
            currency: "HKD"
        )

        let ingested = try await engine.ingestTransaction(tx)
        #expect(ingested.transactionType == TransactionType.topUp)
        #expect(ingested.amountMinor == 50000)

        let snapshot = await engine.getBalanceSnapshot(key: "octopus:default")
        #expect(snapshot?.balanceMinor == 52500)
    }

    @Test("BalanceLedger: Negative buffer anomaly flags needsReview")
    func testOctopusNegativeBufferAnomalyDetection() async throws {
        let engine = TransactionEngine()

        // Previous balance HK$10.00 (1000 minor)
        await engine.setBalanceSnapshot(key: "octopus:default", snapshot: TransactionEngine.BalanceSnapshot(balanceMinor: 1000, updatedAt: Date()))

        // Transaction claims spent HK$100.00, remaining HK$-90.00 (breaches -HK$50 buffer)
        let tx = TransactionEntity(
            idempotencyKey: "oct_tx_anomaly_01",
            provider: .octopus,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            sourceTransactionId: "OCT-ANOM01",
            merchantRaw: "港鐵",
            amountMinor: 10000,
            remainingBalanceMinor: -9000,
            currency: "HKD",
            reviewStatus: .confirmed
        )

        let ingested = try await engine.ingestTransaction(tx)
        #expect(ingested.reviewStatus == ReviewStatus.needsReview)
    }

    // MARK: - 4. Tiered Hold Matching & Reconcile Tests

    @Test("Tiered Hold: Octopus hold pairs cross-device and upgrades generic merchant within 15 min")
    func testOctopusTieredHoldMatchingCrossDeviceAndUpgradesMerchant() async throws {
        let engine = TransactionEngine()
        let now = Date()

        // 1. Apple Watch taps at MTR: creates $0 hold with generic "Octopus" merchant
        let holdTx = TransactionEntity(
            idempotencyKey: "oct_hold_watch_01",
            provider: .octopus,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            sourceTransactionId: "HOLD-WATCH-01",
            merchantRaw: "Octopus",
            merchantCanonical: "八達通",
            amountMinor: 0,
            isHoldCandidate: true,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(-180), // 3 minutes ago
            reviewStatus: .needsReview,
            paymentStatus: .pending
        )
        _ = try await engine.ingestTransaction(holdTx)

        // 2. iPhone receives push notification with specific "港鐵" and settled amount HK$14.50
        let settlementTx = TransactionEntity(
            idempotencyKey: "oct_settle_phone_01",
            provider: .octopus,
            captureChannel: .appleIntelligence,
            deviceSource: .iPhone, // Different device!
            ingestionSource: .notificationOCR,
            sourceTransactionId: "SETTLE-PHONE-01",
            merchantRaw: "港鐵",
            merchantCanonical: "港鐵",
            amountMinor: 1450,
            remainingBalanceMinor: 18550,
            currency: "HKD",
            capturedAt: now
        )

        let reconciled = try await engine.ingestTransaction(settlementTx)

        #expect(reconciled.id == holdTx.id)
        #expect(reconciled.amountMinor == 1450)
        #expect(reconciled.paymentStatus == PaymentStatus.completed)
        #expect(reconciled.reviewStatus == ReviewStatus.confirmed)
        #expect(reconciled.merchantRaw == "港鐵")
    }

    // MARK: - 5. Multi-Channel 120s Deduplication vs Same-Source Tests

    @Test("Cross-Source Duplication: Wallet Shortcut and Bank Notification within 120s merge and enrich without duplicate review")
    func testMultiChannelMergeAndEnrich() async throws {
        let engine = TransactionEngine()
        let now = Date()

        // Event A: Apple Pay Wallet Shortcut captures payment
        let walletTx = TransactionEntity(
            idempotencyKey: "wallet_coffee_01",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            sourceTransactionId: "WALLET-TX-01",
            merchantRaw: "Starbucks Coffee",
            merchantCanonical: "Starbucks",
            amountMinor: 4800,
            currency: "HKD",
            capturedAt: now,
            reviewStatus: .confirmed
        )
        let first = try await engine.ingestTransaction(walletTx)
        #expect(first.reviewStatus == ReviewStatus.confirmed)

        // Event B: Bank SMS / Push notification OCR captures 5 seconds later
        let notificationTx = TransactionEntity(
            idempotencyKey: "notif_coffee_01",
            provider: .applePay,
            captureChannel: .appleIntelligence,
            deviceSource: .iPhone,
            ingestionSource: .notificationOCR, // Different source!
            sourceTransactionId: "BANK-NOTIF-01",
            merchantRaw: "Starbucks Coffee",
            merchantCanonical: "Starbucks",
            amountMinor: 4800,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(5)
        )

        let merged = try await engine.ingestTransaction(notificationTx)

        // Merged into original transaction, reviewStatus stays confirmed, no duplicate noise
        #expect(merged.id == first.id)
        #expect(merged.reviewStatus == ReviewStatus.confirmed)
        #expect(merged.duplicateStatus == DuplicateStatus.unique)
    }

    @Test("Same-Source Duplication: Rapid identical card taps from same source are flagged as possibleDuplicate")
    func testSameSourceDuplicateFlagged() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let tap1 = TransactionEntity(
            idempotencyKey: "card_tap_01",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            merchantRaw: "7-Eleven",
            amountMinor: 2500,
            currency: "HKD",
            capturedAt: now,
            reviewStatus: .confirmed
        )
        _ = try await engine.ingestTransaction(tap1)

        let tap2 = TransactionEntity(
            idempotencyKey: "card_tap_02",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut, // Same source!
            merchantRaw: "7-Eleven",
            amountMinor: 2500,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(20),
            reviewStatus: .confirmed
        )
        let second = try await engine.ingestTransaction(tap2)

        #expect(second.duplicateStatus == DuplicateStatus.possibleDuplicate)
        #expect(second.reviewStatus == ReviewStatus.needsReview)
    }
}
