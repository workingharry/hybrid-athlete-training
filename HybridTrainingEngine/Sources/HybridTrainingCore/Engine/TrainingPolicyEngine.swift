import Foundation

/// 雙向衝突仲裁政策決策引擎 (TrainingPolicyEngine)
public struct TrainingPolicyEngine {
    
    /// 核心決策評估函式 (支援確定性時間注入)
    /// - Parameters:
    ///   - history: 歷史訓練會話清單
    ///   - snapshot: 今日晨間生理快照
    ///   - now: 當前決策參考時間點 (預設 Date())
    ///   - calendar: 日曆
    ///   - baselineCTL: 冷啟動問卷基準
    /// - Returns: DailyDecision 單一事實來源決策體
    public static func evaluateDailyDecision(
        history: [WorkoutSession],
        snapshot: PhysiologicalSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current,
        baselineCTL: Double? = nil,
        configuration: TrainingConfiguration = .default
    ) -> DailyDecision {
        // 1. 去重並預處理會話 (Best-Fit 匹配)
        let processedHistory = SmartMergeEngine.processAndDeduplicate(sessions: history)
        
        // 2. 計算 ATL / CTL / ACWR (過濾未來時間戳記)
        let (atl, ctl, acwr) = ACWRCalculator.calculate(
            sessions: processedHistory,
            referenceDate: now,
            calendar: calendar,
            baselineCTL: baselineCTL,
            configuration: configuration
        )
        
        // 3. 計算生理準備度分數與燈號
        let (readinessScore, readinessGrade, confidence) = RobustZScoreCalculator.evaluateReadiness(
            snapshot: snapshot,
            acwr: acwr
        )
        
        // 4. 計算 4 大動作模式截至 now 之剩餘冷卻時鐘
        let cooldownMap = MuscleCooldownEngine.calculateCooldownStatuses(
            sessions: processedHistory,
            now: now,
            configuration: configuration
        )
        let cooldownList = [
            cooldownMap[.upperPush]!,
            cooldownMap[.upperPull]!,
            cooldownMap[.lowerQuad]!,
            cooldownMap[.lowerPosterior]!
        ]
        
        var warnings: [String] = []
        
        // ACWR 風控啟發式提示
        if acwr > configuration.acwrHighLoadThreshold {
            warnings.append("7天急性負荷顯著超出過去月均（ACWR: \(String(format: "%.2f", acwr))），強烈建議安排主動恢復或完全休息。")
        } else if acwr > configuration.acwrWarningThreshold {
            warnings.append("近期訓練增量偏快（ACWR: \(String(format: "%.2f", acwr))），今日課表建議偏向中低強度。")
        }
        
        let quadCooldown = cooldownMap[.lowerQuad]!.remainingHours
        let posteriorCooldown = cooldownMap[.lowerPosterior]!.remainingHours
        let pushCooldown = cooldownMap[.upperPush]!.remainingHours
        let pullCooldown = cooldownMap[.upperPull]!.remainingHours
        
        if quadCooldown > 0 || posteriorCooldown > 0 {
            warnings.append("下肢肌群修復中（深蹲前側剩餘: \(Int(quadCooldown))h，後側鏈剩餘: \(Int(posteriorCooldown))h），已自動調降下肢衝擊課表。")
        }
        if pushCooldown > 0 || pullCooldown > 0 {
            warnings.append("上半身肌群修復中（推剩餘: \(Int(pushCooldown))h，拉剩餘: \(Int(pullCooldown))h）。")
        }
        
        // 5. 決策樹仲裁主推薦與安全備選
        let primaryRec: RecommendedWorkout
        let safeAlternates: [RecommendedWorkout]
        
        if readinessGrade == .injured {
            // 傷病安全閘門熔斷 (Case 6)
            primaryRec = RecommendedWorkout(
                title: "完全休息或溫和伸展",
                subtitle: "偵測到急性不適 · 啟動傷病安全保護",
                discipline: .mobility,
                targetPatterns: [],
                estimatedDurationMinutes: 20.0,
                estimatedLoadAU: 20.0,
                steps: [
                    WorkoutStepItem(order: 1, name: "下肢髖關節放鬆與呼吸", durationSeconds: 600, stepDescription: "輕柔活動，如有疼痛立即停止"),
                    WorkoutStepItem(order: 2, name: "全身脊椎活動度調節", durationSeconds: 600, stepDescription: "保持深長呼吸")
                ]
            )
            safeAlternates = [
                RecommendedWorkout(
                    title: "完全靜態休息",
                    subtitle: "給予受損組織充足修復時間",
                    discipline: .rest,
                    estimatedDurationMinutes: 0.0,
                    estimatedLoadAU: 0.0
                )
            ]
        } else if acwr > 1.5 || readinessGrade == .fatigued {
            // 高負荷警示或紅燈疲勞
            primaryRec = RecommendedWorkout(
                title: "Zone 1 超慢主動恢復跑",
                subtitle: "低心肺衝擊 · 排解自律神經壓力",
                discipline: .running,
                runningType: .recoveryRun,
                targetPatterns: [],
                estimatedDurationMinutes: 25.0,
                estimatedLoadAU: 50.0,
                steps: [
                    WorkoutStepItem(order: 1, name: "極輕鬆超慢跑", durationSeconds: 1500, stepDescription: "全程維持深長呼吸，步頻保持 175+")
                ]
            )
            safeAlternates = [
                RecommendedWorkout(
                    title: "活動度伸展與核心",
                    subtitle: "徒手活動度 · 無下肢衝擊",
                    discipline: .mobility,
                    targetPatterns: [],
                    estimatedDurationMinutes: 20.0,
                    estimatedLoadAU: 20.0
                ),
                RecommendedWorkout(
                    title: "完全休息日",
                    subtitle: "促進副交感神經恢復",
                    discipline: .rest,
                    estimatedDurationMinutes: 0.0,
                    estimatedLoadAU: 0.0
                )
            ]
        } else {
            // 黃燈 (Moderate) 或 綠燈 (Ready)
            if posteriorCooldown > 24.0 || quadCooldown > 24.0 {
                // 下肢深度冷卻中 ➔ 限制跑步強度 (Zone 2)
                primaryRec = RecommendedWorkout(
                    title: "Zone 2 有氧基底慢跑",
                    subtitle: "目標 40 分鐘 · 避開高強度衝擊",
                    discipline: .running,
                    runningType: .baseRun,
                    targetPatterns: [],
                    estimatedDurationMinutes: 40.0,
                    estimatedLoadAU: 140.0,
                    steps: [
                        WorkoutStepItem(order: 1, name: "熱身慢跑", durationSeconds: 300, stepDescription: "Zone 1 慢跑"),
                        WorkoutStepItem(order: 2, name: "Zone 2 基底慢跑", durationSeconds: 1800, targetHeartRateRangeMin: 130, targetHeartRateRangeMax: 144, stepDescription: "保持輕鬆談話配速"),
                        WorkoutStepItem(order: 3, name: "緩和慢步", durationSeconds: 300, stepDescription: "心率降至 110 以下")
                    ],
                    isLockedDueToFatigue: true
                )
                
                // 上半身冷卻感知備選
                var alternates: [RecommendedWorkout] = []
                if pushCooldown <= 24.0 {
                    alternates.append(RecommendedWorkout(
                        title: "上半身推 (Push) 肌力訓練",
                        subtitle: "胸肩三頭 · 完全避開下肢干擾",
                        discipline: .strength,
                        targetPatterns: [.upperPush],
                        estimatedDurationMinutes: 45.0,
                        estimatedLoadAU: 337.5
                    ))
                }
                if pullCooldown <= 24.0 {
                    alternates.append(RecommendedWorkout(
                        title: "上半身拉 (Pull) 肌力訓練",
                        subtitle: "背部與核心穩定 · 輔助跑步軀幹",
                        discipline: .strength,
                        targetPatterns: [.upperPull],
                        estimatedDurationMinutes: 45.0,
                        estimatedLoadAU: 315.0
                    ))
                }
                alternates.append(RecommendedWorkout(
                    title: "活動度與放鬆 (Mobility)",
                    subtitle: "髖關節與腳踝修復",
                    discipline: .mobility,
                    estimatedDurationMinutes: 20.0,
                    estimatedLoadAU: 20.0
                ))
                safeAlternates = alternates
            } else if readinessGrade == .ready {
                // 綠燈且下肢充沛 ➔ 可解鎖間歇跑或大重量主項
                primaryRec = RecommendedWorkout(
                    title: "Zone 4 閾值節奏跑 (Tempo Run)",
                    subtitle: "目標 40 分鐘 · 提升乳酸代謝耐受力",
                    discipline: .running,
                    runningType: .tempoRun,
                    targetPatterns: [.lowerQuad, .lowerPosterior],
                    estimatedDurationMinutes: 40.0,
                    estimatedLoadAU: 240.0,
                    steps: [
                        WorkoutStepItem(order: 1, name: "熱身", durationSeconds: 600, stepDescription: "Zone 1~2 漸進熱身"),
                        WorkoutStepItem(order: 2, name: "閾值主課表", durationSeconds: 1200, targetHeartRateRangeMin: 160, targetHeartRateRangeMax: 172, stepDescription: "乳酸閾值穩定巡航"),
                        WorkoutStepItem(order: 3, name: "緩和慢跑", durationSeconds: 600, stepDescription: "緩和回穩")
                    ]
                )
                safeAlternates = [
                    RecommendedWorkout(
                        title: "下肢膝主導 (Quads) 深蹲主項",
                        subtitle: "下肢肌力與爆發力強化",
                        discipline: .strength,
                        targetPatterns: [.lowerQuad],
                        estimatedDurationMinutes: 50.0,
                        estimatedLoadAU: 400.0
                    ),
                    RecommendedWorkout(
                        title: "Zone 2 長距離有氧跑",
                        subtitle: "有氧基底儲備",
                        discipline: .running,
                        runningType: .baseRun,
                        estimatedDurationMinutes: 60.0,
                        estimatedLoadAU: 210.0
                    )
                ]
            } else {
                // 黃燈常態
                primaryRec = RecommendedWorkout(
                    title: "Zone 2 有氧基底跑",
                    subtitle: "目標 45 分鐘 · 穩健代謝適應",
                    discipline: .running,
                    runningType: .baseRun,
                    targetPatterns: [],
                    estimatedDurationMinutes: 45.0,
                    estimatedLoadAU: 157.5,
                    steps: [
                        WorkoutStepItem(order: 1, name: "有氧慢跑", durationSeconds: 2700, targetHeartRateRangeMin: 130, targetHeartRateRangeMax: 145, stepDescription: "鼻吸鼻呼輕鬆交談")
                    ]
                )
                safeAlternates = [
                    RecommendedWorkout(
                        title: "上半身推 (Push) 肌耐力",
                        subtitle: "維持力量儲備",
                        discipline: .strength,
                        targetPatterns: [.upperPush],
                        estimatedDurationMinutes: 40.0,
                        estimatedLoadAU: 260.0
                    ),
                    RecommendedWorkout(
                        title: "活動度伸展",
                        subtitle: "下肢筋膜放鬆",
                        discipline: .mobility,
                        estimatedDurationMinutes: 20.0,
                        estimatedLoadAU: 20.0
                    )
                ]
            }
        }
        
        return DailyDecision(
            date: now,
            readinessGrade: readinessGrade,
            readinessScore: readinessScore,
            confidence: confidence,
            acwrRatio: acwr,
            atl: atl,
            ctl: ctl,
            cooldowns: cooldownList,
            primaryRecommendation: primaryRec,
            safeAlternates: safeAlternates,
            fatigueWarnings: warnings
        )
    }
}
