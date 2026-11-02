import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Vision OCR Engine Tests")
struct VisionOCRTests {
    let ocrService = VisionOCRService.shared

    @Test("AlipayHK: Single amount and merchant parsing")
    func testAlipayHKSingleAmount() {
        let lines = [
            "AlipayHK",
            "付款成功",
            "商戶名稱：Café de Coral 大家樂",
            "HK$ 62.00",
            "交易號：20261023220014008888",
            "完成"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.provider == .alipayHK)
        #expect(result.currency == "HKD")
        #expect(result.amountMinor == 6200)
        #expect(result.candidateAmountsMinor == [6200])
        #expect(result.merchantRaw == "Café de Coral 大家樂")
        #expect(result.sourceTransactionId == "20261023220014008888")
        #expect(result.requiresManualReview == false)
        #expect(result.amountConfidence == 1.0)
    }

    @Test("Alipay China: CNY Currency and Merchant Detection")
    func testAlipayChinaDetection() {
        let lines = [
            "支付宝",
            "支付成功",
            "收款方：喜茶 HEYTEA 深圳萬象城店",
            "¥ 28.50",
            "訂單號：20261024888899990000",
            "立即查看"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.provider == .alipayChina)
        #expect(result.currency == "CNY")
        #expect(result.amountMinor == 2850)
        #expect(result.merchantRaw == "喜茶 HEYTEA 深圳萬象城店")
        #expect(result.sourceTransactionId == "20261024888899990000")
        #expect(result.requiresManualReview == false)
    }

    @Test("Ambiguous Amounts: Original Price vs. Discounted Price requires manual review")
    func testAmbiguousMultiAmountDetection() {
        // As defined in §5.5 & S04: Original HK$85.00 vs actual paid HK$58.00
        let lines = [
            "AlipayHK",
            "付款成功",
            "大家樂 Café de Coral",
            "訂單原價 HK$85.00",
            "優惠券折抵 -HK$27.00",
            "實付金額 HK$58.00",
            "流水號：2026102511223344"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.candidateAmountsMinor.contains(8500))
        #expect(!result.candidateAmountsMinor.contains(2700))
        #expect(result.candidateAmountsMinor.contains(5800))
        #expect(result.amountMinor == 5800)
        #expect(result.requiresManualReview == true)
        #expect(result.amountConfidence == 0.5)
    }

    @Test("Fallback Merchant Extraction: When colon delimiter is missing")
    func testFallbackMerchantExtraction() {
        let lines = [
            "759 阿信屋",
            "付款成功",
            "HK$ 34.50",
            "完成"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.merchantRaw == "759 阿信屋")
        #expect(result.amountMinor == 3450)
        #expect(result.requiresManualReview == false)
    }

    @Test("Thousands Separator: Parses amounts with commas correctly")
    func testCommaFormattedAmount() {
        let lines = [
            "Apple Store ifc mall",
            "付款成功",
            "HK$ 1,250.00",
            "完成"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 125000)
        #expect(result.requiresManualReview == false)
    }

    @Test("Integer amount parsing: 10 hkd, HK$10, and standalone 10")
    func testIntegerAmountParsing() {
        let res1 = ocrService.parseRecognizedStrings(["10 hkd"])
        #expect(res1.amountMinor == 1000)
        #expect(res1.currency == "HKD")

        let res2 = ocrService.parseRecognizedStrings(["HK$10"])
        #expect(res2.amountMinor == 1000)
        #expect(res2.currency == "HKD")

        let res3 = ocrService.parseRecognizedStrings(["10"])
        #expect(res3.amountMinor == 1000)
    }

    @Test("English key-value format parsing: amount, merchant, store, payee, currency")
    func testEnglishKeyValueParsing() {
        let line1 = "amount: 10 hkd, merchant: seven eleven"
        let res1 = ocrService.parseRecognizedStrings([line1])
        #expect(res1.amountMinor == 1000)
        #expect(res1.currency == "HKD")
        #expect(res1.merchantRaw == "seven eleven")
        #expect(res1.requiresManualReview == false)

        let line2 = "store: Starbucks, price: 45, currency: USD"
        let res2 = ocrService.parseRecognizedStrings([line2])
        #expect(res2.amountMinor == 4500)
        #expect(res2.currency == "USD")
        #expect(res2.merchantRaw == "Starbucks")

        let line3 = "payee: Wellcome, cost: 88.50, cur: HKD"
        let res3 = ocrService.parseRecognizedStrings([line3])
        #expect(res3.amountMinor == 8850)
        #expect(res3.currency == "HKD")
        #expect(res3.merchantRaw == "Wellcome")
    }

