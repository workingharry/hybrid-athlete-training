import Testing
import Foundation
@testable import ZeroTypingExpense

@Suite("Merchant Learning Engine Tests")
struct MerchantLearningEngineTests {

    @Test("Rule learning and aliasing: MTR and Uber Eats correctly mapped")
    func testMerchantLearning() async throws {
        let engine = MerchantLearningEngine()
        let transportId = UUID()
        let diningId = UUID()

        // 1. Initial manual confirmation: learn "Uber Eats" -> Dining
        await engine.learnMerchantMapping(rawName: "UBER EATS HK", canonicalName: "Uber Eats", categoryId: diningId)

        // 2. Querying "Uber Eats" alias
        let match1 = await engine.matchCategory(forMerchantRaw: "UBER EATS HK")
        #expect(match1?.canonicalName == "Uber Eats")
        #expect(match1?.categoryId == diningId)
        #expect(match1?.confidence == 1.0)

        // 3. Substring match
        let match2 = await engine.matchCategory(forMerchantRaw: "Uber Eats Central Branch")
        #expect(match2?.canonicalName == "Uber Eats")
        #expect(match2?.categoryId == diningId)

        // 4. Register built-in rule: MTR -> Transport
        let mtrRule = MerchantRule(
            canonicalName: "MTR",
            aliases: ["MTR Mobile", "港鐵"],
            defaultCategoryId: transportId,
            isUserDefined: false
        )
        await engine.registerRule(mtrRule)

        let mtrMatch = await engine.matchCategory(forMerchantRaw: "港鐵")
        #expect(mtrMatch?.canonicalName == "MTR")
        #expect(mtrMatch?.categoryId == transportId)
    }
}
