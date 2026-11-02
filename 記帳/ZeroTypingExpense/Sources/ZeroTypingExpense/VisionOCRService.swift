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
        requiresManualReview: Bool = false
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
    }
}

public final class VisionOCRService: Sendable {
    public static let shared = VisionOCRService()

    public init() {}

    /// Sanitize text lines to prevent CSV / formula injection (=, +, -, @, cmd, \t, \r, |)
    public static func sanitizeFormulaPrefix(_ input: String) -> String {
        var str = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check for CSV / Excel formula injection prefixes
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

    /// Parse array of OCR recognized text lines into structured financial receipt details
    public func parseRecognizedStrings(_ lines: [String]) -> OCRResult {
        // Sanitize incoming lines against formula injection
        let rawSanitizedLines = lines.map { VisionOCRService.sanitizeFormulaPrefix($0) }
        let sanitizedLines = VisionOCRService.cleanNaturalLanguageLines(rawSanitizedLines)
        let fullText = sanitizedLines.joined(separator: "\n")

        // 1. Detect Provider & Initial Currency
        let provider = VisionOCRService.detectPaymentProvider(in: fullText)
        let isAlipayChina = (provider == .alipayChina)
        var detectedCurrency = isAlipayChina ? "CNY" : "HKD"

        // 2. Extract Key-Value Pairs from lines and comma-delimited segments
        var kvAmountRaw: String?
        var kvMerchantRaw: String?
        var kvCurrencyRaw: String?
        var kvTxIdRaw: String?

        let kvPattern = #"(?i)(?:^|[,;\n{\[])\s*[\*_\-`'"]*([A-Za-z_\u4e00-\u9fa5]+)[\*_\-`'"]*\s*[:=：]\s*[\*`'"]*([^,;\n}\]]+?)[\*`'"]*(?=[,;\n}\]]|$)"#
        if let kvRegex = try? NSRegularExpression(pattern: kvPattern, options: []) {
            let nsText = fullText as NSString
            let matches = kvRegex.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let key = nsText.substring(with: match.range(at: 1))
                        .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n*_-`'\""))
                        .lowercased()
                    let val = nsText.substring(with: match.range(at: 2))
                        .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n*`'\""))

                    switch key {
                    case "amount", "price", "cost", "val", "total", "sum", "實付金額", "實付", "实际支付", "支付金額", "扣款金額", "總計", "合計", "金額":
                        if kvAmountRaw == nil || key == "實付金額" || key == "實付" || key == "实际支付" || key == "amount" {
                            kvAmountRaw = val
                        }
                    case "merchant", "store", "payee", "shop", "vendor", "seller", "商戶名稱", "收款方", "商戶", "商家", "店舖":
                        if kvMerchantRaw == nil || key == "merchant" || key == "商戶名稱" || key == "收款方" {
                            kvMerchantRaw = val
                        }
                    case "currency", "cur", "幣別", "貨幣":
                        kvCurrencyRaw = val
                    case "txid", "transaction", "order", "交易號", "訂單號", "流水號", "單號":
                        kvTxIdRaw = val
                    default:
                        break
                    }
                }
            }
        }

