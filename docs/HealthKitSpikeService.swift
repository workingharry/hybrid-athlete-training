import Foundation
import HealthKit
#if canImport(WorkoutKit)
import WorkoutKit
#endif

// MARK: - 1. HealthKit 資料探針與統計服務 (HealthKitSpikeService)
/// 用於驗證真實 HealthKit 資料品質（HRV 採樣密度、睡眠階層去重、心率區間動態積分）
public final class HealthKitSpikeService {
    private let healthStore = HKHealthStore()
    
    public init() {}
    
    /// 檢查裝置是否支援 HealthKit
    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// 請求讀取權限
    public func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitSpikeError.healthDataNotAvailable
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
    
    // MARK: - Spike 1: 檢驗過去 N 天的 HRV (SDNN) 採樣頻率與分佈 (單位：毫秒 ms)
    public func fetchHRVSamples(days: Int = 14) async throws -> HRVSpikeReport {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitSpikeError.typeIdentifierInvalid
        }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let hrvSamples = samples as? [HKQuantitySample], !hrvSamples.isEmpty else {
                    continuation.resume(returning: HRVSpikeReport(totalSamples: 0, valuesMs: [], dailyAverageCount: 0, isPassStandard: false))
                    return
                }
                
                let msUnit = HKUnit.secondUnit(with: .milli)
                let values = hrvSamples.map { $0.quantity.doubleValue(for: msUnit) }
                let dailyAverage = Double(hrvSamples.count) / Double(max(1, days))
                
                // 驗收標準：每日夜間平均取樣數 >= 3 筆為通過
                let isPass = dailyAverage >= 3.0
                
                let report = HRVSpikeReport(
                    totalSamples: hrvSamples.count,
                    valuesMs: values,
                    dailyAverageCount: dailyAverage,
                    isPassStandard: isPass
                )
                continuation.resume(returning: report)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Spike 2: 檢驗單次跑步 Workout 之離散心率樣本並計算 5 區間停留秒數
    /// 使用動態時間差累計，支援最大心率使用者自訂覆寫
    public func calculateHeartRateZones(for workout: HKWorkout, userMaxHR: Double?) async throws -> HeartRateZonesReport {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitSpikeError.typeIdentifierInvalid
        }
        
        // 優先使用 predicateForObjects 綁定該 workout，若為舊版資料則 fallback 至時間範圍
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let hrSamples = samples as? [HKQuantitySample], hrSamples.count > 1 else {
                    continuation.resume(returning: HeartRateZonesReport(zoneDurations: [:], totalCalculatedSeconds: 0, workoutDuration: workout.duration, sampleCount: 0, isPassStandard: false))
                    return
                }
                
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                let effectiveMaxHR = userMaxHR ?? 185.0 // 若使用者未手動設定，預設為保守經驗值
                var zoneDurations: [Int: TimeInterval] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
                var totalCalculatedTime: TimeInterval = 0
                
                for i in 0..<(hrSamples.count - 1) {
                    let currentSample = hrSamples[i]
                    let nextSample = hrSamples[i + 1]
                    let interval = nextSample.startDate.timeIntervalSince(currentSample.startDate)
                    
                    // 防呆：異常大間隔（例如中途手錶脫落或暫停 > 30秒）設定時間差上限，避免失真
                    let clampedInterval = min(interval, 15.0)
                    
                    if clampedInterval > 0 {
                        let bpm = currentSample.quantity.doubleValue(for: bpmUnit)
                        let zone = self.resolveHeartRateZone(bpm: bpm, maxHR: effectiveMaxHR)
                        zoneDurations[zone, default: 0] += clampedInterval
                        totalCalculatedTime += clampedInterval
                    }
                }
                
                // 驗收標準：累計積分時間與實際 workout duration 誤差在 5% 以內為通過
                let diffRatio = abs(totalCalculatedTime - workout.duration) / max(1.0, workout.duration)
                let isPass = diffRatio <= 0.05
                
