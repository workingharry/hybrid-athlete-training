import Foundation
import CryptoKit

/// Backup format container conforming to schema version 1.3
public struct BackupPayload: Codable, Sendable {
    public static let currentSchemaVersion: Int = 1
    public static let currentFormatVersion: String = "1.3"

    public let schemaVersion: Int
    public let formatVersion: String
    public let exportedAt: Date
    public let transactions: [TransactionEntity]
    public let categories: [CategoryEntity]
    public let merchantRules: [MerchantRule]
    public let checksum: String

    public init(
        schemaVersion: Int = currentSchemaVersion,
        formatVersion: String = currentFormatVersion,
        exportedAt: Date = Date(),
        transactions: [TransactionEntity],
        categories: [CategoryEntity],
        merchantRules: [MerchantRule],
        checksum: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.transactions = transactions
        self.categories = categories
        self.merchantRules = merchantRules
        self.checksum = checksum
    }
}

/// Restore mode: merge new non-colliding items or overwrite existing records
public enum RestoreMode: Sendable {
    case merge
    case overwrite
}

/// Statistics outcome of restore operation
public struct RestoreResult: Sendable, Equatable {
    public let importedTransactionsCount: Int
    public let skippedDuplicatesCount: Int
    public let importedCategoriesCount: Int
    public let importedRulesCount: Int
}

