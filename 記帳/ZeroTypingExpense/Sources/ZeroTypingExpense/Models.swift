import Foundation

public enum PaymentProvider: String, Codable, Sendable, CaseIterable {
    case applePay
    case appleStoreSubscription = "apple_store_subscription"
    case alipayHK
    case alipayChina
    case payMe
    case octopus
    case other
}

public enum CaptureChannel: String, Codable, Sendable, CaseIterable {
    case walletAutomation = "walletAutomation"
    case onlineApplePay = "online_apple_pay"
    case shortcut = "shortcut"
    case backTap = "back_tap"
    case actionButton = "action_button"
    case controlCenter = "control_center"
    case clipboardParse = "clipboard_parse"
    case urlScheme = "url_scheme"
    case appleIntelligence = "apple_intelligence"
    case shareSheet = "shareSheet"
    case photoPicker = "photoPicker"
    case manualImport = "manualImport"
}

public enum IngestionSource: String, Codable, Sendable, CaseIterable {
    case walletShortcut = "walletShortcut"
    case notificationOCR = "notificationOCR"
    case clipboard = "clipboard"
    case manual = "manual"
}

public enum NotificationIntent: String, Codable, Sendable, CaseIterable {
    case confirmedExpenditure       // Actual completed purchase/deduction
    case refundOrReversal           // Money returned to user
    case topUpOrInternalTransfer    // Octopus AAVS/reload, FPS to self, card bill payment
    case loanOrPromoOffer           // Loans, installment ads, cashback targets, coupons
    case balanceInquiryOnly         // Balance update without a spend amount
    case otpOrAuthAttempt           // 3DS OTP / incomplete auth
}

public enum ReviewStatus: String, Codable, Sendable, CaseIterable {
    case confirmed
    case needsCategory
    case needsReview
}

public enum PaymentStatus: String, Codable, Sendable, CaseIterable {
    case unknown
    case pending
    case completed
    case cancelled
    case partiallyRefunded
    case refunded
}

public enum DuplicateStatus: String, Codable, Sendable, CaseIterable {
    case unique
    case possibleDuplicate
    case confirmedDuplicate
}

public enum TransactionType: String, Codable, Sendable, CaseIterable {
    case payment
    case transfer
    case topUp
    case refund
    case fee
    case adjustment
    case unknown
}

public enum ArtifactOrigin: String, Codable, Sendable, CaseIterable {
    case shortcutTemp
    case photoLibrary
    case shareSheetImport
    case pickerImport
}

public enum OCRStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case succeeded
    case failed
}

public enum CleanupStatus: String, Codable, Sendable, CaseIterable {
    case notEligible
    case eligible
    case pendingUserReview
    case deleteRequested
    case deleted
    case deleteFailed
    case keptByUser
}

public enum SourceSetupStatus: String, Codable, Sendable, CaseIterable {
    case notSetUp
    case pendingVerification
    case active
    case noRecentActivity
    case captureError
    case needsReverification
}

public enum RefundKind: String, Codable, Sendable, CaseIterable {
    case full
    case partial
    case reversal
}

public struct CategoryEntity: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var isDefault: Bool
    public var isHidden: Bool
    public var mergedIntoId: UUID?

    public init(id: UUID = UUID(), name: String, isDefault: Bool = false, isHidden: Bool = false, mergedIntoId: UUID? = nil) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isHidden = isHidden
        self.mergedIntoId = mergedIntoId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isDefault
        case isHidden
        case mergedIntoId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "未命名"
        self.isDefault = (try? container.decodeIfPresent(Bool.self, forKey: .isDefault)) ?? false
        self.isHidden = (try? container.decodeIfPresent(Bool.self, forKey: .isHidden)) ?? false
        self.mergedIntoId = try? container.decodeIfPresent(UUID.self, forKey: .mergedIntoId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(mergedIntoId, forKey: .mergedIntoId)
    }
}

