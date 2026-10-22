import Foundation
#if canImport(HealthKit)
import HealthKit
#endif
import HybridTrainingCore

/// HealthKit 具體資料轉譯與讀取適配器 (HealthKitAdapter)
/// 遵循 HybridTrainingCore 的 HealthKitPort 端口協議
public final class HealthKitAdapter: HealthKitPort, @unchecked Sendable {
    
    #if canImport(HealthKit)
    private let healthStore: HKHealthStore?
    #endif
    public let isMockMode: Bool
    public var userMaxHR: Double = 185.0
    
    public init(isMockMode: Bool = false) {
        self.isMockMode = isMockMode
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() && !isMockMode {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
        }
        #endif
    }
    
    public var isHealthDataAvailable: Bool {
        #if canImport(HealthKit)
        return isMockMode || HKHealthStore.isHealthDataAvailable()
        #else
        return isMockMode
        #endif
    }
    
    public func requestAuthorization() async throws {
        if isMockMode { return }
        #if targetEnvironment(simulator)
        // 模擬器無 GUI 環境直接略過彈窗等待
        return
        #elseif canImport(HealthKit)
        guard let healthStore = self.healthStore, HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitAdapterError.healthDataNotAvailable
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        #else
        throw HealthKitAdapterError.healthDataNotAvailable
        #endif
    }
    
    // MARK: - 查詢每日晨間生理快照 (HRV SDNN 14天穩健 Z-score + 昨夜去重睡眠 + Apple Watch 生理指標)
    public func fetchPhysiologicalSnapshot(date: Date) async throws -> PhysiologicalSnapshot {
        #if targetEnvironment(simulator)
        return generateMockSnapshot(for: date)
        #else
        if isMockMode || healthStore == nil {
            return generateMockSnapshot(for: date)
        }
        
        #if canImport(HealthKit)
        guard let healthStore = self.healthStore else {
            return generateMockSnapshot(for: date)
        }
        
        // 1. 抓取昨夜睡眠分析 (總時長、深睡、REM 與分期狀態)
        let sleepAnalysis = try await fetchSleepAnalysis(for: date, healthStore: healthStore)
        
        // 2. 抓取 14 天 HRV SDNN 樣本
        let (todaySDNN, median14d, mad14d) = try await fetchHRVStatistics(upTo: date, healthStore: healthStore)

        // 3. 抓取 Apple Watch 靜息心率與呼吸率
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let rhr = try? await fetchRecentQuantity(for: .restingHeartRate, upTo: date, unit: bpmUnit, healthStore: healthStore)
        let resp = try? await fetchRecentQuantity(for: .respiratoryRate, upTo: date, unit: bpmUnit, healthStore: healthStore)
        
        // 4. 構建 Apple Watch 生理指標評估
        let todaySample = NightlyBiomarkerSample(
            date: date,
            sleepWindow: sleepAnalysis.sleepInterval,
            sleepSyncStatus: sleepAnalysis.status,
            totalSleepDurationSeconds: sleepAnalysis.totalHours * 3600.0,
            deepSleepSeconds: sleepAnalysis.deepHours.map { $0 * 3600.0 },
            remSleepSeconds: sleepAnalysis.remHours.map { $0 * 3600.0 },
            nightlySDNNValuesMs: todaySDNN.map { [$0, $0, $0] } ?? [],
            nocturnalSleepingHeartRateBpm: rhr,
            morningRestingHRBpm: rhr,
            sleepingRespiratoryRateRpm: resp,
            confounders: []
        )
        
        let engine = AppleWatchBiomarkerEngine()
        let outcome = engine.evaluate(today: todaySample, history28d: [todaySample])
        let assessment: ReadinessAssessment?
        switch outcome {
        case .assessed(let a):
            assessment = a
        case .calibrating(_, let a):
            assessment = a
        case .insufficientData:
            assessment = nil
        }
        
        return PhysiologicalSnapshot(
            date: date,
            hrvTodayMs: todaySDNN,
            hrv14dMedianMs: median14d,
            hrv14dMADMs: mad14d,
            sleepDurationHours: sleepAnalysis.totalHours,
            hasReportedPainOrInjury: false,
            morningSorenessRating: nil,
            deepSleepHours: sleepAnalysis.deepHours,
            remSleepHours: sleepAnalysis.remHours,
            nocturnalSleepingHeartRateBpm: rhr,
            restingHeartRateBpm: rhr,
            sleepingRespiratoryRateRpm: resp,
            biomarkerAssessment: assessment
        )
        #else
        return generateMockSnapshot(for: date)
        #endif
        #endif
    }
    
