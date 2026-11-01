import Foundation
#if canImport(AppIntents)
import AppIntents

// MARK: - Parsed Expense Entity for iOS Shortcuts Output

@available(iOS 16.0, macOS 13.0, *)
public struct ParsedExpenseEntity: AppEntity, Sendable {
    public static let defaultQuery = ParsedExpenseEntityQuery()
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "記帳解析結果"

    public var id: String

    @Property(title: "金額")
    public var amount: Double

    @Property(title: "幣別")
    public var currency: String

    @Property(title: "商戶名稱")
    public var merchant: String

    @Property(title: "付款方式")
    public var paymentMethod: String

    @Property(title: "需要核對")
    public var needsReview: Bool

    public init(
        id: String,
        amount: Double,
        currency: String = "HKD",
        merchant: String,
        paymentMethod: String = "Apple Pay",
        needsReview: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.needsReview = needsReview
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(merchant)",
            subtitle: "\(paymentMethod) · \(currency) $\(String(format: "%.2f", amount))"
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ParsedExpenseEntityQuery: EntityQuery, Sendable {
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [ParsedExpenseEntity] {
        return []
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct RecordExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "記錄支出"
    public static let description = IntentDescription("由 Apple Pay 錢包自動化觸發或手動記錄一筆支出")

    @Parameter(title: "金額", description: "支出金額", default: 0.0)
    public var amount: Double

    @Parameter(title: "貨幣代碼", description: "ISO 4217 貨幣代碼（預設 HKD）", default: "HKD")
    public var currency: String

    @Parameter(title: "商戶名稱", description: "消費商戶名稱", default: "Unknown Merchant")
    public var merchant: String

    @Parameter(title: "卡號末四碼", description: "交易卡片末四位數字", default: nil)
    public var cardLastFour: String?

    @Parameter(title: "來源交易序號", description: "Apple Pay 提供的原始序號", default: nil)
    public var sourceTransactionId: String?

    @Parameter(title: "設備來源", description: "iPhone 或 Apple Watch", default: "iPhone")
    public var deviceSource: String

    @Parameter(title: "支出類型", description: "消費/轉帳/儲值/手續費", default: "payment")
    public var expenditureType: String

    @Parameter(title: "備註 / 交易資訊", description: "附加備忘或捷徑輸入文字", default: nil)
    public var notes: String?

    @Parameter(title: "捷徑完整輸入 (極簡免設定)", description: "可直接將『捷徑輸入』整體帶入此欄位，系統自動解析金額與商戶", default: nil)
    public var rawInput: String?

    public init() {
        self.deviceSource = "iPhone"
        self.expenditureType = "payment"
        self.notes = nil
        self.rawInput = nil
    }

    public init(
        amount: Double,
        currency: String = "HKD",
        merchant: String = "Unknown Merchant",
        cardLastFour: String? = nil,
        sourceTransactionId: String? = nil,
        deviceSource: String = "iPhone",
        expenditureType: String = "payment",
        notes: String? = nil,
        rawInput: String? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.cardLastFour = cardLastFour
        self.sourceTransactionId = sourceTransactionId
        self.deviceSource = deviceSource
        self.expenditureType = expenditureType
        self.notes = notes
        self.rawInput = rawInput
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("記錄 \(\.$amount) \(\.$currency) 於 \(\.$merchant)")
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ParsedExpenseEntity> & ProvidesDialog {
        guard amount.isFinite, amount >= 0, amount <= 100_000_000 else {
            throw IntentError.invalidAmount
        }

        var finalAmountMinor = Int64(round(amount * 100))
        var resolvedMerchant = merchant
        var resolvedCurrency = currency

        // Multi-field intelligent fallback:
        // If amount is 0, extract amounts from rawInput, notes, or even merchant string
        let candidateTexts = [rawInput, notes, (merchant != "Unknown Merchant" ? merchant : nil)]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if finalAmountMinor == 0 && !candidateTexts.isEmpty {
            for text in candidateTexts {
                let lines = text.components(separatedBy: .newlines)
                let parsed = VisionOCRService.shared.parseRecognizedStrings(lines)
                if let detectedMinor = parsed.amountMinor, detectedMinor > 0 {
                    finalAmountMinor = detectedMinor
                }
                if (resolvedMerchant.isEmpty || resolvedMerchant == "Unknown Merchant"), let detectedMerchant = parsed.merchantRaw, detectedMerchant != "Unknown Merchant" {
                    resolvedMerchant = detectedMerchant
                }
                if parsed.currency != "HKD" && resolvedCurrency == "HKD" {
                    resolvedCurrency = parsed.currency
                }
                if finalAmountMinor > 0 { break }
            }
        }

        // Multi-candidate merchant fallback when merchant is missing or default
        if (resolvedMerchant.isEmpty || resolvedMerchant == "Unknown Merchant") && !candidateTexts.isEmpty {
            for text in candidateTexts {
                let lines = text.components(separatedBy: .newlines)
                let parsed = VisionOCRService.shared.parseRecognizedStrings(lines)
                if let detectedMerchant = parsed.merchantRaw, detectedMerchant != "Unknown Merchant", !detectedMerchant.isEmpty {
                    resolvedMerchant = detectedMerchant
                    break
                }
            }
        }

        let effectiveTxId = sourceTransactionId ?? UUID().uuidString
        let date = Date()

        let devSource: DeviceSource
        if deviceSource.localizedCaseInsensitiveContains("watch") {
            devSource = .appleWatch
        } else if deviceSource.localizedCaseInsensitiveContains("phone") {
            devSource = .iPhone
        } else {
            devSource = .unknown
        }

        let parsedType: TransactionType
        switch expenditureType.lowercased() {
        case "transfer", "轉帳":
            parsedType = .transfer
        case "topup", "儲值":
            parsedType = .topUp
        case "fee", "手續費":
            parsedType = .fee
        case "refund", "退款":
            parsedType = .refund
        case "adjustment", "調整":
            parsedType = .adjustment
        default:
            parsedType = .payment
        }

        // Double-layer idempotency key (§8.5)
        let idempotencyKey: String
        if let stid = sourceTransactionId, !stid.isEmpty {
            idempotencyKey = "applePay_\(stid)"
        } else {
            let cardSuffix = cardLastFour ?? "unknown"
            idempotencyKey = "applePay_\(cardSuffix)_\(resolvedMerchant)_\(finalAmountMinor)_\(Int(date.timeIntervalSince1970 / 60))"
        }

        let isZeroAmount = (finalAmountMinor == 0)

        let transaction = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: .applePay,
            captureChannel: .walletAutomation,
            deviceSource: devSource,
            sourceTransactionId: effectiveTxId,
            merchantRaw: resolvedMerchant,
            merchantCanonical: resolvedMerchant,
            amountMinor: finalAmountMinor,
            currency: resolvedCurrency,
            ledgerAmountMinor: finalAmountMinor,
            ledgerCurrency: resolvedCurrency,
            reviewStatus: isZeroAmount ? .needsReview : .confirmed,
            paymentStatus: isZeroAmount ? .pending : .completed,
            duplicateStatus: .unique,
            transactionType: parsedType,
            amountConfidence: 1.0,
            currencyConfidence: 1.0,
            merchantConfidence: 0.95
        )

        // Store into shared engine and persist to disk
        let engine = SharedTransactionEngine.shared
        _ = try await engine.ingestTransaction(transaction)
        try? await ZeroTypingDiskStorage.shared.persistTransaction(transaction)

        let parsedAmount = Double(finalAmountMinor) / 100.0
        let entity = ParsedExpenseEntity(
            id: effectiveTxId,
            amount: parsedAmount,
            currency: resolvedCurrency,
            merchant: resolvedMerchant,
            paymentMethod: "Apple Pay",
            needsReview: isZeroAmount
        )

        if isZeroAmount {
            if resolvedMerchant.localizedCaseInsensitiveContains("mtr") || resolvedMerchant.localizedCaseInsensitiveContains("港鐵") || resolvedMerchant.localizedCaseInsensitiveContains("進站") {
                return .result(value: entity, dialog: "已記錄交通進站預授權（待出站結算扣款）")
            } else {
                return .result(value: entity, dialog: "已記錄待確認交易（金額為 0，請確認捷徑是否已正確綁定「捷徑輸入 ➔ 金額」）")
            }
        }

        let displayAmount = String(format: "%.2f", parsedAmount)
        return .result(value: entity, dialog: "已自動入帳 \(resolvedCurrency)$\(displayAmount) 於 \(resolvedMerchant)")
    }

    public enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case invalidAmount

        public var localizedStringResource: LocalizedStringResource {
            switch self {
            case .invalidAmount:
                return "交易金額必須大於或等於 0"
            }
        }
    }
}

// MARK: - Process Payment Screenshot Intent (Back Tap / Action Button / Direct Image)

@available(iOS 17.0, macOS 14.0, *)
public struct ProcessPaymentScreenshotIntent: AppIntent {
    public static let title: LocalizedStringResource = "辨識截圖記帳"
    public static let description = IntentDescription("接收付款收據或線上 Apple Pay 截圖，透過 Vision OCR 辨識金額、商戶並自動記帳")

    @Parameter(title: "截圖圖片", description: "直接傳入付款截圖或收據圖片檔案進行端側 AI 辨識", default: nil)
    public var screenshotFile: IntentFile?

    @Parameter(title: "截圖文字或收據行", description: "從截圖 OCR 或剪貼簿提取之收據文字行數", default: [])
    public var recognizedLines: [String]

    @Parameter(title: "來源渠道", description: "觸發渠道 (backTap 或 actionButton)", default: "back_tap")
    public var triggerChannel: String

    public init() {
        self.screenshotFile = nil
        self.recognizedLines = []
        self.triggerChannel = "back_tap"
    }

    public init(screenshotFile: IntentFile? = nil, recognizedLines: [String] = [], triggerChannel: String = "back_tap") {
        self.screenshotFile = screenshotFile
        self.recognizedLines = recognizedLines
        self.triggerChannel = triggerChannel
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("解析付款截圖並自動入帳")
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ParsedExpenseEntity> & ProvidesDialog {
        let channel: CaptureChannel = (triggerChannel == "action_button") ? .actionButton : .backTap

        let ocrResult: OCRResult
        if let file = screenshotFile, !file.data.isEmpty {
            if let recognized = try? await VisionOCRService.shared.recognizeReceipt(imageData: file.data) {
                ocrResult = recognized
            } else {
                ocrResult = VisionOCRService.shared.parseRecognizedStrings(recognizedLines)
            }
        } else {
            ocrResult = VisionOCRService.shared.parseRecognizedStrings(recognizedLines)
        }

        let provider: PaymentProvider
        if recognizedLines.joined(separator: "\n").localizedCaseInsensitiveContains("apple store") ||
           recognizedLines.joined(separator: "\n").localizedCaseInsensitiveContains("subscription") ||
           recognizedLines.joined(separator: "\n").localizedCaseInsensitiveContains("訂閱") {
            provider = .appleStoreSubscription
        } else {
            provider = ocrResult.provider
        }

        let effectiveTxId = ocrResult.sourceTransactionId ?? "SCREENSHOT-\(UUID().uuidString.prefix(8))"
        let idempotencyKey: String
        if let stid = ocrResult.sourceTransactionId, !stid.isEmpty {
            idempotencyKey = "\(channel.rawValue)_\(stid)_\(ocrResult.amountMinor ?? 0)"
        } else {
            let canon = (ocrResult.merchantRaw ?? "unknown").replacingOccurrences(of: " ", with: "_")
            let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
            idempotencyKey = "\(channel.rawValue)_\(canon)_\(ocrResult.amountMinor ?? 0)_\(minuteBucket)"
        }

        let isAmountMissingOrZero = (ocrResult.amountMinor == nil || ocrResult.amountMinor == 0)
        let reviewStatus: ReviewStatus = (isAmountMissingOrZero || ocrResult.requiresManualReview) ? .needsReview : .confirmed
        let paymentStatus: PaymentStatus = isAmountMissingOrZero ? .pending : .completed

        let transaction = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: provider,
            captureChannel: channel,
            deviceSource: .iPhone,
            sourceTransactionId: effectiveTxId,
            merchantRaw: ocrResult.merchantRaw,
            merchantCanonical: ocrResult.merchantRaw,
            amountMinor: ocrResult.amountMinor,
            candidateAmountsMinor: ocrResult.candidateAmountsMinor,
            currency: ocrResult.currency,
            ledgerAmountMinor: ocrResult.amountMinor,
            ledgerCurrency: ocrResult.currency,
            reviewStatus: reviewStatus,
            paymentStatus: paymentStatus,
            duplicateStatus: .unique,
            transactionType: .payment,
            amountConfidence: ocrResult.amountConfidence,
            currencyConfidence: 1.0,
            merchantConfidence: ocrResult.merchantConfidence,
            ocrEngineVersion: ocrResult.ocrEngineVersion,
            ocrTemplateVersion: ocrResult.ocrTemplateVersion
        )

        let engine = SharedTransactionEngine.shared
        _ = try await engine.ingestTransaction(transaction)
        try? await ZeroTypingDiskStorage.shared.persistTransaction(transaction)

        let parsedAmount = Double(ocrResult.amountMinor ?? 0) / 100.0
        let parsedMerchant = ocrResult.merchantRaw ?? "Unknown Merchant"
        let entity = ParsedExpenseEntity(
            id: effectiveTxId,
            amount: parsedAmount,
            currency: ocrResult.currency,
            merchant: parsedMerchant,
            paymentMethod: provider.rawValue,
            needsReview: reviewStatus == .needsReview
        )

        if let minor = ocrResult.amountMinor, minor > 0 {
            let major = Double(minor) / 100.0
            return .result(value: entity, dialog: "已由截圖自動入帳 \(ocrResult.currency)$\(String(format: "%.2f", major)) 於 \(parsedMerchant)")
        } else {
            return .result(value: entity, dialog: "截圖未辨識到明確金額，已建立待審核交易以保護預算")
        }
    }
}

// MARK: - Parse Clipboard Expense Intent (SMS / Notification / Clipboard)

@available(iOS 17.0, macOS 14.0, *)
public struct ParseClipboardExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "解析剪貼簿支出文字"
    public static let description = IntentDescription("從通知文字或剪貼簿中辨識扣款資訊並入帳")

    @Parameter(title: "文字內容", description: "扣款簡訊或通知文字", default: "")
    public var rawText: String

    public init() {
        self.rawText = ""
    }

    public init(rawText: String) {
        self.rawText = rawText
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("解析剪貼簿支出：\(\.$rawText)")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let lines = rawText.components(separatedBy: .newlines)
        let ocrResult = VisionOCRService.shared.parseRecognizedStrings(lines)

        let effectiveTxId = ocrResult.sourceTransactionId ?? "CLIP-\(UUID().uuidString.prefix(8))"
        let idempotencyKey: String
        if let stid = ocrResult.sourceTransactionId, !stid.isEmpty {
            idempotencyKey = "clipboard_\(stid)_\(ocrResult.amountMinor ?? 0)"
        } else {
            let canon = (ocrResult.merchantRaw ?? "unknown").replacingOccurrences(of: " ", with: "_")
            let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
            idempotencyKey = "clipboard_\(canon)_\(ocrResult.amountMinor ?? 0)_\(minuteBucket)"
        }

        let isAmountMissingOrZero = (ocrResult.amountMinor == nil || ocrResult.amountMinor == 0)
        let reviewStatus: ReviewStatus = (isAmountMissingOrZero || ocrResult.requiresManualReview) ? .needsReview : .confirmed
        let paymentStatus: PaymentStatus = isAmountMissingOrZero ? .pending : .completed

        let transaction = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: .applePay,
            captureChannel: .clipboardParse,
            deviceSource: .iPhone,
            sourceTransactionId: effectiveTxId,
            merchantRaw: ocrResult.merchantRaw,
            merchantCanonical: ocrResult.merchantRaw,
            amountMinor: ocrResult.amountMinor,
            candidateAmountsMinor: ocrResult.candidateAmountsMinor,
            currency: ocrResult.currency,
            ledgerAmountMinor: ocrResult.amountMinor,
            ledgerCurrency: ocrResult.currency,
            reviewStatus: reviewStatus,
            paymentStatus: paymentStatus,
            duplicateStatus: .unique,
            transactionType: .payment,
            amountConfidence: ocrResult.amountConfidence,
            currencyConfidence: 1.0,
            merchantConfidence: ocrResult.merchantConfidence
        )

        let engine = SharedTransactionEngine.shared
        _ = try await engine.ingestTransaction(transaction)
        try? await ZeroTypingDiskStorage.shared.persistTransaction(transaction)

        if let minor = ocrResult.amountMinor, minor > 0 {
            let major = Double(minor) / 100.0
            return .result(dialog: "已自簡訊/剪貼簿解析入帳 \(ocrResult.currency)$\(String(format: "%.2f", major)) 於 \(ocrResult.merchantRaw ?? "商家")")
        } else {
            return .result(dialog: "文字已記錄至待審核（金額未確認）")
        }
    }
}

