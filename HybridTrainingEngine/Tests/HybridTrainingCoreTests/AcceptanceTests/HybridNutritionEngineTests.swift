import XCTest
@testable import HybridTrainingCore

final class HybridNutritionEngineTests: XCTestCase {
    
    // 70kg 運動員，去脂體重約 60kg，基礎代謝 BMR 1650 kcal
    private let weightKg: Double = 70.0
    private let fatFreeMassKg: Double = 60.0
    private let bmr: Double = 1650.0
    
    // MARK: - Test 1: 極大化增肌模式 (Maximize Hypertrophy)
    func testMaximizeHypertrophySurplusAndProteinPulse() {
        let target = HybridNutritionEngine.calculateDailyTarget(
            bmr: bmr,
            weightKg: weightKg,
            fatFreeMassKg: fatFreeMassKg,
            dayType: .heavyStrength,
            goal: .maximizeHypertrophy
        )
        
        // 1. 熱量必須具備 5% ~ 15% 保守盈餘或達到 EA >= 45 增肌充沛標準 (2600 ~ 3200 kcal)
        XCTAssertGreaterThan(target.calories, 2400.0)
        XCTAssertLessThanOrEqual(target.calories, 3200.0)
        
        // 2. 蛋白質鎖定約 2.0 g/kg (70kg * 2.0 = 140g)
        XCTAssertEqual(target.proteinGrams, 140.0, accuracy: 5.0)
        
        // 3. 單餐蛋白質脈衝 (0.4~0.55 g/kg => 70 * 0.45 ≈ 31.5g ~ 35g)
        XCTAssertGreaterThanOrEqual(target.proteinPerMealSuggestionGrams, 28.0)
        XCTAssertLessThanOrEqual(target.proteinPerMealSuggestionGrams, 40.0)
        
        // 4. 充沛增肌能量可用性 (EA >= 45 kcal/kg FFM)
        XCTAssertTrue(target.isAnabolicEASafe)
        XCTAssertGreaterThanOrEqual(target.estimatedEA, 45.0)
    }
    
    // MARK: - Test 2: 休息日防 RED-S 碳水底線護欄 (>= 3.0 g/kg)
    func testActiveRestDayCarbThresholdPreventsREDS() {
        let target = HybridNutritionEngine.calculateDailyTarget(
            bmr: bmr,
            weightKg: weightKg,
            fatFreeMassKg: fatFreeMassKg,
            dayType: .activeRest,
            goal: .maximizeHypertrophy
        )
        
        // 碳水絕對不能掉到 1.5~2.0 g/kg，必須 >= 3.0 g/kg (70kg * 3.0 = 210g)
        XCTAssertGreaterThanOrEqual(target.carbsGrams, 210.0)
        
        // 休息日蛋白質仍需維持底線保護 (>= 1.6 g/kg => 112g)
        XCTAssertGreaterThanOrEqual(target.proteinGrams, 112.0)
        
        // 脂肪不得低於總熱量的 20%
        let fatCalories = target.fatGrams * 9.0
        XCTAssertGreaterThanOrEqual(fatCalories / target.calories, 0.20)
    }
    
    // MARK: - Test 3: 週末長跑高碳水化合物配置 (防止 AMPK 抑制 mTORC1)
    func testLongRunHighCarbProtectsMTOR() {
        let target = HybridNutritionEngine.calculateDailyTarget(
            bmr: bmr,
            weightKg: weightKg,
            fatFreeMassKg: fatFreeMassKg,
            dayType: .longRun,
            goal: .maximizeHypertrophy
        )
        
        // 長跑日碳水需達到 6.0 ~ 8.0 g/kg (70kg * 6.0 = 420g)
        XCTAssertGreaterThanOrEqual(target.carbsGrams, 400.0)
        
        // 包含水分建議提示 (長跑至少 3000ml)
        XCTAssertGreaterThanOrEqual(target.waterMl, 3000.0)
        
        // 具有運動後補水補碳指引
        XCTAssertTrue(target.guidanceNotes.contains(where: { $0.contains("補碳") || $0.contains("糖原") }))
    }
}
