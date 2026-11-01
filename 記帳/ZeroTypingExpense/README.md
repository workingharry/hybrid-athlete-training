# 零打字記帳 (Zero-Typing Expense)
> 專為香港與國際市場打造的極致自動化零摩擦記帳 iOS App。支援 Apple Pay 即時截取、截圖 Vision OCR、智慧雙層去重、Section 8.3 預算抵減、以及 Section 9.3 完整可逆撤銷機制。

---

## 🌟 核心特色 (Core Features)

1. **零打字截取 (Zero-Typing Ingestion)**
   - **Apple Pay 捷徑自動化**：交易完成瞬間經由 `RecordExpenseIntent` 背景無感入帳。
   - **截圖與背頁輕點 (Back Tap)**：配合 iOS Vision OCR 辨識消費明細、單據與金額。
   - **交通 $0 預授權智慧配對**：拍卡入閘（港鐵 MTR / 倫敦地鐵）$0.00 自動標記 Pending，並於 24 小時內與出閘結算金額自動對齊配對，絕不拋錯。
   - **手錶與手機來源隔離**：精確標記交易來源設備（`iPhone` vs `Apple Watch`），支援多卡獨立追蹤。

2. **智慧去重與防碰撞 (Double-Layer Idempotency Engine)**
   - **事件級去重**：以唯一的 `idempotencyKey` 防禦短時間重複回呼。
   - **語意級防碰撞**：兩分鐘內相同商戶、相同金額之交易自動進入 `possibleDuplicate` 待審核池，保障每筆支出真實性。

3. **Section 8.3 商業級預算與統計 (Commercial-Grade Accounting & Analytics)**
   - 待確認交易、可疑重複交易自動排除於有效預算外。
   - 退款（全額退款與部分退款）即時抵減原消費類別與總支出。
   - 支出類型切換（`一般消費`、`轉帳`、`儲值`、`手續費`）即時連動預算重算。
   - 外幣隔離（Foreign Currency Isolation）：非基準貨幣獨立彙整，絕不擅自混合匯率。

4. **Section 9.3 完整可逆撤銷機制 (Reversible Undo Engine)**
   - **還原分類 (`revertCategory`)**：保留分類歷史，一鍵復原。
   - **退回待審核 (`returnToNeedsReview`)**：立即從有效確認預算中移除。
   - **軟隱藏交易 (`hideTransaction` / `unhideTransaction`)**：隱藏交易而不物理刪除，落實 PhotoKit 與資料安全指引。

---

## 🏗️ 系統架構 (Architecture Overview)

- **UI 層**：SwiftUI 現代響應式架構，涵蓋 `DashboardView`（總覽）、`InsightsView`（分析）、`BudgetView`（預算）、`LedgerView`（帳本）與 `PendingReviewView`（待審核）。
- **領域層**：`TransactionEngine`（Swift 6 Actor 隔離並行保護）、`MerchantEngine`（貪婪最長子字串商戶別名學習）、`PhotoCleanupService`（7日冷卻物理防誤刪）。
- **整合層**：`RecordExpenseIntent`（App Intents 框架）、`VisionEngine`（Vision 文字辨識與金額擷取）、`BackupEngine`（RFC 4180 CSV 匯出防注入與 SHA-256 驗證備份）。

---

## 🚀 快速上手 (Quick Start)

### 環境需求
- macOS Sonoma 14.0+
- Xcode 16.0+
- iOS 17.0+ 實體裝置或模擬器
- Swift 6.0+

### 本地測試與編譯
```bash
# 執行 Swift Testing 測試套件 (39 項商業規格檢驗)
swift test --scratch-path /tmp/ZeroTypingBuild

# 產生 Xcode 專案檔
xcodegen generate

# 一鍵編譯與安裝至 iPhone
./install_to_phone.sh
```

---

## 🛡️ 品質保證 (Commercial Standards)
- **100% 測試覆蓋**：39 條公開縫隙（Public Seams）測試全數通過（RED -> GREEN -> REFACTOR）。
- **零殘缺交付 (Zero Half-Products)**：代碼庫絕無未實現占位標籤或 Mock 虛假樁點。
- **Swift 6 Strict Concurrency**：全域 Actor 隔離，零競態洩漏。
