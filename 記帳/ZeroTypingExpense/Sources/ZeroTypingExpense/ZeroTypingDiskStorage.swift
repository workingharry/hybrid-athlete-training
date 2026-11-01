import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Codable persistence envelope for ZeroTypingExpense disk storage
public struct AppStorageEnvelope: Codable, Sendable {
    public var version: Int = 1
    public var monthlyBudgetTotalMinor: Int64
    public var categoryBudgets: [String: Int64] // Stringified UUID keys for Codable
    public var categories: [CategoryEntity]
    public var transactions: [TransactionEntity]
    public var refunds: [RefundEntity]

    public init(
        version: Int = 1,
        monthlyBudgetTotalMinor: Int64 = 1_000_000,
        categoryBudgets: [String: Int64] = [:],
        categories: [CategoryEntity] = [],
        transactions: [TransactionEntity] = [],
        refunds: [RefundEntity] = []
    ) {
        self.version = version
        self.monthlyBudgetTotalMinor = monthlyBudgetTotalMinor
        self.categoryBudgets = categoryBudgets
        self.categories = categories
        self.transactions = transactions
        self.refunds = refunds
    }
}

/// Thread-safe actor for atomic disk persistence in Application Support directory
public actor ZeroTypingDiskStorage {
    public static let shared = ZeroTypingDiskStorage()

    public static var defaultStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("ZeroTypingStorage.json")
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
            return try operation()
        }
    }

    /// Load existing envelope from disk or create default envelope
    public func loadEnvelope(from url: URL = defaultStorageURL) throws -> AppStorageEnvelope {
        guard fileManager.fileExists(atPath: url.path) else {
            return AppStorageEnvelope(
                version: 1,
                monthlyBudgetTotalMinor: 1_000_000,
                categoryBudgets: [:],
                categories: AppState.defaultCategories(),
                transactions: [],
                refunds: []
            )
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppStorageEnvelope.self, from: data)
    }

    /// Atomically write storage envelope to disk
    public func saveEnvelope(_ envelope: AppStorageEnvelope, to url: URL = defaultStorageURL) throws {
        try withFileLock(for: url) {
            let parentDir = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: .atomic)
        }
    }

    /// Persist a single transaction safely into ZeroTypingStorage.json
    public func persistTransaction(_ transaction: TransactionEntity, to url: URL = defaultStorageURL) throws {
        try withFileLock(for: url) {
            var envelope: AppStorageEnvelope
            if fileManager.fileExists(atPath: url.path) {
                envelope = try loadEnvelope(from: url)
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

            let parentDir = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: .atomic)

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AppState.didIngestTransactionNotification, object: nil)
            }
        }
    }
}