        // Helper to extract known currency from a string token
        func extractCurrencyCode(from text: String) -> String? {
            let upper = text.uppercased()
            if upper.contains("HKD") || upper.contains("HK$") || upper.contains("港幣") {
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
            let cleaned = str
                .replacingOccurrences(of: "(?i)HK\\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\\$|港幣|元", with: "", options: .regularExpression)
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'*`"))

            if cleaned.contains(".") {
                if let decimal = Decimal(string: cleaned) {
                    return NSDecimalNumber(decimal: decimal * 100).int64Value
                }
            } else if let intVal = Int64(cleaned), intVal > 0 {
                return intVal * 100
            }
            return nil
        }

        if let kvAmount = kvAmountRaw, let parsed = parseAmountString(kvAmount) {
            foundMinorAmounts.append(parsed)
            scoredCandidates.append((amount: parsed, score: 95, isNegative: false))
        }

        let amountPattern = #"(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)?\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2}|[0-9]+\.[0-9]{1,2})"#
        let intCurrencyPattern = #"(?i)(?:HK\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\$)\s*([0-9]{1,7})(?![0-9]|\.[0-9])|(?<![0-9])([0-9]{1,7})\s*(?:HKD|HK\$|USD|CNY|RMB|EUR|GBP|JPY|元|港幣)(?![0-9]|\.[0-9])"#

        // Negative line filter keywords
        let balanceLineKeywords = ["餘額", "卡片餘額", "$0.00"]
        let discountLineKeywords = ["優惠", "折扣", "回贈", "積分"]

        // Positive payment keywords
        let tier1PositiveKeywords = ["扣除", "實付", "實際支付", "扣款金額", "扣款", "收費", "車費"]
        let tier2PositiveKeywords = ["支出", "消費", "合計", "總計", "总计", "金額", "金额"]

        for line in sanitizedLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Balance lines (e.g. Octopus "餘額 $145.20") and $0.00 are completely discarded from candidate amounts
            let isBalanceLine = balanceLineKeywords.contains { trimmed.contains($0) }
            if isBalanceLine {
                continue
            }

            // Discount lines (e.g. "優惠券折抵 -HK$27.00") should never be chosen as the paid amount
            let isDiscountLine = discountLineKeywords.contains { trimmed.contains($0) }

            var lineScore = 20
            if tier1PositiveKeywords.contains(where: { trimmed.contains($0) }) {
                lineScore = 100
            } else if tier2PositiveKeywords.contains(where: { trimmed.contains($0) }) {
                lineScore = 70
            }

            var lineFoundMinors: [Int64] = []

            // Extract decimal amounts on this line
            if let regex = try? NSRegularExpression(pattern: amountPattern, options: []) {
                let nsLine = trimmed as NSString
                let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsLine.length))
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
                if let regex = try? NSRegularExpression(pattern: intCurrencyPattern, options: []) {
                    let nsLine = trimmed as NSString
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsLine.length))
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
            }

            // Standalone pure integer line fallback (e.g. "10")
            if lineFoundMinors.isEmpty {
                if let intVal = Int64(trimmed), intVal > 0, intVal < 1000000 {
                    lineFoundMinors.append(intVal * 100)
                }
            }

            for minor in lineFoundMinors {
                if !foundMinorAmounts.contains(minor) {
                    foundMinorAmounts.append(minor)
                }
                scoredCandidates.append((amount: minor, score: isDiscountLine ? -100 : lineScore, isNegative: isDiscountLine))
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

        // 4. Extract Merchant
        var merchantCandidate: String? = kvMerchantRaw.map { VisionOCRService.cleanMerchantName($0) }

        // 4-pre: Transit and Known Merchant Recognition (§5.5)
        if merchantCandidate == nil {
            let transitMerchants: [(pattern: String, name: String)] = [
                ("港鐵", "港鐵"),
                ("MTR", "港鐵"),
                ("九巴", "九巴"),
                ("KMB", "九巴"),
                ("城巴", "城巴"),
                ("Citybus", "城巴"),
                ("新巴", "新巴"),
                ("NWFB", "新巴"),
                ("天星小輪", "天星小輪"),
                ("Star Ferry", "天星小輪"),
                ("7-Eleven", "7-Eleven"),
                ("7-ELEVEN", "7-Eleven"),
                ("7-11", "7-Eleven"),
                ("Circle K", "Circle K"),
                ("OK便利店", "Circle K")
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
            let connectivePatterns = [
                #"(?i)(?:於|在|at|to)\s*([A-Za-z0-9_\u4e00-\u9fa5\s&'. -]{2,35})"#,
                #"(?i)([A-Za-z0-9_\u4e00-\u9fa5\s&'. -]{2,35})\s+(?:於|在)\s+"#
            ]
            for pat in connectivePatterns {
                if let regex = try? NSRegularExpression(pattern: pat, options: []) {
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
                var stripped = trimmed
                    .replacingOccurrences(of: "(?i)HK\\$|HKD|USD|CNY|RMB|EUR|GBP|JPY|¥|￥|\\$|港幣|元", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "(?i)amount|price|merchant|store|payee|cost|消費|付款|支出|扣款|成功", with: "", options: .regularExpression)

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
                    stripped = stripped.replacingOccurrences(of: #"[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2}|[0-9]+"#, with: "", options: .regularExpression)
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
            let txIdPattern = #"(?:交易號|訂單號|流水號|單號|txid|transaction|order)[:：\s]*([A-Za-z0-9_-]{8,})"#
            if let regex = try? NSRegularExpression(pattern: txIdPattern, options: .caseInsensitive) {
                let nsText = fullText as NSString
                if let match = regex.firstMatch(in: fullText, range: NSRange(location: 0, length: nsText.length)),
                   match.numberOfRanges > 1 {
                    txIdCandidate = nsText.substring(with: match.range(at: 1))
                }
            }
        }

        // 6. Confidence Scoring (§5.5 / ATM-12)
        let amountConf: Float = hasAmbiguousAmounts ? 0.5 : (primaryAmount != nil ? 1.0 : 0.0)
        let merchantConf: Float = merchantCandidate != nil ? (kvMerchantRaw != nil ? 1.0 : 0.9) : 0.0

        return OCRResult(
            provider: provider,
            currency: detectedCurrency,
            amountMinor: primaryAmount,
            candidateAmountsMinor: foundMinorAmounts,
            merchantRaw: merchantCandidate ?? "Unknown Merchant",
            sourceTransactionId: txIdCandidate,
            transactionDate: Date(),
            amountConfidence: amountConf,
            merchantConfidence: merchantConf,
            ocrEngineVersion: "AppleVision-v1.0",
            ocrTemplateVersion: "Alipay-v1.3",
            requiresManualReview: hasAmbiguousAmounts || primaryAmount == nil || merchantCandidate == nil
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
                  upper.contains("MTR") || text.contains("港鐵") ||
                  text.contains("九巴") || upper.contains("KMB") ||
                  text.contains("城巴") || upper.contains("CITYBUS") ||
                  text.contains("新巴") || text.contains("天星小輪") ||
                  (text.contains("扣除") && text.contains("餘額")) {
            return .octopus
        } else if upper.contains("PAYME") {
            return .payMe
        } else if upper.contains("APPLE PAY") || upper.contains("APPLE STORE") || text.contains("錢包") {
            return .applePay
        }
        return .applePay
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

        let trailingPatterns = [
            #"(?i)[\s]*(?:消費了|消費|買了|支付了|扣款|付款|結帳|買早餐|吃午餐|paid|paying|spent|for|了)[\s]*$"#,
            #"[，,。！!？?、;；].*$"#
        ]
        for pat in trailingPatterns {
            str = str.replacingOccurrences(of: pat, with: "", options: .regularExpression)
        }

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
