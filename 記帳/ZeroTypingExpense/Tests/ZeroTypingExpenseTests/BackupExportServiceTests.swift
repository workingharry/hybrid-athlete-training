import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Backup, CSV Export & Restore Engine Tests")
struct BackupExportServiceTests {
    let backupService = BackupExportService()

    @Test("CSV Export: Adheres to RFC 4180 with UTF-8 BOM")
    func testCSVExportFormattingAndBOM() async {
        let fixedDate = Date(timeIntervalSince1970: 1730000000)
        let catId = UUID()
        let cat = CategoryEntity(id: catId, name: "餐飲美食")

        let tx = TransactionEntity(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            idempotencyKey: "test_csv_1",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Café de Coral, 大家樂", // Needs quotes escaping due to comma
            amountMinor: 6250,
            currency: "HKD",
            ledgerAmountMinor: 6250,
            ledgerCurrency: "HKD",
            categoryId: catId,
            transactionDate: fixedDate,
            reviewStatus: .confirmed,
            paymentStatus: .completed,
            duplicateStatus: .unique
        )

        let csv = await backupService.exportTransactionsCSV(
            transactions: [tx],
            categories: [catId: cat]
        )

        // 1. Must start with UTF-8 BOM
        #expect(csv.hasPrefix("\u{FEFF}"))

        // 2. Contains RFC 4180 escaped commas
        #expect(csv.contains("\"Café de Coral, 大家樂\""))

        // 3. Contains formatted amounts
        #expect(csv.contains("62.50"))

        // 4. Contains category name
        #expect(csv.contains("餐飲美食"))

        // 5. Line endings must be CRLF
        #expect(csv.contains("\r\n"))
    }

    @Test("JSON Backup: Checksum generation and validation")
    func testJSONBackupIntegrityChecksum() async throws {
        let tx = TransactionEntity(
            idempotencyKey: "test_json_1",
            provider: .alipayChina,
            captureChannel: .backTap,
            merchantRaw: "喜茶 HEYTEA",
            amountMinor: 2800,
            currency: "CNY"
        )

        let catId = UUID()
        let cat = CategoryEntity(id: catId, name: "茶飲")
        let rule = MerchantRule(
            canonicalName: "喜茶 HEYTEA",
            aliases: ["喜茶"],
            defaultCategoryId: catId
        )

        let backupData = try await backupService.createBackup(
            transactions: [tx],
            categories: [cat],
            merchantRules: [rule]
        )

        #expect(!backupData.isEmpty)

        // Restore in merge mode
        let (payload, result) = try await backupService.restoreBackup(
            data: backupData,
            existingTransactions: [],
            existingCategories: [],
            existingRules: [],
            mode: .merge
        )

        #expect(payload.schemaVersion == 1)
        #expect(payload.formatVersion == "1.3")
        #expect(!payload.checksum.isEmpty)
        #expect(result.importedTransactionsCount == 1)
        #expect(result.skippedDuplicatesCount == 0)
        #expect(result.importedCategoriesCount == 1)
        #expect(result.importedRulesCount == 1)
    }

    @Test("Forward Version Rejection: Refuses newer schema safely")
    func testForwardSchemaRejection() async throws {
        // Construct mock backup payload with schemaVersion = 999
        let forwardPayload = BackupPayload(
            schemaVersion: 999, // Future schema version!
            formatVersion: "99.0",
            exportedAt: Date(),
            transactions: [],
            categories: [],
            merchantRules: [],
            checksum: "mock_hash"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let forwardData = try encoder.encode(forwardPayload)

        do {
            _ = try await backupService.restoreBackup(
                data: forwardData,
                existingTransactions: [],
                existingCategories: [],
                existingRules: [],
                mode: .merge
            )
            #expect(Bool(false), "Should have rejected forward schema version")
        } catch let error as BackupExportService.RestoreError {
            switch error {
            case .unsupportedForwardSchema(let bVer, let cVer):
                #expect(bVer == 999)
                #expect(cVer == 1)
            default:
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        }
    }

    @Test("Tampered Checksum Rejection: Detects corrupted or modified backup data")
    func testTamperedChecksumRejection() async throws {
        let tx = TransactionEntity(
            idempotencyKey: "test_tx",
            provider: .applePay,
            captureChannel: .walletAutomation,
            amountMinor: 1000
        )

        let backupData = try await backupService.createBackup(
            transactions: [tx],
            categories: [],
            merchantRules: []
        )

        // Tamper with checksum in JSON string
        var jsonString = String(data: backupData, encoding: .utf8)!
        jsonString = jsonString.replacingOccurrences(of: "\"checksum\" : \"", with: "\"checksum\" : \"corrupted_")
        let tamperedData = jsonString.data(using: .utf8)!

        do {
            _ = try await backupService.restoreBackup(
                data: tamperedData,
                existingTransactions: [],
                existingCategories: [],
                existingRules: [],
                mode: .merge
            )
            #expect(Bool(false), "Should have rejected checksum mismatch")
        } catch let error as BackupExportService.RestoreError {
            switch error {
            case .checksumMismatch:
                #expect(error == .checksumMismatch)
            default:
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        }
    }

    @Test("Deduplication on Restore: IdempotencyKey collision skips duplicate")
    func testDeduplicationOnRestore() async throws {
        let txId = UUID()
        let tx = TransactionEntity(
            id: txId,
            idempotencyKey: "unique_key_001",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "MTR",
            amountMinor: 1200
        )

        let backupData = try await backupService.createBackup(
            transactions: [tx],
            categories: [],
            merchantRules: []
        )

        // Restore when existingTransactions already contains a transaction with the same idempotencyKey
        let existingTx = TransactionEntity(
            idempotencyKey: "unique_key_001",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "MTR",
            amountMinor: 1200
        )

        let (_, result) = try await backupService.restoreBackup(
            data: backupData,
            existingTransactions: [existingTx],
            existingCategories: [],
            existingRules: [],
            mode: .merge
        )

        #expect(result.importedTransactionsCount == 0)
        #expect(result.skippedDuplicatesCount == 1)
    }

    @Test("CSV Injection Defense: Formula prefixes are safely escaped with single quote")
    func testCSVFormulaInjectionEscaping() async {
        let maliciousTx = TransactionEntity(
            idempotencyKey: "malicious_cmd",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "=SUM(A1:A10)",
            amountMinor: 5000
        )

        let csv = await backupService.exportTransactionsCSV(transactions: [maliciousTx])
        #expect(csv.contains("\"'=SUM(A1:A10)\""))
    }

    @Test("Invalid Schema Version: Rejects version < 1")
    func testInvalidSchemaVersionRejection() async throws {
        let payload = BackupPayload(
            schemaVersion: 0,
            formatVersion: "1.3",
            exportedAt: Date(),
            transactions: [],
            categories: [],
            merchantRules: [],
            checksum: String(repeating: "a", count: 64)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        await #expect(throws: BackupExportService.RestoreError.self) {
            try await backupService.restoreBackup(
                data: data,
                existingTransactions: [],
                existingCategories: [],
                existingRules: [],
                mode: .merge
            )
        }
    }
}
