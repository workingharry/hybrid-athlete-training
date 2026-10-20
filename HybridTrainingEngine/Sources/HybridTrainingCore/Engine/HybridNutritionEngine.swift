import Foundation

/// 混合運動員營養計算引擎 (HybridNutritionEngine)
/// 遵循 ISSN / ACSM 運動營養學立場聲明與 IOC RED-S 共識
public enum HybridNutritionEngine {
    
    /// 依據基礎代謝、體重、去脂體重、訓練日型態與體態目標，計算當日精準三大營養素與能量目標
    public static func calculateDailyTarget(
        bmr: Double,
        weightKg: Double,
        fatFreeMassKg: Double,
        dayType: TrainingDayType,
        goal: BodyCompositionGoal = .maximizeHypertrophy
    ) -> MacroTarget {
        // 1. 估算基礎活動消耗與訓練消耗 (Activity & Exercise Expenditure)
        let exerciseExpenditure: Double
        let baseWaterMl: Double
        
        switch dayType {
        case .heavyStrength:
            exerciseExpenditure = 400.0  // 大重量肌力訓練 (高強度無氧)
            baseWaterMl = 2600.0
        case .longRun:
            exerciseExpenditure = 850.0  // 週末長跑 (>=60 分鐘高有氧代謝)
            baseWaterMl = 3400.0
        case .twoADaySession:
            exerciseExpenditure = 1000.0 // 雙練日
            baseWaterMl = 3800.0
        case .easyRunZone2:
            exerciseExpenditure = 350.0  // 輕鬆慢跑
            baseWaterMl = 2500.0
        case .activeRest:
            exerciseExpenditure = 100.0  // 活動度/散步恢復
            baseWaterMl = 2200.0
        }
        
        // 日常非運動消耗 (NEAT ~ 1.25 * BMR)
        let tdee = (bmr * 1.25) + exerciseExpenditure
        
        // 2. 目標調整幅度 (Goal Adjustment)
        let baseTargetCalories: Double
        switch goal {
        case .maximizeHypertrophy:
            // 保守微幅熱量盈餘 (+5% ~ +10%，預設 +8% 約 200~300 kcal)
            baseTargetCalories = tdee * 1.08
        case .maintenance:
            baseTargetCalories = tdee
        case .fatLossPreserve:
            baseTargetCalories = max(bmr, tdee * 0.85) // -15% 赤字但絕不低於 BMR
        }
        
        // 增肌充沛 EA 護欄保障 (EA >= 45 kcal/kg FFM => Target Calories - exerciseExpenditure >= 45 * fatFreeMassKg)
        let targetCalories: Double
        if goal == .maximizeHypertrophy {
            let minAnabolicCalories = (45.0 * fatFreeMassKg) + exerciseExpenditure
            targetCalories = max(baseTargetCalories, minAnabolicCalories)
        } else {
            targetCalories = baseTargetCalories
        }
        
        // 3. 蛋白質計算 (1.8 ~ 2.2 g/kg，增肌優先鎖定 2.0 g/kg，休息日保護底線 1.6 g/kg)
        let proteinGramsPerKg: Double
        switch goal {
        case .maximizeHypertrophy:
            proteinGramsPerKg = (dayType == .activeRest) ? 1.8 : 2.0
        case .maintenance:
            proteinGramsPerKg = 1.8
        case .fatLossPreserve:
            proteinGramsPerKg = 2.2
        }
        let totalProteinGrams = round(weightKg * proteinGramsPerKg)
        let proteinCalories = totalProteinGrams * 4.0
        
        // 單餐蛋白質脈衝 (0.4 ~ 0.55 g/kg，平均 0.45 g/kg)
        let proteinPerMeal = round(weightKg * 0.45)
        
        // 4. 脂肪防護底線 (0.8 ~ 1.0 g/kg，且不得低於總熱量的 20%)
        var targetFatGrams = round(weightKg * 0.9)
        if (targetFatGrams * 9.0) < (targetCalories * 0.20) {
            targetFatGrams = round((targetCalories * 0.20) / 9.0)
        }
        let fatCalories = targetFatGrams * 9.0
        
        // 5. 碳水化合物配置 (剩餘熱量配置，並實施嚴格防 RED-S 護欄)
        let remainingCaloriesForCarbs = max(0.0, targetCalories - proteinCalories - fatCalories)
        var totalCarbsGrams = round(remainingCaloriesForCarbs / 4.0)
        
        // 長跑日與大重量日特別保障
        if dayType == .longRun && totalCarbsGrams < (weightKg * 6.0) {
            totalCarbsGrams = round(weightKg * 6.0) // 長跑日保障 6.0 g/kg
        }
        
        // 休息日防 RED-S 碳水最低底線 (>= 3.0 g/kg)
        if totalCarbsGrams < (weightKg * 3.0) {
            totalCarbsGrams = round(weightKg * 3.0)
        }
        
        // 重新依最終微調宏量熱量校準
        let adjustedTotalCalories = (totalProteinGrams * 4.0) + (totalCarbsGrams * 4.0) + (targetFatGrams * 9.0)
        
        // 6. 能量可用性 (Energy Availability, EA) 計算
        // EA = (每日攝入熱量 - 運動消耗) / 去脂體重 (kcal/kg FFM)
        let calculatedEA = (adjustedTotalCalories - exerciseExpenditure) / max(1.0, fatFreeMassKg)
        let isAnabolicEASafe = calculatedEA >= 45.0
        
        // 7. 產生引導說明
        var notes: [String] = []
        if dayType == .longRun || dayType == .twoADaySession {
            notes.append("長跑高有氧消耗：運動後 30 分鐘內建議補充 40~60g 易消化碳水與 25g 乳清蛋白，加速肌糖原超量修復並關閉 AMPK 抑制訊號。")
        }
        if isAnabolicEASafe {
            notes.append("能量可用性 (EA) 達標 (\(Int(calculatedEA)) kcal/kg FFM)：處於合成代謝巔峰環境。")
        } else if calculatedEA < 30.0 {
            notes.append("⚠️ 警示：能量可用性偏低 (<30 kcal/kg FFM)，已自動調高碳水防範 RED-S 症候群。")
        }
        
        return MacroTarget(
            calories: adjustedTotalCalories,
            proteinGrams: totalProteinGrams,
            carbsGrams: totalCarbsGrams,
            fatGrams: targetFatGrams,
            waterMl: baseWaterMl,
            estimatedEA: calculatedEA,
            isAnabolicEASafe: isAnabolicEASafe,
            proteinPerMealSuggestionGrams: proteinPerMeal,
            recommendedMealCount: 4,
            guidanceNotes: notes
        )
    }
}