    // MARK: - 查詢歷史訓練記錄並轉譯為 WorkoutSession
    public func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        #if targetEnvironment(simulator)
        return generateMockWorkouts(from: startDate, to: endDate)
        #else
        if isMockMode || healthStore == nil {
            return generateMockWorkouts(from: startDate, to: endDate)
        }
        
        #if canImport(HealthKit)
        guard let healthStore = self.healthStore else {
            return generateMockWorkouts(from: startDate, to: endDate)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let hkWorkouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
        
        var sessions: [WorkoutSession] = []
        for workout in hkWorkouts {
            let session = try await convertHKWorkoutToSession(workout, healthStore: healthStore)
            sessions.append(session)
        }
        return sessions
        #else
        return generateMockWorkouts(from: startDate, to: endDate)
        #endif
        #endif
    }
    
    // MARK: - 私有 HealthKit 資料抓取細節
    #if canImport(HealthKit)
    private struct SleepAnalysisDetails {
        let totalHours: Double
        let deepHours: Double?
        let remHours: Double?
        let status: SleepSyncStatus
        let sleepInterval: DateInterval?
    }

    private func fetchSleepAnalysis(for date: Date, healthStore: HKHealthStore) async throws -> SleepAnalysisDetails {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return SleepAnalysisDetails(totalHours: 7.5, deepHours: 1.5, remHours: 1.8, status: .finalized, sleepInterval: nil)
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let queryStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let queryEnd = calendar.date(byAdding: .hour, value: 14, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: SleepAnalysisDetails(totalHours: 7.5, deepHours: 1.5, remHours: 1.8, status: .finalized, sleepInterval: nil))
                    return
                }
                
                var intervals: [(start: Date, end: Date)] = []
                var deepSeconds = 0.0
                var remSeconds = 0.0
                var hasStagedSamples = false
                
