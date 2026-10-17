# 0004. Swift Package 拆分為 Core 與 Storage 雙目標架構

## 狀態
Accepted

## 背景與決策
規格書中同時包含純數學決策模型與基於 iOS 17+ SwiftData `@Model` 的持久化存取實體 (`SDWorkoutSession`)。我們決定在 `HybridTrainingEngine` SPM 套件中拆分為兩個明確獨立的 Target：
1. `HybridTrainingCore`：封裝所有運動科學演算法、冷卻狀態機、衝突仲裁決策樹與純 Swift 領域模型（完全零外部框架依賴）。
2. `HybridTrainingStorage`：依賴 `HybridTrainingCore`，專責 SwiftData `@Model` 宣告與雙向資料轉換適配器。

## 原因與取捨
此架構確保了核心決策邏輯能夠在無任何 Apple 專有生態框架（HealthKit/SwiftData/UIKit）的前提下，於本機終端、macOS 或 CI 環境以毫秒級速度運行 100% 確定性的 XCTest 單元測試與 Phase 6 BDD 邊界驗證；同時隔離了 SwiftData 在不同 iOS 版本的編譯器環境限制。
