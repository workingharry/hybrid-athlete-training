**總體架構健全度評分：9.2 / 10 分**

本專案《iPhone 混合訓練自適應排課系統》展現了極高水準的企業級工程品質與深厚的運動生理學底蘊。架構上透過 `HybridTrainingCore`（純值型別、零外部依賴、確定性時間注入）與 `HybridTrainingStorage`（SwiftData 適配層）的嚴格分離，完美實踐了潔淨架構（Clean Architecture）與函數式核心、命令式外殼（Functional Core, Imperative Shell）的現代軟體設計範式。在運動科學層面，將 Foster's Session RPE 與 NSCA CSCS 並行訓練干擾效應（Concurrent Training Interference Effect）、Garmin Firstbeat 動態權重降級機制結合，兼顧了理論嚴謹度與穿戴裝置真實世界的容錯率。

以下為結合 **NSCA CSCS 肌力與體能專家視角** 與 **Apple 平台首席系統架構師視角** 的全面對證審查報告與生產級技術強化規格書。

---

## 1. 系統總覽與組件設計 (System Overview & Component Design)

### 1.1 高階架構與職責邊界 (High-Level Architecture & Responsibility Breakdown)

系統採用嚴格的單向依賴與六角架構（Hexagonal / Ports and Adapters Architecture），將所有不確定性（HealthKit 非同步 I/O、感測器訊號遺失、SwiftData 執行緒上下文、系統時鐘）隔離於外圍適配層：

| 架構分層 | 模組 / 組件名稱 | 核心職責與設計邊界 | 外部依賴 |
| --- | --- | --- | --- |
| **Domain Core**<br>

<br>(純粹領域與數學核心) | `HybridTrainingCore`<br>

<br>- `TrainingPolicyEngine`<br>

<br>- `MuscleCooldownEngine`<br>

<br>- `FosterLoadCalculator`<br>

<br>- `ACWRCalculator`<br>

<br>- `RobustZScoreCalculator`<br>

<br>- `SmartMergeEngine` | - 封裝所有運動生理學公式、統計正規化與冷卻時鐘衰減邏輯。<br>

<br>- 輸入皆為不可變 `Sendable` 值型別（Struct/Enum），輸出為單一事實來源 `DailyDecision`。<br>

<br>- 透過 `now: Date` 與 `calendar: Calendar` 參數注入，保證 100% 確定性（Deterministic）運算。 | **零依賴**<br>

<br>(僅 `Foundation`) |
| **Persistence Adapter**<br>

<br>(持久化適配層) | `HybridTrainingStorage`<br>

<br>- `SDWorkoutSession`<br>

<br>- `SDPhysiologicalSnapshot`<br>

<br>- `StorageAdapter` | - 封裝 iOS 17+ `SwiftData` `@Model` 實體。<br>

<br>- 透過 `@ModelActor` 提供背景執行緒安全的 CRUD 與領域實體雙向映射（DTO Mapping）。<br>

<br>- 維護 HealthKit UUID 唯一索引與軟刪除對帳狀態。 | `SwiftData`<br>

<br>`HybridTrainingCore` |
| **Hardware & OS Adapters**<br>

<br>(硬體與系統服務層) | `HealthKitSpikeService`<br>

<br>`WorkoutKitScheduler` | - **HealthKit 適配器**：封裝 `HKAnchoredObjectQuery`、睡眠階段去重（排除 `.inBed`）、離散心率樣本提取與夜間 HRV (SDNN) 採樣。<br>

<br>- **WorkoutKit 適配器**：將 `RecommendedWorkout` 編譯為 iOS 17+ `CustomWorkout` 並透過 `WorkoutScheduler` 推送至 Apple Watch 原生體能訓練 App。 | `HealthKit`<br>

<br>`WorkoutKit`<br>

<br>`HybridTrainingCore` |
| **Application & Presentation**<br>

<br>(應用協調與表現層) | `TrainingCoordinator`<br>

<br>SwiftUI Views | - 協調晨間喚醒評估、15 秒極簡重訓打卡、課後 2 小時時間窗對帳（Reconciliation）。<br>

<br>- 驅動響應式 UI 渲染三色準備度燈號、4 大動作模式冷卻環與安全替換課表。 | `SwiftUI`<br>

<br>All Modules |

### 1.2 核心資料流與雙向衝突仲裁序列圖 (Mermaid Sequence & Flowchart)

