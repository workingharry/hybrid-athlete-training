import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Photo Cleanup Service Lifecycle & Safety Tests")
struct PhotoCleanupServiceTests {
    let cleanupService = PhotoCleanupService()

    @Test("Candidate Filtering: Only confirmed, eligible screenshots older than 7 days")
    func testFetchCleanupCandidatesFilter() async {
        let referenceDate = Date(timeIntervalSince1970: 1730000000) // Fixed reference
        let eightDaysAgo = referenceDate.addingTimeInterval(-8 * 86400)
        let threeDaysAgo = referenceDate.addingTimeInterval(-3 * 86400)

        let txConfirmedId = UUID()
        let txPendingId = UUID()
        let txRecentId = UUID()

        let txConfirmed = TransactionEntity(
            id: txConfirmedId,
            idempotencyKey: "tx_1",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantRaw: "Café de Coral",
            amountMinor: 6200,
            currency: "HKD",
            transactionDate: eightDaysAgo,
            reviewStatus: .confirmed
        )

        let txPending = TransactionEntity(
            id: txPendingId,
            idempotencyKey: "tx_2",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantRaw: "Uber",
            amountMinor: 6500,
            currency: "HKD",
            transactionDate: eightDaysAgo,
            reviewStatus: .needsReview // Unconfirmed transaction
        )

        let txRecent = TransactionEntity(
            id: txRecentId,
            idempotencyKey: "tx_3",
            provider: .alipayHK,
            captureChannel: .backTap,
            merchantRaw: "Starbucks",
            amountMinor: 4500,
            currency: "HKD",
            transactionDate: threeDaysAgo,
            reviewStatus: .confirmed // Only 3 days old
        )

        let txMap = [
            txConfirmedId: txConfirmed,
            txPendingId: txPending,
            txRecentId: txRecent
        ]

        let art1 = SourceArtifactEntity(
            transactionId: txConfirmedId,
            origin: .photoLibrary,
            photoAssetLocalIdentifier: "ASSET-001",
            importedAt: eightDaysAgo,
            cleanupStatus: .eligible
        )

        let art2 = SourceArtifactEntity(
            transactionId: txPendingId,
            origin: .photoLibrary,
            photoAssetLocalIdentifier: "ASSET-002",
            importedAt: eightDaysAgo,
            cleanupStatus: .eligible
        )

        let art3 = SourceArtifactEntity(
            transactionId: txRecentId,
            origin: .photoLibrary,
            photoAssetLocalIdentifier: "ASSET-003",
            importedAt: threeDaysAgo,
            cleanupStatus: .eligible
        )

        let art4NoAsset = SourceArtifactEntity(
            transactionId: txConfirmedId,
            origin: .shortcutTemp,
            photoAssetLocalIdentifier: nil, // Missing asset ID
            importedAt: eightDaysAgo,
            cleanupStatus: .eligible
        )

        let candidates = await cleanupService.fetchCleanupCandidates(
            artifacts: [art1, art2, art3, art4NoAsset],
            transactions: txMap,
            retentionDays: 7,
            referenceDate: referenceDate
        )

        // Only art1 meets all criteria: >7 days, .confirmed, has assetIdentifier, .eligible
        #expect(candidates.count == 1)
        #expect(candidates.first?.assetIdentifier == "ASSET-001")
        #expect(candidates.first?.merchantName == "Café de Coral")
        #expect(candidates.first?.amountFormatted == "HKD$62.00")
        #expect(candidates.first?.isSelected == true)
    }

    @Test("Simulated Batch Deletion: Non-empty asset ID list returns deletion counts")
    func testPerformBatchDeletionExecution() async throws {
        let candidateIds = ["ASSET-001", "ASSET-002", "ASSET-003"]
        let (deletedCount, failedIds) = try await cleanupService.performBatchDeletion(candidateAssetIds: candidateIds)

        #expect(deletedCount == 3)
        #expect(failedIds.isEmpty)
    }

    @Test("Zero Deletions: Empty candidate list returns zero without errors")
    func testPerformEmptyBatchDeletion() async throws {
        let (deletedCount, failedIds) = try await cleanupService.performBatchDeletion(candidateAssetIds: [])

        #expect(deletedCount == 0)
        #expect(failedIds.isEmpty)
    }

    @Test("Retention Bounds: Negative retention days clamped to zero")
    func testRetentionBoundsNegativeDaysClamping() async {
        let now = Date()
        let futureDate = now.addingTimeInterval(3600)
        let txId = UUID()
        let tx = TransactionEntity(
            id: txId,
            idempotencyKey: "tx_future",
            provider: .applePay,
            captureChannel: .walletAutomation,
            merchantRaw: "Future Store",
            amountMinor: 1000,
            reviewStatus: .confirmed
        )
        let artifact = SourceArtifactEntity(
            transactionId: txId,
            origin: .photoLibrary,
            photoAssetLocalIdentifier: "ASSET-FUTURE",
            importedAt: futureDate,
            cleanupStatus: .eligible
        )

        // Passing negative retention days (-7) should clamp to 0 and NOT pull future items
        let candidates = await cleanupService.fetchCleanupCandidates(
            artifacts: [artifact],
            transactions: [txId: tx],
            retentionDays: -7,
            referenceDate: now
        )

        #expect(candidates.isEmpty)
    }
}