public struct RefundEntity: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var originalTransactionId: UUID
    public var refundTransactionId: UUID?
    public var amountMinor: Int64
    public var currency: String
    public var kind: RefundKind
    public var occurredAt: Date

    public init(
        id: UUID = UUID(),
        originalTransactionId: UUID,
        refundTransactionId: UUID? = nil,
        amountMinor: Int64,
        currency: String,
        kind: RefundKind,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.originalTransactionId = originalTransactionId
        self.refundTransactionId = refundTransactionId
        self.amountMinor = amountMinor
        self.currency = currency
        self.kind = kind
        self.occurredAt = occurredAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case originalTransactionId
        case refundTransactionId
        case amountMinor
        case currency
        case kind
        case occurredAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.originalTransactionId = (try? container.decodeIfPresent(UUID.self, forKey: .originalTransactionId)) ?? UUID()
        self.refundTransactionId = try? container.decodeIfPresent(UUID.self, forKey: .refundTransactionId)
        self.amountMinor = (try? container.decodeIfPresent(Int64.self, forKey: .amountMinor)) ?? 0
        self.currency = (try? container.decodeIfPresent(String.self, forKey: .currency)) ?? "HKD"
        if let rawKind = try? container.decodeIfPresent(String.self, forKey: .kind) {
            self.kind = RefundKind(rawValue: rawKind) ?? .full
        } else {
            self.kind = .full
        }
        self.occurredAt = (try? container.decodeIfPresent(Date.self, forKey: .occurredAt)) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(originalTransactionId, forKey: .originalTransactionId)
        try container.encodeIfPresent(refundTransactionId, forKey: .refundTransactionId)
        try container.encode(amountMinor, forKey: .amountMinor)
        try container.encode(currency, forKey: .currency)
        try container.encode(kind, forKey: .kind)
        try container.encode(occurredAt, forKey: .occurredAt)
    }
}

public struct SourceArtifactEntity: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var transactionId: UUID?
    public var origin: ArtifactOrigin
    public var photoAssetLocalIdentifier: String?
    public var temporaryFilePath: String?
    public var importedAt: Date
    public var ocrStatus: OCRStatus
    public var cleanupStatus: CleanupStatus

    public init(
        id: UUID = UUID(),
        transactionId: UUID? = nil,
        origin: ArtifactOrigin,
        photoAssetLocalIdentifier: String? = nil,
        temporaryFilePath: String? = nil,
        importedAt: Date = Date(),
        ocrStatus: OCRStatus = .pending,
        cleanupStatus: CleanupStatus = .notEligible
    ) {
        self.id = id
        self.transactionId = transactionId
        self.origin = origin
        self.photoAssetLocalIdentifier = photoAssetLocalIdentifier
        self.temporaryFilePath = temporaryFilePath
        self.importedAt = importedAt
        self.ocrStatus = ocrStatus
        self.cleanupStatus = cleanupStatus
    }
}

public enum DeviceSource: String, Codable, Sendable, CaseIterable {
    case iPhone
    case appleWatch
    case unknown
}