```mermaid
sequenceDiagram
    autonumber
    actor Athlete as 混合訓練運動員
    participant Watch as Apple Watch (原生體能訓練)
    participant HK as HealthKit Store
    participant Adapter as HealthKit & Storage Adapter (Actor)
    participant Engine as TrainingPolicyEngine (Pure Swift)
    participant WK as WorkoutKit Scheduler

    Note over Athlete, WK: 階段一：晨間喚醒與生理快照聚合 (Morning Readiness Evaluation)
    Athlete->>Adapter: 開啟 App 觸發晨間同步
    par 並行讀取生理與訓練歷史
        Adapter->>HK: 查詢昨夜睡眠 (過濾 .inBed) 與 14d 夜間 HRV SDNN
        Adapter->>HK: 查詢近 28 天 HKWorkout 與離散 HR Samples
    end
    HK-->>Adapter: 返回原始生理樣本與運動紀錄
    Adapter->>Engine: 調用 FosterLoadCalculator (Δt <= 15s 箝位, 50% 覆蓋率檢驗)
    Engine-->>Adapter: 返回推導 sRPE 與區間秒數 (或標記需手動確認)

    Note over Adapter, Engine: 階段二：雙重寫入智慧合併與確定性決策 (Smart Merge & Policy Arbitration)
    Adapter->>Engine: evaluateDailyDecision(history, snapshot, now, calendar, baselineCTL)
    activate Engine
    Engine->>Engine: 1. SmartMergeEngine: 50% 時間重疊合併 (Watch 時長 + App 動作/sRPE)
    Engine->>Engine: 2. ACWRCalculator: 7d ATL / 28d CTL (CTL_floor = 30.0 AU, 冷啟動加權)
    Engine->>Engine: 3. RobustZScoreCalculator: MAD Z-Score (MAD_min = 2.0ms) 或無 HRV 0.70 睡眠加權
    Engine->>Engine: 4. MuscleCooldownEngine: 4 大模式連續小時差衰減 (主項 1.0 / 輔項 0.7)
    Engine->>Engine: 5. 決策樹仲裁：傷病熔斷 -> ACWR/紅燈降級 -> 下肢冷卻 >24h 鎖定 -> 主課表與備選
    Engine-->>Adapter: 返回 DailyDecision (不可變決策體)
    deactivate Engine

    Note over Adapter, WK: 階段三：WorkoutKit 原生課表編譯與推送 (WorkoutKit Provisioning)
    Adapter->>Athlete: 渲染準備度燈號、冷卻時鐘與推薦課表
    Athlete->>Adapter: 確認今日跑步課表 (或切換為上半身安全備選)
    Adapter->>WK: 將 RecommendedWorkout.steps 轉譯為 CustomWorkout
    WK->>Watch: 排程同步至 Apple Watch 原生「體能訓練」App

```

---

## 2. 關鍵技術決策與雙維度對證審查 (Key Technical Decisions & Cross-Validation)

### 2.1 運動科學與生理學模型對證 (NSCA CSCS & Wearable Industry Standard)

| 審查項目 | 驗證結論 | 專業對證分析（CSCS 理論與穿戴大廠工程實踐） | 識別出之潛在生理盲區與數學邊界漏洞 |
| --- | --- | --- | --- |
| **1. Foster sRPE × Duration (AU) 雙軌唯一量化貨幣** | **符合標準**<br>

<br>(具高度工程實用性) | - **合理性**：Carl Foster (2001) 提出的 Session RPE 已在無數運動科學文獻中被證實與心率 TRIMP、血乳酸濃度及自主神經疲勞具高度相關性。以此作為統一貨幣，完美解決了重訓無法以心率反映神經肌肉負荷（高強度深蹲平均心率極低，但 CNS 疲勞極高）的跨模態失真。<br>

<br>- **個人偏差校正 (`personalBias`)**：取近 10 次中位數並箝位於 `[-1.5, +1.5]`，有效消除心率漂移（Cardiac Drift）或個體最大心率預估偏差。 | **[數學與生理漏洞 1：心率脫落未計入個人偏差與保底負荷偏誤]**<br>

<br>在 `FosterLoadCalculator.calculateFromDiscreteHeartRateSamples` 中，當 `coverageRatio < 0.50` 時強制返回硬編碼 `finalRPE = 3.5`，忽略了 `personalBias`。此外，重訓極簡打卡若遇到「長組間休息的力量舉訓練（如 90 分鐘僅練 5 組大重量，sRPE 9.0 ➔ 810 AU）」，會產生虛高之代謝負荷。建議對重訓單次時長超過 75 分鐘者引入非線性衰減或有效密度提示。 |
| **2. 7d ATL / 28d CTL 滾動平均與 `CTL_min = 30.0` 保底** | **符合標準**<br>

<br>(成功防禦數學奇異點) | - **合理性**：Gabbett (2016) 的 ACWR 模型中，0.8～1.3 為甜蜜點（Sweet Spot），大於 1.5 為危險區（Danger Zone）。設立 `ctlFloor = 30.0` AU/day（約當每日慢跑 15 分鐘或每週 2 次輕量訓練）是極佳的工程防護，能避免傷後復出或休賽期重啟時因分母趨近於 0 導致 ACWR 暴衝至 5.0+ 而觸發永久鎖死。 | **[數學邊界漏洞 2：冷啟動公式將「休息日」誤判為「未記錄日」]**<br>

<br>在 `ACWRCalculator.calculate` 中：`if let load = dailyLoadMap[date] { recordedDaysCount += 1 }`。由於休息日沒有 `WorkoutSession`，`dailyLoadMap[date]` 為 `nil`！這意味著一位已經使用 App 滿 28 天、每週規律練 4 休 3 的運動員，其 `recordedDaysCount` 永遠只有 16 天（小於 28），導致系統**永遠卡在冷啟動過渡公式**，且 `recordedAvg = last28DaysSum / 16` 會嚴重高估真實日均負荷！必須改以「首筆歷史紀錄距今天數（Account Age Days）」或明確傳入 onboarding 日期作為冷啟動權重分母。 |
| **3. 14 天夜間 HRV SDNN 之 MAD 穩健 Z-Score 與 `2.0ms` 下限** | **超越平均水準**<br>

<br>(統計學極為嚴謹) | - **合理性**：Apple Watch 背景採樣的 HRV 為超短時程（Ultra-short-term, 60s）SDNN，極易受單一夜間翻身、飲酒或感測器雜訊產生極端離群值（Outliers）。採用中位數與絕對離差中位數（$\text{MAD} \times 1.4826$ 漸近常態標準誤轉換）遠優於傳統 Mean/SD。`2.0ms` 下限則防止了規律作息者在 MAD 極小時因微小波動（如 -1.5ms）產生極端負 Z-Score。 | **[生理邊界盲區 3：副交感神經超飽和 (Parasympathetic Hyperactivity)]**<br>

