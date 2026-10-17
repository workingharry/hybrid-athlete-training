# 0005. 參考 CSCS 肌力體能與 Garmin Readiness 演算法之生理模型校準

## 狀態
Accepted

## 背景與決策
在落實純 Swift 領域核心運算時，針對「無 HRV 時之準備度動態加權」與「肌肉冷卻連續小時衰減」進行演算法細化：
1. **參考 Garmin (Firstbeat Analytics) Training Readiness 權重重平衡機制**：
   當夜間 HRV 數據缺失時，系統將原本由 HRV 承載之權重動態重分配至「有效總睡眠時數」與「晨間主觀活力/痠痛指數」，將睡眠係數由 $0.35$ 提升至 $0.70$。這確保了睡眠充分且 ACWR 穩健的運動員在低信心度模式下仍能合理達到綠燈（$\ge 70$）就緒狀態，避免公式出現假性疲勞死鎖。
2. **參考 NSCA CSCS (Essentials of Strength Training and Conditioning) 恢復與並行訓練原則**：
   * **48～72 小時肌群恢復律**：針對中高強度肌力訓練（sRPE $\ge 7.0$），嚴格維持下肢 48～60 小時之基礎冷卻時鐘。
   * **連續小時差 (Continuous Hours) 衰減**：依據 CSCS 建議之並行訓練同日內需至少間隔 6 小時（$\ge 6$h separation）以恢復肝醣並減輕急性干擾效應，冷卻衰減一律採用精確至秒級的時間戳記浮點小時差（$H_{\text{elapsed}} = \frac{T_{\text{now}} - T_{\text{end}}}{3600}$），捨棄粗糙的曆日天數差。

## 原因與取捨
此架構使演算法既具備嚴謹運動生理學文獻背書，又能完美契合 Phase 6 BDD 驗收測試中「一日兩練」、「跨夜補打卡回推」與「低信心度平滑降級」的精確數值需求。
