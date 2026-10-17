# Hybrid Training Engine (混合訓練排課系統)

專為混合體能運動員（同時兼修耐力路跑與重量訓練）設計的 iPhone 原生自適應訓練排程系統，透過統一負荷貨幣與雙向運動學衝擊狀態機協調疲勞累積。

## 訓練負荷與度量 (Training Load & Metrics)

**Session Load (任意單位負荷, AU)**:
Foster's sRPE 與訓練時長（分鐘）的乘積，作為衡量心肺有氧與肌力神經疲勞的統一數值貨幣。
_Avoid_: TRIMP, EPOC, Strain, 訓練點數, 疲勞積點

**Foster sRPE (運動自覺強度標尺)**:
運動員於課後主觀自評訓練強度的 1.0 至 10.0 數值標尺。
_Avoid_: RPE 6-20, Borg 標尺, 體感強度, 努力程度

**Acute Workload (7天急性負荷, ATL-SMA)**:
近 7 天單日總訓練負荷（AU）的簡單滾動移動平均值（AU/day），作為短期疲勞累積之工程啟發指標。
_Avoid_: 指數加權疲勞 (EWMA Fatigue), 7日絕對疲勞

**Chronic Workload (28天慢性負荷, CTL-SMA)**:
近 28 天單日總訓練負荷（AU）的簡單滾動移動平均值（AU/day），並具備 30.0 AU/day 的保護下限，作為長期體能儲備之工程啟發基準。
_Avoid_: 指數加權體能 (EWMA Fitness), 長期絕對體能

**Acute:Chronic Workload Ratio (急慢性負荷比, ACWR-SMA)**:
7 天急性負荷與 28 天慢性負荷之比值。依據運動科學界批評（Impellizzeri et al., 2020），本系統僅作為增量速率之軟性啟發式參考，嚴禁作為硬性阻斷決策。
_Avoid_: 傷病預測係數, 硬性風控閘門, TSB

**Personal Bias (個人校正偏差)**:
由歷史跑步自評 sRPE 與心率區間推導值之中位數誤差計算而得的個體補償項，箝位於 -1.5 至 +1.5 之間。
_Avoid_: 誤差校正係數, 個人偏好, 心率補償值

**Zone 0 (恢復與熱身區間)**:
跑步期間心率低於 50% MaxHR 的動態恢復或步行時間，對應基準強度 $\text{BaseRPE} = 1.0$。
_Avoid_: 無效區間, 休息心率, 靜態時間

## 運動機能與冷卻 (Biomechanics & Cooldown)

**Movement Pattern (動作模式)**:
基於運動機能學劃分的 4 大肌力受力模式（上半身推 `upperPush`、上半身拉 `upperPull`、下肢膝主導 `lowerQuad`、下肢髖主導 `lowerPosterior`）。
_Avoid_: 肌群, 部位, 訓練動作, 分化部位

**Cooldown Clock (啟發式冷卻時鐘)**:
各動作模式在接受單次訓練刺激後，自結束時間點起算、至肌纖維微創傷與神經疲勞預計緩解的工程啟發式倒數小時數（可由使用者依體質自訂配置）。
_Avoid_: 生理絕對恢復時間, 休息天數, DOMS 絕對計時器

**Volume Discount (輔項折減係數)**:
同日訓練多個動作模式時，非首項的次要輔助模式享有之 0.7 倍基礎冷卻時數折減機制。
_Avoid_: 多部位折扣, 疲勞分散比率, 輔項優惠

## 生理恢復與決策 (Physiological Readiness & Decision)

**Robust HRV Z-Score (穩健 HRV Z 分數)**:
以過去 14 天夜間 SDNN 中位數與絕對離差中位數（MAD，保底 2.0ms）計算之標準化自律神經狀態指標。
_Avoid_: 標準差 Z 分數, HRV 平衡度, 自律神經指數

**Readiness Score (綜合生理準備度分數)**:
由穩健 HRV Z 分數、昨夜去重總睡眠時長與 ACWR 加權合成的 0 至 100 分連續型生理就緒指數。
_Avoid_: 恢復分數, 活力指數, Recovery Score

**Readiness Grade (準備度燈號)**:
系統對外輸出的四態決策標記，包含綠燈 (`ready`)、黃燈 (`moderate`)、紅燈 (`fatigued`) 與傷病中斷 (`injured`)。
_Avoid_: 訓練狀態, 燈號狀態, 狀態標籤

## 資料同步與對帳 (Sync & Deduplication)

**Smart Merge (50% 智慧合併)**:
當 Apple Watch 體能訓練與 App 手動打卡的時間區間重疊達 50% 以上時，自動將心率時長與打卡動作模式融合成單一會話的去重機制。
_Avoid_: 覆蓋去重, 自動合併, 雙重入帳

**Time Offset (時間回推錨定)**:
跨日或延遲補打卡時，以使用者指定之實際訓練結束時間作為冷卻時鐘起算點的計算邏輯。
_Avoid_: 補打卡時間差, 延遲校正, 時間追溯

**Reconciliation (課後時間窗對帳)**:
在預定課表時間前後 2 小時內，自動關聯手錶上報的真實跑步體能訓練並計算時長與區間達成率的校驗程序。
_Avoid_: 課表核銷, 訓練結算, 體能比對
