import XCTest
@testable import HybridTrainingCore

final class AppleWatchBiomarkerEngineTests: XCTestCase {

    var engine: AppleWatchBiomarkerEngine!
    let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        engine = AppleWatchBiomarkerEngine()
    }

    func test_lnHrv_filtersArtifactsAndComputesNightlyMedian() {
        // Given: Samples with normal values and extreme artifacts (< 5ms or > 350ms)
        let samples = [3.0, 45.0, 50.0, 55.0, 400.0]
        
        // When
        let nightlyLnHRV = engine.computeNightlyLnHRV(from: samples)
        
        // Then: 3.0 and 400.0 filtered out. Remaining: [45.0, 50.0, 55.0].
        // Median of log(45), log(50), log(55) is log(50.0) ≈ 3.9120
        XCTAssertNotNil(nightlyLnHRV)
        XCTAssertEqual(nightlyLnHRV!, log(50.0), accuracy: 0.001)
    }

    func test_lnHrv_returnsNilWhenFewerThanThreeSamples() {
        // Given: only 2 valid samples
        let samples = [45.0, 50.0]
        
        // When
        let nightlyLnHRV = engine.computeNightlyLnHRV(from: samples)
        
        // Then: Fails minimum sample gate (needs >= 3)
        XCTAssertNil(nightlyLnHRV)
    }

    func test_evaluatesReadyWhenAllBiomarkersNormal() {
        // Given: 28 days of baseline data
        var history: [NightlyBiomarkerSample] = []
        for i in 1...28 {
            history.append(
                NightlyBiomarkerSample(
                    date: baseDate.addingTimeInterval(Double(-i * 86400)),
                    sleepWindow: DateInterval(
                        start: baseDate.addingTimeInterval(Double(-i * 86400)),
                        duration: 28800
                    ),
                    sleepSyncStatus: .finalized,
                    totalSleepDurationSeconds: 28800,
                    deepSleepSeconds: 5400,
                    remSleepSeconds: 7200,
                    nightlySDNNValuesMs: [48.0, 50.0, 52.0, 50.0],
                    nocturnalSleepingHeartRateBpm: 50.0,
                    sleepingRespiratoryRateRpm: 14.0,
                    confounders: []
                )
            )
        }

        let today = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: DateInterval(start: baseDate, duration: 28800),
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 52.0, 54.0],
            nocturnalSleepingHeartRateBpm: 50.0,
            sleepingRespiratoryRateRpm: 14.0,
            confounders: []
        )

        // When
        let outcome = engine.evaluate(today: today, history28d: history)

        // Then
        switch outcome {
        case .assessed(let assessment):
            XCTAssertEqual(assessment.zone, .ready)
            XCTAssertEqual(assessment.autonomic, .balanced)
            XCTAssertGreaterThanOrEqual(assessment.score, 80)
            XCTAssertEqual(assessment.confidence, .high)
        case .calibrating, .insufficientData:
            XCTFail("Expected assessed outcome")
        }
    }

    func test_singleDayRhrSpikeDoesNotTriggerOverreachedDueToNoiseFloor() {
        // Given 28 days of history with RHR 50 bpm
        let history = (1...28).map { i in
            NightlyBiomarkerSample(
                date: baseDate.addingTimeInterval(Double(-i * 86400)),
                sleepWindow: nil,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 28800,
                deepSleepSeconds: 5400,
                remSleepSeconds: 7200,
                nightlySDNNValuesMs: [50.0, 50.0, 50.0],
                nocturnalSleepingHeartRateBpm: 50.0,
                sleepingRespiratoryRateRpm: 14.0
            )
        }

        // Today has a single-day RHR spike (+4 bpm to 54.0), but yesterday was 50.0
        let todaySpike = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 50.0, 50.0],
            nocturnalSleepingHeartRateBpm: 54.0,
            sleepingRespiratoryRateRpm: 14.0
        )

        // When
        let outcome = engine.evaluate(today: todaySpike, history28d: history)

        // Then: consecutive days elevated = 1, so zone remains steady (not overreached)
        switch outcome {
        case .assessed(let assessment):
            XCTAssertEqual(assessment.consecutiveElevatedRHRDays, 1)
            XCTAssertNotEqual(assessment.zone, .overreached)
            XCTAssertGreaterThanOrEqual(assessment.score, 60)
        default:
            XCTFail("Expected assessed outcome")
        }
    }

    func test_consecutiveTwoDaysRhrSpike_triggersOverreached() {
        // Given: 28 days history where yesterday was also elevated to 54 bpm
        var history = (2...28).map { i in
            NightlyBiomarkerSample(
                date: baseDate.addingTimeInterval(Double(-i * 86400)),
                sleepWindow: nil,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 28800,
                deepSleepSeconds: 5400,
                remSleepSeconds: 7200,
                nightlySDNNValuesMs: [50.0, 50.0, 50.0],
                nocturnalSleepingHeartRateBpm: 50.0,
                sleepingRespiratoryRateRpm: 14.0
            )
        }
        let yesterdayElevated = NightlyBiomarkerSample(
            date: baseDate.addingTimeInterval(-86400),
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 50.0, 50.0],
            nocturnalSleepingHeartRateBpm: 53.5, // > 50 + 3
            sleepingRespiratoryRateRpm: 14.0
        )
        history.insert(yesterdayElevated, at: 0)

        // Today is also elevated
        let todaySpike = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 50.0, 50.0],
            nocturnalSleepingHeartRateBpm: 54.0,
            sleepingRespiratoryRateRpm: 14.0
        )

        // When
        let outcome = engine.evaluate(today: todaySpike, history28d: history)

        // Then: consecutive days elevated = 2 -> triggers overreached
        switch outcome {
        case .assessed(let assessment):
            XCTAssertEqual(assessment.consecutiveElevatedRHRDays, 2)
            XCTAssertEqual(assessment.zone, .overreached)
        default:
            XCTFail("Expected assessed outcome")
        }
    }

    func test_madZeroFloorProtection_preventsDivisionByZero() {
        // Given: Perfectly constant history (MAD = 0)
        let history = (1...28).map { i in
            NightlyBiomarkerSample(
                date: baseDate.addingTimeInterval(Double(-i * 86400)),
                sleepWindow: nil,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 28800,
                deepSleepSeconds: 5400,
                remSleepSeconds: 7200,
                nightlySDNNValuesMs: [50.0, 50.0, 50.0],
                nocturnalSleepingHeartRateBpm: 48.0,
                sleepingRespiratoryRateRpm: 14.0
            )
        }

        // Today has a minor fluctuation (+1 bpm to 49.0)
        let today = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 50.0, 50.0],
            nocturnalSleepingHeartRateBpm: 49.0,
            sleepingRespiratoryRateRpm: 14.0
        )

        // When
        let outcome = engine.evaluate(today: today, history28d: history)

        // Then: Must NOT crash and score must be in valid 0...100 range
        switch outcome {
        case .assessed(let assessment):
            XCTAssertGreaterThanOrEqual(assessment.score, 0)
            XCTAssertLessThanOrEqual(assessment.score, 100)
        default:
            XCTFail("Expected assessed outcome")
        }
    }

    func test_baselineMasking_excludesAlcoholAndIllnessFromReferencePool() {
        // Given: 28 days of history where 2 days had extreme alcohol hangovers (SDNN 15ms, RHR 75bpm)
        var history = (1...26).map { i in
            NightlyBiomarkerSample(
                date: baseDate.addingTimeInterval(Double(-i * 86400)),
                sleepWindow: nil,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 28800,
                deepSleepSeconds: 5400,
                remSleepSeconds: 7200,
                nightlySDNNValuesMs: [60.0, 60.0, 60.0],
                nocturnalSleepingHeartRateBpm: 50.0,
                sleepingRespiratoryRateRpm: 14.0
            )
        }
        let alcoholDay1 = NightlyBiomarkerSample(
            date: baseDate.addingTimeInterval(-27 * 86400),
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 21600,
            deepSleepSeconds: 1800,
            remSleepSeconds: 3600,
            nightlySDNNValuesMs: [15.0, 18.0, 15.0],
            nocturnalSleepingHeartRateBpm: 75.0,
            sleepingRespiratoryRateRpm: 18.0,
            confounders: [.alcohol]
        )
        let illnessDay = NightlyBiomarkerSample(
            date: baseDate.addingTimeInterval(-28 * 86400),
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 21600,
            deepSleepSeconds: 1800,
            remSleepSeconds: 3600,
            nightlySDNNValuesMs: [20.0, 20.0, 20.0],
            nocturnalSleepingHeartRateBpm: 70.0,
            sleepingRespiratoryRateRpm: 17.0,
            confounders: [.illness]
        )
        history.append(alcoholDay1)
        history.append(illnessDay)

        let today = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [60.0, 60.0, 60.0],
            nocturnalSleepingHeartRateBpm: 50.0,
            sleepingRespiratoryRateRpm: 14.0
        )

        // When
        let outcome = engine.evaluate(today: today, history28d: history)

        // Then: baseline pool length should be 26 (2 masked), median RHR should be 50.0, not contaminated by 75 and 70
        switch outcome {
        case .assessed(let assessment):
            XCTAssertEqual(assessment.zone, .ready)
            XCTAssertEqual(assessment.autonomic, .balanced)
        default:
            XCTFail("Expected assessed outcome")
        }
    }

    func test_calibratingStatus_whenCleanDaysLessThan14() {
        // Given: only 8 clean days of history
        let shortHistory = (1...8).map { i in
            NightlyBiomarkerSample(
                date: baseDate.addingTimeInterval(Double(-i * 86400)),
                sleepWindow: nil,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 28800,
                deepSleepSeconds: 5400,
                remSleepSeconds: 7200,
                nightlySDNNValuesMs: [50.0, 50.0, 50.0],
                nocturnalSleepingHeartRateBpm: 50.0,
                sleepingRespiratoryRateRpm: 14.0
            )
        }

        let today = NightlyBiomarkerSample(
            date: baseDate,
            sleepWindow: nil,
            sleepSyncStatus: .finalized,
            totalSleepDurationSeconds: 28800,
            deepSleepSeconds: 5400,
            remSleepSeconds: 7200,
            nightlySDNNValuesMs: [50.0, 50.0, 50.0],
            nocturnalSleepingHeartRateBpm: 50.0,
            sleepingRespiratoryRateRpm: 14.0
        )

        // When
        let outcome = engine.evaluate(today: today, history28d: shortHistory)

        // Then
        switch outcome {
        case .calibrating(let cleanDays, _):
            XCTAssertEqual(cleanDays, 8)
        default:
            XCTFail("Expected calibrating outcome when N < 14")
        }
    }
}
