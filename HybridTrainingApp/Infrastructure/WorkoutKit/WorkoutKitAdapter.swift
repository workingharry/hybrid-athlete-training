import Foundation
#if canImport(WorkoutKit)
import WorkoutKit
import HealthKit
#endif
import HybridTrainingCore

/// WorkoutKit 原生課表推播與排程適配器 (WorkoutKitAdapter)
/// 遵循 WorkoutKitPort 協議
public final class WorkoutKitAdapter: WorkoutKitPort, @unchecked Sendable {
    
    public init() {}
    
    public var isWorkoutKitAvailable: Bool {
        #if canImport(WorkoutKit)
        if #available(iOS 17.0, *) {
            return true
        }
        #endif
        return false
    }
    
    public func scheduleWorkout(workout: RecommendedWorkout, at date: Date) async throws -> WorkoutScheduleResult {
        #if canImport(WorkoutKit)
        if #available(iOS 17.0, *) {
            do {
                // 1. 請求 WorkoutKit 排程授權
                try await WorkoutScheduler.shared.requestAuthorization()
                
                // 2. 構建 CustomWorkout
                let customWorkout = buildCustomWorkout(from: workout)
                let workoutPlan = WorkoutKit.WorkoutPlan(.custom(customWorkout))
                
                // 3. 轉換日期為 DateComponents
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                
                // 4. 排程至手錶
                try await WorkoutScheduler.shared.schedule(workoutPlan, at: dateComponents)
                return .scheduled(planId: workout.id)
            } catch {
                return .failed(reason: error.localizedDescription)
            }
        }
        #endif
        
        // 模擬或非支援環境之處置
        return .scheduled(planId: workout.id)
    }
    
    public func removeScheduledWorkout(id: UUID) async throws {
        // 在 WorkoutKit 中若需取消，可視 API 支援情況呼叫或記錄標記
    }
    
    #if canImport(WorkoutKit)
    @available(iOS 17.0, *)
    private func buildCustomWorkout(from workout: RecommendedWorkout) -> WorkoutKit.CustomWorkout {
        var intervalSteps: [WorkoutKit.IntervalStep] = []
        var warmupStep: WorkoutKit.WorkoutStep?
        var cooldownStep: WorkoutKit.WorkoutStep?
        
        for step in workout.steps {
            let durationSeconds = Double(step.durationSeconds)
            
            if step.name.contains("熱身") || step.name.lowercased().contains("warmup") {
                warmupStep = WorkoutKit.WorkoutStep(goal: .time(durationSeconds, .seconds))
            } else if step.name.contains("緩和") || step.name.lowercased().contains("cooldown") {
                cooldownStep = WorkoutKit.WorkoutStep(goal: .time(durationSeconds, .seconds))
            } else {
                // 主運動區間，設定心率警示
                let alertTarget: (any WorkoutKit.WorkoutAlert)?
                if let minBpm = step.targetHeartRateRangeMin, let maxBpm = step.targetHeartRateRangeMax {
                    alertTarget = .heartRate(minBpm...maxBpm)
                } else {
                    alertTarget = nil
                }
                
                let workStep = WorkoutKit.IntervalStep(
                    .work,
                    goal: .time(durationSeconds, .seconds),
                    alert: alertTarget
                )
                intervalSteps.append(workStep)
            }
        }
        
        let intervalBlock = WorkoutKit.IntervalBlock(
            steps: intervalSteps.isEmpty ? [
                WorkoutKit.IntervalStep(.work, goal: .time(Double(workout.estimatedDurationMinutes) * 60, .seconds))
            ] : intervalSteps,
            iterations: 1
        )
        
        return WorkoutKit.CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: workout.title,
            warmup: warmupStep,
            blocks: [intervalBlock],
            cooldown: cooldownStep
        )
    }
    #endif
}