    @Test("Markdown, quoted, and JSON formatted AI outputs")
    func testMarkdownAndQuotedAppleIntelligenceOutputs() {
        // Markdown bold
        let md = "**amount**: 10 hkd, **merchant**: seven eleven"
        let resMd = ocrService.parseRecognizedStrings([md])
        #expect(resMd.amountMinor == 1000)
        #expect(resMd.currency == "HKD")
        #expect(resMd.merchantRaw == "seven eleven")
        #expect(resMd.requiresManualReview == false)

        // Quoted JSON-like format
        let jsonLike = #"{"amount": "10 hkd", "merchant": "seven eleven"}"#
        let resJson = ocrService.parseRecognizedStrings([jsonLike])
        #expect(resJson.amountMinor == 1000)
        #expect(resJson.currency == "HKD")
        #expect(resJson.merchantRaw == "seven eleven")

        // Single quoted format
        let quotes = "amount: '45.00 USD', store: 'Starbucks'"
        let resQuotes = ocrService.parseRecognizedStrings([quotes])
        #expect(resQuotes.amountMinor == 4500)
        #expect(resQuotes.currency == "USD")
        #expect(resQuotes.merchantRaw == "Starbucks")
    }

    @Test("Natural language connective extraction and single-line brand preservation")
    func testConnectiveNaturalLanguageExtraction() {
        // "HK$68.00 於 Pacific Coffee"
        let res1 = ocrService.parseRecognizedStrings(["HK$68.00 於 Pacific Coffee"])
        #expect(res1.amountMinor == 6800)
        #expect(res1.currency == "HKD")
        #expect(res1.merchantRaw == "Pacific Coffee")

        // "10 hkd at seven eleven"
        let res2 = ocrService.parseRecognizedStrings(["10 hkd at seven eleven"])
        #expect(res2.amountMinor == 1000)
        #expect(res2.currency == "HKD")
        #expect(res2.merchantRaw == "seven eleven")

        // "7-Eleven 10 hkd" -> brand number 7 in 7-Eleven preserved
        let res3 = ocrService.parseRecognizedStrings(["7-Eleven 10 hkd"])
        #expect(res3.amountMinor == 1000)
        #expect(res3.currency == "HKD")
        #expect(res3.merchantRaw == "7-Eleven")
    }

    @Test("Currency isolation: foreign currency code inside merchant name does not pollute base currency")
    func testCurrencyIsolationWhenMerchantContainsForeignCurrencyCode() {
        // Merchant contains "USD", but amount explicitly says "10 hkd"
        let line = "amount: 10 hkd, merchant: USD Global Express"
        let res = ocrService.parseRecognizedStrings([line])
        #expect(res.amountMinor == 1000)
        #expect(res.currency == "HKD")
        #expect(res.merchantRaw == "USD Global Express")
    }

    @Test("Octopus reader screenshot OCR: parses 1250 minor units and ignores 14520 balance")
    func testOctopusReaderScreenshotOCR() {
        let lines = [
            "港鐵",
            "扣除 $12.50",
            "餘額 $145.20"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 1250)
        #expect(result.currency == "HKD")
        #expect(result.provider == .octopus)
        #expect(result.merchantRaw == "港鐵")
        #expect(result.requiresManualReview == false)
        #expect(result.amountConfidence == 1.0)
    }

    @Test("Capscreen with discounts and promotions: parses 4500, not 200")
    func testCapscreenWithDiscounts() {
        let lines = [
            "7-Eleven",
            "實付 $45.00",
            "優惠 $2.00"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 4500)
        #expect(result.currency == "HKD")
        #expect(result.merchantRaw == "7-Eleven")
        #expect(result.candidateAmountsMinor == [4500])
        #expect(result.requiresManualReview == false)
        #expect(result.amountConfidence == 1.0)
    }