// MARK: - Quick Record Expense Intent (Siri / Control Center)

@available(iOS 17.0, macOS 14.0, *)
public struct QuickRecordExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "控制中心 / Siri 快速記帳"
    public static let description = IntentDescription("透過控制中心按鈕或 Siri 捷徑快速記錄支出")

    @Parameter(title: "金額", description: "支出金額")
    public var amount: Double

    @Parameter(title: "商戶", description: "消費商戶", default: "快捷消費")
    public var merchant: String

    @Parameter(title: "分類", description: "消費分類", default: "其他")
    public var category: String

    public init() {
        self.amount = 0.0
        self.merchant = "快捷消費"
        self.category = "其他"
    }

    public init(amount: Double, merchant: String = "快捷消費", category: String = "其他") {
        self.amount = amount
        self.merchant = merchant
        self.category = category
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("快速記錄 \(\.$amount) 於 \(\.$merchant)")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount.isFinite, amount >= 0 else {
            throw RecordExpenseIntent.IntentError.invalidAmount
        }

        let amountMinor = Int64(round(amount * 100))
        let effectiveTxId = "QUICK-\(UUID().uuidString.prefix(8))"
        let idempotencyKey = "controlCenter_\(effectiveTxId)_\(amountMinor)"

        let transaction = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: .applePay,
            captureChannel: .controlCenter,
            deviceSource: .iPhone,
            sourceTransactionId: effectiveTxId,
            merchantRaw: merchant,
            merchantCanonical: merchant,
            amountMinor: amountMinor,
            currency: "HKD",
            ledgerAmountMinor: amountMinor,
            ledgerCurrency: "HKD",
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique,
            transactionType: .payment,
            amountConfidence: 1.0,
            currencyConfidence: 1.0,
            merchantConfidence: 1.0
        )

        let engine = SharedTransactionEngine.shared
        _ = try await engine.ingestTransaction(transaction)
        try? await ZeroTypingDiskStorage.shared.persistTransaction(transaction)

        let displayAmount = String(format: "%.2f", amount)
        return .result(dialog: "已由快捷控制中心入帳 HKD$\(displayAmount) 於 \(merchant)")
    }
}

