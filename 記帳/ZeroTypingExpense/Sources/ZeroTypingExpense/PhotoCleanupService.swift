import Foundation
#if canImport(Photos)
import Photos
#endif

/// Candidate transaction screenshot item for user review before cleanup
public struct CleanupCandidate: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let assetIdentifier: String
    public let merchantName: String
    public let date: Date
    public let amountFormatted: String
    public let fileSizeMB: Double
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        assetIdentifier: String,
        merchantName: String,
        date: Date,
        amountFormatted: String,
        fileSizeMB: Double,
        isSelected: Bool = true
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.merchantName = merchantName
        self.date = date
        self.amountFormatted = amountFormatted
        self.fileSizeMB = fileSizeMB
        self.isSelected = isSelected
    }
}

/// Cleanup scope settings
public enum CleanupScope: String, Codable, Sendable, CaseIterable {
    case allRecognized = "allRecognized"
    case onlyConfirmed = "onlyConfirmed"
}

/// PhotoKit Screenshot Cleanup Service
/// Strictly adheres to App Store Review Guideline 5.1.1:
/// - ZERO silent background deletions.
/// - Explicit user authorization and pre-deletion preview.
/// - Verification: Transaction must be .confirmed, importedAt > retentionDays,
///   photoAssetLocalIdentifier != nil, and cleanupStatus == .eligible.
public actor PhotoCleanupService {
    public init() {}

    /// Evaluates eligible candidates for deletion preview
    /// - Parameters:
    ///   - artifacts: List of source screenshot artifacts
    ///   - transactions: Map of transactions indexed by UUID
    ///   - retentionDays: Retention threshold (default: 7 days)
    ///   - referenceDate: Reference date for retention calculation (default: current Date())
    /// - Returns: Filtered list of cleanup candidates
    public func fetchCleanupCandidates(
        artifacts: [SourceArtifactEntity],
        transactions: [UUID: TransactionEntity],
        retentionDays: Int = 7,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [CleanupCandidate] {
        let sanitizedRetentionDays = max(0, retentionDays)
        guard let retentionCutoff = calendar.date(byAdding: .day, value: -sanitizedRetentionDays, to: referenceDate) else {
            return []
        }
        var candidates: [CleanupCandidate] = []

        for artifact in artifacts {
            // Must have a photo asset local identifier
            guard let assetId = artifact.photoAssetLocalIdentifier, !assetId.isEmpty else {
                continue
            }

            // Must be eligible for cleanup
            guard artifact.cleanupStatus == .eligible else {
                continue
            }

            // Must have been imported at least retentionDays ago
            guard artifact.importedAt <= retentionCutoff else {
                continue
            }

            // Must link to a valid confirmed transaction
            guard let txId = artifact.transactionId,
                  let tx = transactions[txId],
                  tx.reviewStatus == .confirmed else {
                continue
            }

            // Format amount
            let amountDisplay: String
            if let minor = tx.amountMinor {
                let currency = tx.currency ?? "HKD"
                let major = Double(minor) / 100.0
                amountDisplay = String(format: "%@$%.2f", currency, major)
            } else {
                amountDisplay = "HK$0.00"
            }

            let candidate = CleanupCandidate(
                id: artifact.id,
                assetIdentifier: assetId,
                merchantName: tx.merchantCanonical ?? tx.merchantRaw ?? "未知商戶",
                date: tx.transactionDate ?? artifact.importedAt,
                amountFormatted: amountDisplay,
                fileSizeMB: 0.62, // Approximate typical screenshot size (PNG/HEIC ~0.6MB)
                isSelected: true
            )
            candidates.append(candidate)
        }

        return candidates.sorted(by: { $0.date > $1.date })
    }

    /// Requests Photo Library readWrite authorization if needed
    public func requestPhotoAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        #if canImport(Photos) && !os(macOS)
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return currentStatus
        #else
        return .authorized
        #endif
    }

    /// Performs batch deletion using PhotoKit PHPhotoLibrary
    /// Conforms to iOS explicit user authorization flow
    /// - Parameter candidateAssetIds: List of local identifiers to delete
    /// - Returns: Tuple of successfully deleted count and list of failed IDs
    public func performBatchDeletion(
        candidateAssetIds: [String]
    ) async throws -> (deletedCount: Int, failedIds: [String]) {
        guard !candidateAssetIds.isEmpty else {
            return (0, [])
        }

        #if canImport(Photos) && !os(macOS)
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        guard status == .authorized || status == .limited else {
            throw CleanupError.unauthorizedPhotosAccess
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: candidateAssetIds, options: nil)
        var foundIds = Set<String>()
        var assetsToDelete: [PHAsset] = []

        assets.enumerateObjects { asset, _, _ in
            foundIds.insert(asset.localIdentifier)
            assetsToDelete.append(asset)
        }

        let missingOrInaccessibleIds = candidateAssetIds.filter { !foundIds.contains($0) }

        guard !assetsToDelete.isEmpty else {
            // Assets not found in PhotoKit or all inaccessible; safe return without calling performChanges
            return (deletedCount: 0, failedIds: candidateAssetIds)
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }

        return (deletedCount: assetsToDelete.count, failedIds: missingOrInaccessibleIds)
        #else
        // Mock / Desktop headless testing environment: simulated deletion execution
        return (deletedCount: candidateAssetIds.count, failedIds: [])
        #endif
    }

    public enum CleanupError: LocalizedError, Sendable {
        case unauthorizedPhotosAccess
        case deletionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unauthorizedPhotosAccess:
                return "未授權存取相片圖庫，無法清理截圖。請前往「設定」開啟相片權限。"
            case .deletionFailed(let reason):
                return "相片清理失敗: \(reason)"
            }
        }
    }
}
