# 0002. 純 Swift 領域模型與平台框架完全解耦

## 狀態
Accepted

## 背景與決策
運動科學演算法、衝突仲裁決策樹與冷卻狀態機是系統的核心價值，需要極致的測試覆蓋率與確定性驗證。我們決定將核心決策與領域實體 (`WorkoutSession`, `PhysiologicalSnapshot`, `MuscleCooldownStatus`, `DailyDecision`) 實作為不依賴任何外部框架（禁止 `import HealthKit`、`import SwiftData`、`import UIKit`）的純 Swift 結構體，所有資料庫存取與健康數據皆透過外部適配器 (`StorageAdapter`) 轉換注入。

## 原因與取捨
雖然該架構需要編寫額外的 DTO/Model 轉換層代碼，但它換取了核心演算法 100% 可在純終端環境毫秒級執行單元測試、BDD 極端邊界驗證與 4～8 週歷史回測模擬的能力，徹底杜絕模擬器啟動延遲與 HealthKit 依賴地獄。
