import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(Security)
import Security
#endif

/// Codable persistence envelope for ZeroTypingExpense disk storage
public struct AppStorageEnvelope: Codable, Sendable {
    public var version: Int = 1
    public var monthlyBudgetTotalMinor: Int64
    public var categoryBudgets: [String: Int64] // Stringified UUID keys for Codable
    public var categories: [CategoryEntity]
    public var transactions: [TransactionEntity]
    public var refunds: [RefundEntity]
    public var merchantRules: [MerchantRule]

    public init(
        version: Int = 1,
        monthlyBudgetTotalMinor: Int64 = 1_000_000,
        categoryBudgets: [String: Int64] = [:],
        categories: [CategoryEntity] = [],
        transactions: [TransactionEntity] = [],
        refunds: [RefundEntity] = [],
        merchantRules: [MerchantRule] = []
    ) {
        self.version = version
        self.monthlyBudgetTotalMinor = monthlyBudgetTotalMinor
        self.categoryBudgets = categoryBudgets
        self.categories = categories
        self.transactions = transactions
        self.refunds = refunds
        self.merchantRules = merchantRules
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case monthlyBudgetTotalMinor
        case categoryBudgets
        case categories
        case transactions
        case refunds
        case merchantRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        self.monthlyBudgetTotalMinor = (try? container.decodeIfPresent(Int64.self, forKey: .monthlyBudgetTotalMinor)) ?? 1_000_000
        self.categoryBudgets = (try? container.decodeIfPresent([String: Int64].self, forKey: .categoryBudgets)) ?? [:]
        self.categories = (try? container.decodeIfPresent([CategoryEntity].self, forKey: .categories)) ?? []
        self.refunds = (try? container.decodeIfPresent([RefundEntity].self, forKey: .refunds)) ?? []
        self.merchantRules = (try? container.decodeIfPresent([MerchantRule].self, forKey: .merchantRules)) ?? []

        // Resilient array decoding for transactions: If one record is corrupted, do not drop the rest!
        if let directList = try? container.decodeIfPresent([TransactionEntity].self, forKey: .transactions) {
            self.transactions = directList
        } else if var txContainer = try? container.nestedUnkeyedContainer(forKey: .transactions) {
            var recoveredList: [TransactionEntity] = []
            while !txContainer.isAtEnd {
                if let tx = try? txContainer.decode(TransactionEntity.self) {
                    recoveredList.append(tx)
                } else if (try? txContainer.decode(DummyDiscardable.self)) != nil {
                    continue
                } else {
                    break
                }
            }
            self.transactions = recoveredList
        } else {
            self.transactions = []
        }
    }
}

private struct DummyDiscardable: Decodable {}