                let report = HeartRateZonesReport(
                    zoneDurations: zoneDurations,
                    totalCalculatedSeconds: totalCalculatedTime,
                    workoutDuration: workout.duration,
                    sampleCount: hrSamples.count,
                    isPassStandard: isPass
                )
                continuation.resume(returning: report)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Spike 3: 檢驗昨夜睡眠 Stage 結構（包含多來源區間去重）
    public func fetchRecentSleepAnalysis() async throws -> SleepSpikeReport {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitSpikeError.typeIdentifierInvalid
        }
        
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: SleepSpikeReport(hasDetailedStages: false, totalSleepHours: 0, isPassStandard: false))
                    return
                }
                
                var hasDetailedStages = false
                var totalDurationSeconds: TimeInterval = 0
                
                // 簡易區間合併去重邏輯 (避免多 App 或 Watch 同時寫入造成睡眠時間加倍)
                var mergedIntervals: [(start: Date, end: Date)] = []
                
                for sample in sleepSamples {
                    let isAsleep: Bool
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                             HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            hasDetailedStages = true
                            isAsleep = true
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            isAsleep = true
                        default:
                            isAsleep = false
                        }
                    } else {
                        isAsleep = (sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue)
                    }
                    
                    if isAsleep {
                        mergedIntervals.append((sample.startDate, sample.endDate))
                    }
                }
                
                // 合併重疊時間段
                mergedIntervals.sort { $0.start < $1.start }
                var dedupedIntervals: [(start: Date, end: Date)] = []
                for interval in mergedIntervals {
                    if let last = dedupedIntervals.last, interval.start <= last.end {
                        dedupedIntervals[dedupedIntervals.count - 1].end = max(last.end, interval.end)
                    } else {
                        dedupedIntervals.append(interval)
                    }
                }
                
                for interval in dedupedIntervals {
                    totalDurationSeconds += interval.end.timeIntervalSince(interval.start)
                }
                
                let totalHours = totalDurationSeconds / 3600.0
                let isPass = hasDetailedStages && totalHours >= 4.0
                
                let report = SleepSpikeReport(
                    hasDetailedStages: hasDetailedStages,
                    totalSleepHours: totalHours,
                    isPassStandard: isPass
                )
                continuation.resume(returning: report)
            }
            healthStore.execute(query)
        }
    }
    
    private func resolveHeartRateZone(bpm: Double, maxHR: Double) -> Int {
        let percent = bpm / maxHR
        switch percent {
        case ..<0.60: return 1
        case 0.60..<0.70: return 2
        case 0.70..<0.80: return 3
        case 0.80..<0.90: return 4
        default: return 5
        }
    }
}

// MARK: - 2. WorkoutKit 推播服務 (WorkoutKitSpikeService)
/// 驗證如何使用 WorkoutKit 正確將自訂跑步課表推播排程至 Apple Watch
#if canImport(WorkoutKit)
@available(iOS 17.0, *)
public final class WorkoutKitSpikeService {
    public init() {}
    
    /// 請求 WorkoutKit 排程授權
    public func requestAuthorization() async throws {
        try await WorkoutScheduler.shared.requestAuthorization()
    }
    
    /// 構建一個「自適應 Zone 2 耐力跑課表」並同步到 Apple Watch (支援排程日期設定)
    public func scheduleZone2WorkoutToWatch(targetMinutes: Int = 30, lowerBpm: Double = 130, upperBpm: Double = 145, scheduledDate: Date = Date()) async throws {
        // 1. 定義心率目標區間 (Target Zone)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let lowQuantity = HKQuantity(unit: bpmUnit, doubleValue: lowerBpm)
        let highQuantity = HKQuantity(unit: bpmUnit, doubleValue: upperBpm)
        let heartRateRange = WorkoutKit.WorkoutRange(low: lowQuantity, high: highQuantity)
        let heartRateTarget = WorkoutKit.WorkoutTarget.heartRate(heartRateRange)
        
        // 2. 暖身步驟 (Warmup - 5分鐘)
        let warmupStep = WorkoutKit.WorkoutStep(
            goal: .time(5 * 60, .seconds)
        )
        
        // 3. 主區間區塊 (IntervalStep)
        let workStep = WorkoutKit.IntervalStep(
            .work,
            goal: .time(Double(targetMinutes) * 60, .seconds),
            alert: heartRateTarget
        )
        
        let intervalBlock = WorkoutKit.IntervalBlock(
            steps: [workStep],
            iterations: 1
        )
        
        // 4. 緩和收操 (Cooldown - 5分鐘)
        let cooldownStep = WorkoutKit.WorkoutStep(
            goal: .time(5 * 60, .seconds)
        )
        
        // 5. 組合為自訂跑步體能訓練 (CustomWorkout)
        let customWorkout = WorkoutKit.CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: "今日自適應 Zone 2 基底跑",
            warmup: warmupStep,
            blocks: [intervalBlock],
            cooldown: cooldownStep
        )
        
        let workoutPlan = WorkoutKit.WorkoutPlan(.custom(customWorkout))
        
        // 6. 轉換日期為 DateComponents 並排程至手錶
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
        
        try await WorkoutScheduler.shared.schedule(workoutPlan, at: dateComponents)
    }
}
#endif

// MARK: - 探針回報數據結構
public struct HRVSpikeReport {
    public let totalSamples: Int
    public let valuesMs: [Double]
    public let dailyAverageCount: Double
    public let isPassStandard: Bool
}

public struct HeartRateZonesReport {
    public let zoneDurations: [Int: TimeInterval]
    public let totalCalculatedSeconds: TimeInterval
    public let workoutDuration: TimeInterval
    public let sampleCount: Int
    public let isPassStandard: Bool
}

public struct SleepSpikeReport {
    public let hasDetailedStages: Bool
    public let totalSleepHours: Double
    public let isPassStandard: Bool
}

public enum HealthKitSpikeError: Error {
    case healthDataNotAvailable
    case typeIdentifierInvalid
}
