# 系統架構設計與公開縫隙規格 (System Architecture & Public Seams)
> 專案：零打字記帳 (ZeroTypingExpense)  
> 規格版本：v1.3 Strict Implementation  
> 並行模型：Swift 6 Strict Concurrency (Actors & Sendable)

---

## 1. 核心分層架構 (Layered Architecture)

```
+-------------------------------------------------------------------------+
|                              SwiftUI Views                              |
|  DashboardView | InsightsView | BudgetView | LedgerView | PendingReview |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                         App Intents Integration                         |
|   RecordExpenseIntent (Wallet Automation / Back Tap / Siri Shortcuts)   |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                       Domain Engines (Actor-Isolated)                   |
|   • TransactionEngine: Ingestion, Idempotency, Budget, Reversible Undo   |
|   • MerchantEngine: Rule Learning, Aliasing, Confidence Scoring         |
|   • PhotoCleanupService: 7-Day Cooldown, Batch Deletion Safeguards       |
|   • BackupEngine: RFC 4180 CSV Export, SHA-256 JSON Integrity Backup    |
|   • VisionEngine: Multimodal OCR, Currency & Amount Extraction          |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                           Core Data Models                              |
|   TransactionEntity | RefundEntity | CategoryEntity | MerchantEntity    |
+-------------------------------------------------------------------------+
```

---

## 2. 關鍵公開縫隙規格 (Public Seam Specifications)

### 2.1 TransactionEngine (Swift 6 Actor)
- `ingestTransaction(TransactionEntity) throws -> TransactionEntity`
  - 零元入閘識別：`amountMinor == 0` 自動賦予 `.pending` 狀態，排除於當期活躍預算外。
  - 24 小時出閘對齊：以最短時間差算法對齊同一商戶、同一來源設備之入閘 hold。
  - 雙層去重：第一層 IdempotencyKey 精確命中；第二層 120 秒同金額同商戶模糊預警。
- `calculateActiveNetSpending(forCurrency:start:end:) -> Int64`
  - 嚴格遵守 §8.3：排除未確認、疑似重複、轉帳與儲值；自動抵減已確認退款。
- `calculateSpendingByCategory(forCurrency:start:end:) -> [UUID: Int64]`
  - 各分類實質淨支出計算，支援退款扣減。
- `getTopMerchants(forCurrency:limit:start:end:) -> [(merchant: String, count: Int, totalMinor: Int64)]`
  - 依累計金額降序排列，提供交易筆數與總支出。
- `getSpendingByDeviceSource(forCurrency:start:end:) -> [DeviceSource: Int64]`
  - 區分 iPhone 與 Apple Watch 實質支出分佈。
- `calculateUnconvertedForeignSpending(baseCurrency:) -> [String: Int64]`
  - 外幣隔離池，防止外幣混入主幣種預算統計。
- Section 9.3 撤銷機制：
  - `revertCategory(id:toCategoryId:)`
  - `returnToNeedsReview(id:)`
  - `hideTransaction(id:)`
  - `unhideTransaction(id:)`

### 2.2 BackupEngine
- `exportToCSV(transactions:[TransactionEntity]) -> String`
  - 實作 RFC 4180 標準，開頭添加 UTF-8 BOM (`\u{FEFF}`) 解決 Excel 亂碼。
  - 防 CSV 公式注入：針對 `=`, `+`, `-`, `@`, `\t`, `\r` 注入前綴單引號 `'` 轉義。
- `generateJSONBackup(transactions:[TransactionEntity]) throws -> (jsonData: Data, checksum: String)`
  - 計算 SHA-256 Checksum，還原時嚴格核對，篡改即拒絕。

---

## 3. 防禦性程式設計與安全考量 (Defensive Guards)
- **溢位防護**：全統計計算使用 `addingReportingOverflow`，溢位時安全封頂於 `Int64.max`，防止進程崩潰。
- **PhotoKit 隱私安全**：嚴格遵循 Apple PhotoKit 指引 5.1.1，提供 7 天冷卻期，禁止自動物理刪除相片，全流程用戶可見。
- **剪貼簿與進程隔離**：跨工具通訊加裝互斥鎖與防污染保護。
