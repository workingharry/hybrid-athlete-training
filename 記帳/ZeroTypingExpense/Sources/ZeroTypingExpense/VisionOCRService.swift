import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct OCRResult: Sendable, Equatable {
    public let provider: PaymentProvider
    public let currency: String
    public let amountMinor: Int64?
    public let candidateAmountsMinor: [Int64]
    public let merchantRaw: String?
    public let sourceTransactionId: String?
    public let transactionDate: Date?
    public let amountConfidence: Float
    public let merchantConfidence: Float
    public let ocrEngineVersion: String
    public let ocrTemplateVersion: String
    public let requiresManualReview: Bool
    public let transactionType: TransactionType
    public let intent: NotificationIntent
    public let remainingBalanceMinor: Int64?
    public let isHypotheticalOrConditional: Bool
    public let evidencePhrase: String?

    public init(
        provider: PaymentProvider,
        currency: String,
        amountMinor: Int64?,
        candidateAmountsMinor: [Int64] = [],
        merchantRaw: String?,
        sourceTransactionId: String? = nil,
        transactionDate: Date? = nil,
        amountConfidence: Float = 1.0,
        merchantConfidence: Float = 1.0,
        ocrEngineVersion: String = "AppleVision-v1.0",
        ocrTemplateVersion: String = "Alipay-v1.3",
        requiresManualReview: Bool = false,
        transactionType: TransactionType = .payment,
        intent: NotificationIntent = .confirmedExpenditure,
        remainingBalanceMinor: Int64? = nil,
        isHypotheticalOrConditional: Bool = false,
        evidencePhrase: String? = nil
    ) {
        self.provider = provider
        self.currency = currency
        self.amountMinor = amountMinor
        self.candidateAmountsMinor = candidateAmountsMinor
        self.merchantRaw = merchantRaw
        self.sourceTransactionId = sourceTransactionId
        self.transactionDate = transactionDate
        self.amountConfidence = amountConfidence
        self.merchantConfidence = merchantConfidence
        self.ocrEngineVersion = ocrEngineVersion
        self.ocrTemplateVersion = ocrTemplateVersion
        self.requiresManualReview = requiresManualReview
        self.transactionType = transactionType
        self.intent = intent
        self.remainingBalanceMinor = remainingBalanceMinor
        self.isHypotheticalOrConditional = isHypotheticalOrConditional
        self.evidencePhrase = evidencePhrase
    }
}

