import Foundation

public actor TransactionEngine {
    private var transactions: [UUID: TransactionEntity] = [:]
    private var idempotencyIndex: [String: UUID] = [:]
    private var amountIndex: [Int64: [UUID]] = [:]
    private var refunds: [UUID: [RefundEntity]] = [:] // originalTransactionId -> refunds
    private var pairedDuplicates: [UUID: UUID] = [:] // newTx -> candidateTx

    public struct BalanceSnapshot: Codable, Sendable, Equatable {
        public let balanceMinor: Int64
        public let updatedAt: Date

        public init(balanceMinor: Int64, updatedAt: Date = Date()) {
            self.balanceMinor = balanceMinor
            self.updatedAt = updatedAt
        }
    }

    private var balanceLedger: [String: BalanceSnapshot] = [:]

    public func getBalanceSnapshot(key: String) -> BalanceSnapshot? {
        return balanceLedger[key]
    }

    public func setBalanceSnapshot(key: String, snapshot: BalanceSnapshot) {
        balanceLedger[key] = snapshot
    }

    public init() {}

    public enum EngineError: Error, Equatable {
        case duplicateIdempotencyKey(String)
        case transactionNotFound(UUID)
        case invalidAmount
        case zeroAmountNotAllowed
        case currencyMismatch
        case refundExceedsOriginal
    }

    /// Ingestion Entrypoint with double-layer idempotency protection (§8.5) and hardened boundary checks
    public func ingestTransaction(_ transaction: TransactionEntity) throws -> TransactionEntity {
        // 0. Boundary Guard: Reject negative amounts
        if let amt = transaction.amountMinor, amt < 0 {
            throw EngineError.invalidAmount
        }

        // 1. Event-level Idempotency Check
        if let existingId = idempotencyIndex[transaction.idempotencyKey],
           let existingTx = transactions[existingId] {
            return existingTx
        }

        var newTx = transaction
        let effectiveDate = newTx.transactionDate ?? newTx.capturedAt
        let genericMerchants = ["", "octopus", "八達通", "transit", "快捷交通卡", "apple pay", "unknown", "未知商戶", "unknown merchant"]

        // 2.5 Stateful BalanceLedger Engine Pre-Check & Delta Inference
        let ledgerKey = "\(newTx.provider.rawValue):default"
        if newTx.provider == .octopus {
            let prevSnapshot = balanceLedger[ledgerKey]
            if let newBalance = newTx.remainingBalanceMinor {
                // Guard 0: Negative Buffer & Ceiling Anomaly Guard (Octopus bounds [-5000, 300000])
                if newBalance < -5000 || newBalance > 300_000 || (prevSnapshot != nil && (newTx.amountMinor ?? 0) > 0 && prevSnapshot!.balanceMinor - (newTx.amountMinor ?? 0) < -5000) {
                    newTx.reviewStatus = .needsReview
                }

                // State 0: Cold-Start Initialization
                if prevSnapshot == nil {
                    balanceLedger[ledgerKey] = BalanceSnapshot(balanceMinor: newBalance, updatedAt: effectiveDate)
                    if newTx.transactionType == .topUp || (newTx.amountMinor == nil || newTx.amountMinor == 0) {
                        newTx.paymentStatus = .completed
                        newTx.reviewStatus = .confirmed
                        transactions[newTx.id] = newTx
                        return newTx
                    }
                } else if let prev = prevSnapshot {
                    // State 1: Silent Top-Up / AAVS Detection
                    if newTx.transactionType == .topUp || newBalance > prev.balanceMinor {
                        balanceLedger[ledgerKey] = BalanceSnapshot(balanceMinor: newBalance, updatedAt: effectiveDate)
                        newTx.transactionType = .topUp
                        newTx.amountMinor = newBalance - prev.balanceMinor
                        newTx.ledgerAmountMinor = newTx.amountMinor
                        newTx.paymentStatus = .completed
                        newTx.reviewStatus = .confirmed
                        transactions[newTx.id] = newTx
                        return newTx
                    } else if let spent = newTx.amountMinor, spent > 0 {
                        // State 2: Dual Match Verification
                        if prev.balanceMinor - spent == newBalance {
                            newTx.amountConfidence = 1.0
                        }
                        balanceLedger[ledgerKey] = BalanceSnapshot(balanceMinor: newBalance, updatedAt: effectiveDate)
                    } else if newTx.amountMinor == nil || newTx.amountMinor == 0 {
                        // State 3: Inferred Spent Recovery
                        let diff = prev.balanceMinor - newBalance
                        if diff > 0 && diff <= 300_000 {
                            newTx.amountMinor = diff
                            newTx.ledgerAmountMinor = diff
                            newTx.paymentStatus = .completed
                            newTx.reviewStatus = .needsReview
                            balanceLedger[ledgerKey] = BalanceSnapshot(balanceMinor: newBalance, updatedAt: effectiveDate)
                        }
                    }
                }
            }
        }

        // Stage 3: ZeroDollarGate
        if let amt = newTx.amountMinor, amt == 0 {
            let m = (newTx.merchantCanonical ?? newTx.merchantRaw ?? "").lowercased()
            let transitKeywords = ["mtr", "港鐵", "transit", "transport", "kmb", "九巴", "citybus", "城巴", "ferry", "tram", "octopus", "八達通"]
            let isTransitMerchant = transitKeywords.contains { m.contains($0) }
            let isTransitHold = newTx.remainingBalanceMinor == nil && (newTx.provider == .octopus || newTx.isHoldCandidate || isTransitMerchant || newTx.captureChannel == .walletAutomation)

            if isTransitHold {
                // Transit Hold Candidate: store in amountIndex[0]
                newTx.paymentStatus = .pending
                newTx.reviewStatus = .needsReview
                newTx.isHoldCandidate = true
                transactions[newTx.id] = newTx
                idempotencyIndex[newTx.idempotencyKey] = newTx.id
                amountIndex[0, default: []].append(newTx.id)
                return newTx
            } else if newTx.captureChannel == .photoPicker || newTx.captureChannel == .backTap || newTx.captureChannel == .actionButton || newTx.captureChannel == .shareSheet {
                // Unresolved Screenshot OCR: Relegated to (.pending, .needsReview), excluded from amountIndex[0] and active budget
                newTx.paymentStatus = .pending
                newTx.reviewStatus = .needsReview
                transactions[newTx.id] = newTx
                idempotencyIndex[newTx.idempotencyKey] = newTx.id
                return newTx
            } else {
                throw EngineError.zeroAmountNotAllowed
            }
        } else if let amt = newTx.amountMinor, amt > 0 {
            // Tiered Hold Matching:
            let newEffectiveDate = newTx.transactionDate ?? newTx.capturedAt
            let zeroHoldIds = amountIndex[0] ?? []
            let eligibleHolds = zeroHoldIds.compactMap { transactions[$0] }.filter { candidate in
                guard (candidate.amountMinor == 0 || candidate.paymentStatus == .pending) else {
                    return false
                }

                let candidateEffectiveDate = candidate.transactionDate ?? candidate.capturedAt
                let timeDiff = abs(newEffectiveDate.timeIntervalSince(candidateEffectiveDate))

                if newTx.provider == .octopus {
                    // Octopus Hold Match: same provider, cross-device permitted, window <= 15 min (900s)
                    guard candidate.provider == .octopus else { return false }
                    guard timeDiff <= 900 else { return false }
                    let m1 = (candidate.merchantCanonical ?? candidate.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                    let m2 = (newTx.merchantCanonical ?? newTx.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                    let isGenericM1 = genericMerchants.contains(m1) || m1.isEmpty
                    let isGenericM2 = genericMerchants.contains(m2) || m2.isEmpty
                    let merchantMatches = isGenericM1 || isGenericM2 || (m1 == m2) || (!m1.isEmpty && !m2.isEmpty && (m1.contains(m2) || m2.contains(m1)))
                    return merchantMatches
                } else {
                    // Contactless Card Transit Pre-Auth (e.g. Visa/Mastercard MTR tap)
                    guard candidate.provider == newTx.provider,
                          candidate.deviceSource == newTx.deviceSource else {
                        return false
                    }
                    guard timeDiff <= 86400 else { return false } // 24 hours
                    let m1 = (candidate.merchantCanonical ?? candidate.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                    let m2 = (newTx.merchantCanonical ?? newTx.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                    let merchantMatches = (m1 == m2) || (!m1.isEmpty && !m2.isEmpty && (m1.contains(m2) || m2.contains(m1)))
                    return merchantMatches
                }
            }

            // Pick the hold closest in time to the settlement
            let matchingHold = eligibleHolds.min { a, b in
                let dateA = a.transactionDate ?? a.capturedAt
                let dateB = b.transactionDate ?? b.capturedAt
                return abs(newEffectiveDate.timeIntervalSince(dateA)) < abs(newEffectiveDate.timeIntervalSince(dateB))
            }

            if let hold = matchingHold {
                amountIndex[0]?.removeAll(where: { $0 == hold.id })
                if amountIndex[0]?.isEmpty == true {
                    amountIndex.removeValue(forKey: 0)
                }

                var updatedHold = hold
                updatedHold.amountMinor = newTx.amountMinor
                updatedHold.ledgerAmountMinor = newTx.ledgerAmountMinor ?? newTx.amountMinor
                updatedHold.currency = newTx.currency ?? updatedHold.currency
                updatedHold.ledgerCurrency = newTx.ledgerCurrency ?? updatedHold.ledgerCurrency
                updatedHold.paymentStatus = .completed
                updatedHold.reviewStatus = .confirmed
                updatedHold.isHoldCandidate = false
                updatedHold.transactionDate = newTx.transactionDate ?? updatedHold.transactionDate
                updatedHold.sourceTransactionId = newTx.sourceTransactionId ?? updatedHold.sourceTransactionId

                // Upgrade generic merchant name
                let holdRaw = (hold.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let isHoldGeneric = genericMerchants.contains(holdRaw) || holdRaw.isEmpty
                if isHoldGeneric, let newM = newTx.merchantRaw, !genericMerchants.contains(newM.lowercased()) {
                    updatedHold.merchantRaw = newTx.merchantRaw
                    updatedHold.merchantCanonical = newTx.merchantCanonical ?? newTx.merchantRaw
                }
                if updatedHold.remainingBalanceMinor == nil {
                    updatedHold.remainingBalanceMinor = newTx.remainingBalanceMinor
                }
                updatedHold.updatedAt = Date()

                transactions[updatedHold.id] = updatedHold
                idempotencyIndex[newTx.idempotencyKey] = updatedHold.id
                if let newAmt = updatedHold.amountMinor {
                    amountIndex[newAmt, default: []].append(updatedHold.id)
                }
                return updatedHold
            }
        }

        // 2. Transaction-level duplication heuristic (prioritizing transactionDate over capturedAt)
        if newTx.duplicateStatus == .unique, let amt = newTx.amountMinor {
            let newEffectiveDate = newTx.transactionDate ?? newTx.capturedAt

            let candidateIds = amountIndex[amt] ?? []
            let possibleDup = candidateIds.compactMap { transactions[$0] }.first { candidate in
                guard candidate.id != newTx.id,
                      candidate.amountMinor == newTx.amountMinor,
                      candidate.currency == newTx.currency else {
                    return false
                }

                let m1 = (candidate.merchantCanonical ?? candidate.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let m2 = (newTx.merchantCanonical ?? newTx.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let isGenericM1 = genericMerchants.contains(m1) || m1.isEmpty
                let isGenericM2 = genericMerchants.contains(m2) || m2.isEmpty
                let merchantMatches = isGenericM1 || isGenericM2 || (m1 == m2) || (!m1.isEmpty && !m2.isEmpty && (m1.contains(m2) || m2.contains(m1)))
                guard merchantMatches else { return false }

                // If both have distinct sourceTransactionIds from the same ingestion source, they are distinct purchases
                if candidate.ingestionSource == newTx.ingestionSource,
                   let s1 = candidate.sourceTransactionId, let s2 = newTx.sourceTransactionId,
                   !s1.isEmpty, !s2.isEmpty, s1 != s2 {
                    return false
                }

                let candidateEffectiveDate = candidate.transactionDate ?? candidate.capturedAt
                let timeDiff = abs(candidateEffectiveDate.timeIntervalSince(newEffectiveDate))
                return timeDiff <= 120 // Within 2 minutes
            }

            if var dupCandidate = possibleDup {
                if dupCandidate.ingestionSource != newTx.ingestionSource {
                    // Cross-source capture (e.g. Wallet Shortcut + Bank Notification OCR ~5s apart): Merge & Enrich!
                    if dupCandidate.sourceTransactionId == nil || dupCandidate.sourceTransactionId?.isEmpty == true {
                        dupCandidate.sourceTransactionId = newTx.sourceTransactionId
                    }
                    if dupCandidate.remainingBalanceMinor == nil {
                        dupCandidate.remainingBalanceMinor = newTx.remainingBalanceMinor
                    }
                    let candRaw = (dupCandidate.merchantRaw ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                    if genericMerchants.contains(candRaw) || candRaw.isEmpty {
                        if let newM = newTx.merchantRaw, !genericMerchants.contains(newM.lowercased()) {
                            dupCandidate.merchantRaw = newTx.merchantRaw
                            dupCandidate.merchantCanonical = newTx.merchantCanonical ?? newTx.merchantRaw
                        }
                    }
                    dupCandidate.reviewStatus = .confirmed
                    dupCandidate.updatedAt = Date()
                    transactions[dupCandidate.id] = dupCandidate
                    idempotencyIndex[newTx.idempotencyKey] = dupCandidate.id
                    return dupCandidate
                } else {
                    // Same-Source Collision:
                    // Case 2b: Identical Provider ID -> Idempotent Replay (return existing candidate)
                    if let s1 = dupCandidate.sourceTransactionId, let s2 = newTx.sourceTransactionId,
                       !s1.isEmpty, !s2.isEmpty, s1 == s2 {
                        idempotencyIndex[newTx.idempotencyKey] = dupCandidate.id
                        return dupCandidate
                    }
                    // Case 2c: Missing Provider ID on either side -> Flag possibleDuplicate
                    newTx.duplicateStatus = .possibleDuplicate
                    pairedDuplicates[newTx.id] = dupCandidate.id
                    pairedDuplicates[dupCandidate.id] = newTx.id
                    if newTx.reviewStatus == .confirmed {
                        newTx.reviewStatus = .needsReview
                    }
                }
            }
        }

        // Store
        transactions[newTx.id] = newTx
        idempotencyIndex[newTx.idempotencyKey] = newTx.id
        if let amt = newTx.amountMinor {
            amountIndex[amt, default: []].append(newTx.id)
        }
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
        if let oldAmt = tx.amountMinor {
            amountIndex[oldAmt]?.removeAll(where: { $0 == id })
            if amountIndex[oldAmt]?.isEmpty == true {
                amountIndex.removeValue(forKey: oldAmt)
            }
        }
        tx.amountMinor = newAmountMinor
        tx.ledgerAmountMinor = newAmountMinor
        tx.amountConfidence = 1.0
        tx.paymentStatus = .completed
        tx.updatedAt = Date()
        transactions[id] = tx
        amountIndex[newAmountMinor, default: []].append(id)
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
        // Remove from amount index
        if let amt = tx.amountMinor {
            amountIndex[amt]?.removeAll(where: { $0 == id })
            if amountIndex[amt]?.isEmpty == true {
                amountIndex.removeValue(forKey: amt)
            }
        }
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
        amountIndex.removeAll()
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
        if let oldAmt = tx.amountMinor {
            amountIndex[oldAmt]?.removeAll(where: { $0 == id })
            if amountIndex[oldAmt]?.isEmpty == true {
                amountIndex.removeValue(forKey: oldAmt)
            }
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
        amountIndex[chosenAmountMinor, default: []].append(id)
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
            amountIndex.removeAll()
            refunds.removeAll()
            pairedDuplicates.removeAll()
        }

        for tx in importedTransactions {
            if let existingId = idempotencyIndex[tx.idempotencyKey] {
                if overwrite {
                    if let oldAmt = transactions[existingId]?.amountMinor {
                        amountIndex[oldAmt]?.removeAll(where: { $0 == existingId })
                        if amountIndex[oldAmt]?.isEmpty == true {
                            amountIndex.removeValue(forKey: oldAmt)
                        }
                    }
                    transactions[existingId] = tx
                    if let amt = tx.amountMinor {
                        amountIndex[amt, default: []].append(existingId)
                    }
                    importedCount += 1
                } else {
                    skippedCount += 1
                }
            } else {
                transactions[tx.id] = tx
                idempotencyIndex[tx.idempotencyKey] = tx.id
                if let amt = tx.amountMinor {
                    amountIndex[amt, default: []].append(tx.id)
                }
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

    private func effectiveNetAmount(for tx: TransactionEntity, start: Date? = nil, end: Date? = nil) -> Int64 {
        let txAmount = tx.ledgerAmountMinor ?? tx.amountMinor ?? 0
        let txRefunds = refunds[tx.id] ?? []
        let eligibleRefunds = txRefunds.filter { ref in
            if let start = start, ref.occurredAt < start { return false }
            if let end = end, ref.occurredAt > end { return false }
            return true
        }
        let refundedAmount = eligibleRefunds.reduce(Int64(0)) { $0 + $1.amountMinor }
        return max(0, txAmount - refundedAmount)
    }

    /// Section 8.3 Budget Accounting Rule with Overflow Protection
    public func calculateActiveNetSpending(forCurrency targetCurrency: String, start: Date? = nil, end: Date? = nil) -> Int64 {
        var netSpending: Int64 = 0

        for tx in transactions.values {
            guard isActiveConfirmedExpense(tx, targetCurrency: targetCurrency, start: start, end: end) else { continue }
            let effectiveAmount = effectiveNetAmount(for: tx, start: start, end: end)
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

            let effectiveAmount = effectiveNetAmount(for: tx, start: start, end: end)
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
            let effectiveAmount = effectiveNetAmount(for: tx, start: start, end: end)

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
            let effectiveAmount = effectiveNetAmount(for: tx, start: start, end: end)
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