/// Backup, Export, and Restore Engine
/// Adheres strictly to requirements:
/// 1. CSV export in RFC 4180 format with UTF-8 BOM (`\u{FEFF}`) for Microsoft Excel compatibility.
/// 2. Versioned JSON export with SHA-256 payload checksum validation.
/// 3. Forward version rejection (rejects backups newer than current schema).
/// 4. Deduplication by `idempotencyKey` and `id`.
public actor BackupExportService {
    public init() {}

    // MARK: - CSV Export (RFC 4180 + UTF-8 BOM)

    /// Generates RFC 4180 compliant CSV formatted with UTF-8 BOM
    public func exportTransactionsCSV(
        transactions: [TransactionEntity],
        categories: [UUID: CategoryEntity] = [:]
    ) -> String {
        var csv = "\u{FEFF}" // UTF-8 BOM

        // Header columns
        let headers = [
            "ID",
            "日期",
            "時間",
            "商戶",
            "分類",
            "原始金額",
            "原始貨幣",
            "記帳金額",
            "記帳貨幣",
            "支付方式",
            "擷取管道",
            "審核狀態",
            "支付狀態",
            "重複狀態"
        ]
        csv.append(headers.map { escapeCSVField($0) }.joined(separator: ",") + "\r\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        for tx in transactions {
            let txDate = tx.transactionDate ?? tx.capturedAt
            let dateStr = dateFormatter.string(from: txDate)
            let timeStr = timeFormatter.string(from: txDate)
            let merchantStr = tx.merchantCanonical ?? tx.merchantRaw ?? "未知商戶"

            let categoryName: String
            if let catId = tx.categoryId, let cat = categories[catId] {
                categoryName = cat.name
            } else {
                categoryName = "未分類"
            }

            let rawAmount: String
            if let minor = tx.amountMinor {
                rawAmount = String(format: "%.2f", Double(minor) / 100.0)
            } else {
                rawAmount = "0.00"
            }

            let ledgerAmount: String
            if let minor = tx.ledgerAmountMinor {
                ledgerAmount = String(format: "%.2f", Double(minor) / 100.0)
            } else {
                ledgerAmount = "0.00"
            }

            let row = [
                tx.id.uuidString,
                dateStr,
                timeStr,
                merchantStr,
                categoryName,
                rawAmount,
                tx.currency ?? "HKD",
                ledgerAmount,
                tx.ledgerCurrency ?? "HKD",
                tx.provider.rawValue,
                tx.captureChannel.rawValue,
                tx.reviewStatus.rawValue,
                tx.paymentStatus.rawValue,
                tx.duplicateStatus.rawValue
            ]

            csv.append(row.map { escapeCSVField($0) }.joined(separator: ",") + "\r\n")
        }

        return csv
    }

    private func escapeCSVField(_ field: String) -> String {
        var sanitized = field
        let formulaPrefixes: [Character] = ["=", "+", "-", "@", "\t", "\r"]
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)

        // OWASP CSV Injection Defense: Prepend single quote if field starts with formula trigger
        var needsQuotes = false
        if let firstChar = trimmed.first, formulaPrefixes.contains(firstChar) {
            sanitized = "'" + sanitized
            needsQuotes = true
        }

        if needsQuotes || sanitized.contains(",") || sanitized.contains("\"") || sanitized.contains("\n") || sanitized.contains("\r") {
            let escaped = sanitized.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return sanitized
    }

    // MARK: - JSON Versioned Backup

    /// Creates a complete JSON backup with SHA-256 checksum
    public func createBackup(
        transactions: [TransactionEntity],
        categories: [CategoryEntity],
        merchantRules: [MerchantRule]
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Temporary payload without checksum for hash calculation
        let partialPayload = BackupPayload(
            schemaVersion: BackupPayload.currentSchemaVersion,
            formatVersion: BackupPayload.currentFormatVersion,
            exportedAt: Date(),
            transactions: transactions,
            categories: categories,
            merchantRules: merchantRules,
            checksum: ""
        )

        let partialData = try encoder.encode(partialPayload)
        let hash = SHA256.hash(data: partialData)
        let checksumString = hash.compactMap { String(format: "%02x", $0) }.joined()

        let fullPayload = BackupPayload(
            schemaVersion: partialPayload.schemaVersion,
            formatVersion: partialPayload.formatVersion,
            exportedAt: partialPayload.exportedAt,
            transactions: transactions,
            categories: categories,
            merchantRules: merchantRules,
            checksum: checksumString
        )

        return try encoder.encode(fullPayload)
    }

    // MARK: - Restore Engine

    /// Validates and restores backup data
    /// Rejects forward schema versions safely and deduplicates transactions
    public func restoreBackup(
        data: Data,
        existingTransactions: [TransactionEntity],
        existingCategories: [CategoryEntity],
        existingRules: [MerchantRule],
        mode: RestoreMode
    ) throws -> (payload: BackupPayload, result: RestoreResult) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw RestoreError.invalidJSON(error.localizedDescription)
        }

        // Forward version safety gate (§8.6)
        guard payload.schemaVersion >= 1 else {
            throw RestoreError.invalidJSON("Invalid schema version: \(payload.schemaVersion)")
        }

        if payload.schemaVersion > BackupPayload.currentSchemaVersion {
            throw RestoreError.unsupportedForwardSchema(
                backupVersion: payload.schemaVersion,
                currentVersion: BackupPayload.currentSchemaVersion
            )
        }

        // Validate checksum format: Must be 64-character hexadecimal
        let hexPattern = "^[0-9a-fA-F]{64}$"
        guard payload.checksum.range(of: hexPattern, options: .regularExpression) != nil else {
            throw RestoreError.checksumMismatch
        }

        // Verify SHA-256 Checksum
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let partialPayload = BackupPayload(
            schemaVersion: payload.schemaVersion,
            formatVersion: payload.formatVersion,
            exportedAt: payload.exportedAt,
            transactions: payload.transactions,
            categories: payload.categories,
            merchantRules: payload.merchantRules,
            checksum: ""
        )

        let partialData = try encoder.encode(partialPayload)
        let calculatedHash = SHA256.hash(data: partialData)
        let calculatedChecksum = calculatedHash.compactMap { String(format: "%02x", $0) }.joined()

        if payload.checksum != calculatedChecksum {
            throw RestoreError.checksumMismatch
        }

        // Deduplication & Merging logic
        var importedTxCount = 0
        var skippedDuplicatesCount = 0

        switch mode {
        case .overwrite:
            importedTxCount = payload.transactions.count
            skippedDuplicatesCount = 0

        case .merge:
            let existingTxIds = Set(existingTransactions.map { $0.id })
            let existingIdempotencyKeys = Set(existingTransactions.map { $0.idempotencyKey })

            for tx in payload.transactions {
                if existingTxIds.contains(tx.id) || existingIdempotencyKeys.contains(tx.idempotencyKey) {
                    skippedDuplicatesCount += 1
                } else {
                    importedTxCount += 1
                }
            }
        }

        let result = RestoreResult(
            importedTransactionsCount: importedTxCount,
            skippedDuplicatesCount: skippedDuplicatesCount,
            importedCategoriesCount: payload.categories.count,
            importedRulesCount: payload.merchantRules.count
        )

        return (payload, result)
    }

    public enum RestoreError: LocalizedError, Sendable, Equatable {
        case invalidJSON(String)
        case unsupportedForwardSchema(backupVersion: Int, currentVersion: Int)
        case checksumMismatch

        public var errorDescription: String? {
            switch self {
            case .invalidJSON(let details):
                return "無效的備份檔案格式: \(details)"
            case .unsupportedForwardSchema(let backupVersion, let currentVersion):
                return "此備份來自較新版本 (Schema v\(backupVersion))，目前 App 支援至 Schema v\(currentVersion)，請更新 App 後再還原。"
            case .checksumMismatch:
                return "備份資料完整性檢查失敗 (SHA-256 Checksum 不符)，檔案可能已損毀或遭到篡改。"
            }
        }
    }
}
