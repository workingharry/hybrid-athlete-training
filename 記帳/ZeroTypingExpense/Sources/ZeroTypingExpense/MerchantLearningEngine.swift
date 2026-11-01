import Foundation

public struct MerchantRule: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var canonicalName: String
    public var aliases: [String]
    public var defaultCategoryId: UUID
    public var isUserDefined: Bool
    public var lastConfirmedAt: Date

    public init(
        id: UUID = UUID(),
        canonicalName: String,
        aliases: [String] = [],
        defaultCategoryId: UUID,
        isUserDefined: Bool = false,
        lastConfirmedAt: Date = Date()
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.defaultCategoryId = defaultCategoryId
        self.isUserDefined = isUserDefined
        self.lastConfirmedAt = lastConfirmedAt
    }
}

public actor MerchantLearningEngine {
    private var rules: [String: MerchantRule] = [:] // normalized alias/canonical -> rule
    private var rulesById: [UUID: MerchantRule] = [:]

    public init() {}

    private func normalize(_ name: String) -> String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func registerRule(_ rule: MerchantRule) {
        rulesById[rule.id] = rule
        let canonicalKey = normalize(rule.canonicalName)
        rules[canonicalKey] = rule
        for alias in rule.aliases {
            rules[normalize(alias)] = rule
        }
    }

    public func matchCategory(forMerchantRaw rawName: String) -> (canonicalName: String, categoryId: UUID, confidence: Float)? {
        let key = normalize(rawName)

        // 1. Direct exact match (canonical or alias)
        if let rule = rules[key] {
            return (rule.canonicalName, rule.defaultCategoryId, rule.isUserDefined ? 1.0 : 0.95)
        }

        // 2. Greedy longest-substring match to prevent short-token shadowing (e.g., "Pacific Coffee" > "Coffee")
        let sortedRules = rulesById.values.sorted { r1, r2 in
            r1.canonicalName.count > r2.canonicalName.count
        }

        for rule in sortedRules {
            let canon = normalize(rule.canonicalName)
            if key.contains(canon) {
                return (rule.canonicalName, rule.defaultCategoryId, 0.85)
            }
            for alias in rule.aliases {
                let normAlias = normalize(alias)
                if key.contains(normAlias) {
                    return (rule.canonicalName, rule.defaultCategoryId, 0.85)
                }
            }
        }

        return nil
    }

    /// User confirms or overrides a merchant category (§8.7)
    public func learnMerchantMapping(rawName: String, canonicalName: String, categoryId: UUID) {
        let key = normalize(canonicalName)
        if var existingRule = rules[key] {
            if !existingRule.aliases.contains(rawName) && normalize(rawName) != key {
                existingRule.aliases.append(rawName)
            }
            existingRule.defaultCategoryId = categoryId
            existingRule.isUserDefined = true
            existingRule.lastConfirmedAt = Date()
            registerRule(existingRule)
        } else {
            let newRule = MerchantRule(
                canonicalName: canonicalName,
                aliases: normalize(rawName) != key ? [rawName] : [],
                defaultCategoryId: categoryId,
                isUserDefined: true,
                lastConfirmedAt: Date()
            )
            registerRule(newRule)
        }
    }
}