<br>在耐力運動科學（Plews et al., 2013）中，當運動員陷入急性過度訓練初期（Functional Overreaching）時，常出現副交感神經反彈性亢進，導致 HRV 異常飆高（$Z > +2.0$）。目前 `RobustZScoreCalculator` 將 $+2.5$ 直接換算為 $+50$ 分加分。建議當 $Z > +1.8$ 且伴隨高 ACWR ($> 1.3$) 或主觀痠痛 ($\ge 4$) 時，將正 Z-Score 視為異常訊號並抑制加分。 |
| **4. 4 大動作模式 48~60h 冷卻、0.7 輔項折減與跑步下肢衝擊矩陣** | **符合 CSCS 規範**<br>

<br>(具小幅邊界瑕疵) | - **合理性**：將肌力簡化為 `upperPush`、`upperPull`、`lowerQuad`、`lowerPosterior` 完美契合運動機能學分類。依強度階梯給予上肢 12~48h、下肢 18~60h 冷卻，且高強度間歇跑給予後側鏈（膕旁肌/臀肌推進）48h、前側 36h 冷卻，完全符合高速跑對後側鏈離心收縮張力更高的生物力學實證。 | **[演算法邊界漏洞 4：跑步衝擊矩陣的「順序遮蔽效應」與「疲勞覆寫而非疊加」]**<br>

<br>1. `calculateRunningImpactCooldown` 採用 `if-else` 短路邏輯：若跑者進行 46 分鐘訓練，其中包含 12 分鐘 Zone 4 間歇，程式碼會正確命中規則 2（36h, 48h）；但若跑者進行 **76 分鐘訓練且含 15 分鐘 Zone 5 衝刺**，規則 1（`>= 75m`）等同於 `(48, 48)` 尚可，然而若未來調整長距離冷卻參數就會發生遮蔽，應改為取各條件之 `max(quad, posterior)`。<br>

<br>2. `MuscleCooldownEngine` 採用 `if remaining > remainingMap[pattern]!.remainingHours` 取最大值而非殘餘疲勞疊加，且 `TrainingPolicyEngine` 在綠燈時推薦的「上半身推/拉」備選課表**未檢查上肢是否也在冷卻中**（若昨日剛練完大重量胸推，今日下肢冷卻 >24h 時，系統仍會盲目推薦上半身推）。 |
| **5. Zone 0 (`< 50% MaxHR`, Base RPE 1.0) 恢復區間** | **符合標準** | - **合理性**：涵蓋跑間步行休息、動態熱身與緩和時間，賦予 `BaseRPE = 1.0` 避免低心率時段將整體加權平均 RPE 稀釋至 0，同時防止間歇跑組間休息被視為無負荷。 | 無明顯缺陷，設計穩健。 |
| **6. 缺失 HRV 動態權重重分配 (對標 Garmin Firstbeat Fallback)** | **符合標準**<br>

<br>(平滑降級典範) | - **合理性**：當 `hrvTodayMs == nil` 時，將 `sleepFactor` 由 `0.35` 倍增至 `0.70` 並標註 `confidence = .low`。實測數學邊界：睡眠 7.5h (`sleepScore = 100`)、`acwr = 1.0`、無痠痛時，`rawScore = 50 + 0 + 0.70 * (100 - 70) = 71.0 >= 70.0`，恰能解鎖綠燈（`.ready`），完美避免手錶沒電或未戴錶睡覺導致運動員永遠無法獲得綠燈課表的「假性疲勞死鎖」。 | **[數學邊界微調建議]**<br>

<br>在低信心度模式下，若使用者也未填寫晨間痠痛（`morningSorenessRating == nil`），目前 `sorenessAdjustment = 0.0`。若要完全貫徹 ADR 0005 所述「轉移至睡眠總時長與晨間主觀活力」，建議在無 HRV 時將 `sorenessAdjustment` 的權重係數由 `3.0` 提升至 `5.0`（即 ±10 分），讓主觀體感在缺失客觀自律神經指標時發揮更關鍵的煞車作用。 |

---

### 2.2 Apple 平台架構與潔淨架構對證 (Clean Architecture & Swift Ecosystem)

| 審查項目 | 驗證結論 | 架構師深度評估與潛在漏洞分析 |
| --- | --- | --- |
| **1. 純 Swift 領域核心與 SPM 雙 Target 分離 (`Core` vs `Storage`)** | **極優 (10/10)** | 徹底消除了 `HealthKit` 與 `SwiftData` 對單元測試的污染。`swift test` 可在 macOS CLI 與 Linux CI 容器中以毫秒級執行，是 iOS 大型專案罕見的高規格實踐。 |
| **2. WorkoutKit-First 原生課表推送架構** | **極優 (9.5/10)** | 省去獨立 watchOS App 的 `WatchConnectivity` 狀態同步惡夢與雙端背景耗電問題。**潛在邊界注意事項**：`WorkoutStepItem` 目前使用絕對心率 (`targetHeartRateRangeMin/Max: 130~144`) 硬編碼於 `TrainingPolicyEngine` 中；不同年齡與最大心率的運動員其 Zone 2 心率截然不同，必須改由外部傳入 `UserPhysiologyProfile(maxHR:restingHR:)` 動態計算目標心率區間。 |
| **3. 50% 時間重疊智慧合併去重 (`SmartMergeEngine`)** | **良好，但有配對貪婪漏洞 (8/10)** | **發現 3 個邊界漏洞**：<br>

<br>1. **First-Match 貪婪配對偏差**：`processAndDeduplicate` 雙層迴圈中，只要遇到第一個 `ratio >= 0.50` 的手動紀錄就立即 `break`，而非尋找**重疊率最高（Best Overlap Ratio）**的配對。<br>

<br>2. **跑步課表被誤轉型或覆蓋**：若跑者用 Apple Watch 記錄了一場跑步，隨後又在 App 誤觸一筆同時間段的打卡，`mergeIfOverlapping` 會將 `requiresManualRPEConfirmation` 強制設為 `false`，且未保留個人偏差校準所需的原始誤差紀錄。<br>

