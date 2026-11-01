import Foundation

public enum URLSchemeAction: Equatable, Sendable {
    case record(amountMinor: Int64, currency: String, merchant: String, categoryName: String?, notes: String?)
    case clipboard
    case screenshot
    case onboarding
    case reset
    case unknown
}

public enum URLHandleResult: Sendable {
    case recorded(TransactionEntity)
    case clipboardParsed(TransactionEntity)
    case openedOnboarding
    case resetCompleted
    case error(String)
}

public struct URLSchemeHandler: Sendable {
    public static func parse(url: URL) -> URLSchemeAction? {
        guard let scheme = url.scheme?.lowercased(), scheme == "zerotyping" else {
            return nil
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let command = host.isEmpty ? path : host

        switch command {
        case "record":
            return parseRecordCommand(url: url)
        case "clip", "clipboard":
            return .clipboard
        case "screenshot", "screen":
            return .screenshot
        case "onboarding", "setup", "guide":
            return .onboarding
        case "reset", "clear":
            return .reset
        default:
            return .unknown
        }
    }

    private static func parseRecordCommand(url: URL) -> URLSchemeAction {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .unknown
        }

        let queryItems = components.queryItems ?? []
        var rawAmount: String?
        var rawMerchant: String?
        var rawCurrency: String?
        var rawCategory: String?
        var rawNotes: String?

        // If query contains notes=, robustly extract the tail to avoid premature splitting on unencoded & or #
        if let fullQuery = url.query, let range = fullQuery.range(of: "notes=") {
            let notesSubstring = String(fullQuery[range.upperBound...])
            rawNotes = notesSubstring.removingPercentEncoding ?? notesSubstring
        }

        for item in queryItems {
            let name = item.name.lowercased()
            switch name {
            case "amount", "price", "val", "cost":
                rawAmount = item.value
            case "merchant", "store", "name", "payee", "shop":
                rawMerchant = item.value
            case "currency", "cur":
                rawCurrency = item.value
            case "category", "cat":
                rawCategory = item.value
            case "notes", "note", "desc", "memo":
                if rawNotes == nil {
                    rawNotes = item.value
                }
            default:
                break
            }
        }

        var amountMinor = parseAmountMinor(from: rawAmount)
        var cleanMerchant = rawMerchant.map { sanitizeFormula($0) }
        var cleanCurrency = sanitizeFormula(rawCurrency ?? "HKD").uppercased()
        let cleanCategory = rawCategory.map { sanitizeFormula($0) }
        let cleanNotes = rawNotes.map { sanitizeFormula($0) }

        // If rawAmount or merchant is missing, parse notes with VisionOCRService
        if let notes = cleanNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let isMerchantMissing = (cleanMerchant == nil || cleanMerchant?.isEmpty == true || cleanMerchant == "快捷消費")
            let isAmountMissing = (amountMinor == 0)

            if isAmountMissing || isMerchantMissing {
                let lines = notes.components(separatedBy: .newlines)
                let ocrResult = VisionOCRService.shared.parseRecognizedStrings(lines)
                if isAmountMissing, let detectedAmount = ocrResult.amountMinor, detectedAmount > 0 {
                    amountMinor = detectedAmount
                }
                if isMerchantMissing, let detectedMerchant = ocrResult.merchantRaw, detectedMerchant != "Unknown Merchant", !detectedMerchant.isEmpty {
                    cleanMerchant = detectedMerchant
                }
                if (cleanCurrency.isEmpty || cleanCurrency == "HKD") && ocrResult.currency != "HKD" {
                    cleanCurrency = ocrResult.currency
                }
            }
        }

        let finalMerchant = cleanMerchant ?? "快捷消費"
        let finalCurrency = cleanCurrency.isEmpty ? "HKD" : cleanCurrency

        return .record(
            amountMinor: amountMinor,
            currency: finalCurrency,
            merchant: finalMerchant.isEmpty ? "快捷消費" : finalMerchant,
            categoryName: cleanCategory,
            notes: cleanNotes
        )
    }

    public static func parseAmountMinor(from text: String?) -> Int64 {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return 0
        }

        // Clean currency symbols and commas
        let cleaned = raw
            .replacingOccurrences(of: "HK$", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let doubleVal = Double(cleaned), doubleVal.isFinite, doubleVal >= 0 {
            return Int64(round(doubleVal * 100))
        }

        return 0
    }

    public static func sanitizeFormula(_ input: String) -> String {
        var str = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Neutralize Excel/CSV/Shell formula injection prefixes
        let dangerousPrefixes = ["=", "+", "-", "@", "\t", "\r", "|", "cmd", "powershell"]
        var changed = true
        while changed {
            changed = false
            for p in dangerousPrefixes {
                if str.lowercased().hasPrefix(p) {
                    str.removeFirst(p.count)
                    str = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                }
            }
        }
        return str
    }
}