public struct TransactionEntity: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var idempotencyKey: String
    public var provider: PaymentProvider
    public var captureChannel: CaptureChannel
    public var deviceSource: DeviceSource
    public var sourceTransactionId: String?
    public var merchantRaw: String?
    public var merchantCanonical: String?
    public var amountMinor: Int64?
    public var currency: String?
    public var ledgerAmountMinor: Int64?
    public var ledgerCurrency: String?
    public var exchangeRate: Decimal?
    public var exchangeRateDate: Date?
    public var exchangeRateSource: String?
    public var categoryId: UUID?
    public var transactionDate: Date?
    public var transactionTimeZone: String?
    public var capturedAt: Date
    public var reviewStatus: ReviewStatus
    public var paymentStatus: PaymentStatus
    public var duplicateStatus: DuplicateStatus
    public var transactionType: TransactionType
    public var amountConfidence: Float?
    public var currencyConfidence: Float?
    public var merchantConfidence: Float?
    public var categoryConfidence: Float?
    public var transactionTypeConfidence: Float?
    public var ocrEngineVersion: String?
    public var ocrTemplateVersion: String?
    public var candidateAmountsMinor: [Int64]
    public var isHidden: Bool
    public var ingestionSource: IngestionSource
    public var remainingBalanceMinor: Int64?
    public var isHoldCandidate: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        idempotencyKey: String,
        provider: PaymentProvider,
        captureChannel: CaptureChannel,
        deviceSource: DeviceSource = .iPhone,
        ingestionSource: IngestionSource = .manual,
        sourceTransactionId: String? = nil,
        merchantRaw: String? = nil,
        merchantCanonical: String? = nil,
        amountMinor: Int64? = nil,
        remainingBalanceMinor: Int64? = nil,
        isHoldCandidate: Bool = false,
        candidateAmountsMinor: [Int64] = [],
        currency: String? = nil,
        ledgerAmountMinor: Int64? = nil,
        ledgerCurrency: String? = nil,
        exchangeRate: Decimal? = nil,
        exchangeRateDate: Date? = nil,
        exchangeRateSource: String? = nil,
        categoryId: UUID? = nil,
        transactionDate: Date? = nil,
        transactionTimeZone: String? = nil,
        capturedAt: Date = Date(),
        reviewStatus: ReviewStatus = .needsReview,
        paymentStatus: PaymentStatus = .unknown,
        duplicateStatus: DuplicateStatus = .unique,
        transactionType: TransactionType = .payment,
        amountConfidence: Float? = nil,
        currencyConfidence: Float? = nil,
        merchantConfidence: Float? = nil,
        categoryConfidence: Float? = nil,
        transactionTypeConfidence: Float? = nil,
        ocrEngineVersion: String? = nil,
        ocrTemplateVersion: String? = nil,
        isHidden: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.provider = provider
        self.captureChannel = captureChannel
        self.deviceSource = deviceSource
        self.ingestionSource = ingestionSource
        self.sourceTransactionId = sourceTransactionId
        self.merchantRaw = merchantRaw
        self.merchantCanonical = merchantCanonical
        self.amountMinor = amountMinor
        self.remainingBalanceMinor = remainingBalanceMinor
        self.isHoldCandidate = isHoldCandidate
        self.candidateAmountsMinor = candidateAmountsMinor
        self.currency = currency
        self.ledgerAmountMinor = ledgerAmountMinor
        self.ledgerCurrency = ledgerCurrency
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.exchangeRateSource = exchangeRateSource
        self.categoryId = categoryId
        self.transactionDate = transactionDate
        self.transactionTimeZone = transactionTimeZone
        self.capturedAt = capturedAt
        self.reviewStatus = reviewStatus
        self.paymentStatus = paymentStatus
        self.duplicateStatus = duplicateStatus
        self.transactionType = transactionType
        self.amountConfidence = amountConfidence
        self.currencyConfidence = currencyConfidence
        self.merchantConfidence = merchantConfidence
        self.categoryConfidence = categoryConfidence
        self.transactionTypeConfidence = transactionTypeConfidence
        self.ocrEngineVersion = ocrEngineVersion
        self.ocrTemplateVersion = ocrTemplateVersion
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case idempotencyKey
        case provider
        case captureChannel
        case deviceSource
        case sourceTransactionId
        case merchantRaw
        case merchantCanonical
        case amountMinor
        case currency
        case ledgerAmountMinor
        case ledgerCurrency
        case exchangeRate
        case exchangeRateDate
        case exchangeRateSource
        case categoryId
        case transactionDate
        case transactionTimeZone
        case capturedAt
        case reviewStatus
        case paymentStatus
        case duplicateStatus
        case transactionType
        case amountConfidence
        case currencyConfidence
        case merchantConfidence
        case categoryConfidence
        case transactionTypeConfidence
        case ocrEngineVersion
        case ocrTemplateVersion
        case candidateAmountsMinor
        case isHidden
        case ingestionSource
        case remainingBalanceMinor
        case isHoldCandidate
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 1. Identifiers & core identity
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.idempotencyKey = (try? container.decodeIfPresent(String.self, forKey: .idempotencyKey)) ?? self.id.uuidString

        // 2. Resilient enum decodings (safe against missing keys or newly introduced cases)
        if let rawProvider = try? container.decodeIfPresent(String.self, forKey: .provider) {
            self.provider = PaymentProvider(rawValue: rawProvider) ?? .other
        } else {
            self.provider = .other
        }

        if let rawChannel = try? container.decodeIfPresent(String.self, forKey: .captureChannel) {
            self.captureChannel = CaptureChannel(rawValue: rawChannel) ?? .walletAutomation
        } else {
            self.captureChannel = .walletAutomation
        }

        if let rawDevice = try? container.decodeIfPresent(String.self, forKey: .deviceSource) {
            self.deviceSource = DeviceSource(rawValue: rawDevice) ?? .iPhone
        } else {
            self.deviceSource = .iPhone
        }

        if let rawIngestion = try? container.decodeIfPresent(String.self, forKey: .ingestionSource) {
            self.ingestionSource = IngestionSource(rawValue: rawIngestion) ?? .manual
        } else {
            self.ingestionSource = .manual
        }

        if let rawReview = try? container.decodeIfPresent(String.self, forKey: .reviewStatus) {
            self.reviewStatus = ReviewStatus(rawValue: rawReview) ?? .needsReview
        } else {
            self.reviewStatus = .needsReview
        }

        if let rawPayment = try? container.decodeIfPresent(String.self, forKey: .paymentStatus) {
            self.paymentStatus = PaymentStatus(rawValue: rawPayment) ?? .unknown
        } else {
            self.paymentStatus = .unknown
        }

        if let rawDup = try? container.decodeIfPresent(String.self, forKey: .duplicateStatus) {
            self.duplicateStatus = DuplicateStatus(rawValue: rawDup) ?? .unique
        } else {
            self.duplicateStatus = .unique
        }

        if let rawTxType = try? container.decodeIfPresent(String.self, forKey: .transactionType) {
            self.transactionType = TransactionType(rawValue: rawTxType) ?? .payment
        } else {
            self.transactionType = .payment
        }

        // 3. String & Numeric metadata
        self.sourceTransactionId = try? container.decodeIfPresent(String.self, forKey: .sourceTransactionId)
        self.merchantRaw = try? container.decodeIfPresent(String.self, forKey: .merchantRaw)
        self.merchantCanonical = try? container.decodeIfPresent(String.self, forKey: .merchantCanonical)
        self.amountMinor = try? container.decodeIfPresent(Int64.self, forKey: .amountMinor)
        self.remainingBalanceMinor = try? container.decodeIfPresent(Int64.self, forKey: .remainingBalanceMinor)
        self.isHoldCandidate = (try? container.decodeIfPresent(Bool.self, forKey: .isHoldCandidate)) ?? false
        self.candidateAmountsMinor = (try? container.decodeIfPresent([Int64].self, forKey: .candidateAmountsMinor)) ?? []
        self.currency = try? container.decodeIfPresent(String.self, forKey: .currency)
        self.ledgerAmountMinor = try? container.decodeIfPresent(Int64.self, forKey: .ledgerAmountMinor)
        self.ledgerCurrency = try? container.decodeIfPresent(String.self, forKey: .ledgerCurrency)
        self.exchangeRate = try? container.decodeIfPresent(Decimal.self, forKey: .exchangeRate)
        self.exchangeRateDate = try? container.decodeIfPresent(Date.self, forKey: .exchangeRateDate)
        self.exchangeRateSource = try? container.decodeIfPresent(String.self, forKey: .exchangeRateSource)
        self.categoryId = try? container.decodeIfPresent(UUID.self, forKey: .categoryId)
        self.transactionDate = try? container.decodeIfPresent(Date.self, forKey: .transactionDate)
        self.transactionTimeZone = try? container.decodeIfPresent(String.self, forKey: .transactionTimeZone)

        // 4. Dates
        let fallbackDate = Date()
        self.capturedAt = (try? container.decodeIfPresent(Date.self, forKey: .capturedAt)) ?? fallbackDate
        self.createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? self.capturedAt
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? self.createdAt

        // 5. Confidence & OCR info
        self.amountConfidence = try? container.decodeIfPresent(Float.self, forKey: .amountConfidence)
        self.currencyConfidence = try? container.decodeIfPresent(Float.self, forKey: .currencyConfidence)
        self.merchantConfidence = try? container.decodeIfPresent(Float.self, forKey: .merchantConfidence)
        self.categoryConfidence = try? container.decodeIfPresent(Float.self, forKey: .categoryConfidence)
        self.transactionTypeConfidence = try? container.decodeIfPresent(Float.self, forKey: .transactionTypeConfidence)
        self.ocrEngineVersion = try? container.decodeIfPresent(String.self, forKey: .ocrEngineVersion)
        self.ocrTemplateVersion = try? container.decodeIfPresent(String.self, forKey: .ocrTemplateVersion)
        self.isHidden = (try? container.decodeIfPresent(Bool.self, forKey: .isHidden)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(provider, forKey: .provider)
        try container.encode(captureChannel, forKey: .captureChannel)
        try container.encode(deviceSource, forKey: .deviceSource)
        try container.encode(ingestionSource, forKey: .ingestionSource)
        try container.encodeIfPresent(sourceTransactionId, forKey: .sourceTransactionId)
        try container.encodeIfPresent(merchantRaw, forKey: .merchantRaw)
        try container.encodeIfPresent(merchantCanonical, forKey: .merchantCanonical)
        try container.encodeIfPresent(amountMinor, forKey: .amountMinor)
        try container.encodeIfPresent(remainingBalanceMinor, forKey: .remainingBalanceMinor)
        try container.encode(isHoldCandidate, forKey: .isHoldCandidate)
        try container.encode(candidateAmountsMinor, forKey: .candidateAmountsMinor)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encodeIfPresent(ledgerAmountMinor, forKey: .ledgerAmountMinor)
        try container.encodeIfPresent(ledgerCurrency, forKey: .ledgerCurrency)
        try container.encodeIfPresent(exchangeRate, forKey: .exchangeRate)
        try container.encodeIfPresent(exchangeRateDate, forKey: .exchangeRateDate)
        try container.encodeIfPresent(exchangeRateSource, forKey: .exchangeRateSource)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(transactionDate, forKey: .transactionDate)
        try container.encodeIfPresent(transactionTimeZone, forKey: .transactionTimeZone)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encode(reviewStatus, forKey: .reviewStatus)
        try container.encode(paymentStatus, forKey: .paymentStatus)
        try container.encode(duplicateStatus, forKey: .duplicateStatus)
        try container.encode(transactionType, forKey: .transactionType)
        try container.encodeIfPresent(amountConfidence, forKey: .amountConfidence)
        try container.encodeIfPresent(currencyConfidence, forKey: .currencyConfidence)
        try container.encodeIfPresent(merchantConfidence, forKey: .merchantConfidence)
        try container.encodeIfPresent(categoryConfidence, forKey: .categoryConfidence)
        try container.encodeIfPresent(transactionTypeConfidence, forKey: .transactionTypeConfidence)
        try container.encodeIfPresent(ocrEngineVersion, forKey: .ocrEngineVersion)
        try container.encodeIfPresent(ocrTemplateVersion, forKey: .ocrTemplateVersion)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