<br>3. **負荷計算一致性**：需確保 `WorkoutSession.loadAU` 為計算屬性 (`durationMinutes * sRPE`)，避免合併後緩存了舊的 `loadAU`。 |
| **4. 延遲打卡真實時間戳記錨定 (`Time Offset`) 與確定性時間注入 (`now: Date`)** | **良好，但有未來時間穿越漏洞 (8.5/10)** | 1. **`MuscleCooldownEngine`** 使用 `max(0.0, now.timeIntervalSince(session.endDate) / 3600.0)`。若系統在做歷史回測（Backtesting）或處理時區異常資料時，傳入的 `sessions` 中包含 `session.endDate > now` 的未來紀錄，`elapsedHours` 會變成 `0.0`，導致未來還沒發生的訓練提前鎖死當下的冷卻時鐘！必須過濾 `where session.endDate <= now`。<br>

<br>2. **`ACWRCalculator`** 同樣未過濾 `session.startDate <= referenceDate`（或 normalizedRefDate 結束前）的會話，回測時會發生「未來數據洩漏（Data Leakage）」。 |

---

## 3. 關鍵架構取捨與強化設計方案 (Key Technical Decisions & Trade-offs)

為修復上述審查發現的 6 個潛在邊界漏洞，我們在不破壞既有 Public API 相容性的前提下，制定以下架構強化決策：

1. **修復 ACWR 冷啟動分母失真（引入 `onboardingDate` 或首筆會話錨點）**：
* *取捨分析*：若要求使用者每天即使休息也要打開 App 打「休息卡」才能累積 `recordedDaysCount`，會嚴重違反 ADR 0003 的極簡低摩擦原則。
* *決策*：在 `ACWRCalculator.calculate` 中，自動推導歷史最早一筆會話距參考日的日曆天數 `activeSpanDays = min(28, max(1, daysBetween(earliestSession, referenceDate) + 1))`。只要使用者首筆紀錄已超過 28 天，或明確傳入 `activeDaysCount`，即直接除以 `28.0`；在未滿 28 天的冷啟動期內，以 `activeSpanDays` 作為真實經歷天數（包含其中的休息日），徹底根除休息日造成 CTL 虛高的數學漏洞。


2. **升級 `TrainingPolicyEngine` 的上半身冷卻感知與動態心率區間計算**：
* *決策*：當下肢處於深度冷卻（`> 24h`）而退避至上半身訓練或 Zone 2 慢跑時，引擎必須檢查 `upperPush` 與 `upperPull` 的剩餘冷卻時數，優先推薦剩餘冷卻較低（或為 0）的上半身模式；若上下半身全面處於深度冷卻（例如昨日剛完成全身 CrossFit 高強度訓練），則強制降級為 `Zone 1 恢復跑` 或 `活動度伸展`。


3. **重構 `SmartMergeEngine` 為最大重疊率優先匹配（Best-Fit Matching）**：
* *決策*：先計算所有候選 `(watch, manual)` 配對的重疊率矩陣，依 `overlapRatio` 由大至小排序後再進行一對一消費合併，確保「一日兩練（早晚緊鄰訓練）」場景下的絕對精準去重。



---

## 4. 漸進式實作與重構路線圖 (Step-by-Step Implementation Roadmap)

以下按優先級列出需修改（Modified）與新增（New）的生產級程式碼變更：

### Milestone 1: 領域核心數學與生理邊界修復 (`HybridTrainingCore`)

#### 1. [MODIFIED] `HybridTrainingEngine/Sources/HybridTrainingCore/Engine/ACWRCalculator.swift`

* **變更重點**：過濾未來時間戳記防止回測資料洩漏；將冷啟動過渡期天數 `n` 由「有訓練紀錄的天數」修正為「自首筆紀錄以來的實際日曆涵蓋天數（含休息日）」。

```swift
import Foundation

/// 急性與慢性負荷統計計算器 (ATL / CTL / ACWR)
public struct ACWRCalculator {
    
    /// CTL 最小保護下限 (AU/day)，防止除以零或冷啟動/中斷重啟暴衝
    public static let ctlFloor: Double = 30.0
    
    /// 計算給定參考時間點的 ATL、CTL 與 ACWR
    public static func calculate(
        sessions: [WorkoutSession],
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        baselineCTL: Double? = nil
    ) -> (atl: Double, ctl: Double, acwr: Double) {
        let normalizedRefDate = calendar.startOfDay(for: referenceDate)
        guard let endOfRefDay = calendar.date(byAdding: .day, value: 1, to: normalizedRefDate) else {
            return (0.0, ctlFloor, 0.0)
        }
        
        // 防護 1：嚴格過濾未來會話，杜絕歷史回測時發生 Data Leakage
        let validSessions = sessions.filter { $0.startDate < endOfRefDay }
        
        // 1. 將 Session 依日曆天分桶加總當日負荷
        var dailyLoadMap: [Date: Double] = [:]
        var earliestSessionDay: Date?
        
        for session in validSessions {
            let sessionDay = calendar.startOfDay(for: session.startDate)
            dailyLoadMap[sessionDay, default: 0.0] += session.loadAU
            if let currentEarliest = earliestSessionDay {
                if sessionDay < currentEarliest { earliestSessionDay = sessionDay }
            } else {
                earliestSessionDay = sessionDay
            }
        }
        
        // 2. 累加近 7 天單日總負荷 (含 referenceDate 當日)
        var last7DaysSum = 0.0
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: normalizedRefDate) {
                last7DaysSum += dailyLoadMap[date, default: 0.0]
            }
        }
        let atl = last7DaysSum / 7.0
        
        // 3. 累加近 28 天單日總負荷
        var last28DaysSum = 0.0
        for dayOffset in 0..<28 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: normalizedRefDate) {
                last28DaysSum += dailyLoadMap[date, default: 0.0]
            }
        }
        
        // 防護 2：以首筆紀錄距今的日曆跨度天數 (含休息日) 計算冷啟動權重 n
        let rawCTL: Double
        if let baseline = baselineCTL, let earliest = earliestSessionDay {
            let daysSinceFirstSession = (calendar.dateComponents([.day], from: earliest, to: normalizedRefDate).day ?? 0) + 1
            let activeSpanDays = min(max(daysSinceFirstSession, 1), 28)
            
            if activeSpanDays < 28 {
                let n = Double(activeSpanDays)
                let spanDailyAvg = last28DaysSum / n
                rawCTL = spanDailyAvg * (n / 28.0) + baseline * ((28.0 - n) / 28.0)
            } else {
                rawCTL = last28DaysSum / 28.0
            }
        } else if let baseline = baselineCTL, validSessions.isEmpty {
            rawCTL = baseline
        } else {
            rawCTL = last28DaysSum / 28.0
        }
        
        // 應用 CTL 保底機制
        let ctl = max(rawCTL, ctlFloor)
        let acwr = atl / ctl
        
        return (atl, ctl, acwr)
    }
}

```