/// Thread-safe actor for atomic disk persistence in Application Support directory
public actor ZeroTypingDiskStorage {
    public static let shared = ZeroTypingDiskStorage()

    public static var defaultStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath()
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("ZeroTypingStorage.json").resolvingSymlinksInPath()
    }

    public static var backupStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath()
        return appSupport.appendingPathComponent("ZeroTypingStorage.backup.json").resolvingSymlinksInPath()
    }

    public static var documentsStorageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath()
        return docs.appendingPathComponent("ZeroTypingStorage.json").resolvingSymlinksInPath()
    }

    // MARK: - Hardware Keychain Multi-Tier Backup
    public static let defaultKeychainService = "com.zerotyping.expense.storage"
    public static let defaultKeychainAccount = "active_ledger_backup"

    nonisolated public static func saveToKeychain(
        data: Data,
        service: String = defaultKeychainService,
        account: String = defaultKeychainAccount
    ) {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
        #endif
    }

    nonisolated public static func loadFromKeychain(
        service: String = defaultKeychainService,
        account: String = defaultKeychainAccount
    ) -> Data? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        return nil
        #else
        return nil
        #endif
    }

    nonisolated public static func clearKeychain(
        service: String = defaultKeychainService,
        account: String = defaultKeychainAccount
    ) {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }

    private let fileManager = FileManager.default

    public init() {}

    /// Helper to execute an operation while holding a cross-process advisory lock
    private func withFileLock<T>(for url: URL, operation: () throws -> T) throws -> T {
        let lockURL = url.deletingPathExtension().appendingPathExtension("lock")
        let lockPath = lockURL.path
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o666)
        if fd >= 0 {
            flock(fd, LOCK_EX)
            defer {
                flock(fd, LOCK_UN)
                close(fd)
            }
            return try operation()
        } else {
            print("Warning: Failed to acquire advisory lock for \(url.path), proceeding unlocked")
            return try operation()
        }
    }

    /// Load existing envelope from disk or create default envelope
    public func loadEnvelope(
        from url: URL = defaultStorageURL,
        keychainAccount: String = defaultKeychainAccount
    ) throws -> AppStorageEnvelope {
        let normalizedURL = url.resolvingSymlinksInPath()
        let normalizedDefault = Self.defaultStorageURL.resolvingSymlinksInPath()
        let isDefault = (normalizedURL.path == normalizedDefault.path)

        if isDefault {
            let candidateURLs: [URL] = [normalizedURL, Self.backupStorageURL.resolvingSymlinksInPath(), Self.documentsStorageURL.resolvingSymlinksInPath()]
            for candidate in candidateURLs {
                if fileManager.fileExists(atPath: candidate.path) {
                    if let data = try? Data(contentsOf: candidate),
                       let envelope = try? JSONDecoder().decode(AppStorageEnvelope.self, from: data) {
                        return envelope
                    }
                }
            }

            // Keychain Fallback: If disk files are missing or container UUID changed
            if let keychainData = Self.loadFromKeychain(account: keychainAccount),
               let envelope = try? JSONDecoder().decode(AppStorageEnvelope.self, from: keychainData) {
                return envelope
            }

            return AppStorageEnvelope(
                version: 1,
                monthlyBudgetTotalMinor: 1_000_000,
                categoryBudgets: [:],
                categories: AppState.defaultCategories(),
                transactions: [],
                refunds: []
            )
        } else {
            guard fileManager.fileExists(atPath: normalizedURL.path) else {
                // If caller specified an isolated non-default URL with an explicit test keychain account, check keychain
                if keychainAccount != Self.defaultKeychainAccount,
                   let keychainData = Self.loadFromKeychain(account: keychainAccount),
                   let envelope = try? JSONDecoder().decode(AppStorageEnvelope.self, from: keychainData) {
                    return envelope
                }
                return AppStorageEnvelope(
                    version: 1,
                    monthlyBudgetTotalMinor: 1_000_000,
                    categoryBudgets: [:],
                    categories: AppState.defaultCategories(),
                    transactions: [],
                    refunds: []
                )
            }
            let data = try Data(contentsOf: normalizedURL)
            return try JSONDecoder().decode(AppStorageEnvelope.self, from: data)
        }
    }

    /// Atomically write storage envelope to disk
    public func saveEnvelope(_ envelope: AppStorageEnvelope, to url: URL = defaultStorageURL) throws {
        try withFileLock(for: url) {
            let parentDir = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let normalizedURL = url.resolvingSymlinksInPath()
            let normalizedDefault = Self.defaultStorageURL.resolvingSymlinksInPath()

            // Create pre-save snapshot backup
            if normalizedURL.path == normalizedDefault.path, fileManager.fileExists(atPath: normalizedURL.path) {
                let backupURL = Self.backupStorageURL
                try? fileManager.removeItem(at: backupURL)
                try? fileManager.copyItem(at: normalizedURL, to: backupURL)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: normalizedURL, options: .atomic)

            // Mirror to Documents directory and Keychain for preservation across updates & container resets
            if normalizedURL.path == normalizedDefault.path {
                let docsURL = Self.documentsStorageURL
                try? data.write(to: docsURL, options: .atomic)
                Self.saveToKeychain(data: data)
            }
        }
    }

    /// Persist a single transaction safely into ZeroTypingStorage.json
    public func persistTransaction(_ transaction: TransactionEntity, to url: URL = defaultStorageURL) throws {
        // Defensive check: Zero or negative amounts must not be persisted into storage
        if let minor = transaction.amountMinor, minor <= 0 {
            return
        }
        try withFileLock(for: url) {
            var envelope: AppStorageEnvelope
            let normalizedURL = url.resolvingSymlinksInPath()
            let normalizedDefault = Self.defaultStorageURL.resolvingSymlinksInPath()

            if fileManager.fileExists(atPath: normalizedURL.path) {
                envelope = try loadEnvelope(from: normalizedURL)
            } else {
                envelope = AppStorageEnvelope(
                    version: 1,
                    monthlyBudgetTotalMinor: 1_000_000,
                    categoryBudgets: [:],
                    categories: AppState.defaultCategories(),
                    transactions: [],
                    refunds: []
                )
            }

            if let existingIdx = envelope.transactions.firstIndex(where: { $0.id == transaction.id || $0.idempotencyKey == transaction.idempotencyKey }) {
                envelope.transactions[existingIdx] = transaction
            } else {
                envelope.transactions.insert(transaction, at: 0)
            }

            let parentDir = normalizedURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // Create pre-save backup
            if normalizedURL.path == normalizedDefault.path, fileManager.fileExists(atPath: normalizedURL.path) {
                let backupURL = Self.backupStorageURL
                try? fileManager.removeItem(at: backupURL)
                try? fileManager.copyItem(at: normalizedURL, to: backupURL)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: normalizedURL, options: .atomic)

            // Mirror to Documents and Keychain
            if normalizedURL.path == normalizedDefault.path {
                let docsURL = Self.documentsStorageURL
                try? data.write(to: docsURL, options: .atomic)
                Self.saveToKeychain(data: data)
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AppState.didIngestTransactionNotification, object: nil)
            }
        }
    }
}
