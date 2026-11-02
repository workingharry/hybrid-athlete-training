import XCTest
import Foundation
@testable import HybridTrainingCore
@testable import HybridTrainingStorage

final class NutritionDailyAggregationTests: XCTestCase {
    
    func testAggregateTodayEntriesAcross4AMBoundary() {
        let calendar = Calendar.current
        
        // 基準日：2026-10-22 14:00 (屬於 2026-10-22 訓練日)
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 10
        comp.day = 22
        comp.hour = 14
        comp.minute = 0
        let refDate = calendar.date(from: comp)!
        
        // entry 1: 今天早上 8:00 (同一天)
        comp.hour = 8
        let date1 = calendar.date(from: comp)!
        let entry1 = SDDailyNutritionEntry(
            timestamp: date1,
            foodName: "早餐燕麥蛋白粉",
            calories: 450,
            proteinGrams: 35,
            carbsGrams: 50,
            fatGrams: 8
        )
        
        // entry 2: 今天凌晨 04:15 (同一天，在 4:00 AM 之後)
        comp.hour = 4
        comp.minute = 15
        let date2 = calendar.date(from: comp)!
        let entry2 = SDDailyNutritionEntry(
            timestamp: date2,
            foodName: "凌晨練前香蕉",
            calories: 105,
            proteinGrams: 1,
            carbsGrams: 27,
            fatGrams: 0
        )
        
        // entry 3: 今天凌晨 03:30 (在 4:00 AM 之前，屬於前一天 10-21 訓練日)
        comp.hour = 3
        comp.minute = 30
        let date3 = calendar.date(from: comp)!
        let entry3 = SDDailyNutritionEntry(
            timestamp: date3,
            foodName: "昨天深夜加餐",
            calories: 300,
            proteinGrams: 20,
            carbsGrams: 30,
            fatGrams: 5
        )
        
        // entry 4: 昨天中午 (屬於前一天)
        comp.day = 21
        comp.hour = 12
        let date4 = calendar.date(from: comp)!
        let entry4 = SDDailyNutritionEntry(
            timestamp: date4,
            foodName: "昨日午餐",
            calories: 700,
            proteinGrams: 45,
            carbsGrams: 80,
            fatGrams: 20
        )
        
        let allEntries = [entry1, entry2, entry3, entry4]
        
        let todayKey = TrainingDayKey(date: refDate, calendar: calendar).dateString
        let todayEntries = allEntries.filter {
            TrainingDayKey(date: $0.timestamp, calendar: calendar).dateString == todayKey
        }
        
        XCTAssertEqual(todayEntries.count, 2)
        XCTAssertTrue(todayEntries.contains(where: { $0.foodName == "早餐燕麥蛋白粉" }))
        XCTAssertTrue(todayEntries.contains(where: { $0.foodName == "凌晨練前香蕉" }))
        XCTAssertFalse(todayEntries.contains(where: { $0.foodName == "昨天深夜加餐" }))
        XCTAssertFalse(todayEntries.contains(where: { $0.foodName == "昨日午餐" }))
        
        let totalKcal = todayEntries.reduce(0.0) { $0 + $1.calories }
        let totalProtein = todayEntries.reduce(0.0) { $0 + $1.proteinGrams }
        let totalCarbs = todayEntries.reduce(0.0) { $0 + $1.carbsGrams }
        
        XCTAssertEqual(totalKcal, 555.0)
        XCTAssertEqual(totalProtein, 36.0)
        XCTAssertEqual(totalCarbs, 77.0)
    }

    func testSDDailyNutritionEntry_caffeineMgField() {
        let defaultEntry = SDDailyNutritionEntry(
            timestamp: Date(),
            foodName: "白飯",
            calories: 200,
            proteinGrams: 4,
            carbsGrams: 45,
            fatGrams: 0.5
        )
        XCTAssertEqual(defaultEntry.caffeineMg, 0.0, "預設咖啡因應為 0.0mg")

        let caffeineEntry1 = SDDailyNutritionEntry(
            timestamp: Date(),
            foodName: "晨間美式黑咖啡",
            calories: 5,
            proteinGrams: 0,
            carbsGrams: 1,
            fatGrams: 0,
            caffeineMg: 150.0
        )
        let caffeineEntry2 = SDDailyNutritionEntry(
            timestamp: Date().addingTimeInterval(3600),
            foodName: "午後綠茶",
            calories: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            caffeineMg: 35.0
        )

        let totalCaffeine = [defaultEntry, caffeineEntry1, caffeineEntry2].reduce(0.0) { $0 + $1.caffeineMg }
        XCTAssertEqual(totalCaffeine, 185.0, accuracy: 0.001)
    }
}