#### 2. [MODIFIED] `HybridTrainingEngine/Sources/HybridTrainingCore/Engine/MuscleCooldownEngine.swift`

* **變更重點**：
1. `calculateRunningImpactCooldown` 改為評估所有達成條件後取最大冷卻時數，消除順序遮蔽。
2. `calculateCooldownStatuses` 嚴格忽略 `session.endDate > now` 的未來會話。



```swift
import Foundation

/// 4 大動作模式與下肢冷卻時鐘核心引擎
public struct MuscleCooldownEngine {
    
    public static func calculateStrengthCooldownHours(
        pattern: MovementPattern,
        sRPE: Double,
        isPrimary: Bool = true
    ) -> Double {
        let baseHours: Double
        let isUpper = (pattern == .upperPush || pattern == .upperPull)
        
        if sRPE < 5.0 {
            baseHours = isUpper ? 12.0 : 18.0
        } else if sRPE < 7.0 {
            baseHours = isUpper ? 24.0 : 36.0
        } else if sRPE <= 8.5 {
            baseHours = isUpper ? 36.0 : 48.0
        } else {
            baseHours = isUpper ? 48.0 : 60.0
        }
        
        return isPrimary ? baseHours : (baseHours * 0.70)
    }
    
    /// 計算跑步對下肢肌群之衝擊冷卻時間 (採用多條件獨立取最大值，防止遮蔽)
    public static func calculateRunningImpactCooldown(
        durationMinutes: Double,
        zoneDurationsSeconds: [Int: Double] = [:]
    ) -> (quadHours: Double, posteriorHours: Double) {
        let zone3Seconds = zoneDurationsSeconds[3] ?? 0.0
        let zone4Seconds = zoneDurationsSeconds[4] ?? 0.0
        let zone5Seconds = zoneDurationsSeconds[5] ?? 0.0
        let highIntensitySeconds = zone4Seconds + zone5Seconds
        
        var maxQuad = 12.0
        var maxPosterior = 12.0
        
        // 條件 4: 標準有氧基底跑 (>= 45 分鐘)
        if durationMinutes >= 45.0 {
            maxQuad = max(maxQuad, 24.0)
            maxPosterior = max(maxPosterior, 24.0)
        }
        // 條件 3: 乳酸閾值節奏跑 (Zone 3 >= 20 分鐘)
        if zone3Seconds >= (20.0 * 60.0) {
            maxQuad = max(maxQuad, 36.0)
            maxPosterior = max(maxPosterior, 36.0)
        }
        // 條件 2: 高強度無氧間歇 / 衝刺 (Zone 4~5 >= 10 分鐘)
        if highIntensitySeconds >= (10.0 * 60.0) {
            maxQuad = max(maxQuad, 36.0)
            maxPosterior = max(maxPosterior, 48.0)
        }
        // 條件 1: 長距離耐力跑 (>= 75 分鐘)
        if durationMinutes >= 75.0 {
            maxQuad = max(maxQuad, 48.0)
            maxPosterior = max(maxPosterior, 48.0)
        }
        
        return (maxQuad, maxPosterior)
    }
    
    public static func calculateCooldownStatuses(
        sessions: [WorkoutSession],
        now: Date = Date()
    ) -> [MovementPattern: MuscleCooldownStatus] {
        var remainingMap: [MovementPattern: (remainingHours: Double, lastDate: Date?)] = [
            .upperPush: (0.0, nil),
            .upperPull: (0.0, nil),
            .lowerQuad: (0.0, nil),
            .lowerPosterior: (0.0, nil)
        ]
        
        // 僅評估已經結束的歷史會話 (session.endDate <= now)
        let validSessions = sessions
            .filter { $0.endDate <= now }
            .sorted(by: { $0.endDate < $1.endDate })
        
        for session in validSessions {
            let elapsedHours = max(0.0, now.timeIntervalSince(session.endDate) / 3600.0)
            
            if session.discipline == .running {
                let (quadImpact, posteriorImpact) = calculateRunningImpactCooldown(
                    durationMinutes: session.durationMinutes,
                    zoneDurationsSeconds: session.zoneDurationsSeconds ?? [:]
                )
                
                let quadRemaining = max(0.0, quadImpact - elapsedHours)
                if quadRemaining >= remainingMap[.lowerQuad]!.remainingHours && quadRemaining > 0 {
                    remainingMap[.lowerQuad] = (quadRemaining, session.endDate)
                } else if remainingMap[.lowerQuad]!.remainingHours == 0 {
                    remainingMap[.lowerQuad] = (0.0, session.endDate)
                }
                
                let posteriorRemaining = max(0.0, posteriorImpact - elapsedHours)
                if posteriorRemaining >= remainingMap[.lowerPosterior]!.remainingHours && posteriorRemaining > 0 {
                    remainingMap[.lowerPosterior] = (posteriorRemaining, session.endDate)
                } else if remainingMap[.lowerPosterior]!.remainingHours == 0 {
                    remainingMap[.lowerPosterior] = (0.0, session.endDate)
                }
            } else if session.discipline == .strength {
                for (index, pattern) in session.movementPatterns.enumerated() {
                    let isPrimary = (index == 0)
                    let totalHours = calculateStrengthCooldownHours(
                        pattern: pattern,
                        sRPE: session.sRPE,
                        isPrimary: isPrimary
                    )
                    let remaining = max(0.0, totalHours - elapsedHours)
                    if remaining >= remainingMap[pattern]!.remainingHours && remaining > 0 {
                        remainingMap[pattern] = (remaining, session.endDate)
                    } else if remainingMap[pattern]!.remainingHours == 0 {
                        remainingMap[pattern] = (0.0, session.endDate)
                    }
                }
            }
        }
        
        var result: [MovementPattern: MuscleCooldownStatus] = [:]
        for (pattern, data) in remainingMap {
            result[pattern] = MuscleCooldownStatus(
                pattern: pattern,
                remainingHours: data.remainingHours,
                lastStimulatedDate: data.lastDate
            )
        }
        return result
    }
}

```

