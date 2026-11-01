import XCTest
@testable import HybridTrainingCore

final class RunningMechanicsAndAdvancedBiomarkersTests: XCTestCase {
    
    private var referenceDate: Date!
    private var engine: RunningMechanicsEngine!
    
    override func setUp() {
        super.setUp()
        referenceDate = Date(timeIntervalSince1970: 1_792_828_800)
        engine = RunningMechanicsEngine()
    }
    
    // MARK: - 1. BiomarkerDomainModels 新增欄位與迷走神經遲滯邏輯
    
    func testBiomarkerNewFieldsAndVagalReactivationLogic() throws {
        let sleepStart = referenceDate.addingTimeInterval(-8 * 3600)
        let dtoTemp = RawBiomarkerSampleDTO(
            kind: .sleepingWristTemperature,
            value: 36.85,
            start: sleepStart,
            end: referenceDate
        )
        let dtoWalkingHR = RawBiomarkerSampleDTO(
            kind: .walkingHeartRateAverage,
            value: 104.0,
            start: sleepStart,
            end: referenceDate
        )
        let dtoHRR = RawBiomarkerSampleDTO(
            kind: .heartRateRecoveryOneMinute,
            value: 14.0,
            start: sleepStart,
            end: referenceDate
        )
        
        XCTAssertEqual(dtoTemp.kind, .sleepingWristTemperature)
        XCTAssertEqual(dtoWalkingHR.kind, .walkingHeartRateAverage)
        XCTAssertEqual(dtoHRR.kind, .heartRateRecoveryOneMinute)
        
        let sample = NightlyBiomarkerSample(
            date: referenceDate,
            totalSleepDurationSeconds: 7.5 * 3600,
            nightlySDNNValuesMs: [52.0, 58.0, 61.0],
            nocturnalSleepingHeartRateBpm: 51.0,
            sleepingRespiratoryRateRpm: 14.2,
            sleepingWristTemperatureCelsius: 36.85,
            wristTemperatureBaselineDeltaCelsius: 0.72,
            walkingHeartRateAverageBpm: 104.0,
            heartRateRecoveryOneMinuteBpm: 14.0
        )
        
        XCTAssertTrue(sample.hasValidWristTemperature)
        XCTAssertTrue(sample.isVagalReactivationBlunted, "HRR-1min (14 bpm) < 18 bpm 應判定為迷走神經再活化遲滯")
        
        // 測試 Codable 序列化與反序列化完整性
        let encoded = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(NightlyBiomarkerSample.self, from: encoded)
        XCTAssertEqual(decoded, sample)
        XCTAssertEqual(decoded.sleepingWristTemperatureCelsius, 36.85)
        XCTAssertEqual(decoded.walkingHeartRateAverageBpm, 104.0)
        XCTAssertEqual(decoded.heartRateRecoveryOneMinuteBpm, 14.0)
    }
    
    // MARK: - 2. 跑步力學彈簧剛性與伸展收縮循環 (SSC) 疲勞測試
    
    func testSpringMassStiffnessAndEfficiencyCalculations() {
        let sample = RunningMechanicsSample(
            date: referenceDate,
            durationSeconds: 2400,
            averageSpeedMetersPerSecond: 3.51,
            groundContactTimeMs: 230.0,
            verticalOscillationCm: 8.2,
            runningPowerWatts: 252.0,
            strideLengthMeters: 1.18,
            cadenceStepsPerMinute: 178.0,
            athleteBodyMassKg: 72.0,
            estimatedLegLengthMeters: 0.90
        )
        
        XCTAssertTrue(sample.isValidBiomechanicsSample)
        XCTAssertEqual(sample.verticalRatioPercent ?? 0.0, 6.949, accuracy: 0.05)
        XCTAssertNotNil(sample.verticalStiffnessKiloNewtonsPerMeter)
        XCTAssertGreaterThan(sample.verticalStiffnessKiloNewtonsPerMeter ?? 0.0, 15.0)
    }
    