// MARK: - Pre-compiled Regex Registry (§Algorithm P1 ROI)
internal enum VisionRegexRegistry: Sendable {
    static let cmdPrefix = try! NSRegularExpression(pattern: #"(?i)^cmd\|?"#)
    static let kvPair = try! NSRegularExpression(
        pattern: #"(?i)(?:^|[,;\n{\[])\s*[\*_\-`'"]*([A-Za-z_\u4e00-\u9fa5]+(?:[ \t\/\-][A-Za-z0-9_\u4e00-\u9fa5]+)*)[\*_\-`'"]*\s*[:=：]\s*[\*`'"]*([^,;\n}\]]+?)[\*`'"]*(?=[,;\n}\]]|$)"#
    )
    static let currencyStrip = try! NSRegularExpression(
        pattern: #"(?i)HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$|港幣|元|蚊"#
    )
    static let dotMatrixO1 = try! NSRegularExpression(pattern: #"(?<=\.)[Oo]{1,2}\b"#)
    static let dotMatrixO2 = try! NSRegularExpression(pattern: #"(?<=\.[0-9])[Oo]\b"#)
    static let dotMatrixO3 = try! NSRegularExpression(pattern: #"(?<=\.)[Oo](?=[0-9])"#)
    static let balanceClause = try! NSRegularExpression(
        pattern: #"(?i)(?:餘額|卡片餘額|現有結餘|結餘|Remaining(?:\s*Value)?|Card\s*Balance|Balance)[\s:：為是is]*[+-]?(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)?\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?"#
    )
    static let discountClause = try! NSRegularExpression(
        pattern: #"(?i)(?:優惠券折抵|優惠折抵|會員優惠|優惠|折扣|折抵|回贈|積分|減免|Discount|Coupon|Promo|Voucher)[\s:：為是is]*[+-]?(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)?\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?"#
    )
    static let cantoneseDetailed = try! NSRegularExpression(pattern: #"([0-9]{1,6})\s*蚊\s*([0-9]{1,2})\s*毫"#)
    static let cantoneseHalf = try! NSRegularExpression(pattern: #"([0-9]{1,6})\s*蚊半"#)
    static let cantoneseSimple = try! NSRegularExpression(pattern: #"([0-9]{1,6}(?:\.[0-9]{1,2})?)\s*蚊"#)
    static let cantoneseCent = try! NSRegularExpression(pattern: #"(?<![0-9])([0-9]{1,2})\s*毫"#)
    static let decimalAmount = try! NSRegularExpression(
        pattern: #"(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)?\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2}|[0-9]+\.[0-9]{1,2})"#
    )
    static let intCurrency = try! NSRegularExpression(
        pattern: #"(?i)(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)\s*([0-9]{1,7})(?![0-9]|\.[0-9])|(?<![0-9])([0-9]{1,7})\s*(?:HKD|HK\$|USD|CNY|RMB|EUR|GBP|JPY|元|港幣|蚊)(?![0-9]|\.[0-9])"#
    )
    static let connective1 = try! NSRegularExpression(pattern: #"(?i)(?:於|在|at|to)\s*([A-Za-z0-9_\u4e00-\u9fa5\s&'. -]{2,35})"#)
    static let connective2 = try! NSRegularExpression(pattern: #"(?i)([A-Za-z0-9_\u4e00-\u9fa5\s&'. -]{2,35})\s+(?:於|在)\s+"#)
    static let merchantStripCurrency = try! NSRegularExpression(pattern: #"(?i)HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$|港幣|元"#)
    static let merchantStripWords = try! NSRegularExpression(pattern: #"(?i)amount|price|merchant|store|payee|cost|消費|付款|支出|扣款|成功"#)
    static let merchantStripNumbers = try! NSRegularExpression(pattern: #"[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2}|[0-9]+"#)
    static let txId = try! NSRegularExpression(pattern: #"(?i)(?:交易號|訂單號|流水號|單號|txid|transaction|order)[:：\s]*([A-Za-z0-9_-]{8,})"#)
    static let trailingAction = try! NSRegularExpression(pattern: #"(?i)[\s]*(?:消費了|消費|買了|支付了|扣款|付款|結帳|買早餐|吃午餐|paid|paying|spent|for|了)[\s]*$"#)
    static let trailingPunctuation = try! NSRegularExpression(pattern: #"[，,。！!？?、;；].*$"#)
    static let clauseSplit = try! NSRegularExpression(pattern: #"(?:[\n。；;|]|\.(?![0-9]))"#)

    // Receipt Date Patterns
    static let isoDate = try! NSRegularExpression(pattern: #"\b(20[2-3][0-9])[-.](0[1-9]|1[0-2])[-.](0[1-9]|[12][0-9]|3[01])\b"#)
    static let slashYearFirst = try! NSRegularExpression(pattern: #"\b(20[2-3][0-9])/(0[1-9]|1[0-2])/(0[1-9]|[12][0-9]|3[01])\b"#)
    static let commonwealthDate = try! NSRegularExpression(pattern: #"\b(0[1-9]|[12][0-9]|3[01])[/-](0[1-9]|1[0-2])/(20[2-3][0-9])\b"#)
    static let chineseDate = try! NSRegularExpression(pattern: #"(20[2-3][0-9])\s*年\s*(1[0-2]|0?[1-9])\s*月\s*([12][0-9]|3[01]|0?[1-9])\s*日?"#)
    static let timePattern = try! NSRegularExpression(pattern: #"\b([01]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?\b"#)
}

extension NSRegularExpression {
    func replace(in input: String, with template: String = "") -> String {
        let ns = input as NSString
        return self.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: ns.length), withTemplate: template)
    }
}

public final class VisionOCRService: Sendable {
    public static let shared = VisionOCRService()

    public init() {}

    /// Normalize full-width digits and symbols to half-width ASCII
    public static func normalizeOCRText(_ input: String) -> String {
        let fullWidthMap: [Character: Character] = [
            "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
            "５": "5", "６": "6", "７": "7", "８": "8", "９": "9",
            "．": ".", "，": ",", "：": ":", "；": ";", "！": "!",
            "？": "?", "（": "(", "）": ")", "／": "/", "－": "-",
            "＋": "+", "＝": "=", "＄": "$", "￥": "¥", "％": "%"
        ]
        var normalizedChars: [Character] = []
        for ch in input {
            if let mapped = fullWidthMap[ch] {
                normalizedChars.append(mapped)
            } else {
                normalizedChars.append(ch)
            }
        }
        return String(normalizedChars)
    }

    /// Sanitize text lines to prevent CSV / formula injection (=, +, -, @, cmd, \t, \r, |)
    public static func sanitizeFormulaPrefix(_ input: String) -> String {
        var str = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let dangerousPrefixes: [Character] = ["=", "+", "-", "@", "\t", "\r", "|"]
        while let firstChar = str.first, dangerousPrefixes.contains(firstChar) {
            str.removeFirst()
            str = str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if str.lowercased().hasPrefix("cmd|") || str.lowercased().hasPrefix("cmd") {
            str = str.replacingOccurrences(of: "(?i)^cmd\\|?", with: "", options: .regularExpression)
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
    }

    public struct ParsedClause: Sendable, Equatable {
        public let text: String
        public let intent: NotificationIntent
        public let isHypotheticalOrConditional: Bool
        public let evidencePhrase: String?

        public init(text: String, intent: NotificationIntent, isHypotheticalOrConditional: Bool = false, evidencePhrase: String? = nil) {
            self.text = text
            self.intent = intent
            self.isHypotheticalOrConditional = isHypotheticalOrConditional
            self.evidencePhrase = evidencePhrase
        }
    }

    public struct DualRoleResult: Sendable, Equatable {
        public let spentMinor: Int64?
        public let balanceMinor: Int64?

        public init(spentMinor: Int64?, balanceMinor: Int64?) {
            self.spentMinor = spentMinor
            self.balanceMinor = balanceMinor
        }
    }

    /// Stage 0: Clause Segmentation + Hybrid Intent Gate
    public static func segmentAndClassifyClauses(_ rawText: String) -> [ParsedClause] {
        var cleanRaw = VisionRegexRegistry.dotMatrixO1.replace(in: rawText, with: "00")
        cleanRaw = VisionRegexRegistry.dotMatrixO2.replace(in: cleanRaw, with: "0")
        cleanRaw = VisionRegexRegistry.dotMatrixO3.replace(in: cleanRaw, with: "0")
        let pattern = #"(?:[\n。；;|]|\.(?![0-9Oo]))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [classifySingleClause(cleanRaw)]
        }
        let ns = cleanRaw as NSString
        let matches = regex.matches(in: rawText, range: NSRange(location: 0, length: ns.length))
        var clauses: [String] = []
        var lastIdx = 0
        for m in matches {
            let r = NSRange(location: lastIdx, length: m.range.location - lastIdx)
            if r.length > 0 {
                let part = ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { clauses.append(part) }
            }
            lastIdx = m.range.location + m.range.length
        }
        if lastIdx < ns.length {
            let part = ns.substring(from: lastIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { clauses.append(part) }
        }
        if clauses.isEmpty { return [classifySingleClause(rawText)] }
        return clauses.map { classifySingleClause($0) }
    }

    public static func classifySingleClause(_ clause: String) -> ParsedClause {
        let lower = clause.lowercased()

        let loanKeywords = ["貸款", "借貸", "預批", "分期", "月平息", "信用額", "最低還款", "loan", "pre-approved", "installment", "apr", "credit limit", "min pay"]
        let promoKeywords = ["高達", "低至", "消費滿", "簽賬滿", "回贈", "獎賞", "抽獎", "up to", "as low as", "rebate", "cashback", "win"]
        let topUpKeywords = ["自動增值", "已增值", "增值", "top up", "top-up", "reload", "aavs", "儲值", "充值"]
        let refundKeywords = ["退款", "退回", "refund", "reversal"]
        let settledKeywords = ["已扣除", "扣除", "已付款", "付款", "消費", "支付", "扣款", "交易金額", "車費", "收費", "deducted", "paid", "spent", "charged", "payment of", "purchase", "fare", "net", "實付", "買了", "結帳"]
        let otpKeywords = ["驗證碼", "otp", "one-time password", "3ds", "動態密碼"]
        let balanceKeywords = ["餘額", "結餘", "現時餘額", "最新結餘", "可用餘額", "可用信用額", "剩餘儲值", "餘額為", "remaining value", "remaining balance", "balance", "bal", "avail"]

        let hasOTP = otpKeywords.contains { lower.contains($0.lowercased()) }
        if hasOTP {
            return ParsedClause(text: clause, intent: .otpOrAuthAttempt, isHypotheticalOrConditional: true, evidencePhrase: nil)
        }

        let hasRefund = refundKeywords.contains { lower.contains($0.lowercased()) }
        let hasTopUp = topUpKeywords.contains { lower.contains($0.lowercased()) }
        let hasLoan = loanKeywords.contains { lower.contains($0.lowercased()) }
        let hasPromo = promoKeywords.contains { lower.contains($0.lowercased()) }
        let hasSettled = settledKeywords.contains { lower.contains($0.lowercased()) }
        let hasBalance = balanceKeywords.contains { lower.contains($0.lowercased()) }

        if hasRefund {
            return ParsedClause(text: clause, intent: .refundOrReversal, isHypotheticalOrConditional: false, evidencePhrase: clause)
        }

        if hasLoan || (hasPromo && !hasSettled) {
            return ParsedClause(text: clause, intent: .loanOrPromoOffer, isHypotheticalOrConditional: true, evidencePhrase: nil)
        }

        if hasTopUp && !hasSettled {
            return ParsedClause(text: clause, intent: .topUpOrInternalTransfer, isHypotheticalOrConditional: false, evidencePhrase: clause)
        }

        if hasSettled {
            return ParsedClause(text: clause, intent: .confirmedExpenditure, isHypotheticalOrConditional: false, evidencePhrase: clause)
        }

        if hasBalance && !hasSettled {
            return ParsedClause(text: clause, intent: .balanceInquiryOnly, isHypotheticalOrConditional: false, evidencePhrase: nil)
        }

        return ParsedClause(text: clause, intent: .confirmedExpenditure, isHypotheticalOrConditional: false, evidencePhrase: clause)
    }

    /// Role-Anchored Dual Extraction (DualNumberRoleExtractor)
    public static func extractDualNumberRoles(_ text: String) -> DualRoleResult {
        var normalizedText = VisionRegexRegistry.dotMatrixO1.replace(in: text, with: "00")
        normalizedText = VisionRegexRegistry.dotMatrixO2.replace(in: normalizedText, with: "0")
        normalizedText = VisionRegexRegistry.dotMatrixO3.replace(in: normalizedText, with: "0")
        let ns = normalizedText as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        struct CandidateMatch {
            let minor: Int64
            let location: Int
            let spendScore: Int
            let balanceScore: Int
        }

        var candidates: [CandidateMatch] = []

        func evaluateCandidate(rawAmountStr: String, location: Int, multiplier: Int64 = 100) {
            let cleaned = rawAmountStr.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            let minor: Int64
            if cleaned.contains(".") {
                guard let dec = Decimal(string: cleaned) else { return }
                minor = NSDecimalNumber(decimal: dec * 100).int64Value
            } else if let intVal = Int64(cleaned), intVal > 0 {
                minor = intVal * multiplier
            } else {
                return
            }
            guard minor > 0 else { return }

            // Inspect prefix window up to previous punctuation/delimiter (max 25 chars before the number)
            let start = max(0, location - 25)
            let len = location - start
            let rawPrefix = (len > 0 ? ns.substring(with: NSRange(location: start, length: len)) : "").lowercased()
            let delimChars = CharacterSet(charactersIn: "，,。;\n\r；|")
            let prefixSegments = rawPrefix.components(separatedBy: delimChars)
            let prefix = prefixSegments.last?.trimmingCharacters(in: .whitespaces) ?? rawPrefix

            var sSpend = 0
            var sBalance = 0

            let spendPositiveWords = ["已扣除", "扣除", "扣款", "已付款", "付款", "消費", "支付", "交易金額", "車費", "收費", "deducted", "paid", "spent", "charged", "payment of", "purchase", "fare", "net", "實付"]
            let spendNegativeWords = ["餘額", "結餘", "剩餘", "可用", "儲值額", "balance", "remaining", "bal", "avail", "高達", "增值", "自動增值", "貸款", "分期"]

            let balancePositiveWords = ["餘額", "結餘", "現時餘額", "最新結餘", "可用餘額", "可用信用額", "剩餘儲值", "餘額為", "remaining value", "remaining balance", "balance", "bal", "avail"]
            let balanceNegativeWords = ["扣除", "消費", "付款", "deducted", "paid", "spent", "車費", "已扣除", "已付款", "支付"]

            if spendPositiveWords.contains(where: { prefix.contains($0.lowercased()) }) {
                sSpend += 3
            }
            if spendNegativeWords.contains(where: { prefix.contains($0.lowercased()) }) {
                sSpend -= 5
            }

            if balancePositiveWords.contains(where: { prefix.contains($0.lowercased()) }) {
                sBalance += 3
            }
            if balanceNegativeWords.contains(where: { prefix.contains($0.lowercased()) }) {
                sBalance -= 5
            }

            candidates.append(CandidateMatch(minor: minor, location: location, spendScore: sSpend, balanceScore: sBalance))
        }

        // Match decimals
        for m in VisionRegexRegistry.decimalAmount.matches(in: text, range: fullRange) {
            if m.numberOfRanges > 1 {
                let range = m.range(at: 1)
                let numStr = ns.substring(with: range)
                evaluateCandidate(rawAmountStr: numStr, location: range.location)
            }
        }

        // Match integer currencies
        for m in VisionRegexRegistry.intCurrency.matches(in: text, range: fullRange) {
            let r1 = m.range(at: 1)
            let r2 = m.range(at: 2)
            if r1.location != NSNotFound {
                evaluateCandidate(rawAmountStr: ns.substring(with: r1), location: r1.location, multiplier: 100)
            } else if r2.location != NSNotFound {
                evaluateCandidate(rawAmountStr: ns.substring(with: r2), location: r2.location, multiplier: 100)
            }
        }

        let bestSpend = candidates.filter { $0.spendScore > 0 }
            .sorted { $0.spendScore != $1.spendScore ? $0.spendScore > $1.spendScore : $0.location > $1.location }
            .first?.minor

        let bestBalance = candidates.filter { $0.balanceScore > 0 }
            .sorted { $0.balanceScore != $1.balanceScore ? $0.balanceScore > $1.balanceScore : $0.location > $1.location }
            .first?.minor

        return DualRoleResult(spentMinor: bestSpend, balanceMinor: bestBalance)
    }

    /// Parse array of OCR recognized text lines into structured financial receipt details
    public func parseRecognizedStrings(_ lines: [String]) -> OCRResult {
        // Normalize fullwidth digits and sanitize incoming lines against formula injection
        let normalizedLines = lines.map { VisionOCRService.normalizeOCRText($0) }
        let rawSanitizedLines = normalizedLines.map { VisionOCRService.sanitizeFormulaPrefix($0) }
        let sanitizedLines = VisionOCRService.cleanNaturalLanguageLines(rawSanitizedLines)
        let fullText = sanitizedLines.joined(separator: "\n")

        // Stage 0: Clause Segmentation & Hybrid Intent Gate
        let parsedClauses = VisionOCRService.segmentAndClassifyClauses(fullText)
        let hasExpenditureClause = parsedClauses.contains { $0.intent == .confirmedExpenditure }
        let hasRefundClause = parsedClauses.contains { $0.intent == .refundOrReversal }
        let hasTopUpClause = parsedClauses.contains { $0.intent == .topUpOrInternalTransfer }
        let hasLoanPromoOnly = !hasExpenditureClause && !hasRefundClause && !hasTopUpClause && parsedClauses.contains { $0.intent == .loanOrPromoOffer }
        let hasOTPOnly = !hasExpenditureClause && !hasRefundClause && parsedClauses.contains { $0.intent == .otpOrAuthAttempt }

        var primaryIntent: NotificationIntent = .confirmedExpenditure
        var isHypo = false
        var evidencePhrase: String? = nil

        if hasLoanPromoOnly {
            primaryIntent = .loanOrPromoOffer
            isHypo = true
        } else if hasOTPOnly {
            primaryIntent = .otpOrAuthAttempt
            isHypo = true
        } else if hasRefundClause {
            primaryIntent = .refundOrReversal
            evidencePhrase = parsedClauses.first { $0.intent == .refundOrReversal }?.evidencePhrase
        } else if hasTopUpClause && !hasExpenditureClause {
            primaryIntent = .topUpOrInternalTransfer
            evidencePhrase = parsedClauses.first { $0.intent == .topUpOrInternalTransfer }?.evidencePhrase
        } else if let exp = parsedClauses.first(where: { $0.intent == .confirmedExpenditure }) {
            primaryIntent = .confirmedExpenditure
            evidencePhrase = exp.evidencePhrase
        }

        // Active lines for amount extraction: drop pure loan/promo/otp clauses so non-expenditure limits are never extracted as spent
        let activeClauses = parsedClauses.filter { $0.intent != .loanOrPromoOffer && $0.intent != .otpOrAuthAttempt }
        let effectiveLines = (hasExpenditureClause || hasRefundClause || hasTopUpClause) ? activeClauses.map { $0.text } : sanitizedLines

        // 1. Detect Provider & Initial Currency & Transaction Type
        let provider = VisionOCRService.detectPaymentProvider(in: fullText)
        let isAlipayChina = (provider == .alipayChina)
        var detectedCurrency = isAlipayChina ? "CNY" : "HKD"

        var detectedType: TransactionType = (primaryIntent == .topUpOrInternalTransfer) ? .topUp : ((primaryIntent == .refundOrReversal) ? .refund : .payment)
        let lowerFull = fullText.lowercased()
        if primaryIntent != .topUpOrInternalTransfer && primaryIntent != .refundOrReversal {
            if lowerFull.contains("增值") || lowerFull.contains("自動增值") || lowerFull.contains("aavs") ||
               lowerFull.contains("儲值") || lowerFull.contains("充值") || lowerFull.contains("top up") ||
               lowerFull.contains("top-up") || lowerFull.contains("add value") || lowerFull.contains("reload") {
                detectedType = .topUp
            } else if lowerFull.contains("退款") || lowerFull.contains("退回") || lowerFull.contains("refund") || lowerFull.contains("reversal") {
                detectedType = .refund
            } else if lowerFull.contains("轉帳") || lowerFull.contains("轉賬") || lowerFull.contains("轉數快") ||
                      lowerFull.contains("fps") || lowerFull.contains("transfer") {
                detectedType = .transfer
            } else if lowerFull.contains("手續費") || lowerFull.contains("服務費") || lowerFull.contains("handling fee") {
                detectedType = .fee
            }
        }

        // 2. Extract Key-Value Pairs from lines and comma-delimited segments
        var kvAmountRaw: String?
        var kvMerchantRaw: String?
        var kvCurrencyRaw: String?
        var kvTxIdRaw: String?

        let nsText = fullText as NSString
        let matches = VisionRegexRegistry.kvPair.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            if match.numberOfRanges >= 3 {
                let rawKey = nsText.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n*_-`'\""))
                    .lowercased()
                let val = nsText.substring(with: match.range(at: 2))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n*`'\""))

                    let keyTokens = rawKey.components(separatedBy: CharacterSet(charactersIn: " /-_")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

                    let isAmountKey = keyTokens.contains { k in
                        ["amount", "price", "cost", "val", "total", "sum", "fare", "charge", "net", "deducted", "paid", "subtotal", "實付金額", "實付", "實際支付", "支付金額", "扣款金額", "總計", "合計", "金額", "扣除", "扣款", "車費", "收費", "支出", "消費", "應付", "八達通扣款"].contains(k)
                    }
                    let isMerchantKey = keyTokens.contains { k in
                        ["merchant", "store", "payee", "shop", "vendor", "seller", "商戶名稱", "收款方", "商戶", "商家", "店舖", "店鋪", "機構", "受款人"].contains(k)
                    }
                    let isCurrencyKey = keyTokens.contains { k in
                        ["currency", "cur", "幣別", "貨幣", "幣種"].contains(k)
                    }
                    let isTxIdKey = keyTokens.contains { k in
                        ["txid", "transaction", "order", "ref", "reference", "txn", "交易號", "訂單號", "流水號", "單號", "參考號"].contains(k)
                    }

                    if isAmountKey {
                        if kvAmountRaw == nil || rawKey.contains("實付") || rawKey.contains("實際") || rawKey.contains("扣除") || rawKey.contains("車費") || rawKey.contains("net") {
                            kvAmountRaw = val
                        }
                    } else if isMerchantKey {
                        if kvMerchantRaw == nil || rawKey.contains("商戶名稱") || rawKey.contains("收款方") || rawKey == "merchant" {
                            kvMerchantRaw = val
                        }
                    } else if isCurrencyKey {
                        kvCurrencyRaw = val
                    } else if isTxIdKey {
                        kvTxIdRaw = val
                    }
                }
            }

        // Multi-line Key-Value extraction: Line i has key label, Line i+1 has the value
        if kvAmountRaw == nil || kvMerchantRaw == nil {
            for (idx, line) in sanitizedLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n:：;·|*-`'\"")).lowercased()
                if idx + 1 < sanitizedLines.count {
                    let nextLine = sanitizedLines[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if kvAmountRaw == nil && (trimmed == "實付金額" || trimmed == "實付" || trimmed == "實際支付" || trimmed == "扣除" || trimmed == "車費" || trimmed == "收費" || trimmed == "扣款金額" || trimmed == "總計" || trimmed == "合計" || trimmed == "total" || trimmed == "net amount" || trimmed == "amount") {
                        if nextLine.rangeOfCharacter(from: .decimalDigits) != nil || nextLine == "HK$" || nextLine == "$" {
                            if (nextLine == "HK$" || nextLine == "$" || nextLine == "¥" || nextLine == "元") && idx + 2 < sanitizedLines.count {
                                kvAmountRaw = nextLine + " " + sanitizedLines[idx + 2].trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                kvAmountRaw = nextLine
                            }
                        }
                    } else if kvMerchantRaw == nil && (trimmed == "商戶名稱" || trimmed == "收款方" || trimmed == "商戶" || trimmed == "商家" || trimmed == "merchant" || trimmed == "store" || trimmed == "payee") {
                        if !nextLine.isEmpty && nextLine.rangeOfCharacter(from: .decimalDigits) == nil {
                            kvMerchantRaw = nextLine
                        }
                    }
                }
            }
        }

        // Helper to extract known currency from a string token
        func extractCurrencyCode(from text: String) -> String? {
            let upper = text.uppercased()
            if upper.contains("HKD") || upper.contains("HK$") || upper.contains("港幣") || upper.contains("蚊") {
                return "HKD"
            } else if upper.contains("USD") || upper.contains("US$") || upper.contains("美元") {
                return "USD"
            } else if upper.contains("CNY") || upper.contains("RMB") || upper.contains("元") || upper.contains("¥") || upper.contains("￥") {
                return "CNY"
            } else if upper.contains("EUR") || upper.contains("歐元") || upper.contains("€") {
                return "EUR"
            } else if upper.contains("GBP") || upper.contains("英鎊") || upper.contains("£") {
                return "GBP"
            } else if upper.contains("JPY") || upper.contains("日元") {
                return "JPY"
            }
            return nil
        }

        // Detect currency override: explicit currency field > amount token > line with digits > full text
        if let explicitCur = kvCurrencyRaw, let code = extractCurrencyCode(from: explicitCur) {
            detectedCurrency = code
        } else if let kvAmount = kvAmountRaw, let code = extractCurrencyCode(from: kvAmount) {
            detectedCurrency = code
        } else {
            var matchedLineCur: String?
            for line in sanitizedLines {
                if let code = extractCurrencyCode(from: line), line.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                    matchedLineCur = code
                    break
                }
            }
            if let mlc = matchedLineCur {
                detectedCurrency = mlc
            } else if let code = extractCurrencyCode(from: fullText) {
                detectedCurrency = code
            }
        }

        // 3. Extract Candidate Amounts & Keyword-Anchored Scoring
        var foundMinorAmounts: [Int64] = []
        var scoredCandidates: [(amount: Int64, score: Int, isNegative: Bool)] = []

        func parseAmountString(_ str: String) -> Int64? {
            var cleaned = VisionRegexRegistry.currencyStrip.replace(in: str)
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'*`"))

            // Dot-matrix letter O/o confusion fix in decimal part: e.g. .OO -> .00, .O5 -> .05, .5O -> .50
            cleaned = VisionRegexRegistry.dotMatrixO1.replace(in: cleaned, with: "00")
            cleaned = VisionRegexRegistry.dotMatrixO2.replace(in: cleaned, with: "0")

            if cleaned.contains(".") {
                if let decimal = Decimal(string: cleaned) {
                    return NSDecimalNumber(decimal: decimal * 100).int64Value
                }
            } else if let intVal = Int64(cleaned), intVal > 0 {
                return intVal * 100
            }
            return nil
        }

        if let kvAmount = kvAmountRaw, let parsed = parseAmountString(kvAmount), parsed > 0 {
            foundMinorAmounts.append(parsed)
            scoredCandidates.append((amount: parsed, score: 95, isNegative: false))
        }

        // Balance & Discount filters
        let balanceKeywords = ["餘額", "卡片餘額", "現有結餘", "結餘", "balance", "remaining"]
        let discountKeywords = ["優惠", "折扣", "回贈", "積分", "折抵", "減免", "discount", "coupon", "promo", "voucher"]
        let positivePaymentKeywords = ["扣除", "車費", "收費", "實付", "實際支付", "扣款金額", "扣款", "支出", "消費", "應付", "deducted", "fare", "paid", "net"]
        let tier1PositiveKeywords = ["扣除", "實付", "實際支付", "扣款金額", "扣款", "收費", "車費", "應付", "淨額", "deducted", "fare", "paid", "net"]
        let tier2PositiveKeywords = ["支出", "消費", "合計", "總計", "总计", "金額", "金额", "total", "amount", "sum"]

        var pendingScoreInheritance: Int = 0

        for line in effectiveLines {
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let hasPositiveKeyword = positivePaymentKeywords.contains { trimmed.localizedCaseInsensitiveContains($0) }
            let hasBalanceKeyword = balanceKeywords.contains { trimmed.localizedCaseInsensitiveContains($0) }
            let hasDiscountKeyword = discountKeywords.contains { trimmed.localizedCaseInsensitiveContains($0) }

            // If line is PURE balance without payment keywords, skip line entirely
            if hasBalanceKeyword && !hasPositiveKeyword {
                continue
            }

            // If line is PURE discount without payment keywords, skip line entirely
            if hasDiscountKeyword && !hasPositiveKeyword {
                continue
            }

            // On mixed lines (e.g. "扣除 $12.50 餘額 $145.20" or "扣除 HK$14.50，卡片餘額為 HK$128.50"), strip balance clause so balance amount is never extracted
            if hasBalanceKeyword && hasPositiveKeyword {
                trimmed = VisionRegexRegistry.balanceClause.replace(in: trimmed)
            }

            // Strip discount clause on mixed lines (e.g. "原價 $85.00 折扣 $27.00 實付 $58.00")
            if hasDiscountKeyword && hasPositiveKeyword {
                trimmed = VisionRegexRegistry.discountClause.replace(in: trimmed)
            }

            // Dot-matrix letter O/o confusion fix in decimal numbers: e.g. .OO -> .00, .O5 -> .05, .5O -> .50
            trimmed = VisionRegexRegistry.dotMatrixO1.replace(in: trimmed, with: "00")
            trimmed = VisionRegexRegistry.dotMatrixO2.replace(in: trimmed, with: "0")
            trimmed = VisionRegexRegistry.dotMatrixO3.replace(in: trimmed, with: "0")

            // Discard pure $0.00 zero lines
            let containsZeroToken = trimmed == "$0.00" || trimmed == "$0" || trimmed == "0.00" ||
                                    trimmed.contains("$0.00") || trimmed.contains("$ 0.00") ||
                                    trimmed.contains("HK$0.00") || trimmed.contains("HK$ 0.00")
            let hasNonZeroDigit = trimmed.contains("1") || trimmed.contains("2") || trimmed.contains("3") ||
                                  trimmed.contains("4") || trimmed.contains("5") || trimmed.contains("6") ||
                                  trimmed.contains("7") || trimmed.contains("8") || trimmed.contains("9")
            if containsZeroToken && !hasNonZeroDigit {
                continue
            }

            var lineScore = 20
            if tier1PositiveKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                lineScore = 100
            } else if tier2PositiveKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                lineScore = 70
            } else if pendingScoreInheritance > 0 {
                lineScore = pendingScoreInheritance
            }

            var lineFoundMinors: [Int64] = []

            // Extract Cantonese units first (e.g. 12蚊5毫, 12蚊半, 12.5蚊, 5毫)
            let nsLine = trimmed as NSString
            let lineRange = NSRange(location: 0, length: nsLine.length)

            if let match = VisionRegexRegistry.cantoneseDetailed.firstMatch(in: trimmed, range: lineRange), match.numberOfRanges > 2 {
                let dollarStr = nsLine.substring(with: match.range(at: 1))
                let centStr = nsLine.substring(with: match.range(at: 2))
                if let d = Int64(dollarStr), let c = Int64(centStr) {
                    let minor = d * 100 + c * 10
                    if minor > 0 && !lineFoundMinors.contains(minor) {
                        lineFoundMinors.append(minor)
                    }
                }
            }
            if lineFoundMinors.isEmpty, let match = VisionRegexRegistry.cantoneseHalf.firstMatch(in: trimmed, range: lineRange), match.numberOfRanges > 1 {
                let dollarStr = nsLine.substring(with: match.range(at: 1))
                if let d = Int64(dollarStr) {
                    let minor = d * 100 + 50
                    if minor > 0 && !lineFoundMinors.contains(minor) {
                        lineFoundMinors.append(minor)
                    }
                }
            }
            if lineFoundMinors.isEmpty, let match = VisionRegexRegistry.cantoneseSimple.firstMatch(in: trimmed, range: lineRange), match.numberOfRanges > 1 {
                let amtStr = nsLine.substring(with: match.range(at: 1))
                if let dec = Decimal(string: amtStr) {
                    let minor = NSDecimalNumber(decimal: dec * 100).int64Value
                    if minor > 0 && !lineFoundMinors.contains(minor) {
                        lineFoundMinors.append(minor)
                    }
                }
            }
            if lineFoundMinors.isEmpty, let match = VisionRegexRegistry.cantoneseCent.firstMatch(in: trimmed, range: lineRange), match.numberOfRanges > 1 {
                let centStr = nsLine.substring(with: match.range(at: 1))
                if let c = Int64(centStr) {
                    let minor = c * 10
                    if minor > 0 && !lineFoundMinors.contains(minor) {
                        lineFoundMinors.append(minor)
                    }
                }
            }

            // Extract decimal amounts on this line
            if lineFoundMinors.isEmpty {
                let matches = VisionRegexRegistry.decimalAmount.matches(in: trimmed, range: lineRange)
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let amountStr = nsLine.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                        if let decimal = Decimal(string: amountStr) {
                            let minor = NSDecimalNumber(decimal: decimal * 100).int64Value
                            if minor > 0 && !lineFoundMinors.contains(minor) {
                                lineFoundMinors.append(minor)
                            }
                        }
                    }
                }
            }

            // Extract integer amounts with currency tokens if no decimal found on this line
            if lineFoundMinors.isEmpty {
                let matches = VisionRegexRegistry.intCurrency.matches(in: trimmed, range: lineRange)
                for match in matches {
                    let range1 = match.range(at: 1)
                    let range2 = match.range(at: 2)
                    let str = (range1.location != NSNotFound) ? nsLine.substring(with: range1) : (range2.location != NSNotFound ? nsLine.substring(with: range2) : nil)
                    if let s = str, let intVal = Int64(s), intVal > 0 {
                        let minor = intVal * 100
                        if !lineFoundMinors.contains(minor) {
                            lineFoundMinors.append(minor)
                        }
                    }
                }
            }

            // Standalone pure integer line fallback (e.g. "10") - with lower confidence score to prevent route number confusion
            if lineFoundMinors.isEmpty {
                if let intVal = Int64(trimmed), intVal > 0, intVal < 1000000 {
                    lineFoundMinors.append(intVal * 100)
                    if lineScore == 20 {
                        lineScore = 15
                    }
                }
            }

            // Multi-line lookahead propagation: if line had keywords but no amount, pass down score
            if lineFoundMinors.isEmpty {
                if tier1PositiveKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                    pendingScoreInheritance = 100
                } else if tier2PositiveKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                    pendingScoreInheritance = 70
                } else if trimmed != "HK$" && trimmed != "$" && trimmed != "¥" && trimmed != "元" && trimmed != "HKD" {
                    pendingScoreInheritance = 0
                }
            } else {
                pendingScoreInheritance = 0
            }

            for minor in lineFoundMinors {
                if !foundMinorAmounts.contains(minor) {
                    foundMinorAmounts.append(minor)
                }
                scoredCandidates.append((amount: minor, score: lineScore, isNegative: false))
            }
        }

        // Determine primary candidate amount using keyword-anchored scoring
        let eligibleCandidates = scoredCandidates.filter { !$0.isNegative && $0.score > 0 }
        let sortedEligible = eligibleCandidates.sorted { c1, c2 in
            if c1.score != c2.score {
                return c1.score > c2.score
            }
            return c1.amount > c2.amount
        }

        let primaryAmount: Int64? = sortedEligible.first?.amount ?? foundMinorAmounts.first
        let hasAmbiguousAmounts = foundMinorAmounts.count > 1

        // Refinement A: Role-Anchored Dual Extraction (DualNumberRoleExtractor)
        let dualRoles = VisionOCRService.extractDualNumberRoles(fullText)
        let remainingBalanceMinor = dualRoles.balanceMinor

        var finalPrimaryAmount: Int64? = primaryAmount

        // Self-Correction Rule:
        // If primaryAmount matches balanceCandidate (where S_balance > S_spend),
        // deterministically reject it and substitute spentCandidate.
        if let bal = dualRoles.balanceMinor, finalPrimaryAmount == bal {
            finalPrimaryAmount = dualRoles.spentMinor
        } else if finalPrimaryAmount == nil, let spent = dualRoles.spentMinor {
            finalPrimaryAmount = spent
        }

        // If overall intent was classified as loan or OTP, spent amount must be nil
        if primaryIntent == .loanOrPromoOffer || primaryIntent == .otpOrAuthAttempt {
            finalPrimaryAmount = nil
        }

        // 4. Extract Merchant
        var merchantCandidate: String? = kvMerchantRaw.map { VisionOCRService.cleanMerchantName($0) }

        // 4-pre: Transit and Known Merchant Recognition (§5.5)
        if merchantCandidate == nil {
            let transitMerchants: [(pattern: String, name: String)] = [
                ("港鐵", "港鐵"),
                ("MTR", "港鐵"),
                ("機場快綫", "港鐵"),
                ("輕鐵", "港鐵"),
                ("九巴", "九巴"),
                ("KMB", "九巴"),
                ("城巴", "城巴"),
                ("Citybus", "城巴"),
                ("新巴", "新巴"),
                ("NWFB", "新巴"),
                ("龍運巴士", "龍運巴士"),
                ("龍運", "龍運巴士"),
                ("LWB", "龍運巴士"),
                ("新大嶼山巴士", "新大嶼山巴士"),
                ("嶼巴", "新大嶼山巴士"),
                ("NLB", "新大嶼山巴士"),
                ("綠色專線小巴", "綠色專線小巴"),
                ("專線小巴", "綠色專線小巴"),
                ("綠VAN", "綠色專線小巴"),
                ("小巴", "公共小巴"),
                ("天星小輪", "天星小輪"),
                ("Star Ferry", "天星小輪"),
                ("新渡輪", "新渡輪"),
                ("港九小輪", "港九小輪"),
                ("HKKF", "港九小輪"),
                ("香港電車", "香港電車"),
                ("電車", "香港電車"),
                ("叮叮", "香港電車"),
                ("易通行", "易通行 HKeToll"),
                ("HKeToll", "易通行 HKeToll"),
                ("7-Eleven", "7-Eleven"),
                ("7-ELEVEN", "7-Eleven"),
                ("7-11", "7-Eleven"),
                ("Circle K", "Circle K"),
                ("OK便利店", "Circle K"),
                ("百佳", "百佳超級市場"),
                ("PARKnSHOP", "百佳超級市場"),
                ("惠康", "惠康超級市場"),
                ("Wellcome", "惠康超級市場"),
                ("萬寧", "萬寧"),
                ("Mannings", "萬寧"),
                ("屈臣氏", "屈臣氏"),
                ("Watsons", "屈臣氏"),
                ("大家樂", "大家樂"),
                ("Café de Coral", "大家樂"),
                ("大快活", "大快活"),
                ("Fairwood", "大快活"),
                ("美心MX", "美心MX"),
                ("美心快餐", "美心MX"),
                ("麥當勞", "麥當勞"),
                ("McDonald's", "麥當勞"),
                ("Pacific Coffee", "Pacific Coffee"),
                ("Starbucks", "Starbucks"),
                ("星巴克", "Starbucks")
            ]
            for item in transitMerchants {
                if fullText.localizedCaseInsensitiveContains(item.pattern) {
                    merchantCandidate = item.name
                    break
                }
            }
        }

        // 4a. Connective pattern extraction (e.g. "HK$68.00 於 Pacific Coffee", "10 hkd at seven eleven", "在 麥當勞 消費了")
        if merchantCandidate == nil {
            let connectiveRegexes = [VisionRegexRegistry.connective1, VisionRegexRegistry.connective2]
            for regex in connectiveRegexes {
                for line in sanitizedLines {
                    let nsLine = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
                       match.numberOfRanges > 1 {
                        let extracted = nsLine.substring(with: match.range(at: 1))
                        let cleaned = VisionOCRService.cleanMerchantName(extracted)
                        if cleaned.count >= 2 && !cleaned.localizedCaseInsensitiveContains("unknown") {
                            merchantCandidate = cleaned
                            break
                        }
                    }
                }
                if merchantCandidate != nil { break }
            }
        }

        // 4b. Explicit Chinese tags ("商戶名稱：", "收款方：", "商戶：")
        if merchantCandidate == nil {
            for (idx, line) in sanitizedLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("商戶名稱") || trimmed.contains("收款方") || trimmed.contains("商戶") || trimmed.contains("商家") || trimmed.contains("店舖") {
                    let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: ":："))
                    if parts.count > 1, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty {
                        let cleaned = VisionOCRService.cleanMerchantName(parts[1])
                        if !cleaned.isEmpty {
                            merchantCandidate = cleaned
                            break
                        }
                    } else if idx + 1 < sanitizedLines.count {
                        let cleaned = VisionOCRService.cleanMerchantName(sanitizedLines[idx + 1])
                        if !cleaned.isEmpty {
                            merchantCandidate = cleaned
                            break
                        }
                    }
                }
            }
        }

        // 4c. Clean candidate line heuristic (lines without currency tokens, status keywords, or decimal amounts)
        if merchantCandidate == nil {
            for line in sanitizedLines {
                let trimmed = VisionOCRService.cleanMerchantName(line)
                let isDigitsOnly = !trimmed.isEmpty && CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trimmed))
                let containsCurrency = trimmed.localizedCaseInsensitiveContains("HK$") ||
                                       trimmed.localizedCaseInsensitiveContains("HKD") ||
                                       trimmed.localizedCaseInsensitiveContains("USD") ||
                                       trimmed.localizedCaseInsensitiveContains("CNY") ||
                                       trimmed.localizedCaseInsensitiveContains("RMB") ||
                                       trimmed.localizedCaseInsensitiveContains("¥") ||
                                       trimmed.localizedCaseInsensitiveContains("￥") ||
                                       trimmed.localizedCaseInsensitiveContains("$")
                let containsStatus = trimmed.contains("付款成功") || trimmed.contains("支付成功") || trimmed.contains("完成") || trimmed.contains("Alipay") || trimmed.contains("交易號") || trimmed.contains("訂單號")

                if !trimmed.isEmpty &&
                   !isDigitsOnly &&
                   !containsCurrency &&
                   !containsStatus &&
                   trimmed.count >= 2 && trimmed.count <= 35 {
                    merchantCandidate = trimmed
                    break
                }
            }
        }

        // 4d. Fallback: Stripping matched amount and currency from single-line input
        if merchantCandidate == nil {
            for line in sanitizedLines {
                let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'*`"))
                if trimmed.contains("付款成功") || trimmed.contains("支付成功") || trimmed.contains("完成") || trimmed.contains("Alipay") {
                    continue
                }
                var stripped = VisionRegexRegistry.merchantStripCurrency.replace(in: trimmed)
                stripped = VisionRegexRegistry.merchantStripWords.replace(in: stripped)

                if let minor = primaryAmount {
                    let majorDouble = Double(minor) / 100.0
                    let majorInt = minor / 100
                    let decimalStr = String(format: "%.2f", majorDouble)
                    let intStr = "\(majorInt)"
                    stripped = stripped.replacingOccurrences(of: decimalStr, with: "")
                    if minor % 100 == 0 {
                        stripped = stripped.replacingOccurrences(of: "\\b\(intStr)\\b", with: "", options: .regularExpression)
                    }
                } else {
                    stripped = VisionRegexRegistry.merchantStripNumbers.replace(in: stripped)
                }

                let cleaned = VisionOCRService.cleanMerchantName(stripped)
                if cleaned.count >= 2 && cleaned.count <= 35 {
                    merchantCandidate = cleaned
                    break
                }
            }
        }

        // 5. Extract Source Transaction ID
        var txIdCandidate: String? = kvTxIdRaw
        if txIdCandidate == nil {
            let nsText = fullText as NSString
            if let match = VisionRegexRegistry.txId.firstMatch(in: fullText, range: NSRange(location: 0, length: nsText.length)),
               match.numberOfRanges > 1 {
                txIdCandidate = nsText.substring(with: match.range(at: 1))
            }
        }

        // 6. Confidence Scoring (§5.5 / ATM-12)
        let amountConf: Float = hasAmbiguousAmounts ? 0.5 : (finalPrimaryAmount != nil ? 1.0 : 0.0)
        let merchantConf: Float = merchantCandidate != nil ? (kvMerchantRaw != nil ? 1.0 : 0.9) : 0.0

        return OCRResult(
            provider: provider,
            currency: detectedCurrency,
            amountMinor: finalPrimaryAmount,
            candidateAmountsMinor: foundMinorAmounts,
            merchantRaw: merchantCandidate ?? "Unknown Merchant",
            sourceTransactionId: txIdCandidate,
            transactionDate: VisionOCRService.extractTransactionDate(from: sanitizedLines) ?? Date(),
            amountConfidence: amountConf,
            merchantConfidence: merchantConf,
            ocrEngineVersion: "AppleVision-v1.0",
            ocrTemplateVersion: "Alipay-v1.3",
            requiresManualReview: hasAmbiguousAmounts || finalPrimaryAmount == nil || merchantCandidate == nil || isHypo,
            transactionType: detectedType,
            intent: primaryIntent,
            remainingBalanceMinor: remainingBalanceMinor,
            isHypotheticalOrConditional: isHypo,
            evidencePhrase: evidencePhrase
        )
    }

    // MARK: - Natural Language & Payment Provider Helpers

    public static func detectPaymentProvider(in text: String) -> PaymentProvider {
        let upper = text.uppercased()
        if upper.contains("ALIPAYHK") || upper.contains("支付寶香港") || text.contains("AlipayHK") {
            return .alipayHK
        } else if upper.contains("ALIPAY") || text.contains("支付宝") {
            return .alipayChina
        } else if upper.contains("OCTOPUS") || text.contains("八達通") ||
                  upper.contains("MTR") || text.contains("港鐵") || text.contains("機場快綫") || text.contains("輕鐵") ||
                  text.contains("九巴") || upper.contains("KMB") ||
                  text.contains("城巴") || upper.contains("CITYBUS") ||
                  text.contains("新巴") || upper.contains("NWFB") ||
                  text.contains("龍運") || upper.contains("LWB") ||
                  text.contains("新大嶼山巴士") || text.contains("大嶼山巴士") || text.contains("嶼巴") || upper.contains("NLB") ||
                  text.contains("專線小巴") || text.contains("綠VAN") || text.contains("小巴") ||
                  text.contains("天星小輪") || text.contains("新渡輪") || text.contains("港九小輪") ||
                  text.contains("香港電車") || text.contains("電車") || text.contains("叮叮") ||
                  text.contains("易通行") || upper.contains("HKETOLL") ||
                  (text.contains("扣除") && text.contains("餘額")) {
            return .octopus
        } else if upper.contains("PAYME") {
            return .payMe
        } else if upper.contains("APPLE PAY") || upper.contains("APPLE STORE") || text.contains("錢包") {
            return .applePay
        }
        return .other
    }

    public static func extractTransactionDate(from lines: [String]) -> Date? {
        let fullText = lines.joined(separator: "\n")
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        var dateComponents: DateComponents? = nil
        var timeComponents: DateComponents? = nil

        let nsFull = fullText as NSString
        let fullRange = NSRange(location: 0, length: nsFull.length)

        if let match = VisionRegexRegistry.isoDate.firstMatch(in: fullText, range: fullRange) ??
                       VisionRegexRegistry.slashYearFirst.firstMatch(in: fullText, range: fullRange) {
            if let y = Int(nsFull.substring(with: match.range(at: 1))),
               let m = Int(nsFull.substring(with: match.range(at: 2))),
               let d = Int(nsFull.substring(with: match.range(at: 3))) {
                dateComponents = DateComponents(calendar: calendar, timeZone: timeZone, year: y, month: m, day: d)
            }
        } else if let match = VisionRegexRegistry.chineseDate.firstMatch(in: fullText, range: fullRange) {
            if let y = Int(nsFull.substring(with: match.range(at: 1))),
               let m = Int(nsFull.substring(with: match.range(at: 2))),
               let d = Int(nsFull.substring(with: match.range(at: 3))) {
                dateComponents = DateComponents(calendar: calendar, timeZone: timeZone, year: y, month: m, day: d)
            }
        } else if let match = VisionRegexRegistry.commonwealthDate.firstMatch(in: fullText, range: fullRange) {
            if let d = Int(nsFull.substring(with: match.range(at: 1))),
               let m = Int(nsFull.substring(with: match.range(at: 2))),
               let y = Int(nsFull.substring(with: match.range(at: 3))) {
                dateComponents = DateComponents(calendar: calendar, timeZone: timeZone, year: y, month: m, day: d)
            }
        }

        if let match = VisionRegexRegistry.timePattern.firstMatch(in: fullText, range: fullRange) {
            let hour = Int(nsFull.substring(with: match.range(at: 1))) ?? 0
            let minute = Int(nsFull.substring(with: match.range(at: 2))) ?? 0
            let second = match.range(at: 3).location != NSNotFound ? (Int(nsFull.substring(with: match.range(at: 3))) ?? 0) : 0
            timeComponents = DateComponents(hour: hour, minute: minute, second: second)
        }

        guard var comps = dateComponents else {
            return nil
        }

        if let time = timeComponents {
            comps.hour = time.hour
            comps.minute = time.minute
            comps.second = time.second
        } else {
            comps.hour = 12
            comps.minute = 0
            comps.second = 0
        }

        guard let parsedDate = calendar.date(from: comps) else { return nil }

        let now = Date()
        if parsedDate > now.addingTimeInterval(86400) { return nil }
        if parsedDate < now.addingTimeInterval(-365 * 5 * 86400) { return nil }

        return parsedDate
    }

    public static func cleanNaturalLanguageLines(_ lines: [String]) -> [String] {
        let salutations: [String] = [
            "好的", "好的！", "好的,", "沒問題", "好的，",
            "根據您的收據", "根據您的截圖", "根據收據", "根據截圖", "根據扣款文字",
            "為您整理如下", "為您整理扣款資訊如下", "提取資訊如下", "識別結果如下",
            "HERE IS", "BASED ON", "SURE", "HERE ARE",
            "祝您生活愉快", "祝您有美好的一天", "希望這對您有幫助", "HAVE A NICE DAY", "HOPE THIS HELPS"
        ]

        var result: [String] = []
        for line in lines {
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            var isPureSalutation = false
            for s in salutations {
                if trimmed.localizedCaseInsensitiveContains(s) && trimmed.count <= s.count + 4 {
                    isPureSalutation = true
                    break
                }
            }
            if isPureSalutation { continue }

            for s in ["好的！", "好的，", "好的,", "好的", "已為您識別：", "已識別：", "識別結果：", "Apple Intelligence extracted:"] {
                if trimmed.hasPrefix(s) {
                    trimmed = String(trimmed.dropFirst(s.count)).trimmingCharacters(in: .whitespaces)
                }
            }

            if !trimmed.isEmpty {
                result.append(trimmed)
            }
        }
        return result
    }

    public static func cleanMerchantName(_ input: String) -> String {
        var str = input.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'*`.,:;!。，：；！、"))

        let prefixes = ["商戶是", "商家是", "收款方是", "店鋪是", "購買於", "付款給", "這是一筆在", "這筆交易是在", "在"]
        for p in prefixes {
            if str.hasPrefix(p) {
                str = String(str.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        str = VisionRegexRegistry.trailingAction.replace(in: str)
        str = VisionRegexRegistry.trailingPunctuation.replace(in: str)

        return str.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'*`.,:;!。，：；！、"))
    }

    #if canImport(Vision) && canImport(CoreGraphics)
    /// Execute on-device Vision VNRecognizeTextRequest on downsampled image data (Max 2560px to prevent Jetsam OOM)
    public func recognizeReceipt(imageData: Data) async throws -> OCRResult {
        guard !imageData.isEmpty else {
            return parseRecognizedStrings([])
        }

        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return parseRecognizedStrings([])
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2560,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) ?? CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return parseRecognizedStrings([])
        }
        return try await recognizeReceipt(cgImage: cgImage)
        #else
        return parseRecognizedStrings([])
        #endif
    }

    /// Execute on-device Vision VNRecognizeTextRequest on a CGImage
    public func recognizeReceipt(cgImage: CGImage) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: self.parseRecognizedStrings([]))
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let result = self.parseRecognizedStrings(lines)
                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif
}