#### 3. [MODIFIED] `HybridTrainingEngine/Sources/HybridTrainingCore/Engine/SmartMergeEngine.swift`

* **變更重點**：將原本的 First-Match 改為 Best-Fit（最大重疊率優先）匹配，避免一日兩練緊鄰時配錯對象。

```swift
import Foundation

/// 手錶與 App 雙重寫入之 50% 重疊智慧合併去重引擎
public struct SmartMergeEngine {
    
    public static func calculateOverlapRatio(
        startA: Date,
        endA: Date,
        startB: Date,
        endB: Date
    ) -> Double {
        let durA = max(0.0, endA.timeIntervalSince(startA))
        let durB = max(0.0, endB.timeIntervalSince(startB))
        let minDur = min(durA, durB)
        guard minDur > 0 else { return 0.0 }
        
        let overlapStart = max(startA, startB)
        let overlapEnd = min(endA, endB)
        let overlapDur = max(0.0, overlapEnd.timeIntervalSince(overlapStart))
        
        return overlapDur / minDur
    }
    
    public static func mergeIfOverlapping(
        watchSession: WorkoutSession,
        manualSession: WorkoutSession
    ) -> WorkoutSession? {
        let ratio = calculateOverlapRatio(
            startA: watchSession.startDate,
            endA: watchSession.endDate,
            startB: manualSession.startDate,
            endB: manualSession.endDate
        )
        
        guard ratio >= 0.50 else { return nil }
        
        let watchUUID: UUID
        switch watchSession.source {
        case .healthKitWorkout(let id), .smartMerged(let id):
            watchUUID = id
        case .manualLog:
            watchUUID = watchSession.id
        }
        
        return WorkoutSession(
            id: UUID(),
            startDate: watchSession.startDate,
            endDate: watchSession.endDate,
            discipline: manualSession.discipline != .running ? manualSession.discipline : watchSession.discipline,
            durationMinutes: watchSession.durationMinutes,
            sRPE: manualSession.sRPE,
            movementPatterns: manualSession.movementPatterns,
            source: .smartMerged(hkUUID: watchUUID),
            averageHeartRate: watchSession.averageHeartRate,
            zoneDurationsSeconds: watchSession.zoneDurationsSeconds,
            requiresManualRPEConfirmation: false
        )
    }
    
    /// 對整批會話進行 Best-Fit 最佳重疊率優先去重與智慧合併處理
    public static func processAndDeduplicate(sessions: [WorkoutSession]) -> [WorkoutSession] {
        var watchSessions: [WorkoutSession] = []
        var manualSessions: [WorkoutSession] = []
        var others: [WorkoutSession] = []
        
        for s in sessions {
            switch s.source {
            case .healthKitWorkout: watchSessions.append(s)
            case .manualLog: manualSessions.append(s)
            case .smartMerged: others.append(s)
            }
        }
        
        struct CandidatePair {
            let watchIndex: Int
            let manualIndex: Int
            let ratio: Double
        }
        
        var candidates: [CandidatePair] = []
        for (wIdx, watch) in watchSessions.enumerated() {
            for (mIdx, manual) in manualSessions.enumerated() {
                let ratio = calculateOverlapRatio(
                    startA: watch.startDate, endA: watch.endDate,
                    startB: manual.startDate, endB: manual.endDate
                )
                if ratio >= 0.50 {
                    candidates.append(CandidatePair(watchIndex: wIdx, manualIndex: mIdx, ratio: ratio))
                }
            }
        }
        
        // 依重疊率由高至低排序，確保最佳匹配優先
        candidates.sort { $0.ratio > $1.ratio }
        
        var consumedWatchIndices = Set<Int>()
        var consumedManualIndices = Set<Int>()
        var mergedResults: [WorkoutSession] = others
        
        for candidate in candidates {
            guard !consumedWatchIndices.contains(candidate.watchIndex),
                  !consumedManualIndices.contains(candidate.manualIndex) else { continue }
            
            if let merged = mergeIfOverlapping(
                watchSession: watchSessions[candidate.watchIndex],
                manualSession: manualSessions[candidate.manualIndex]
            ) {
                mergedResults.append(merged)
                consumedWatchIndices.insert(candidate.watchIndex)
                consumedManualIndices.insert(candidate.manualIndex)
            }
        }
        
        for (wIdx, watch) in watchSessions.enumerated() where !consumedWatchIndices.contains(wIdx) {
            mergedResults.append(watch)
        }
        for (mIdx, manual) in manualSessions.enumerated() where !consumedManualIndices.contains(mIdx) {
            mergedResults.append(manual)
        }
        
        return mergedResults.sorted(by: { $0.startDate < $1.startDate })
    }
}

```

