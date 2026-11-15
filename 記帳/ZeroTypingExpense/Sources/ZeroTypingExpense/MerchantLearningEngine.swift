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

    private enum CodingKeys: String, CodingKey {
        case id
        case canonicalName
        case aliases
        case defaultCategoryId
        case isUserDefined
        case lastConfirmedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.canonicalName = (try? container.decodeIfPresent(String.self, forKey: .canonicalName)) ?? ""
        self.aliases = (try? container.decodeIfPresent([String].self, forKey: .aliases)) ?? []
        self.defaultCategoryId = (try? container.decodeIfPresent(UUID.self, forKey: .defaultCategoryId)) ?? UUID()
        self.isUserDefined = (try? container.decodeIfPresent(Bool.self, forKey: .isUserDefined)) ?? false
        self.lastConfirmedAt = (try? container.decodeIfPresent(Date.self, forKey: .lastConfirmedAt)) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(canonicalName, forKey: .canonicalName)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(defaultCategoryId, forKey: .defaultCategoryId)
        try container.encode(isUserDefined, forKey: .isUserDefined)
        try container.encode(lastConfirmedAt, forKey: .lastConfirmedAt)
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

    public func allRules() -> [MerchantRule] {
        return Array(rulesById.values)
    }

    public func loadRules(_ imported: [MerchantRule]) {
        for r in imported {
            registerRule(r)
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