                for sample in sleepSamples {
                    let isAsleep: Bool
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            isAsleep = true
                            hasStagedSamples = true
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            isAsleep = true
                            hasStagedSamples = true
                            deepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            isAsleep = true
                            hasStagedSamples = true
                            remSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            isAsleep = true
                        default:
                            isAsleep = false
                        }
                    } else {
                        isAsleep = (sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue)
                    }
                    if isAsleep {
                        intervals.append((sample.startDate, sample.endDate))
                    }
                }
                
                intervals.sort { $0.start < $1.start }
                var merged: [(start: Date, end: Date)] = []
                for interval in intervals {
                    if let last = merged.last, interval.start <= last.end {
                        merged[merged.count - 1].end = max(last.end, interval.end)
                    } else {
                        merged.append(interval)
                    }
                }
                
                let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                let totalHours = totalSeconds / 3600.0
                let deepHours = hasStagedSamples ? (deepSeconds / 3600.0) : nil
                let remHours = hasStagedSamples ? (remSeconds / 3600.0) : nil
                
                let status: SleepSyncStatus
                if totalHours < 4.0 {
                    status = .insufficientData
                } else if hasStagedSamples {
                    status = .finalized
                } else {
                    status = .durationOnly
                }
                
                let sleepInterval: DateInterval? = {
                    guard let first = merged.first, let last = merged.last else { return nil }
                    return DateInterval(start: first.start, end: last.end)
                }()
                
                continuation.resume(returning: SleepAnalysisDetails(
                    totalHours: totalHours,
                    deepHours: deepHours,
                    remHours: remHours,
                    status: status,
                    sleepInterval: sleepInterval
                ))
            }
            healthStore.execute(query)
        }
    }

    private func fetchRecentQuantity(
        for identifier: HKQuantityTypeIdentifier,
        upTo date: Date,
        unit: HKUnit,
        healthStore: HKHealthStore
    ) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let calendar = Calendar.current
        let startWindow = calendar.date(byAdding: .day, value: -2, to: date) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startWindow, end: date, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    private func fetchSleepDurationHours(for date: Date, healthStore: HKHealthStore) async throws -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 7.5
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let queryStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let queryEnd = calendar.date(byAdding: .hour, value: 14, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: 7.5)
                    return
                }
                
                var intervals: [(start: Date, end: Date)] = []
                for sample in sleepSamples {
                    let isAsleep: Bool
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                             HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                             HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            isAsleep = true
                        default:
                            isAsleep = false
                        }
                    } else {
                        isAsleep = (sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue)
                    }
                    if isAsleep {
                        intervals.append((sample.startDate, sample.endDate))
                    }
                }
                
                // 去重重疊區間
                intervals.sort { $0.start < $1.start }
                var merged: [(start: Date, end: Date)] = []
                for interval in intervals {
                    if let last = merged.last, interval.start <= last.end {
                        merged[merged.count - 1].end = max(last.end, interval.end)
                    } else {
                        merged.append(interval)
                    }
                }
                
                let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchHRVStatistics(upTo date: Date, healthStore: HKHealthStore) async throws -> (today: Double?, median14d: Double?, mad14d: Double?) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return (nil, nil, nil)
        }
        
        let calendar = Calendar.current
        let start14d = calendar.date(byAdding: .day, value: -14, to: date) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: start14d, end: date, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let hrvSamples = samples as? [HKQuantitySample], !hrvSamples.isEmpty else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                
                let msUnit = HKUnit.secondUnit(with: .milli)
                let allValues = hrvSamples.map { $0.quantity.doubleValue(for: msUnit) }
                
                let oneDayAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
                let todaySamples = hrvSamples.filter { $0.startDate >= oneDayAgo }.map { $0.quantity.doubleValue(for: msUnit) }
                let todayVal = todaySamples.isEmpty ? allValues.first : todaySamples.sorted()[todaySamples.count / 2]
                
                let sortedAll = allValues.sorted()
                let median14d = sortedAll[sortedAll.count / 2]
                
                let absoluteDeviations = sortedAll.map { abs($0 - median14d) }.sorted()
                let rawMAD = absoluteDeviations[absoluteDeviations.count / 2]
                let mad14d = max(rawMAD, 2.0)
                
                continuation.resume(returning: (todayVal, median14d, mad14d))
            }
            healthStore.execute(query)
        }
    }
    
    private func convertHKWorkoutToSession(_ workout: HKWorkout, healthStore: HKHealthStore) async throws -> WorkoutSession {
        let durationMinutes = workout.duration / 60.0
        let isRunning = (workout.workoutActivityType == .running)
        
        if isRunning {
            let zoneDurations = try await calculateWorkoutZones(workout: workout, healthStore: healthStore)
            let derivedSRPE = FosterLoadCalculator.deriveRunningRPE(zoneDurationsSeconds: zoneDurations, personalBias: 0.0)
            
            return WorkoutSession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                discipline: .running,
                durationMinutes: durationMinutes,
                sRPE: derivedSRPE,
                movementPatterns: [],
                source: .healthKitWorkout(hkUUID: workout.uuid),
                averageHeartRate: nil,
                zoneDurationsSeconds: zoneDurations,
                requiresManualRPEConfirmation: false
            )
        } else if workout.workoutActivityType == .cycling {
            let zoneDurations = try await calculateWorkoutZones(workout: workout, healthStore: healthStore)
            let derivedSRPE = FosterLoadCalculator.deriveRunningRPE(zoneDurationsSeconds: zoneDurations, personalBias: -0.5)
            
            return WorkoutSession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                discipline: .cycling,
                durationMinutes: durationMinutes,
                sRPE: derivedSRPE,
                movementPatterns: [.lowerQuad],
                source: .healthKitWorkout(hkUUID: workout.uuid),
                averageHeartRate: nil,
                zoneDurationsSeconds: zoneDurations,
                requiresManualRPEConfirmation: false
            )
        } else if workout.workoutActivityType == .swimming {
            let zoneDurations = try await calculateWorkoutZones(workout: workout, healthStore: healthStore)
            let derivedSRPE = FosterLoadCalculator.deriveRunningRPE(zoneDurationsSeconds: zoneDurations, personalBias: 0.0)
            
            return WorkoutSession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                discipline: .swimming,
                durationMinutes: durationMinutes,
                sRPE: derivedSRPE,
                movementPatterns: [.upperPull],
                source: .healthKitWorkout(hkUUID: workout.uuid),
                averageHeartRate: nil,
                zoneDurationsSeconds: zoneDurations,
                requiresManualRPEConfirmation: false
            )
        } else if workout.workoutActivityType == .rowing {
            let zoneDurations = try await calculateWorkoutZones(workout: workout, healthStore: healthStore)
            let derivedSRPE = FosterLoadCalculator.deriveRunningRPE(zoneDurationsSeconds: zoneDurations, personalBias: 0.5)
            
            return WorkoutSession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                discipline: .rowing,
                durationMinutes: durationMinutes,
                sRPE: derivedSRPE,
                movementPatterns: [.upperPull, .lowerPosterior],
                source: .healthKitWorkout(hkUUID: workout.uuid),
                averageHeartRate: nil,
                zoneDurationsSeconds: zoneDurations,
                requiresManualRPEConfirmation: false
            )
        } else {
            let discipline: TrainingDiscipline
            let patterns: [MovementPattern]
            if workout.workoutActivityType == .traditionalStrengthTraining || workout.workoutActivityType == .functionalStrengthTraining {
                discipline = .strength
                patterns = [.lowerQuad]
            } else {
                discipline = .mobility
                patterns = []
            }
            
            return WorkoutSession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                discipline: discipline,
                durationMinutes: durationMinutes,
                sRPE: 7.0,
                movementPatterns: patterns,
                source: .healthKitWorkout(hkUUID: workout.uuid),
                requiresManualRPEConfirmation: true
            )
        }
    }
    
    private func calculateWorkoutZones(workout: HKWorkout, healthStore: HKHealthStore) async throws -> [Int: Double] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return [:]
        }
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let hrSamples = samples as? [HKQuantitySample], hrSamples.count > 1 else {
                    continuation.resume(returning: [:])
                    return
                }
                
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                var zoneDurations: [Int: Double] = [0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
                
                for i in 0..<(hrSamples.count - 1) {
                    let cur = hrSamples[i]
                    let next = hrSamples[i + 1]
                    let interval = next.startDate.timeIntervalSince(cur.startDate)
                    let clamped = min(interval, 15.0)
                    if clamped > 0 {
                        let bpm = cur.quantity.doubleValue(for: bpmUnit)
                        let zone = self.resolveZone(bpm: bpm, maxHR: self.userMaxHR)
                        zoneDurations[zone, default: 0] += clamped
                    }
                }
                continuation.resume(returning: zoneDurations)
            }
            healthStore.execute(query)
        }
    }
    
    private func resolveZone(bpm: Double, maxHR: Double) -> Int {
        let percent = bpm / maxHR
        switch percent {
        case ..<0.50: return 0
        case 0.50..<0.60: return 1
        case 0.60..<0.70: return 2
        case 0.70..<0.80: return 3
        case 0.80..<0.90: return 4
        default: return 5
        }
    }
    #endif
    
    // MARK: - 模擬與備用資料生成 (供 Simulator 與離線測試)
    private func generateMockSnapshot(for date: Date) -> PhysiologicalSnapshot {
        let assessment = ReadinessAssessment(
            dayKey: TrainingDayKey(date: date),
            score: 84,
            zone: .ready,
            autonomic: .balanced,
            confidence: .high,
            sleepStatus: .finalized,
            lnHRVZScore: 0.42,
            consecutiveElevatedRHRDays: 0,
            consecutiveElevatedRespRateDays: 0,
            respiratoryWarningTriggered: false,
            revision: 2,
            algorithmVersion: "4.2.0-applewatch",
            diagnosticMessages: ["Apple Watch 生理指標與修復比率處於最佳區間。"]
        )
        return PhysiologicalSnapshot(
            date: date,
            hrvTodayMs: 62.0,
            hrv14dMedianMs: 58.0,
            hrv14dMADMs: 4.5,
            sleepDurationHours: 7.8,
            hasReportedPainOrInjury: false,
            morningSorenessRating: nil,
            deepSleepHours: 1.5,
            remSleepHours: 1.8,
            nocturnalSleepingHeartRateBpm: 48.0,
            restingHeartRateBpm: 50.0,
            sleepingRespiratoryRateRpm: 13.5,
            biomarkerAssessment: assessment
        )
    }
    
    public func generateMockWorkouts(from startDate: Date, to endDate: Date) -> [WorkoutSession] {
        var sessions: [WorkoutSession] = []
        let calendar = Calendar.current
        var cur = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)
        
        while cur <= last {
            let weekday = calendar.component(.weekday, from: cur)
            let workoutTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: cur) ?? cur
            
            switch weekday {
            case 2: // Mon: 腿部重訓
                sessions.append(WorkoutSession(
                    startDate: workoutTime,
                    endDate: workoutTime.addingTimeInterval(50 * 60),
                    discipline: .strength,
                    durationMinutes: 50,
                    sRPE: 7.5,
                    movementPatterns: [.lowerQuad, .lowerPosterior],
                    source: .manualLog
                ))
            case 3: // Tue: Zone 2 跑
                sessions.append(WorkoutSession(
                    startDate: workoutTime,
                    endDate: workoutTime.addingTimeInterval(40 * 60),
                    discipline: .running,
                    durationMinutes: 40,
                    sRPE: 3.5,
                    movementPatterns: [],
                    source: .healthKitWorkout(hkUUID: UUID()),
                    averageHeartRate: 138,
                    zoneDurationsSeconds: [2: 35 * 60, 1: 5 * 60]
                ))
            case 4: // Wed: 上肢推拉
                sessions.append(WorkoutSession(
                    startDate: workoutTime,
                    endDate: workoutTime.addingTimeInterval(45 * 60),
                    discipline: .strength,
                    durationMinutes: 45,
                    sRPE: 7.0,
                    movementPatterns: [.upperPush, .upperPull],
                    source: .manualLog
                ))
            case 5: // Thu: 間歇跑
                sessions.append(WorkoutSession(
                    startDate: workoutTime,
                    endDate: workoutTime.addingTimeInterval(35 * 60),
                    discipline: .running,
                    durationMinutes: 35,
                    sRPE: 8.0,
                    movementPatterns: [],
                    source: .healthKitWorkout(hkUUID: UUID()),
                    averageHeartRate: 165,
                    zoneDurationsSeconds: [4: 20 * 60, 2: 15 * 60]
                ))
            case 7: // Sat: 長距離有氧
                sessions.append(WorkoutSession(
                    startDate: workoutTime,
                    endDate: workoutTime.addingTimeInterval(70 * 60),
                    discipline: .running,
                    durationMinutes: 70,
                    sRPE: 5.0,
                    movementPatterns: [],
                    source: .healthKitWorkout(hkUUID: UUID()),
                    averageHeartRate: 145,
                    zoneDurationsSeconds: [2: 50 * 60, 3: 20 * 60]
                ))
            default:
                break
            }
            
            cur = calendar.date(byAdding: .day, value: 1, to: cur) ?? last.addingTimeInterval(1)
        }
        return sessions
    }
}

public enum HealthKitAdapterError: Error, LocalizedError {
    case healthDataNotAvailable
    case typeIdentifierInvalid
    
    public var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "此裝置目前無法存取 Apple HealthKit 資料庫。"
        case .typeIdentifierInvalid:
            return "無法識別之 HealthKit 資料類型標識符號。"
        }
    }
}