    @Test("Pure coupon or discount screenshot: does not parse discount amount as expense")
    func testPureCouponDoesNotParseAsExpense() {
        let lines = [
            "7-Eleven",
            "會員優惠券 $20.00"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == nil)
        #expect(result.candidateAmountsMinor.isEmpty)
        #expect(result.requiresManualReview == true)
    }

    @Test("Octopus reader with colon delimiters parses correctly")
    func testOctopusReaderWithColons() {
        let lines = [
            "港鐵出閘",
            "扣除：$14.50",
            "餘額：$88.00"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 1450)
        #expect(result.provider == .octopus)
        #expect(result.requiresManualReview == false)
        #expect(result.merchantRaw == "港鐵")
    }

    @Test("Octopus reader with low balance: ignores $5.00 balance and extracts $12.50 fare")
    func testOctopusLowBalanceIgnored() {
        let lines = [
            "九巴 KMB",
            "車費 $12.50",
            "卡片餘額 $5.00"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 1250)
        #expect(result.provider == .octopus)
        #expect(result.merchantRaw == "九巴")
        #expect(result.requiresManualReview == false)
    }

    @Test("Transit merchant recognition: MTR, KMB, Citybus, Star Ferry, Tramways, Light Rail")
    func testTransitMerchantRecognition() {
        let res1 = ocrService.parseRecognizedStrings(["MTR", "收費 $9.80"])
        #expect(res1.merchantRaw == "港鐵")
        #expect(res1.amountMinor == 980)

        let res2 = ocrService.parseRecognizedStrings(["城巴 Citybus", "車費 $15.30"])
        #expect(res2.merchantRaw == "城巴")
        #expect(res2.amountMinor == 1530)

        let res3 = ocrService.parseRecognizedStrings(["天星小輪", "扣款 $5.00"])
        #expect(res3.merchantRaw == "天星小輪")
        #expect(res3.amountMinor == 500)

        let res4 = ocrService.parseRecognizedStrings(["香港電車", "車費 $3.00"])
        #expect(res4.merchantRaw == "香港電車")
        #expect(res4.amountMinor == 300)
        #expect(res4.provider == .octopus)

        let res5 = ocrService.parseRecognizedStrings(["輕鐵出站", "扣除 $4.20", "餘額 $50.00"])
        #expect(res5.merchantRaw == "港鐵")
        #expect(res5.amountMinor == 420)
        #expect(res5.provider == .octopus)
    }

    @Test("Multi-line amounts: label on previous line propagates high keyword confidence score")
    func testMultiLineAmountScorePropagation() {
        let lines = [
            "大家樂",
            "訂單原價 HK$85.00",
            "實付金額",
            "HK$ 58.00"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 5800)
        #expect(result.merchantRaw == "大家樂")
        #expect(result.candidateAmountsMinor.contains(5800))
        #expect(result.candidateAmountsMinor.contains(8500))
    }

    @Test("Bilingual colon keys with slashes: 扣除/Deducted, 餘額/Remaining, 實付/Net")
    func testBilingualSlashColonKeys() {
        let lines = [
            "7-Eleven",
            "扣除/Deducted: HK$ 12.50",
            "餘額/Remaining: HK$ 145.20"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 1250)
        #expect(result.currency == "HKD")
        #expect(result.merchantRaw == "7-Eleven")
        #expect(result.provider == .octopus)

        let netLine = ["實付/Net: $68.00", "商戶/Merchant: Pacific Coffee"]
        let resNet = ocrService.parseRecognizedStrings(netLine)
        #expect(resNet.amountMinor == 6800)
        #expect(resNet.merchantRaw == "Pacific Coffee")
    }

    @Test("Single-line Octopus notifications: extracts deduction and safely strips balance on same line")
    func testSingleLineOctopusNotificationSeparation() {
        // Notification text from Octopus app / SMS on a single line
        let notif1 = ["八達通扣款通知：已於 港鐵 扣除 HK$14.50，卡片餘額為 HK$128.50。"]
        let res1 = ocrService.parseRecognizedStrings(notif1)

        #expect(res1.amountMinor == 1450)
        #expect(res1.provider == .octopus)
        #expect(res1.merchantRaw == "港鐵")
        #expect(!res1.candidateAmountsMinor.contains(12850))

        let notif2 = ["九巴車費 $12.50 餘額 $45.00"]
        let res2 = ocrService.parseRecognizedStrings(notif2)

        #expect(res2.amountMinor == 1250)
        #expect(res2.merchantRaw == "九巴")
        #expect(!res2.candidateAmountsMinor.contains(4500))
    }

