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
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        idempotencyKey: String,
        provider: PaymentProvider,
        captureChannel: CaptureChannel,
        deviceSource: DeviceSource = .iPhone,
        sourceTransactionId: String? = nil,
        merchantRaw: String? = nil,
        merchantCanonical: String? = nil,
        amountMinor: Int64? = nil,
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
        self.sourceTransactionId = sourceTransactionId
        self.merchantRaw = merchantRaw
        self.merchantCanonical = merchantCanonical
        self.amountMinor = amountMinor
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
}
