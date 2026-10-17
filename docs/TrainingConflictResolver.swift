import Foundation

// MARK: - 雙軌統合負荷與衝突仲裁核心模組 (Pure Swift / 獨立無依賴 / 高可測性)

/// 訓練類型
public enum TrainingDiscipline: String, Codable {
    case running
    case strength
}

/// 肌群定義
public enum TargetMuscleGroup: String, Codable, CaseIterable {
    case chest
    case back
    case quads          // 股四頭肌 (深蹲、下肢推)
    case hamstrings     // 後側鏈/臀部 (硬舉、下肢拉)
    case shoulders
    case arms
    case core
}

/// 單次訓練記錄
public struct WorkoutSessionRecord: Identifiable {
    public let id: UUID
    public let date: Date
    public let discipline: TrainingDiscipline
    public let durationMinutes: Double
    public let sRPE: Double                     // Foster sRPE: 1~10
    public let targetMuscles: Set<TargetMuscleGroup> // 重訓主要受力部位，跑步時通常為 quads/hamstrings
    
    public init(id: UUID = UUID(), date: Date, discipline: TrainingDiscipline, durationMinutes: Double, sRPE: Double, targetMuscles: Set<TargetMuscleGroup> = []) {
        self.id = id
        self.date = date
        self.discipline = discipline
        self.durationMinutes = durationMinutes
        self.sRPE = sRPE
        self.targetMuscles = targetMuscles
    }
    
    /// Foster 統一任意單位負荷 (AU, Arbitrary Units)
    public var loadAU: Double {
        return durationMinutes * sRPE
    }
}

/// 生理恢復輸入
public struct PhysiologicalStatus {
    public let hrvTodayMs: Double?             // 當日 SDNN (毫秒)
    public let hrv14dMedianMs: Double?         // 14 天中位數 (毫秒)
    public let hrv14dIQRMs: Double?            // 14 天四分位距 (毫秒)
    public let sleepHours: Double              // 昨夜睡眠時數
    public let hasReportedPainOrInjury: Bool   // 傷病安全閘門
    
    public init(hrvTodayMs: Double? = nil, hrv14dMedianMs: Double? = nil, hrv14dIQRMs: Double? = nil, sleepHours: Double, hasReportedPainOrInjury: Bool = false) {
        self.hrvTodayMs = hrvTodayMs
        self.hrv14dMedianMs = hrv14dMedianMs
        self.hrv14dIQRMs = hrv14dIQRMs
        self.sleepHours = sleepHours
        self.hasReportedPainOrInjury = hasReportedPainOrInjury
    }
    
    /// 計算恢復狀態評級 (若 HRV 資料不足則自動降級為睡眠評估，並回傳信心度)
    public func resolveReadinessGrade(minRequiredHrvSamples: Int = 5, actualHrvSamplesCount: Int = 0) -> (grade: ReadinessGrade, confidence: MetricConfidence) {
        if hasReportedPainOrInjury {
            return (.injured, .high)
        }
        
        // 1. 若有足夠 HRV 統計資料且樣本數達到門檻
        if actualHrvSamplesCount >= minRequiredHrvSamples,
           let hrv = hrvTodayMs, let median = hrv14dMedianMs, let iqr = hrv14dIQRMs, iqr > 0 {
            let zScore = (hrv - median) / iqr
            let grade: ReadinessGrade
            if zScore < -1.5 || sleepHours < 5.0 {
                grade = .fatigued   // 紅燈
            } else if zScore < -0.5 || sleepHours < 6.5 {
                grade = .moderate   // 黃燈
            } else {
                grade = .ready      // 綠燈
            }
            return (grade, .high)
        }
        
        // 2. 降級策略：僅依睡眠時數評定
        let grade: ReadinessGrade
        if sleepHours < 5.5 {
            grade = .fatigued
        } else if sleepHours < 7.0 {
            grade = .moderate
        } else {
            grade = .ready
        }
        return (grade, .low) // 標示為低信心度，提醒使用者戴錶就寢
    }
}

public enum ReadinessGrade: String {
    case ready       // 綠燈：可執行高強度
    case moderate    // 黃燈：限制為中低強度或 Zone 2
    case fatigued    // 紅燈：主動恢復或完全休息
    case injured     // 傷病：鎖定受傷部位，排定物理治療/伸展
}

public enum MetricConfidence: String {
    case high        // 高信心度 (HRV + 睡眠健全)
    case low         // 低信心度 (降級模式)
}

/// 核心排程仲裁引擎配置
public struct ResolverConfiguration {
    public var acwrWarningThreshold: Double       // 警示閾值 (預設 1.4，可由使用者調整)
    public var allowOverrideACWR: Bool             // 是否允許使用者覆寫強制降級
    public var quadsCooldownHours: Double          // 腿部冷卻小時 (預設 48)
    
