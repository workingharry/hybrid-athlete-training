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

    // MARK: - 6. Formally Verified Edge Case Invariants (ATM-01 & Stage 0 Hardening)

    @Test("ATM-01: Same-source consecutive purchases with distinct provider IDs remain distinct and confirmed")
    func testSameSourceDistinctProviderIDsAllowed() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let tx1 = TransactionEntity(
            idempotencyKey: "pos_tap_01",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            sourceTransactionId: "POS-REF-1001",
            merchantRaw: "7-Eleven",
            merchantCanonical: "7-Eleven",
            amountMinor: 1500,
            currency: "HKD",
            capturedAt: now,
            reviewStatus: .confirmed
        )

        let tx2 = TransactionEntity(
            idempotencyKey: "pos_tap_02",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            sourceTransactionId: "POS-REF-1002", // Distinct provider ID!
            merchantRaw: "7-Eleven",
            merchantCanonical: "7-Eleven",
            amountMinor: 1500,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(2),
            reviewStatus: .confirmed
        )

        let res1 = try await engine.ingestTransaction(tx1)
        let res2 = try await engine.ingestTransaction(tx2)

        #expect(res1.id != res2.id)
        #expect(res1.duplicateStatus == .unique)
        #expect(res2.duplicateStatus == .unique)
        #expect(res2.reviewStatus == .confirmed)
    }

    @Test("Stage 5 Case 2b: Same-source replay with identical provider ID returns original transaction")
    func testSameSourceIdenticalProviderIDReplay() async throws {
        let engine = TransactionEngine()
        let now = Date()

        let tx1 = TransactionEntity(
            idempotencyKey: "replay_test_01",
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            sourceTransactionId: "TX-REPLAY-999",
            merchantRaw: "Starbucks",
            amountMinor: 4200,
            currency: "HKD",
            capturedAt: now,
            reviewStatus: .confirmed
        )

        let tx2 = TransactionEntity(
            idempotencyKey: "replay_test_02", // Different idempotency key but same source & provider ID
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            ingestionSource: .walletShortcut,
            sourceTransactionId: "TX-REPLAY-999",
            merchantRaw: "Starbucks",
            amountMinor: 4200,
            currency: "HKD",
            capturedAt: now.addingTimeInterval(3),
            reviewStatus: .confirmed
        )

        let first = try await engine.ingestTransaction(tx1)
        let second = try await engine.ingestTransaction(tx2)

        #expect(second.id == first.id)
        #expect(second.reviewStatus == .confirmed)
    }

    @Test("Stage 0: Negative lookbehind protects merchant abbreviations from clause splitting")
    func testMerchantAbbreviationsProtection() {
        let text = "您已於 7-Eleven Co. Ltd. 扣除 HK$28.50。感謝光臨。"
        let clauses = VisionOCRService.segmentAndClassifyClauses(text)
        #expect(clauses.count == 2)
        #expect(clauses[0].text.contains("7-Eleven Co. Ltd."))
        #expect(clauses[0].intent == .confirmedExpenditure)
    }

    @Test("Stage 0: AAVS deduction with 扣款 classifies as topUpOrInternalTransfer before expenditure")
    func testAAVSDeductionPrecedence() {
        let text = "已從信用卡扣款自動增值 HK$500，八達通餘額為 HK$512.50。"
        let clauses = VisionOCRService.segmentAndClassifyClauses(text)
        #expect(clauses.count >= 1)
        #expect(clauses[0].intent == .topUpOrInternalTransfer)
    }

    @Test("Stage 0: Bank Pop-Up Promo without settlement verb yields nil amount and loanOrPromoOffer intent")
    func testBankPopUpPromoWithoutSettlementVerb() {
        let adText = "立即申請私人貸款高達HK$500,000，享HK$2,000現金回贈，簽賬滿HK$1,000即減HK$100！"
        let result = ocrService.parseRecognizedStrings([adText])
        #expect(result.intent == .loanOrPromoOffer)
        #expect(result.amountMinor == nil)
        #expect(result.isHypotheticalOrConditional == true)
    }

    @Test("Stage 0: Credit card bill reminder with minimum payment yields nil amount and non-expenditure")
    func testCreditCardBillReminderNonExpenditure() {
        let reminderText = "您的恒生信用卡本期最低還款額為 HK$800，結欠 HK$15,000，到期繳款日為 11月28日。"
        let result = ocrService.parseRecognizedStrings([reminderText])
        #expect(result.intent == .loanOrPromoOffer)
        #expect(result.amountMinor == nil)
        #expect(result.isHypotheticalOrConditional == true)
    }

    @Test("Batch Transit Reconcile: Multiple pending $0 Express Transit holds resolved by batch rides")
    func testBatchTransitReconciliation() async throws {
        let engine = TransactionEngine()
        let now = Date()

        // 1. User taps Express Transit at 08:30 (MTR tap-in -> $0 pending hold)
        let tapIn1 = TransactionEntity(
            idempotencyKey: "transit_tap_1",
            provider: .octopus,
            captureChannel: .walletAutomation,
            deviceSource: .appleWatch,
            merchantRaw: "MTR",
            amountMinor: 0,
            isHoldCandidate: true,
            currency: "HKD",
            transactionDate: now.addingTimeInterval(-7200),
            reviewStatus: .needsReview,
            paymentStatus: .pending
        )
        // 2. User taps bus at 12:15 (Bus tap -> $0 pending hold)
        let tapIn2 = TransactionEntity(
            idempotencyKey: "transit_tap_2",
            provider: .octopus,
            captureChannel: .walletAutomation,
            deviceSource: .iPhone,
            merchantRaw: "KMB",
            amountMinor: 0,
            isHoldCandidate: true,
            currency: "HKD",
            transactionDate: now.addingTimeInterval(-3600),
            reviewStatus: .needsReview,
            paymentStatus: .pending
        )

        _ = try await engine.ingestTransaction(tapIn1)
        _ = try await engine.ingestTransaction(tapIn2)

        // Verify 2 holds in engine
        let holds = await engine.getAllTransactions().filter { ($0.amountMinor == 0 || $0.amountMinor == nil) && $0.paymentStatus == .pending }
        #expect(holds.count == 2)

        // 3. User takes Octopus App statement screenshot at night with 2 settled rows
        let ride1 = TransactionEntity(
            idempotencyKey: "settled_ride_1",
            provider: .octopus,
            captureChannel: .photoPicker,
            merchantRaw: "港鐵 MTR",
            amountMinor: 1450, // HK$14.50
            currency: "HKD",
            transactionDate: now.addingTimeInterval(-7180),
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )
        let ride2 = TransactionEntity(
            idempotencyKey: "settled_ride_2",
            provider: .octopus,
            captureChannel: .photoPicker,
            merchantRaw: "九巴 KMB",
            amountMinor: 680, // HK$6.80
            currency: "HKD",
            transactionDate: now.addingTimeInterval(-3580),
            reviewStatus: .confirmed,
            paymentStatus: .completed
        )

        let reconciled = try await engine.batchReconcileTransitHolds([ride1, ride2])
        #expect(reconciled.count == 2)
        #expect(reconciled.allSatisfy { $0.paymentStatus == .completed })
        #expect(reconciled.allSatisfy { $0.reviewStatus == .confirmed })

        // Both holds should now be resolved to non-zero completed transactions
        let remainingPendingHolds = await engine.getAllTransactions().filter { ($0.amountMinor == 0 || $0.amountMinor == nil) && $0.paymentStatus == .pending }
        #expect(remainingPendingHolds.isEmpty)
    }
}