    @Test("Cantonese colloquial currency: 蚊, 毫, and 蚊半 parsing")
    func testCantoneseColloquialCurrencyParsing() {
        let res1 = ocrService.parseRecognizedStrings(["搭九巴 12蚊5毫"])
        #expect(res1.amountMinor == 1250)
        #expect(res1.currency == "HKD")
        #expect(res1.merchantRaw == "九巴")

        let res2 = ocrService.parseRecognizedStrings(["大家樂 45蚊半"])
        #expect(res2.amountMinor == 4550)
        #expect(res2.currency == "HKD")
        #expect(res2.merchantRaw == "大家樂")

        let res3 = ocrService.parseRecognizedStrings(["車費 12.5蚊"])
        #expect(res3.amountMinor == 1250)
        #expect(res3.currency == "HKD")

        let res4 = ocrService.parseRecognizedStrings(["叮叮 3蚊"])
        #expect(res4.amountMinor == 300)
        #expect(res4.provider == .octopus)
        #expect(res4.merchantRaw == "香港電車")
    }

    @Test("Fullwidth character normalization: converts fullwidth Unicode digits and colons to ASCII")
    func testFullWidthCharacterNormalization() {
        let lines = [
            "商戶名稱：７５９ 阿信屋",
            "實付金額：４５．００",
            "訂單號：２０２６１０２８"
        ]

        let result = ocrService.parseRecognizedStrings(lines)

        #expect(result.amountMinor == 4500)
        #expect(result.merchantRaw == "759 阿信屋")
    }

    @Test("Dot-matrix OCR letter-O confusion in amounts: handles $45.OO and $12.O5 gracefully")
    func testDotMatrixLetterOConfusion() {
        let res1 = ocrService.parseRecognizedStrings(["Starbucks", "實付 $45.OO"])
        #expect(res1.amountMinor == 4500)
        #expect(res1.merchantRaw == "Starbucks")

        let res2 = ocrService.parseRecognizedStrings(["7-Eleven", "實付 $12.O5"])
        #expect(res2.amountMinor == 1205)
    }

    @Test("Transaction type detection: Octopus AAVS top up vs payment vs refund")
    func testTransactionTypeInference() {
        let topUpRes = ocrService.parseRecognizedStrings(["八達通自動增值 HK$500.00", "卡片餘額 HK$585.00"])
        #expect(topUpRes.transactionType == .topUp)
        #expect(topUpRes.amountMinor == 50000)
        #expect(topUpRes.provider == .octopus)

        let refundRes = ocrService.parseRecognizedStrings(["商戶：Zara", "退款金額：HK$299.00"])
        #expect(refundRes.transactionType == .refund)
        #expect(refundRes.amountMinor == 29900)
    }

    @Test("Expanded Hong Kong transport operators: LWB, NLB, Green Minibus, HKeToll")
    func testExpandedHKTransportOperators() {
        let resLWB = ocrService.parseRecognizedStrings(["龍運巴士 A31", "車費 $19.80"])
        #expect(resLWB.merchantRaw == "龍運巴士")
        #expect(resLWB.provider == .octopus)
        #expect(resLWB.amountMinor == 1980)

        let resNLB = ocrService.parseRecognizedStrings(["新大嶼山巴士 38", "車費 $3.40"])
        #expect(resNLB.merchantRaw == "新大嶼山巴士")
        #expect(resNLB.provider == .octopus)

        let resGMB = ocrService.parseRecognizedStrings(["綠色專線小巴 403A", "車費 $10.50"])
        #expect(resGMB.merchantRaw == "綠色專線小巴")
        #expect(resGMB.provider == .octopus)

        let resHKeToll = ocrService.parseRecognizedStrings(["易通行 HKeToll", "隧道費 $8.00"])
        #expect(resHKeToll.merchantRaw == "易通行 HKeToll")
        #expect(resHKeToll.provider == .octopus)
    }
}