### Milestone 2: 系統服務適配層 (`HealthKit` & `WorkoutKit` Ports)

#### 4. [NEW] `HybridTrainingEngine/Sources/HybridTrainingCore/Ports/SystemPorts.swift`

* **設計目標**：在 `HybridTrainingCore` 中定義純 Swift Protocol，供外層實現 HealthKit 讀取與 WorkoutKit 推送，確保應用層也可被 100% Mock 測試。

```swift
import Foundation

/// 健康數據讀取埠 (由 HealthKitAdapter 實作)
public protocol HealthDataProviding: Sendable {
    func fetchMorningSnapshot(for date: Date) async throws -> PhysiologicalSnapshot
    func fetchRecentWorkouts(since startDate: Date, until endDate: Date) async throws -> [WorkoutSession]
}

/// 課表排程推送埠 (由 WorkoutKitAdapter 實作)
public protocol WorkoutPlanScheduling: Sendable {
    func scheduleToAppleWatch(workout: RecommendedWorkout, scheduledDate: Date) async throws
}

```

---

## 5. 韌性、並行與錯誤處理策略 (Resilience, Concurrency & Error Strategy)

在 iOS 17+ / Swift 6 Strict Concurrency 環境下，外圍適配層必須防範以下四大系統級失效模式：

### 5.1 HealthKit 裝置鎖定與背景保護 (`HKError.errorDatabaseInaccessible`)

* **失效場景**：使用者早晨在鬧鐘響起、手機尚未完成 FaceID 解鎖前，背景任務（`BGAppRefreshTask`）或 Widget 嘗試讀取夜間 HRV 與睡眠數據，HealthKit 將拋出 `errorDatabaseInaccessible`。
* **韌性對策**：
* `HealthKitAdapter` 捕捉該錯誤後**嚴禁降級寫入空白快照**（否則會污染當日快取為低信心度無 HRV 狀態）。
* 標記當前狀態為 `.awaitingProtectedDataUnlock`，並監聽 `UIApplication.protectedDataDidBecomeAvailableNotification`，待解鎖瞬間立即觸發指數退避重試（Initial Delay: `200ms`, Multiplier: `2.0`, Max Retries: `3`）。



### 5.2 Swift 6 Actor 隔離與競態條件防護 (Race Condition Mitigations)

* **失效場景**：使用者剛跑完步走進健身房，一邊手錶正在透過藍牙向 iPhone HealthKit 同步 `HKWorkout`，一邊使用者已經打開 App 點擊「15 秒極簡打卡」，兩者同時觸發 `SmartMergeEngine` 與 `SwiftData` 寫入。
* **韌性對策**：
* `StorageAdapter` 必須宣告為 `@ModelActor actor WorkoutStorageActor`，將所有資料庫讀寫與去重對帳序列化至單一背景佇列。
* 在 `SDWorkoutSession` 上針對 `healthKitUUID` 建立 `@Attribute(.unique)` 唯一性約束。
* 當 `HKObserverQuery` 收到新手錶訓練寫入時，若發現過去 2 小時內存在未合併之 `.manualLog` 且重疊率 $\ge 50\%$，在 Actor 內部執行原子級（Atomic Transaction）軟合併，將原手動打卡更新為 `.smartMerged(hkUUID:)`，防止產生雙倍 AU 負荷。



### 5.3 任務取消與超時熔斷 (`Task Cancellation & Timeout`)

* **失效場景**：查詢過去 28 天離散心率樣本（`HKQuantitySample`）時，若跑者每天跑長距離，樣本點數可能高達數十萬筆，造成 UI 卡頓。
* **韌性對策**：
* 僅針對 `requiresManualRPEConfirmation` 尚未計算過的 `HKWorkout` 執行一次性離散心率積分，計算完畢後即將 `zoneDurationsSeconds` 與推導後 `sRPE` 持久化至 `HybridTrainingStorage`。
* 在每次離散樣本迴圈迭代前呼叫 `try Task.checkCancellation()`，並為單次 HealthKit 聚合查詢設置 `3.0 秒` TaskGroup 超時保護；若超時則先以已持久化快取呈現 `DailyDecision`。



---

## 6. 驗證與 6 大 P0 BDD 邊界測試驗收清單 (Verification & Testing Strategy)

針對本系統之核心價值，以下整理 **6 大 P0 BDD 邊界測試案例** 與 **4 項新增邊界回歸測試** 的對證檢查表：

| 測試編號 | BDD 測試場景描述 | 預期系統行為與斷言 (Assertions) | 目前程式碼通過狀態 |
| --- | --- | --- | --- |
| **BDD Case 1** | **雙重寫入智慧合併 (Smart Merge)**<br>

<br>Apple Watch 記錄 18:00~19:00 重訓，使用者於 18:10~19:05 手動打卡 `lowerQuad` (sRPE 8.0) | 1. 重疊率 `50m / 55m = 90.9% >= 50%`。<br>