// MARK: - Parse AI / Apple Intelligence Expense Intent

@available(iOS 17.0, macOS 14.0, *)
public struct ParseAIExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "解析 AI / 扣款文字"
    public static let description = IntentDescription("接收 Apple Intelligence 或 AI 生成之單行/多行扣款文字並自動解析記帳")

    @Parameter(title: "文字內容", description: "AI 輸出或扣款文字 (例如 amount: 10 hkd, merchant: seven eleven)", default: "")
    public var text: String

    public init() {
        self.text = ""
    }

    public init(text: String) {
        self.text = text
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("解析 AI 扣款文字 \(\.$text)")
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<ParsedExpenseEntity> & ProvidesDialog {
        let lines = text.components(separatedBy: .newlines)
        let ocrResult = VisionOCRService.shared.parseRecognizedStrings(lines)

        let effectiveTxId = ocrResult.sourceTransactionId ?? "AI-\(UUID().uuidString.prefix(8))"
        let idempotencyKey: String
        if let stid = ocrResult.sourceTransactionId, !stid.isEmpty {
            idempotencyKey = "appleIntelligence_\(stid)_\(ocrResult.amountMinor ?? 0)"
        } else {
            let canon = (ocrResult.merchantRaw ?? "unknown").replacingOccurrences(of: " ", with: "_")
            let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
            idempotencyKey = "appleIntelligence_\(canon)_\(ocrResult.amountMinor ?? 0)_\(minuteBucket)"
        }

        let isAmountMissingOrZero = (ocrResult.amountMinor == nil || ocrResult.amountMinor == 0)
        let reviewStatus: ReviewStatus = (isAmountMissingOrZero || ocrResult.requiresManualReview) ? .needsReview : .confirmed
        let paymentStatus: PaymentStatus = isAmountMissingOrZero ? .pending : .completed

        let transaction = TransactionEntity(
            idempotencyKey: idempotencyKey,
            provider: ocrResult.provider,
            captureChannel: .appleIntelligence,
            deviceSource: .iPhone,
            sourceTransactionId: effectiveTxId,
            merchantRaw: ocrResult.merchantRaw,
            merchantCanonical: ocrResult.merchantRaw,
            amountMinor: ocrResult.amountMinor,
            candidateAmountsMinor: ocrResult.candidateAmountsMinor,
            currency: ocrResult.currency,
            ledgerAmountMinor: ocrResult.amountMinor,
            ledgerCurrency: ocrResult.currency,
            reviewStatus: reviewStatus,
            paymentStatus: paymentStatus,
            duplicateStatus: .unique,
            transactionType: .payment,
            amountConfidence: ocrResult.amountConfidence,
            currencyConfidence: 1.0,
            merchantConfidence: ocrResult.merchantConfidence,
            ocrEngineVersion: ocrResult.ocrEngineVersion,
            ocrTemplateVersion: ocrResult.ocrTemplateVersion
        )

        let engine = SharedTransactionEngine.shared
        _ = try await engine.ingestTransaction(transaction)
        try? await ZeroTypingDiskStorage.shared.persistTransaction(transaction)

        let parsedAmount = Double(ocrResult.amountMinor ?? 0) / 100.0
        let parsedMerchant = ocrResult.merchantRaw ?? "Unknown Merchant"
        let entity = ParsedExpenseEntity(
            id: effectiveTxId,
            amount: parsedAmount,
            currency: ocrResult.currency,
            merchant: parsedMerchant,
            paymentMethod: ocrResult.provider.rawValue,
            needsReview: reviewStatus == .needsReview
        )

        if let minor = ocrResult.amountMinor, minor > 0 {
            let major = Double(minor) / 100.0
            return .result(value: entity, dialog: "已由 AI 文字自動入帳 \(ocrResult.currency)$\(String(format: "%.2f", major)) 於 \(parsedMerchant)")
        } else {
            return .result(value: entity, dialog: "AI 文字未辨識到明確金額，已建立待審核交易")
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ZeroTypingAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "在 \(.applicationName) 記一筆",
                "使用 \(.applicationName) 記錄支出",
                "自動記帳 \(.applicationName)"
            ],
            shortTitle: "記錄 Apple Pay 支出",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: ParseAIExpenseIntent(),
            phrases: [
                "在 \(.applicationName) 解析 AI 文字",
                "使用 \(.applicationName) 解析扣款文字",
                "解析 AI 記帳 \(.applicationName)"
            ],
            shortTitle: "解析 AI / 扣款文字",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ProcessPaymentScreenshotIntent(),
            phrases: [
                "在 \(.applicationName) 辨識截圖記帳"
            ],
            shortTitle: "辨識截圖記帳",
            systemImageName: "photo.on.rectangle.angled"
        )
        AppShortcut(
            intent: ParseClipboardExpenseIntent(),
            phrases: [
                "在 \(.applicationName) 解析剪貼簿支出"
            ],
            shortTitle: "解析剪貼簿支出",
            systemImageName: "doc.on.clipboard.fill"
        )
    }
}

/// Global shared actor bridge for AppIntents and SwiftUI Views
public final class SharedTransactionEngine: Sendable {
    public static let shared = TransactionEngine()
}
#else
public final class SharedTransactionEngine: Sendable {
    public static let shared = TransactionEngine()
}
#endif