    public init(acwrWarningThreshold: Double = 1.4, allowOverrideACWR: Bool = true, quadsCooldownHours: Double = 48.0) {
        self.acwrWarningThreshold = acwrWarningThreshold
        self.allowOverrideACWR = allowOverrideACWR
        self.quadsCooldownHours = quadsCooldownHours
    }
}

/// 核心排程仲裁引擎 (純函式集合，支援注入參考時間與自訂組態，具備極高可測性)
public struct TrainingConflictResolver {
    
    /// 計算急性/慢性負荷比 (ACWR)
    public static func calculateACWR(
        history: [WorkoutSessionRecord],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: referenceDate) ?? referenceDate
        
        let acuteRecords = history.filter { $0.date >= sevenDaysAgo && $0.date <= referenceDate }
        let chronicRecords = history.filter { $0.date >= twentyEightDaysAgo && $0.date <= referenceDate }
        
        let acuteLoadSum = acuteRecords.reduce(0.0) { $0 + $1.loadAU }
        let chronicLoadSum = chronicRecords.reduce(0.0) { $0 + $1.loadAU }
        
        let acuteDailyAvg = acuteLoadSum / 7.0
        let chronicDailyAvg = (chronicLoadSum > 0) ? (chronicLoadSum / 28.0) : 50.0 // 預設底線避免除以零
        
        return acuteDailyAvg / chronicDailyAvg
    }
    
    /// 檢查特定肌群在過去 N 小時內是否仍在冷卻中
    public static func isMuscleFatigued(
        _ muscle: TargetMuscleGroup,
        in history: [WorkoutSessionRecord],
        cooldownHours: Double = 48.0,
        referenceDate: Date = Date()
    ) -> Bool {
        let cutoff = referenceDate.addingTimeInterval(-cooldownHours * 3600)
        let recentTrainings = history.filter { $0.date >= cutoff && $0.targetMuscles.contains(muscle) }
        return !recentTrainings.isEmpty
    }
    
    /// 產出今日排程建議 (決策核心，啟發式提示 + 支援覆寫)
    public static func resolveDailyRecommendation(
        history: [WorkoutSessionRecord],
        status: PhysiologicalStatus,
        preferredTodayDiscipline: TrainingDiscipline,
        config: ResolverConfiguration = ResolverConfiguration(),
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        // 1. 安全閘門
        if status.hasReportedPainOrInjury {
            return "⚠️ 偵測到疼痛或傷病回報：今日建議完全休息或僅進行溫和活動度伸展 (Mobility)。"
        }
        
        let (grade, confidence) = status.resolveReadinessGrade()
        let confidenceNotice = (confidence == .low) ? "（⚠️ 數據未達標準，此建議依據昨夜睡眠推算）" : ""
        
        // 2. ACWR 疲勞風控（啟發式提示，非不可逆死鎖）
        let acwr = calculateACWR(history: history, referenceDate: referenceDate, calendar: calendar)
        if acwr > config.acwrWarningThreshold {
            return "⚠️ 啟發式提醒：近期累積負荷比偏高 (ACWR = \(String(format: "%.2f", acwr)))，受傷風險上升。建議調整為低強度主動恢復跑或休息；若自覺良好亦可手動覆寫執行。" + confidenceNotice
        }
        
        // 3. 生理狀態限制
        if grade == .fatigued {
            return "🛑 今日生理恢復指標偏低 (睡眠不足或自律神經疲勞)：建議完全休息或 20 分鐘 Zone 1 超慢跑。" + confidenceNotice
        }
        
        // 4. 運動學衝突仲裁 (跑步 vs 下肢重訓)
        let quadsFatigued = isMuscleFatigued(.quads, in: history, cooldownHours: config.quadsCooldownHours, referenceDate: referenceDate)
        
        switch preferredTodayDiscipline {
        case .running:
            if quadsFatigued {
                return "💡 股四頭肌/腿部剛於 \(Int(config.quadsCooldownHours)) 小時內經歷高負荷訓練：今日跑步請避免間歇與衝刺，建議執行「低強度 Zone 2 基底慢跑 40 分鐘」。" + confidenceNotice
            } else if grade == .ready {
                return "🔥 今日狀態良好：建議執行「閾值節奏跑 (Tempo Run) 30 分鐘」或「乳酸間歇訓練」。" + confidenceNotice
            } else {
                return "🏃 今日狀態適中：建議執行「標準 Zone 2 有氧跑 45 分鐘」。" + confidenceNotice
            }
            
        case .strength:
            if quadsFatigued {
                return "💪 腿部肌群尚在修復冷卻中：今日重訓切換為「上半身推/拉課表 (Push/Pull)」，避開深蹲與硬舉。" + confidenceNotice
            } else {
                return "🏋️ 腿部與全身肌群已充分恢復：今日可執行「下肢深蹲與核心綜合肌力課表」。" + confidenceNotice
            }
        }
    }
}
