import Foundation

/// 訓練專業類別
public enum TrainingDiscipline: String, Codable, CaseIterable, Sendable {
    case running    // 耐力路跑
    case strength   // 重量肌力訓練
    case mobility   // 活動度與伸展
    case rest       // 完全休息
}

/// 4 大動作模式 (與運動機能學 100% 對齊)
public enum MovementPattern: String, Codable, CaseIterable, Sendable {
    case upperPush       // 上半身推 (胸、肩前、三頭)
    case upperPull       // 上半身拉 (背、二頭)
    case lowerQuad       // 下肢前側膝主導 (深蹲、分腿蹲)
    case lowerPosterior  // 下肢後側鏈髖主導 (硬舉、RDL、臀大肌)
}

/// 生理準備度三色燈號與傷病狀態
public enum ReadinessGrade: String, Codable, Sendable {
    case ready     // 🟢 綠燈：可執行高強度間歇或大重量主項 (Score >= 70)
    case moderate  // 🟡 黃燈：建議維持中低強度有氧或肌耐力 (45 <= Score < 70)
    case fatigued  // 🔴 紅燈：建議主動恢復 (Zone 1) 或休息 (Score < 45)
    case injured   // ⚠️ 傷病安全閘門觸發：鎖定受傷部位
}

/// 數據信心水準標記
public enum MetricConfidence: String, Codable, Sendable {
    case high  // 高信心度：HRV 與睡眠樣本充足
    case low   // 低信心度：缺乏 HRV，由睡眠或自覺活力降級推算
}

/// 單次訓練來源追蹤 (Provenance Tracking)
public enum SessionSource: Codable, Equatable, Sendable {
    case healthKitWorkout(hkUUID: UUID) // Apple Watch 自動同步之 Workout
    case manualLog                      // 使用者於 iPhone App 內手動 15 秒打卡
    case smartMerged(hkUUID: UUID)      // 50% 時間重疊後之智慧合併複合實體
}

/// 跑步結構化課表類型
public enum RunningWorkoutType: String, Codable, CaseIterable, Sendable {
    case recoveryRun   // Zone 1 超慢恢復跑
    case baseRun       // Zone 2 有氧基底耐力跑
    case tempoRun      // Zone 3 乳酸閾值節奏跑
    case intervalRun   // Zone 4~5 無氧間歇衝刺跑
    case longRun       // 週末長距離耐力跑
}
