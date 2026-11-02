import Foundation

public actor TransactionEngine {
    private var transactions: [UUID: TransactionEntity] = [:]
    private var idempotencyIndex: [String: UUID] = [:]
    private var refunds: [UUID: [RefundEntity]] = [:] // originalTransactionId -> refunds
    private var pairedDuplicates: [UUID: UUID] = [:] // newTx -> candidateTx

    public init() {}

    public enum EngineError: Error, Equatable {
        case duplicateIdempotencyKey(String)
        case transactionNotFound(UUID)
        case invalidAmount
        case currencyMismatch
        case refundExceedsOriginal
    }

    /// Ingestion Entrypoint with double-layer idempotency protection (§8.5) and hardened boundary checks
    public func ingestTransaction(_ transaction: TransactionEntity) throws -> TransactionEntity {
        // 0. Boundary Guard: Reject negative or corrupted amounts
        if let amt = transaction.amountMinor, amt < 0 {
            throw EngineError.invalidAmount
        }

        // 1. Event-level Idempotency Check
        if let existingId = idempotencyIndex[transaction.idempotencyKey],
           let existingTx = transactions[existingId] {
            return existingTx
        }

        var newTx = transaction

        // If amount is zero (transit hold / pre-auth hold)
        if let amt = newTx.amountMinor, amt == 0 {
            newTx.paymentStatus = .pending
            newTx.reviewStatus = .needsReview
        } else if let amt = newTx.amountMinor, amt > 0 {
            // Transit Hold Matching:
            // If an existing transaction has amountMinor == 0 (or paymentStatus == .pending)
            // for the same provider, merchant, and deviceSource within 24 hours,
            // pair with the chronologically closest hold and update rather than creating a duplicate.
            let newEffectiveDate = newTx.transactionDate ?? newTx.capturedAt
            let eligibleHolds = transactions.values.filter { candidate in
                guard candidate.provider == newTx.provider,
                      candidate.deviceSource == newTx.deviceSource,
                      (candidate.amountMinor == 0 || candidate.paymentStatus == .pending) else {
                    return false
                }
                
                // Fuzzy/Canonical merchant matching ("MTR" vs "MTR Corporation Limited")
                let m1 = (candidate.merchantCanonical ?? candidate.merchantRaw ?? "").lowercased()
                let m2 = (newTx.merchantCanonical ?? newTx.merchantRaw ?? "").lowercased()
                let merchantMatches = (m1 == m2) || (!m1.isEmpty && !m2.isEmpty && (m1.contains(m2) || m2.contains(m1)))
                guard merchantMatches else { return false }

                let candidateEffectiveDate = candidate.transactionDate ?? candidate.capturedAt
                let timeDiff = abs(newEffectiveDate.timeIntervalSince(candidateEffectiveDate))
                return timeDiff <= 86400 // 24 hours
            }

            // Pick the hold closest in time to the settlement
            let matchingHold = eligibleHolds.min { a, b in
                let dateA = a.transactionDate ?? a.capturedAt
                let dateB = b.transactionDate ?? b.capturedAt
                return abs(newEffectiveDate.timeIntervalSince(dateA)) < abs(newEffectiveDate.timeIntervalSince(dateB))
            }

            if let hold = matchingHold {
                var updatedHold = hold
                updatedHold.amountMinor = newTx.amountMinor
                updatedHold.ledgerAmountMinor = newTx.ledgerAmountMinor ?? newTx.amountMinor
                updatedHold.currency = newTx.currency ?? updatedHold.currency
                updatedHold.ledgerCurrency = newTx.ledgerCurrency ?? updatedHold.ledgerCurrency
                updatedHold.paymentStatus = .completed
                updatedHold.reviewStatus = .confirmed
                updatedHold.transactionDate = newTx.transactionDate ?? updatedHold.transactionDate
                updatedHold.sourceTransactionId = newTx.sourceTransactionId ?? updatedHold.sourceTransactionId
                updatedHold.updatedAt = Date()
                transactions[updatedHold.id] = updatedHold
                idempotencyIndex[newTx.idempotencyKey] = updatedHold.id
                return updatedHold
            }
        }

        // 2. Transaction-level duplication heuristic (prioritizing transactionDate over capturedAt)
        if newTx.duplicateStatus == .unique {
            let newEffectiveDate = newTx.transactionDate ?? newTx.capturedAt

            let possibleDup = transactions.values.first { candidate in
                guard candidate.id != newTx.id,
                      candidate.merchantCanonical == newTx.merchantCanonical || candidate.merchantRaw == newTx.merchantRaw,
                      candidate.amountMinor == newTx.amountMinor,
                      candidate.currency == newTx.currency else {
                    return false
                }

                // If both have distinct sourceTransactionIds from payment provider, they are distinct purchases
                if let s1 = candidate.sourceTransactionId, let s2 = newTx.sourceTransactionId, !s1.isEmpty, !s2.isEmpty, s1 != s2 {
                    return false
                }

                let candidateEffectiveDate = candidate.transactionDate ?? candidate.capturedAt
                let timeDiff = abs(candidateEffectiveDate.timeIntervalSince(newEffectiveDate))
                return timeDiff <= 120 // Within 2 minutes
            }

            if let dupCandidate = possibleDup {
                newTx.duplicateStatus = .possibleDuplicate
                pairedDuplicates[newTx.id] = dupCandidate.id
                if newTx.reviewStatus == .confirmed {
                    newTx.reviewStatus = .needsReview
                }
            }
        }

        // Store
        transactions[newTx.id] = newTx
        idempotencyIndex[newTx.idempotencyKey] = newTx.id
        return newTx
    }

    /// Updates the transaction's transactionType, updates updatedAt, and triggers budget recalculation
    public func updateTransactionType(id: UUID, newType: TransactionType) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.transactionType = newType
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    public func addRefund(_ refund: RefundEntity) throws {
        guard refund.amountMinor > 0 else {
            throw EngineError.invalidAmount
        }

        guard var originalTx = transactions[refund.originalTransactionId] else {
            throw EngineError.transactionNotFound(refund.originalTransactionId)
        }

        // Currency integrity check (§8.8 / Boundary Audit)
        let origCurrency = originalTx.currency ?? originalTx.ledgerCurrency
        if let origCurrency = origCurrency, origCurrency != refund.currency {
            throw EngineError.currencyMismatch
        }

        var currentRefunds = refunds[originalTx.id] ?? []
        let totalRefundedBefore = currentRefunds.reduce(Int64(0)) { $0 + $1.amountMinor }
        let originalAmount = originalTx.ledgerAmountMinor ?? originalTx.amountMinor ?? 0

        // Prevent over-refunding
        if totalRefundedBefore + refund.amountMinor > originalAmount && originalAmount > 0 {
            throw EngineError.refundExceedsOriginal
        }

        currentRefunds.append(refund)
        refunds[originalTx.id] = currentRefunds

        let totalRefunded = totalRefundedBefore + refund.amountMinor
        if totalRefunded >= originalAmount && originalAmount > 0 {
            originalTx.paymentStatus = .refunded
        } else if totalRefunded > 0 {
            originalTx.paymentStatus = .partiallyRefunded
        }
        originalTx.updatedAt = Date()
        transactions[originalTx.id] = originalTx
    }

    public func getTransaction(id: UUID) -> TransactionEntity? {
        return transactions[id]
    }

    public func getPairedDuplicate(forId id: UUID) -> UUID? {
        return pairedDuplicates[id]
    }

    public func getAllTransactions() -> [TransactionEntity] {
        return Array(transactions.values)
    }

    /// Retrieve all transactions requiring user decision in Pending Review (§5.5 & S04)
    public func getPendingReviewTransactions() -> [TransactionEntity] {
        return transactions.values.filter { tx in
            !tx.isHidden && (tx.reviewStatus != .confirmed || tx.duplicateStatus == .possibleDuplicate)
        }.sorted { ($0.transactionDate ?? $0.capturedAt) > ($1.transactionDate ?? $1.capturedAt) }
    }

    /// Update an existing transaction entity
    public func updateTransaction(_ transaction: TransactionEntity) throws {
        guard transactions[transaction.id] != nil else {
            throw EngineError.transactionNotFound(transaction.id)
        }
        var updated = transaction
        updated.updatedAt = Date()
        transactions[updated.id] = updated
    }

    /// Update transaction amount directly (e.g. resolving pending $0 Octopus hold)
    public func updateTransactionAmount(id: UUID, newAmountMinor: Int64) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.amountMinor = newAmountMinor
        tx.ledgerAmountMinor = newAmountMinor
        tx.amountConfidence = 1.0
        tx.paymentStatus = .completed
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Resolve category decision in Pending Review
    public func resolveCategory(id: UUID, categoryId: UUID, canonicalMerchant: String? = nil) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.categoryId = categoryId
        if let canonical = canonicalMerchant {
            tx.merchantCanonical = canonical
        }
        tx.reviewStatus = .confirmed
        tx.categoryConfidence = 1.0
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    // MARK: - Section 9.3 Undo Operations

    /// Reverts category to previous category (§9.3)
    public func revertCategory(id: UUID, toCategoryId: UUID?) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.categoryId = toCategoryId
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Returns reviewStatus to .needsReview (§9.3), immediately removing it from active confirmed budget
    public func returnToNeedsReview(id: UUID) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.reviewStatus = .needsReview
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Hides transaction from list and active budget without physical deletion (§9.3)
    public func hideTransaction(id: UUID) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.isHidden = true
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Unhides a previously hidden transaction (§9.3)
    public func unhideTransaction(id: UUID) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.isHidden = false
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Hard deletes transaction and removes from indexes and associated refunds
    public func deleteTransaction(id: UUID) throws {
        guard let tx = transactions.removeValue(forKey: id) else {
            throw EngineError.transactionNotFound(id)
        }
        // Remove from idempotency index
        idempotencyIndex.removeValue(forKey: tx.idempotencyKey)
        // Cascade delete associated refunds
        refunds.removeValue(forKey: id)
        // Clean up paired duplicates
        pairedDuplicates.removeValue(forKey: id)
        if let key = pairedDuplicates.first(where: { $0.value == id })?.key {
            pairedDuplicates.removeValue(forKey: key)
        }
    }

    /// Clears all transactions and related indexes (keeps category structure by default)
    public func clearAllTransactions(keepCategories: Bool = true) throws {
        transactions.removeAll()
        idempotencyIndex.removeAll()
        refunds.removeAll()
        pairedDuplicates.removeAll()
    }

    /// Resolve amount ambiguity (e.g. from OCR multi-candidate detection)
    public func resolveAmountConflict(id: UUID, chosenAmountMinor: Int64) throws {
        guard chosenAmountMinor > 0 else {
            throw EngineError.invalidAmount
        }
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        tx.amountMinor = chosenAmountMinor
        tx.ledgerAmountMinor = chosenAmountMinor
        tx.amountConfidence = 1.0
        if tx.categoryId != nil {
            tx.reviewStatus = .confirmed
        } else {
            tx.reviewStatus = .needsCategory
        }
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Resolve suspected duplicate transaction (§5.5)
    public func resolveDuplicate(id: UUID, isSameTransaction: Bool) throws {
        guard var tx = transactions[id] else {
            throw EngineError.transactionNotFound(id)
        }
        if isSameTransaction {
            tx.duplicateStatus = .confirmedDuplicate
            tx.reviewStatus = .confirmed // Confirmed duplicate is preserved in ledger but excluded from budget (§8.3)
        } else {
            tx.duplicateStatus = .unique
            tx.reviewStatus = (tx.categoryId != nil) ? .confirmed : .needsCategory
        }
        tx.updatedAt = Date()
        transactions[id] = tx
    }

    /// Bulk import for Restore Engine (§10.1) with deduplication via idempotencyKey
    public func bulkImport(importedTransactions: [TransactionEntity], overwrite: Bool = false) -> (imported: Int, skippedDuplicates: Int) {
        var importedCount = 0
        var skippedCount = 0

        if overwrite {
            transactions.removeAll()
            idempotencyIndex.removeAll()
            refunds.removeAll()
            pairedDuplicates.removeAll()
        }

        for tx in importedTransactions {
            if let existingId = idempotencyIndex[tx.idempotencyKey] {
                if overwrite {
                    transactions[existingId] = tx
                    importedCount += 1
                } else {
                    skippedCount += 1
                }
            } else {
                transactions[tx.id] = tx
                idempotencyIndex[tx.idempotencyKey] = tx.id
                importedCount += 1
            }
        }

        return (importedCount, skippedCount)
    }

    // MARK: - Internal Accounting Helpers

    private func isActiveConfirmedExpense(_ tx: TransactionEntity, targetCurrency: String? = nil, start: Date? = nil, end: Date? = nil) -> Bool {
        guard !tx.isHidden else { return false }
        let effectiveDate = tx.transactionDate ?? tx.capturedAt
        if let start = start, effectiveDate < start { return false }
        if let end = end, effectiveDate > end { return false }

        // Rules from §8.3
        guard tx.reviewStatus == .confirmed,
              tx.duplicateStatus != .possibleDuplicate,
              tx.duplicateStatus != .confirmedDuplicate,
              tx.paymentStatus == .completed || tx.paymentStatus == .unknown || tx.paymentStatus == .partiallyRefunded || tx.paymentStatus == .refunded,
              tx.transactionType == .payment || tx.transactionType == .fee else {
            return false
        }

        if let targetCurrency = targetCurrency {
            let txCurrency = tx.ledgerCurrency ?? tx.currency
            guard txCurrency == targetCurrency else { return false }
        }

        return true
    }

    private func effectiveNetAmount(for tx: TransactionEntity) -> Int64 {
        let txAmount = tx.ledgerAmountMinor ?? tx.amountMinor ?? 0
        let txRefunds = refunds[tx.id] ?? []
        let refundedAmount = txRefunds.reduce(Int64(0)) { $0 + $1.amountMinor }
        return max(0, txAmount - refundedAmount)
    }

    /// Section 8.3 Budget Accounting Rule with Overflow Protection
    public func calculateActiveNetSpending(forCurrency targetCurrency: String, start: Date? = nil, end: Date? = nil) -> Int64 {
        var netSpending: Int64 = 0

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: targetCurrency, start: start, end: end) else { continue }
            let effectiveAmount = effectiveNetAmount(for: tx)
            let (newSum, didOverflow) = netSpending.addingReportingOverflow(effectiveAmount)
            netSpending = didOverflow ? Int64.max : newSum
        }

        return netSpending
    }

    /// Aggregates net spending grouped by Category ID (§6.3 & §8.3)
    public func calculateSpendingByCategory(forCurrency targetCurrency: String, start: Date? = nil, end: Date? = nil) -> [UUID: Int64] {
        var categoryTotals: [UUID: Int64] = [:]

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: targetCurrency, start: start, end: end) else { continue }
            guard let categoryId = tx.categoryId else { continue }

            let effectiveAmount = effectiveNetAmount(for: tx)
            let currentSum = categoryTotals[categoryId, default: 0]
            let (newSum, didOverflow) = currentSum.addingReportingOverflow(effectiveAmount)
            categoryTotals[categoryId] = didOverflow ? Int64.max : newSum
        }

        return categoryTotals
    }

    /// Ranks top merchants by total spend with transaction count (§6.2 Insights S06)
    public func getTopMerchants(forCurrency targetCurrency: String, limit: Int = 5, start: Date? = nil, end: Date? = nil) -> [(merchant: String, count: Int, totalMinor: Int64)] {
        var merchantStats: [String: (count: Int, total: Int64)] = [:]

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: targetCurrency, start: start, end: end) else { continue }
            let merchantName = tx.merchantCanonical ?? tx.merchantRaw ?? "Unknown"
            let effectiveAmount = effectiveNetAmount(for: tx)

            let existing = merchantStats[merchantName, default: (count: 0, total: 0)]
            let (newTotal, didOverflow) = existing.total.addingReportingOverflow(effectiveAmount)
            merchantStats[merchantName] = (count: existing.count + 1, total: didOverflow ? Int64.max : newTotal)
        }

        let sorted = merchantStats.map { (merchant: $0.key, count: $0.value.count, totalMinor: $0.value.total) }
            .sorted { (a, b) -> Bool in
                if a.totalMinor != b.totalMinor {
                    return a.totalMinor > b.totalMinor
                }
                return a.count > b.count
            }

        return Array(sorted.prefix(limit))
    }

    /// Calculates spending breakdown across device sources (e.g. iPhone vs Apple Watch) (§6.2 & §1.3)
    public func getSpendingByDeviceSource(forCurrency targetCurrency: String, start: Date? = nil, end: Date? = nil) -> [DeviceSource: Int64] {
        var deviceTotals: [DeviceSource: Int64] = [:]

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: targetCurrency, start: start, end: end) else { continue }
            let effectiveAmount = effectiveNetAmount(for: tx)
            let current = deviceTotals[tx.deviceSource, default: 0]
            let (newSum, didOverflow) = current.addingReportingOverflow(effectiveAmount)
            deviceTotals[tx.deviceSource] = didOverflow ? Int64.max : newSum
        }

        return deviceTotals
    }

    /// Isolates non-base currency spending without auto-conversion or mixing (§8.8)
    public func calculateUnconvertedForeignSpending(baseCurrency: String) -> [String: Int64] {
        var foreignTotals: [String: Int64] = [:]

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: nil, start: nil, end: nil) else { continue }
            let txCurrency = tx.ledgerCurrency ?? tx.currency ?? ""
            guard !txCurrency.isEmpty, txCurrency != baseCurrency else { continue }

            let effectiveAmount = effectiveNetAmount(for: tx)
            let current = foreignTotals[txCurrency, default: 0]
            let (newSum, didOverflow) = current.addingReportingOverflow(effectiveAmount)
            foreignTotals[txCurrency] = didOverflow ? Int64.max : newSum
        }

        return foreignTotals
    }
}