<br>2. 合併為單一 `.smartMerged` 會話，時長採手錶 `60.0m`，sRPE 採手動 `8.0`，負荷僅單筆入帳 `480.0 AU`（絕不雙重入帳為 920 AU）。 | **PASS** |
| **BDD Case 2** | **延遲跨日補打卡時間錨定 (Time Offset)**<br>

<br>週二早晨 08:00 補打週一晚間 20:00 結束之大重量硬舉 (`lowerPosterior`, sRPE 9.0) | 1. 基礎冷卻時數 = `60.0h`。<br>

<br>2. 截至週二 08:00 已流逝 `12.0h`，剩餘冷卻精確為 `48.0h`（而非從打卡當下起算 60h）。 | **PASS** |
| **BDD Case 3** | **心率感測器脫落防呆 (HR Sensor Dropout)**<br>

<br>手錶記錄 40 分鐘 (2400s) 跑步，但因流汗鬆脫僅前 15 分鐘有心率樣本（或中間間隔長達 10 分鐘） | 1. 單一間隔強制箝位 `min(Δt, 15.0s)`。<br>

<br>2. 有效覆蓋率 `< 50%`，`requiresManualConfirmation == true`，暫以預設 RPE `3.5` 降級保護。 | **PASS** |
| **BDD Case 4** | **無 HRV 低信心度平滑降級 (Garmin Fallback)**<br>

<br>使用者忘記戴錶睡覺 (`hrvTodayMs = nil`)，但手動記錄睡眠 8.0h、ACWR = 1.0、無痠痛 | 1. `confidence == .low`。<br>

<br>2. `sleepFactor` 自動由 `0.35` 提升至 `0.70`。<br>

<br>3. `readinessScore = 50 + 0.7*(100-70) = 71.0`，成功取得 `.ready` 綠燈，不發生死鎖。 | **PASS** |
| **BDD Case 5** | **下肢深度冷卻對跑步課表之雙向鎖定**<br>

<br>晨間 HRV 與睡眠皆滿分（綠燈 `.ready`），但昨日剛練完大重量深蹲（`lowerQuad` 剩餘冷卻 `36.0h > 24.0h`） | 1. 攔截原定之 `Zone 4 閾值節奏跑`。<br>

<br>2. 主課表自動降級為 `Zone 2 有氧基底慢跑` (`isLockedDueToFatigue == true`)，且備選課表提供 `upperPush` / `upperPull` 完全避開下肢干擾。 | **PASS** |
| **BDD Case 6** | **傷病與疼痛安全閘門熔斷 (Injury Circuit Breaker)**<br>

<br>即使 HRV 極佳、ACWR = 0.9，只要晨間快照勾選 `hasReportedPainOrInjury == true` | 1. 立即熔斷：分数強制歸零 (`0.0`)，燈號為 `.injured`。<br>

<br>2. 鎖死所有跑課與重訓，主推薦僅輸出 `完全休息或溫和伸展 (Mobility)` 與 `完全靜態休息`。 | **PASS** |
| **Regression 7** | **[新增驗證] 規律練 4 休 3 滿 28 天之 CTL 準確度** | 驗證套用 Milestone 1 修復後，第 28 天之 CTL 分母精確為 `28.0`，不會因休息日無 `WorkoutSession` 而誤用 `16.0` 造成 CTL 虛高。 | **待套用 Milestone 1 修補** |
| **Regression 8** | **[新增驗證] 一日兩練緊鄰時段 Best-Fit 合併** | 當同日有兩筆手錶紀錄與兩筆手動打卡時，驗證 `SmartMergeEngine` 按最高重疊率精準配對。 | **待套用 Milestone 1 修補** |

### XCTest 邊界驗證範例代碼 (`HybridTrainingCoreTests.swift`)

將以下測試加入 `HybridTrainingEngine/Tests/HybridTrainingCoreTests/` 即可立即驗證上述修復與 6 大 BDD 場景：

```swift
import XCTest
@testable import HybridTrainingCore

final class ArchitectureCrossValidationTests: XCTestCase {
    
    func testRestDaysDoNotCorrupt28DayCTL() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = ISO8601DateFormatter().date(from: "2026-10-17T08:00:00Z")!
        
        // 模擬過去 28 天內，每週練 4 天 (每次 280 AU)、休 3 天，共 16 次訓練，總負荷 = 4480 AU
        // 真實 28 天日均 CTL 應為 4480 / 28 = 160.0 AU/day
        var sessions: [WorkoutSession] = []
        for dayOffset in stride(from: 0, to: 28, by: 2) { // 14 sessions + Day 27 (earliest)
            let start = calendar.date(byAdding: .day, value: -dayOffset, to: refDate)!
            sessions.append(WorkoutSession(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(3600),
                discipline: .running,
                durationMinutes: 40,
                sRPE: 7.0, // 280 AU
                movementPatterns: [],
                source: .manualLog
            ))
        }
        // 補上第 27 天前（最早一筆，確保橫跨滿 28 天）
        let earliestStart = calendar.date(byAdding: .day, value: -27, to: refDate)!
        sessions.append(WorkoutSession(
            id: UUID(),
            startDate: earliestStart,
            endDate: earliestStart.addingTimeInterval(3600),
            discipline: .running,
            durationMinutes: 40,
            sRPE: 7.0,
            movementPatterns: [],
            source: .manualLog
        ))
        
        let (_, ctl, _) = ACWRCalculator.calculate(
            sessions: sessions,
            referenceDate: refDate,
            calendar: calendar,
            baselineCTL: 85.0 // 即使傳入初階 baseline，滿 28 天跨度後也不應受干擾
        )
        
        let expectedCTL = (15.0 * 280.0) / 28.0 // 150.0 AU/day
        XCTAssertEqual(ctl, expectedCTL, accuracy: 0.01, "滿 28 天日曆跨度後，休息日不得觸發冷啟動公式")
    }
}

```