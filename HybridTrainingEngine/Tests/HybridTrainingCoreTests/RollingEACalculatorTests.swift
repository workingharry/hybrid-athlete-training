import XCTest
@testable import HybridTrainingCore

final class RollingEACalculatorTests: XCTestCase {

    var calculator: RollingEACalculator!
    let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        calculator = RollingEACalculator()
    }

    func test_incompleteDay_excludedFrom7DayDenominator() {
        // Given: 6 complete days (intake: 2800 kcal, workout: 500 kcal, FFM: 60kg -> Net: 2300 / 60 ≈ 38.3 kcal/kg FFM)
        let completeDays = (1...6).map { offset in
            DailyNutritionLogInput(
                date: baseDate.addingTimeInterval(Double(-offset * 86400)),
                intakeKcal: 2800,
                loggedMealSlotsCount: 3,
                isDayFinalized: false,
                workoutActiveKcal: 500,
                totalActiveKcal: 700
            )
        }

        // Today only has breakfast logged (850 kcal, BMR estimate is 1700 kcal, 0.75 * BMR = 1275)
        let todayPartial = DailyNutritionLogInput(
            date: baseDate,
            intakeKcal: 850,
            loggedMealSlotsCount: 1,
            isDayFinalized: false,
            workoutActiveKcal: 600,
            totalActiveKcal: 900
        )

        // When
        let estimate = calculator.computeRollingEA(
            pastDays: completeDays + [todayPartial],
            fatFreeMassKg: 60.0,
            estimatedBMRKcal: 1700.0,
            isIntermittentFastingEnabled: false
        )

        // Then: Today is excluded from denominator, so completeDays = 6, excludedDays = 1
        XCTAssertEqual(estimate.state, .estimated)
        XCTAssertEqual(estimate.completeDays, 6)
        XCTAssertEqual(estimate.excludedDays, 1)
        XCTAssertNotNil(estimate.point)
        // Rolling EA stays healthy (~38), NOT dragged down to false RED-S
        XCTAssertGreaterThan(estimate.point!, 35.0)
    }

    func test_intermittentFastingOrOMAD_passesCompletenessGate() {
        // Given an OMAD athlete logging 1 single meal of 2100 kcal (> 0.75 * 1700 = 1275)
        let omadDay = DailyNutritionLogInput(
            date: baseDate,
            intakeKcal: 2100,
            loggedMealSlotsCount: 1,
            isDayFinalized: false,
            workoutActiveKcal: 400,
            totalActiveKcal: 600
        )

        // When
        let completeness = calculator.evaluateCompleteness(
            day: omadDay,
            estimatedBMRKcal: 1700.0,
            isIntermittentFastingEnabled: true
        )

        // Then: Passes completeness gate due to IF enabled and high intake
        XCTAssertTrue(completeness.isComplete)
    }

    func test_fewerThanFourCompleteDays_yieldsInsufficientDaysState() {
        // Given only 2 days of complete logs
        let shortDays = (1...2).map { offset in
            DailyNutritionLogInput(
                date: baseDate.addingTimeInterval(Double(-offset * 86400)),
                intakeKcal: 2600,
                loggedMealSlotsCount: 3,
                isDayFinalized: false,
                workoutActiveKcal: 500,
                totalActiveKcal: 700
            )
        }

        // When
        let estimate = calculator.computeRollingEA(
            pastDays: shortDays,
            fatFreeMassKg: 65.0,
            estimatedBMRKcal: 1700.0,
            isIntermittentFastingEnabled: false
        )

        // Then
        XCTAssertEqual(estimate.state, .insufficientDays)
        XCTAssertNil(estimate.point)
        XCTAssertEqual(estimate.completeDays, 2)
    }

    func test_effectiveEEECalculation_disaggregatesNEAT() {
        // Given: 500 kcal workout active, 1000 total active (500 non-workout NEAT)
        // Effective EEE = 500 + 0.35 * 500 = 675 kcal
        let effectiveEEE = calculator.computeEffectiveEEE(workoutActiveKcal: 500, totalActiveKcal: 1000)
        XCTAssertEqual(effectiveEEE, 675.0, accuracy: 0.1)
    }
}
