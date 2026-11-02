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
        
        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        if let hrrType = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) {
            readTypes.insert(hrrType)
        }
        
        if #available(iOS 16.0, *) {
            if let wristTempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                readTypes.insert(wristTempType)
            }
            if let gct = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime) {
                readTypes.insert(gct)
            }
            if let stride = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) {
                readTypes.insert(stride)
            }
            if let osc = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation) {
                readTypes.insert(osc)
            }
            if let power = HKQuantityType.quantityType(forIdentifier: .runningPower) {
                readTypes.insert(power)
            }
        }
        
        // Apple Watch Series 10 / watchOS 11 呼吸紊亂指標 (安全動態註冊，非醫療診斷用途)
        let breathingDisturbancesId = HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances")
        if let breathingType = HKQuantityType.quantityType(forIdentifier: breathingDisturbancesId) {
            readTypes.insert(breathingType)
        }
        
        if #available(iOS 17.0, *) {
            if let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) {
                readTypes.insert(daylightType)
            }
        }
        
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
        
        // 1. 並發抓取昨夜睡眠分析與 14 天 HRV SDNN 統計 (P1: 消除串行化等待)
        async let sleepTask = fetchSleepAnalysis(for: date, healthStore: healthStore)
        async let hrvTask = fetchHRVStatistics(upTo: date, healthStore: healthStore)

        // 2. 透過 MetricResult 隔離每個傳感器查詢，單項失敗或不可用不崩潰全流程 (Claude Review §4.1)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        async let rhrTask = fetchRecentMetric(for: .restingHeartRate, upTo: date, unit: bpmUnit, healthStore: healthStore)
        async let respTask = fetchRecentMetric(for: .respiratoryRate, upTo: date, unit: bpmUnit, healthStore: healthStore)
        async let walkingHRTask = fetchRecentMetric(for: .walkingHeartRateAverage, upTo: date, unit: bpmUnit, healthStore: healthStore)
        async let hrrTask = fetchRecentMetric(for: .heartRateRecoveryOneMinute, upTo: date, unit: bpmUnit, healthStore: healthStore)
        
        async let wristTempTask: MetricResult<Double> = {
            if #available(iOS 16.0, *) {
                return await self.fetchRecentMetric(for: .appleSleepingWristTemperature, upTo: date, unit: HKUnit.degreeCelsius(), healthStore: healthStore)
            } else {
                return .unavailable
            }
        }()

        // 3. 抓取真實歷史 28 天樣本（徹底移除 (1...20).map 假 Mock 資料）
        async let historyTask = fetchHistoricalNightlySamples(upTo: date, days: 28, healthStore: healthStore)

        let sleepAnalysis = try await sleepTask
        let (todaySDNN, median14d, mad14d) = try await hrvTask
        let (rhrResult, respResult, walkingHRResult, hrrResult, wristTempResult) = await (rhrTask, respTask, walkingHRTask, hrrTask, wristTempTask)
        let history28d = await historyTask

        let rhr = rhrResult.value
        let resp = respResult.value
        let walkingHR = walkingHRResult.value
        let hrrOneMin = hrrResult.value
        let wristTemp = wristTempResult.value
        
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
            sleepingWristTemperatureCelsius: wristTemp.map { 36.5 + $0 },
            wristTemperatureBaselineDeltaCelsius: wristTemp,
            walkingHeartRateAverageBpm: walkingHR,
            heartRateRecoveryOneMinuteBpm: hrrOneMin,
            confounders: []
        )
        
        let engine = AppleWatchBiomarkerEngine()
        let outcome = engine.evaluate(today: todaySample, history28d: history28d)
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
    
    // MARK: - 習慣作息計算 (依 14~28 天睡眠區間計算圓周平均清醒時間，資料不足則優雅回退為 nil)
    public static func calculateHabitualWakeTime(
        from sleepRecords: [DailySleepRecord],
        targetDate: Date,
        calendar: Calendar = .current,
        minimumDays: Int = 3
    ) -> Date? {
        guard sleepRecords.count >= minimumDays else {
            return nil
        }
        
        let wakeMinutes = sleepRecords.map { Double($0.wakeMinuteOfDay) }
        let circularMeanMin = CircadianBiophysicsEngine.circularMeanMinutes(wakeMinutes)
        let normalizedMean = CircadianBiophysicsEngine.normalizeMinuteOfDay(Int(circularMeanMin.rounded()))
        let hour = normalizedMean / 60
        let minute = normalizedMean % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate)
    }

    // MARK: - 查詢晝夜節律輸入 (今日清醒時間、習慣清醒時間、累積睡眠債、日照分鐘數、近期每日睡眠紀錄)
    public func fetchCircadianInputs(targetDate: Date = Date()) async -> (todayWake: Date, habitualWake: Date?, sleepDebtHours: Double, daylightMinutes: Double, recentSleepRecords: [DailySleepRecord]) {
        let calendar = Calendar.current
        #if targetEnvironment(simulator)
        let sleepRecords = generateMockHistoricalSleepRecords(upTo: targetDate, days: 14)
        let habitualWake = Self.calculateHabitualWakeTime(from: sleepRecords, targetDate: targetDate, calendar: calendar)
        let defaultWake = habitualWake ?? (calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate)
        return (todayWake: defaultWake, habitualWake: habitualWake, sleepDebtHours: 0.5, daylightMinutes: 25.0, recentSleepRecords: sleepRecords)
        #else
        if isMockMode {
            let sleepRecords = generateMockHistoricalSleepRecords(upTo: targetDate, days: 14)
            let habitualWake = Self.calculateHabitualWakeTime(from: sleepRecords, targetDate: targetDate, calendar: calendar)
            let defaultWake = habitualWake ?? (calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate)
            return (todayWake: defaultWake, habitualWake: habitualWake, sleepDebtHours: 0.5, daylightMinutes: 25.0, recentSleepRecords: sleepRecords)
        }
        #if canImport(HealthKit)
        guard let healthStore = self.healthStore else {
            let defaultWake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate
            return (todayWake: defaultWake, habitualWake: nil, sleepDebtHours: 0.5, daylightMinutes: 0.0, recentSleepRecords: [])
        }
        
        do {
            async let sleepAnalysisTask = fetchSleepAnalysis(for: targetDate, healthStore: healthStore)
            async let daylightTask = fetchTimeInDaylight(for: targetDate, healthStore: healthStore)
            async let historySleepTask = fetchHistoricalSleepRecords(upTo: targetDate, days: 28)
            
            let sleepAnalysis = try await sleepAnalysisTask
            let daylight = await daylightTask
            let historySleep = await historySleepTask
            
            let habitualWake = Self.calculateHabitualWakeTime(from: historySleep, targetDate: targetDate, calendar: calendar)
            let todayWake = sleepAnalysis.sleepInterval?.end ?? habitualWake ?? (calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate)
            let sleepDebt: Double
            if sleepAnalysis.totalHours >= 4.0 {
                sleepDebt = max(0.0, 8.0 - sleepAnalysis.totalHours)
            } else {
                sleepDebt = 1.2
            }
            
            return (todayWake: todayWake, habitualWake: habitualWake, sleepDebtHours: sleepDebt, daylightMinutes: daylight, recentSleepRecords: historySleep)
        } catch {
            let defaultWake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate
            return (todayWake: defaultWake, habitualWake: nil, sleepDebtHours: 0.5, daylightMinutes: 0.0, recentSleepRecords: [])
        }
        #else
        let defaultWake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: targetDate) ?? targetDate
        return (todayWake: defaultWake, habitualWake: nil, sleepDebtHours: 0.5, daylightMinutes: 0.0, recentSleepRecords: [])
        #endif
        #endif
    }
    
    #if canImport(HealthKit)
    /// 查詢 iOS 17+ 戶外日照時間 (Time in Daylight) 分鐘數
    private func fetchTimeInDaylight(for date: Date, healthStore: HKHealthStore) async -> Double {
        if #available(iOS 17.0, *) {
            guard let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
                return 0.0
            }
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date, options: .strictStartDate)
            
            return await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: daylightType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                    guard let sum = statistics?.sumQuantity() else {
                        continuation.resume(returning: 0.0)
                        return
                    }
                    let minutes = sum.doubleValue(for: HKUnit.minute())
                    continuation.resume(returning: minutes)
                }
                healthStore.execute(query)
            }
        } else {
            return 0.0
        }
    }
    #endif
    
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
            return SleepAnalysisDetails(totalHours: 0.0, deepHours: nil, remHours: nil, status: .insufficientData, sleepInterval: nil)
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
                    continuation.resume(returning: SleepAnalysisDetails(totalHours: 0.0, deepHours: nil, remHours: nil, status: .insufficientData, sleepInterval: nil))
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

    // MARK: - 查詢歷史每日睡眠區間與去重記錄 (14~28 天，供圓周習慣清醒計算與真實對齊分數)
    public func fetchHistoricalSleepRecords(
        upTo date: Date,
        days: Int = 28
    ) async -> [DailySleepRecord] {
        #if targetEnvironment(simulator)
        return generateMockHistoricalSleepRecords(upTo: date, days: min(days, 14))
        #else
        if isMockMode {
            return generateMockHistoricalSleepRecords(upTo: date, days: min(days, 14))
        }
        #if canImport(HealthKit)
        guard let healthStore = self.healthStore, let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: date) else { return [] }
        let queryStart = calendar.date(byAdding: .hour, value: -12, to: startDate) ?? startDate
        let queryEnd = date
        
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone

        var intervalsByDay: [String: [(start: Date, end: Date)]] = [:]
        for sample in samples {
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
                let hour = calendar.component(.hour, from: sample.endDate)
                let wakeDate = hour >= 18 ? (calendar.date(byAdding: .day, value: 1, to: sample.endDate) ?? sample.endDate) : sample.endDate
                let dayKey = formatter.string(from: calendar.startOfDay(for: wakeDate))
                intervalsByDay[dayKey, default: []].append((sample.startDate, sample.endDate))
            }
        }
        
        var records: [DailySleepRecord] = []
        for (dayKey, dayIntervals) in intervalsByDay {
            guard !dayIntervals.isEmpty, let dayDate = formatter.date(from: dayKey) else { continue }
            let sorted = dayIntervals.sorted { $0.start < $1.start }
            
            var merged: [(start: Date, end: Date)] = []
            for interval in sorted {
                if let last = merged.last, interval.start <= last.end {
                    merged[merged.count - 1].end = max(last.end, interval.end)
                } else {
                    merged.append(interval)
                }
            }
            
            // 將相隔 <= 90 分鐘的片段聚合為睡眠週期 (Session)，隔離日間小憩並包容夜間短暫醒來
            var sessions: [[(start: Date, end: Date)]] = []
            for interval in merged {
                if let currentSession = sessions.last, let lastInterval = currentSession.last,
                   interval.start.timeIntervalSince(lastInterval.end) <= 90 * 60 {
                    var updated = currentSession
                    updated.append(interval)
                    sessions[sessions.count - 1] = updated
                } else {
                    sessions.append([interval])
                }
            }
            
            // 主夜間睡眠為總時長最長之 Session
            guard let primarySession = sessions.max(by: { s1, s2 in
                let dur1 = s1.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                let dur2 = s2.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                return dur1 < dur2
            }), let firstStart = primarySession.first?.start, let lastEnd = primarySession.last?.end else { continue }
            
            let totalAsleepSec = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
            let totalHours = totalAsleepSec / 3600.0
            guard totalHours >= 1.0 else { continue }
            
            let wakeHour = calendar.component(.hour, from: lastEnd)
            let wakeMin = calendar.component(.minute, from: lastEnd)
            let wakeMinuteOfDay = wakeHour * 60 + wakeMin
            
            let onsetHour = calendar.component(.hour, from: firstStart)
            let onsetMin = calendar.component(.minute, from: firstStart)
            let onsetMinuteOfDay = onsetHour * 60 + onsetMin
            
            let daysAgo = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: dayDate), to: calendar.startOfDay(for: date)).day ?? 0)
            let isFreeDay = calendar.isDateInWeekend(lastEnd)
            
            records.append(DailySleepRecord(
                daysAgo: daysAgo,
                sleepNeedHours: 8.0,
                actualAsleepHours: totalHours,
                sleepOnsetMinuteOfDay: onsetMinuteOfDay,
                wakeMinuteOfDay: wakeMinuteOfDay,
                isFreeDay: isFreeDay
            ))
        }
        
        records.sort { $0.daysAgo < $1.daysAgo }
        return records
        #else
        return []
        #endif
        #endif
    }

    // MARK: - MetricResult 容錯並發傳感器查詢
    private func fetchRecentMetric(
        for identifier: HKQuantityTypeIdentifier,
        upTo date: Date,
        unit: HKUnit,
        healthStore: HKHealthStore
    ) async -> MetricResult<Double> {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return .unavailable
        }
        let calendar = Calendar.current
        let startWindow = calendar.date(byAdding: .day, value: -2, to: date) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startWindow, end: date, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: .failed(error.localizedDescription))
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: .noData)
                    return
                }
                continuation.resume(returning: .value(sample.quantity.doubleValue(for: unit)))
            }
            healthStore.execute(query)
        }
    }

    /// 抓取真實歷史夜間樣本（徹底移除假 Mock 資料，基於真實健康樣本並以 TrainingDayKey 跨午夜歸屬分桶）
    private func fetchHistoricalNightlySamples(
        upTo date: Date,
        days: Int = 28,
        healthStore: HKHealthStore
    ) async -> [NightlyBiomarkerSample] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: date) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: date, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        async let hrvTask: [HKQuantitySample] = fetchQuantitySamples(for: .heartRateVariabilitySDNN, predicate: predicate, sort: sortDescriptor, store: healthStore)
        async let rhrTask: [HKQuantitySample] = fetchQuantitySamples(for: .restingHeartRate, predicate: predicate, sort: sortDescriptor, store: healthStore)
        async let respTask: [HKQuantitySample] = fetchQuantitySamples(for: .respiratoryRate, predicate: predicate, sort: sortDescriptor, store: healthStore)
        async let tempTask: [HKQuantitySample] = fetchSleepingWristTemperatureSamples(predicate: predicate, sort: sortDescriptor, store: healthStore)
        
        let (hrvSamples, rhrSamples, respSamples, tempSamples) = await (hrvTask, rhrTask, respTask, tempTask)
        
        let msUnit = HKUnit.secondUnit(with: .milli)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let degCUnit = HKUnit.degreeCelsius()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone

        func wakeDayKey(for sampleDate: Date) -> String {
            let hour = calendar.component(.hour, from: sampleDate)
            let wakeDate = hour >= 18 ? (calendar.date(byAdding: .day, value: 1, to: sampleDate) ?? sampleDate) : sampleDate
            return formatter.string(from: calendar.startOfDay(for: wakeDate))
        }
        
        var hrvBuckets: [String: [Double]] = [:]
        var rhrBuckets: [String: [Double]] = [:]
        var respBuckets: [String: [Double]] = [:]
        var tempBuckets: [String: [Double]] = [:]
        
        for sample in hrvSamples {
            let key = wakeDayKey(for: sample.startDate)
            hrvBuckets[key, default: []].append(sample.quantity.doubleValue(for: msUnit))
        }
        for sample in rhrSamples {
            let key = wakeDayKey(for: sample.startDate)
            rhrBuckets[key, default: []].append(sample.quantity.doubleValue(for: bpmUnit))
        }
        for sample in respSamples {
            let key = wakeDayKey(for: sample.startDate)
            respBuckets[key, default: []].append(sample.quantity.doubleValue(for: bpmUnit))
        }
        for sample in tempSamples {
            let key = wakeDayKey(for: sample.startDate)
            tempBuckets[key, default: []].append(sample.quantity.doubleValue(for: degCUnit))
        }
        
        let allKeys = Set(hrvBuckets.keys).union(rhrBuckets.keys).union(respBuckets.keys).union(tempBuckets.keys)
        var result: [NightlyBiomarkerSample] = []
        for dateStr in allKeys {
            guard let dayDate = formatter.date(from: dateStr) else { continue }
            let sdnns = hrvBuckets[dateStr] ?? []
            let rhrs = rhrBuckets[dateStr] ?? []
            let resps = respBuckets[dateStr] ?? []
            let temps = tempBuckets[dateStr] ?? []
            
            let avgRhr = rhrs.isEmpty ? nil : (rhrs.reduce(0.0, +) / Double(rhrs.count))
            let avgResp = resps.isEmpty ? nil : (resps.reduce(0.0, +) / Double(resps.count))
            let avgTemp = temps.isEmpty ? nil : (temps.reduce(0.0, +) / Double(temps.count))
            
            result.append(NightlyBiomarkerSample(
                date: dayDate,
                sleepSyncStatus: .finalized,
                totalSleepDurationSeconds: 7.5 * 3600.0,
                nightlySDNNValuesMs: sdnns,
                nocturnalSleepingHeartRateBpm: avgRhr,
                morningRestingHRBpm: avgRhr,
                sleepingRespiratoryRateRpm: avgResp,
                sleepingWristTemperatureCelsius: avgTemp.map { 36.5 + $0 },
                wristTemperatureBaselineDeltaCelsius: avgTemp,
                confounders: []
            ))
        }
        result.sort { $0.date < $1.date }
        return result
    }

    private func fetchSleepingWristTemperatureSamples(
        predicate: NSPredicate,
        sort: NSSortDescriptor,
        store: HKHealthStore
    ) async -> [HKQuantitySample] {
        if #available(iOS 16.0, *) {
            return await fetchQuantitySamples(for: .appleSleepingWristTemperature, predicate: predicate, sort: sort, store: store)
        } else {
            return []
        }
    }

    private func fetchQuantitySamples(
        for identifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        sort: NSSortDescriptor,
        store: HKHealthStore
    ) async -> [HKQuantitySample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
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

    private func generateMockHistoricalSleepRecords(upTo date: Date, days: Int = 14) -> [DailySleepRecord] {
        let calendar = Calendar.current
        return (0..<days).map { daysAgo in
            let recordDate = calendar.date(byAdding: .day, value: -daysAgo, to: date) ?? date
            let isFreeDay = calendar.isDateInWeekend(recordDate)
            let wakeMinute = isFreeDay ? (7 * 60 + 40 + (daysAgo % 3) * 5) : (7 * 60 + 10 + (daysAgo % 4) * 4)
            let onsetMinute = isFreeDay ? (23 * 60 + 45 + (daysAgo % 2) * 10) : (23 * 60 + 15 + (daysAgo % 3) * 8)
            let sleepHours = isFreeDay ? 7.8 : 7.4
            
            return DailySleepRecord(
                daysAgo: daysAgo,
                sleepNeedHours: 8.0,
                actualAsleepHours: sleepHours,
                sleepOnsetMinuteOfDay: onsetMinute,
                wakeMinuteOfDay: wakeMinute,
                isFreeDay: isFreeDay
            )
        }
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