    func testSquatLegDayDecoupling_TriggersSevereSSCFatigueWarning() {
        // 過去 10 次正常跑步基準 (GCT ~ 220ms, 剛性 ~ 28 kN/m)
        let history: [RunningMechanicsSample] = (1...10).map { day in
            RunningMechanicsSample(
                date: referenceDate.addingTimeInterval(-Double(day) * 86400),
                durationSeconds: 2400,
                averageSpeedMetersPerSecond: 3.50,
                groundContactTimeMs: 220.0,
                verticalOscillationCm: 8.0,
                runningPowerWatts: 250.0,
                strideLengthMeters: 1.18,
                cadenceStepsPerMinute: 180.0
            )
        }
        
        // 昨日深蹲腿部訓練 (18 小時前)
        let squatWorkout = WorkoutSession(
            startDate: referenceDate.addingTimeInterval(-18 * 3600),
            endDate: referenceDate.addingTimeInterval(-17 * 3600),
            discipline: .strength,
            durationMinutes: 60,
            sRPE: 8.5,
            movementPatterns: [.lowerQuad, .lowerPosterior]
        )
        
        // 今日跑步力學：觸地時間大幅拉長到 242ms (+22ms), 垂直剛性下滑
        let todayRun = RunningMechanicsSample(
            date: referenceDate,
            durationSeconds: 1800,
            averageSpeedMetersPerSecond: 3.50,
            groundContactTimeMs: 242.0,
            verticalOscillationCm: 9.5,
            runningPowerWatts: 275.0,
            strideLengthMeters: 1.14,
            cadenceStepsPerMinute: 172.0
        )
        
        let assessment = engine.evaluate(
            latestRun: todayRun,
            historyRuns: history,
            recentWorkouts: [squatWorkout]
        )
        
        XCTAssertEqual(assessment.status, .severeDecoupled)
        XCTAssertTrue(assessment.isSquatLegDayDecoupled, "應正確關聯深蹲重訓與下肢剛性衰竭")
        XCTAssertGreaterThanOrEqual(assessment.groundContactTimeDeltaMs ?? 0.0, 15.0)
        XCTAssertTrue(assessment.injuryMitigationDirectives.contains { $0.contains("深蹲") || $0.contains("阿基里斯腱") })
    }
    
    // MARK: - 3. AppleWatchBiomarkerEngine 手腕高溫發炎與 HRR 破除假性亢進測試
    
    func testBiomarkerEngine_wristTempSpikeAndHRRBlunted() {
        let biomarkerEngine = AppleWatchBiomarkerEngine()
        
        let history: [NightlyBiomarkerSample] = (1...16).map { day in
            NightlyBiomarkerSample(
                date: referenceDate.addingTimeInterval(-Double(day) * 86400),
                totalSleepDurationSeconds: 7.5 * 3600,
                nightlySDNNValuesMs: [50.0, 55.0, 52.0],
                nocturnalSleepingHeartRateBpm: 52.0,
                sleepingRespiratoryRateRpm: 14.0,
                sleepingWristTemperatureCelsius: 36.4,
                wristTemperatureBaselineDeltaCelsius: 0.0,
                walkingHeartRateAverageBpm: 92.0,
                heartRateRecoveryOneMinuteBpm: 30.0
            )
        }
        
        // 今日手腕溫度異常升高 +0.55°C，且 HRR 只有 12 bpm (遲滯)
        let today = NightlyBiomarkerSample(
            date: referenceDate,
            totalSleepDurationSeconds: 7.0 * 3600,
            nightlySDNNValuesMs: [52.0, 56.0, 54.0],
            nocturnalSleepingHeartRateBpm: 54.0,
            sleepingRespiratoryRateRpm: 14.5,
            sleepingWristTemperatureCelsius: 36.95,
            wristTemperatureBaselineDeltaCelsius: 0.55,
            walkingHeartRateAverageBpm: 95.0,
            heartRateRecoveryOneMinuteBpm: 12.0
        )
        
        let outcome = biomarkerEngine.evaluate(today: today, history28d: history)
        guard case .assessed(let assessment) = outcome else {
            XCTFail("16 天基準應完成評估")
            return
        }
        
        XCTAssertTrue(assessment.diagnosticMessages.contains { $0.contains("夜間手腕溫度") })
        XCTAssertTrue(assessment.diagnosticMessages.contains { $0.contains("運動後一分鐘心率恢復遲緩") })
        XCTAssertLessThanOrEqual(assessment.score, 65)
    }
}
