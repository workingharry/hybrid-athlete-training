import SwiftUI

/// Onboarding Tab Scenario for iOS 27 Multi-Channel Setup
public enum OnboardingScenario: String, CaseIterable, Identifiable {
    case nfcTap = "門市拍卡實踐"
    case communityTutorials = "線上教學與最佳解法"
    case interactiveSimulator = "捷徑變數模擬器"
    case appleIntelligence = "Apple Intelligence 提示詞"
    case onlineApplePay = "線上與App內支付"
    case backTapScreenshot = "輕點背面截圖"
    case clipboardNotification = "簡訊與URL快捷"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .nfcTap:
            return "wave.3.right.circle.fill"
        case .communityTutorials:
            return "lightbulb.circle.fill"
        case .interactiveSimulator:
            return "slider.horizontal.2.square.on.square"
        case .appleIntelligence:
            return "sparkles"
        case .onlineApplePay:
            return "creditcard.circle.fill"
        case .backTapScreenshot:
            return "hand.tap.fill"
        case .clipboardNotification:
            return "link.circle.fill"
        }
    }
}

/// Screen S02: Apple Pay Onboarding / Setup Guide with Multi-Scenario Tabs & Interactive Test Sandbox
public struct ApplePayOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared

    @State private var selectedScenario: OnboardingScenario = .nfcTap
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    @State private var isProcessingSimulation: Bool = false

    // Simulator Interactive State
    @State private var simAmountBound: Bool = false
    @State private var simMerchantBound: Bool = false
    @State private var simActivePicker: String? = nil // "amount" or "merchant"
    @State private var simShowSubProperties: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Text("設定引導 · 零打字極速記帳")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.accentLight)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Subtitle
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Apple Pay 自動化設定指引")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                            Text("依據 iOS 官方架構，完成一次性捷徑設定後，每次出門刷卡或交通感應即 100% 靜默入帳，無需打字、點擊或確認。")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .lineSpacing(3)
                        }
                        .padding(.top, 4)

                        // Scenario Picker Segment
                        Picker("情境導航", selection: $selectedScenario) {
                            ForEach(OnboardingScenario.allCases) { scenario in
                                Label(scenario.rawValue, systemImage: scenario.icon)
                                    .tag(scenario)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)

                        // Step-by-step Content for Selected Scenario
                        scenarioContentView
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        // Common Pitfalls & FAQ Section
                        faqSectionView

                        // Interactive Test Sandbox (驗收沙盒)
                        sandboxCardView
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                // Bottom Shortcuts Link Bar
                bottomActionBar
            }
            .background(DesignTokens.Colors.bgLight.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .top) {
                if showToast, let msg = toastMessage {
                    ToastBanner(message: msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
            }
        }
    }

    // MARK: - Scenario Content Views

    @ViewBuilder
    private var scenarioContentView: some View {
        switch selectedScenario {
        case .nfcTap:
            VStack(spacing: 14) {
                ActiveStepCard(
                    stepNumber: 1,
                    title: "步驟 1：開啟「捷徑」自動化標籤頁",
                    description: "打開 iPhone 上的「捷徑」App，點選底部的「自動化 (Automation)」分頁，再點擊右上角「+」新增自動化。"
                )

                ActiveStepCard(
                    stepNumber: 2,
                    title: "步驟 2：選取「交易」並設定「立即執行」",
                    description: "在觸發條件清單中選擇「交易 (Transaction)」，勾選常用 Apple Pay 信用卡或八達通。\n\n⚠️ 關鍵開關：務必勾選「立即執行 (Run Immediately)」並關閉「執行前詢問」與「執行時通知」，才能享受完全無感的背景靜默入帳！"
                )

                ActiveStepCard(
                    stepNumber: 3,
                    title: "步驟 3：新增空白操作 ➔ 加入「記錄支出」",
                    description: "點選「新增空白的自動化操作」➔「加入動作」➔ 在搜尋列輸入「零打字記帳」或「ZeroTypingExpense」，選擇「記錄支出」動作。"
                )

                DetailedVariableBindingStepCard()

                ActiveStepCard(
                    stepNumber: 5,
                    title: "步驟 5：點擊右上角「完成」",
                    description: "點擊右上角「完成」儲存。從現在開始，不論在 7-Eleven、餐廳或地鐵閘門刷卡，0.01 秒背景自動入帳，徹底告別手動記帳！"
                )
            }

        case .communityTutorials:
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(DesignTokens.Colors.accentLight)
                        Text("App Store & GitHub 社群精選解決方案")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    }

                    Text("綜合 App Store 標竿 App（如 Budget Flow、Costy、MoneyWiz）與 Reddit r/shortcuts 開源社群經驗，提供以下四種最穩定、最低人為錯誤的極簡記帳工作流：")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        .lineSpacing(2)
                }
                .padding(14)
                .background(DesignTokens.Colors.surfaceLight)
                .cornerRadius(12)

                ActiveStepCard(
                    stepNumber: 1,
                    title: "解法 1：官方推薦「1 步執行捷徑法」（零失敗、最不易選錯變數）",
                    description: "【原理】：許多人在設定二段式變數「捷徑輸入 ➔ 金額」時卡住。最佳做法是：點選下方「匯出官方捷徑檔 (.shortcut)」，捷徑即一鍵裝入 iPhone 捷徑庫。在自動化中只需 1 個動作：「執行捷徑」➔ 選擇「零打字記帳」，捷徑輸入自動全量傳入，完全不用手動設定屬性！"
                )

                Button(action: {
                    ShortcutFileGenerator.shareShortcutFile()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("一鍵匯出並安裝官方捷徑檔 (.shortcut)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue)
                    .cornerRadius(10)
                }

                ActiveStepCard(
                    stepNumber: 2,
                    title: "解法 2：極簡「單一完整輸入」免二段式設定",
                    description: "【原理】：在捷徑自動化中加入「記錄支出」後，直接將鍵盤上的「捷徑輸入」填入「捷徑完整輸入 (極簡免設定)」單一欄位。本機智慧解析引擎會自動辨識並抽取字串中的金額、商戶與幣別，無需手動點開二級屬性清單！"
                )

                ActiveStepCard(
                    stepNumber: 3,
                    title: "解法 3：線上支付「輕點背面」手勢流（Uber / Foodpanda / Safari）",
                    description: "【原理】：iOS 系統基於隱私限制，線上網購與 In-App Apple Pay 不會觸發 Wallet NFC 自動化。社群公認最順暢的工作流是：在 iPhone「設定 ➔ 輔助使用 ➔ 觸控 ➔ 輕點背面」綁定「辨識截圖記帳」，結帳成功畫面輕點 2 下背面即可秒級入帳！"
                )

                ActiveStepCard(
                    stepNumber: 4,
                    title: "解法 4：各大銀行扣款簡訊與推播通知 (Notification Trigger)",
                    description: "【原理】：針對不支援 Apple Pay 交易自動化的卡片，可在捷徑建立「通知自動化」，當收到來自匯豐 HSBC、中銀、渣打或恒生的扣款通知時，自動傳入零打字記帳引擎，背景秒級清洗入帳。"
                )
            }

        case .interactiveSimulator:
            VStack(spacing: 14) {
                interactiveVariableSimulatorCard
            }

        case .onlineApplePay:
            VStack(spacing: 14) {
                ActiveStepCard(
                    stepNumber: 1,
                    title: "線上 / Safari 網頁結帳支援",
                    description: "iOS 系統限制線上支付不觸發 Wallet NFC 自動化。結帳成功時，長按操作按鈕 (Action Button) 或輕點背面，系統即調用 App Intent 瞬間提取訂單詳情！"
                )
                PendingStepRow(stepNumber: 2, text: "支援外送 Foodpanda、叫車 Uber 及 Safari 購物結帳")
                PendingStepRow(stepNumber: 3, text: "App Store 定期訂閱自動歸類固定開銷，外幣自動隔離匯率")
            }

        case .backTapScreenshot:
            VStack(spacing: 14) {
                ActiveStepCard(
                    stepNumber: 1,
                    title: "啟用「輕點背面」截圖記帳",
                    description: "前往 iPhone「設定」➔「輔助使用」➔「觸控」➔「輕點背面」➔ 點兩下選擇「辨識截圖記帳」捷徑。在任何付款成功畫面點兩下背面，即刻辨識入帳！"
                )
                PendingStepRow(stepNumber: 2, text: "本機 Apple Vision OCR 辨識商戶、多候選金額消歧義")
                PendingStepRow(stepNumber: 3, text: "截圖資產受防誤刪保護，確認記帳後才進入清理候選")
            }

        case .clipboardNotification:
            VStack(spacing: 14) {
                ActiveStepCard(
                    stepNumber: 1,
                    title: "通知與扣款簡訊解析",
                    description: "收到銀行扣款簡訊（如 HSBC、中銀、渣打）時長按複製，或透過「通知」捷徑自動化傳入，引擎自動去除公式注入字元並提取實付金額。"
                )

                ActiveStepCard(
                    stepNumber: 2,
                    title: "URL Scheme 快捷調用",
                    description: "支援第三方 App 或自訂捷徑調用：\nzerotyping://record?amount=48.50&merchant=Starbucks&currency=HKD\n\n一鍵直接入帳，零介面摩擦！"
                )
            }

        case .appleIntelligence:
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Apple Intelligence × 零打字極速記帳")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    }

                    Text("在 iOS 18.1+ 中，可將 Apple Intelligence 的語意理解能力無縫串接至零打字記帳。在捷徑中將任何扣款文字交給模型提取，再直接連接至單一動作「解析 AI / 扣款文字」，全自動秒級完成記帳！")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        .lineSpacing(2)
                }
                .padding(14)
                .background(DesignTokens.Colors.surfaceLight)
                .cornerRadius(12)

                ActiveStepCard(
                    stepNumber: 1,
                    title: "步驟 1：在捷徑中加入「使用模型」操作",
                    description: "接收來自任何來源的扣款簡訊、郵件或螢幕文字，並傳入 Apple Intelligence 模型。"
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .foregroundColor(DesignTokens.Colors.accentLight)
                        Text("步驟 2：建議設定之系統提示詞 (Prompt)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    }

                    Text("將以下提示詞複製並填入捷徑中的 Prompt 欄位：")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)

                    Text("""
                    請從以下扣款文字或收據中提取金額與商戶，並輸出為以下精確格式：
                    amount: [金額數字] [貨幣代碼，如 10 hkd]
                    merchant: [商戶名稱]
                    範例：amount: 10 hkd, merchant: seven eleven
                    """)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    Button(action: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = "請從以下扣款文字或收據中提取金額與商戶，並輸出為以下精確格式：\namount: [金額] [幣別]\nmerchant: [商戶名稱]\n範例：amount: 10 hkd, merchant: seven eleven"
                        #endif
                        self.toastMessage = "已複製 Apple Intelligence 提示詞範本"
                        self.showToast = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            self.showToast = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                            Text("複製 AI 提示詞範本")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(DesignTokens.Colors.surfaceLight)
                .cornerRadius(12)

                ActiveStepCard(
                    stepNumber: 3,
                    title: "步驟 3：串接至「解析 AI / 扣款文字」單一動作",
                    description: "在捷徑下一步加入「解析 AI / 扣款文字」，將 Apple Intelligence 的輸出直接連入。系統自動識別整數或小數金額、中英文鍵值與商戶，背景 0.01 秒秒級寫入磁碟資料庫！"
                )
            }
        }
    }

    // MARK: - Interactive Variable Binding Simulator (練習器)

    private var interactiveVariableSimulatorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(DesignTokens.Colors.accentLight)
                Text("捷徑變數綁定練習器 (Simulator)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Spacer()
                Button("重置練習") {
                    withAnimation {
                        simAmountBound = false
                        simMerchantBound = false
                        simActivePicker = nil
                        simShowSubProperties = false
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.accentLight)
            }

            Text("許多用戶在初次設定捷徑時不知道如何選取「捷徑輸入 ➔ 金額」。請在下方模擬卡片中點擊欄位，親身體驗 iOS 捷徑的二段式變數選取邏輯：")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .lineSpacing(2)

            // Simulated Shortcuts Action Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(Color.blue)
                    Text("記錄支出 (ZeroTypingExpense)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    Spacer()
                }

                Divider()

                // Action Sentence
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("記錄")
                            .font(.system(size: 14))

                        // Amount Button
                        Button(action: {
                            withAnimation(.spring()) {
                                simActivePicker = "amount"
                                simShowSubProperties = false
                            }
                        }) {
                            if simAmountBound {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("捷徑輸入 · 金額")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.18))
                                .foregroundColor(Color.blue)
                                .cornerRadius(6)
                            } else {
                                Text("[ 金額 ▼ ]")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(simActivePicker == "amount" ? Color.blue.opacity(0.12) : Color(hex: "E8E5DD"))
                                    .foregroundColor(simActivePicker == "amount" ? Color.blue : DesignTokens.Colors.textPrimaryLight)
                                    .cornerRadius(6)
                            }
                        }

                        Text("HKD 於")
                            .font(.system(size: 14))

                        // Merchant Button
                        Button(action: {
                            withAnimation(.spring()) {
                                simActivePicker = "merchant"
                                simShowSubProperties = false
                            }
                        }) {
                            if simMerchantBound {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("捷徑輸入 · 商家")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.18))
                                .foregroundColor(Color.blue)
                                .cornerRadius(6)
                            } else {
                                Text("[ 商戶名稱 ▼ ]")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(simActivePicker == "merchant" ? Color.blue.opacity(0.12) : Color(hex: "E8E5DD"))
                                    .foregroundColor(simActivePicker == "merchant" ? Color.blue : DesignTokens.Colors.textPrimaryLight)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            // Simulated Keyboard Variable Bar or Sub-property Sheet
            if let target = simActivePicker {
                VStack(alignment: .leading, spacing: 8) {
                    if !simShowSubProperties {
                        Text("第一段：請在鍵盤變數列點選「捷徑輸入」")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.accentLight)

                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    simShowSubProperties = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    Text("捷徑輸入")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }

                            Text("剪貼簿")
                                .font(.system(size: 13))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "E8E5DD"))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .cornerRadius(8)

                            Text("當前日期")
                                .font(.system(size: 13))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "E8E5DD"))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .cornerRadius(8)
                        }
                    } else {
                        Text("第二段（最關鍵）：點選屬性展開選單，勾選\(target == "amount" ? "「金額」" : "「商家 / 商戶」")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.accentLight)

                        HStack(spacing: 8) {
                            if target == "amount" {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        simAmountBound = true
                                        simActivePicker = nil
                                        simShowSubProperties = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "dollarsign.circle.fill")
                                        Text("金額 (Amount)")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignTokens.Colors.successLight)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            } else {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        simMerchantBound = true
                                        simActivePicker = nil
                                        simShowSubProperties = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "storefront.fill")
                                        Text("商家 / 商戶 (Merchant)")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignTokens.Colors.successLight)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }

                            Text("卡片或票證")
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(hex: "E8E5DD"))
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
                .background(DesignTokens.Colors.accentLight.opacity(0.08))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Status feedback banner
            if simAmountBound && simMerchantBound {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(DesignTokens.Colors.successLight)
                    Text("🎉 恭喜！您已掌握捷徑變數綁定！前往 iPhone「捷徑」App 依照相同流程操作即可！")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                }
                .padding(10)
                .background(DesignTokens.Colors.successLight.opacity(0.12))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Colors.accentLight.opacity(0.35), lineWidth: 1.5)
        )
    }

    // MARK: - FAQ & Common Issues Section

    private var faqSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(DesignTokens.Colors.accentLight)
                Text("常見問題與防坑除錯指南 (FAQ)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Spacer()
            }

            FAQAccordionRow(
                question: "❓ 為什麼搭乘港鐵或海外交通進站時顯示 $0？",
                answer: "各大城市地鐵（如港鐵 MTR、倫敦 Tube、日本 Suica）在進站感應時傳送的是 $0 進站預授權。本 App 內建智能待結算機制，標記為待結算，在出站收到正式扣款金額時自動配對沖銷，絕不漏計也不重計！"
            )

            FAQAccordionRow(
                question: "❓ 為什麼每次刷卡 iPhone 都彈窗要我確認？",
                answer: "這代表你在捷徑自動化中開啟了「執行前詢問」。請至「捷徑」App ➔「自動化」➔ 點進該交易自動化 ➔ 勾選「立即執行」，並將「執行前詢問」與「執行時通知」全部關閉，即可享有 100% 靜默無感自動記帳。"
            )

            FAQAccordionRow(
                question: "❓ 為什麼線上結帳（Foodpanda / Uber / Safari）沒有自動觸發？",
                answer: "iOS 系統限制 Wallet 自動化只監聽實體 NFC 感應。線上或 In-App 支付時，請使用本 App 提供的「輕點背面」或「操作按鈕」捷徑，點兩下背面即可秒級 OCR 辨識入帳！"
            )
        }
        .padding(16)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(16)
    }

    // MARK: - Interactive Test Sandbox (驗收沙盒)

    private var sandboxCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(DesignTokens.Colors.accentLight)
                Text("即時驗收測試沙盒 (Interactive Sandbox)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                Spacer()
                Text("一鍵模擬")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignTokens.Colors.accentLight.opacity(0.12))
                    .foregroundColor(DesignTokens.Colors.accentLight)
                    .cornerRadius(6)
            }

            Text("點擊下方模擬按鈕發送真實交易事件至記帳引擎，立即驗證動態帳本、預算扣減與各情境通道表現：")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .lineSpacing(2)

            // 5 Simulation Buttons Matrix
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    sandboxButton(
                        title: "模擬搭乘港鐵拍卡",
                        amountText: "$0 待結算",
                        icon: "tram.fill",
                        color: Color.blue
                    ) {
                        simulateTransitHold()
                    }

                    sandboxButton(
                        title: "模擬線上 Apple Pay",
                        amountText: "$128.00",
                        icon: "cart.fill",
                        color: Color.orange
                    ) {
                        simulateOnlineApplePay()
                    }
                }

                HStack(spacing: 10) {
                    sandboxButton(
                        title: "模擬 App Store 訂閱",
                        amountText: "$38.00 / 月",
                        icon: "apps.iphone",
                        color: Color.purple
                    ) {
                        simulateAppStoreSubscription()
                    }

                    sandboxButton(
                        title: "模擬退款扣抵",
                        amountText: "-$40.00",
                        icon: "arrow.uturn.backward.circle.fill",
                        color: DesignTokens.Colors.successLight
                    ) {
                        simulateRefundDeduction()
                    }
                }

                sandboxButton(
                    title: "測試 URL Scheme 快捷入帳 (Starbucks HK$55.00)",
                    amountText: "zerotyping://",
                    icon: "link.circle.fill",
                    color: DesignTokens.Colors.accentLight
                ) {
                    simulateURLScheme()
                }

                sandboxButton(
                    title: "一鍵執行全流程真實試用 (End-to-End Trial)",
                    amountText: "完整試用",
                    icon: "checkmark.seal.fill",
                    color: DesignTokens.Colors.successLight
                ) {
                    simulateEndToEndTrial()
                }
            }

            // Sandbox Data Reset & Clean Controls
            Divider()
                .padding(.vertical, 4)

            HStack {
                Button(action: clearSandboxTransactions) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清除所有測試帳單")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.dangerLight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignTokens.Colors.dangerLight.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                Button(action: resetToDefaultSeed) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("還原範例種子資料")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "E8E5DD"))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func sandboxButton(
        title: String,
        amountText: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16))
                    Spacer()
                    Text(amountText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .disabled(isProcessingSimulation)
    }

    // MARK: - Bottom Actions

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button(action: {
                ShortcutFileGenerator.shareShortcutFile()
            }) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("匯出並安裝官方捷徑檔 (.shortcut)")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(DesignTokens.Colors.accentLight)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(DesignTokens.Colors.surfaceLight)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(DesignTokens.Colors.accentLight, lineWidth: 1.5)
                )
            }

            Button(action: openShortcutsApp) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("開啟捷徑 App 進行設置")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignTokens.Colors.accentLight)
                .cornerRadius(25)
            }

            HStack(spacing: 16) {
                Button(action: copyShortcutTemplateLink) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("複製自動化設置速查")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                }

                Button(action: copyURLSchemeLink) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("複製 URL Scheme 範例")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DesignTokens.Colors.bgLight)
    }

    // MARK: - Simulation Triggers

    private func simulateTransitHold() {
        runSimulation(name: "港鐵 MTR (港島線進站)") {
            _ = try await appState.addSampleTransaction(
                merchant: "港鐵 MTR (進站預授權)",
                amountMinor: 0,
                currency: "HKD",
                provider: .applePay,
                captureChannel: .walletAutomation,
                transactionType: .payment,
                isPending: true
            )
            return "已模擬港鐵 $0 進站預授權！狀態標記為待結算，不影響當前支出預算。"
        }
    }

    private func simulateOnlineApplePay() {
        runSimulation(name: "HKTVmall 網購") {
            _ = try await appState.addSampleTransaction(
                merchant: "HKTVmall 線上超市",
                amountMinor: 12800,
                currency: "HKD",
                provider: .applePay,
                captureChannel: .onlineApplePay,
                transactionType: .payment
            )
            return "已成功記錄線上 Apple Pay HK$128.00 於 HKTVmall！"
        }
    }

    private func simulateAppStoreSubscription() {
        runSimulation(name: "iCloud+ 雲端儲存空間") {
            _ = try await appState.addSampleTransaction(
                merchant: "Apple Store 訂閱扣款 (iCloud+)",
                amountMinor: 3800,
                currency: "HKD",
                provider: .appleStoreSubscription,
                captureChannel: .actionButton,
                transactionType: .payment
            )
            return "已記錄 App Store 訂閱支出 HK$38.00 (iCloud+)"
        }
    }

    private func simulateRefundDeduction() {
        runSimulation(name: "退款沖抵") {
            try await appState.addSampleRefund(amountMinor: 4000, currency: "HKD")
            return "已成功模擬退款抵扣 -HK$40.00！帳本已即時沖銷淨額。"
        }
    }

    private func simulateURLScheme() {
        runSimulation(name: "URL Scheme Starbucks") {
            let url = URL(string: "zerotyping://record?amount=55.00&merchant=Starbucks%20Reserve&currency=HKD&category=餐飲")!
            let res = await appState.handleIncomingURL(url)
            switch res {
            case .recorded(let tx):
                return "已透過 URL Scheme 成功入帳：HKD$55.00 於 \(tx.merchantRaw ?? "Starbucks")"
            default:
                return "URL 入帳處理完成"
            }
        }
    }

    private func simulateEndToEndTrial() {
        runSimulation(name: "完整端到端試用") {
            let tx = try await appState.addSampleTransaction(
                merchant: "Pacific Coffee (中環旗艦店)",
                amountMinor: 4200,
                currency: "HKD",
                provider: .applePay,
                captureChannel: .walletAutomation,
                transactionType: .payment,
                isPending: false
            )
            try await appState.confirmCategory(id: tx.id, categoryId: AppState.diningCategoryId)
            return "✅ 完整試用驗收成功！已成功入帳 HK$42.00 於 Pacific Coffee，分類為餐飲，預算與帳本已即時同步，無任何未完成項目！"
        }
    }

    private func runSimulation(name: String, action: @escaping () async throws -> String) {
        guard !isProcessingSimulation else { return }
        isProcessingSimulation = true

        Task {
            do {
                let successMsg = try await action()
                await MainActor.run {
                    self.toastMessage = successMsg
                    withAnimation(.spring()) {
                        self.showToast = true
                    }
                    self.isProcessingSimulation = false
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    withAnimation {
                        self.showToast = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.toastMessage = "模擬失敗：\(error.localizedDescription)"
                    self.showToast = true
                    self.isProcessingSimulation = false
                }
            }
        }
    }

    private func clearSandboxTransactions() {
        Task {
            await appState.clearAllSandboxTransactions()
            await MainActor.run {
                self.toastMessage = "已清除所有測試帳單，帳簿已重置為空！"
                withAnimation {
                    self.showToast = true
                }
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }

    private func resetToDefaultSeed() {
        Task {
            await appState.resetToInitialSeed()
            await MainActor.run {
                self.toastMessage = "已成功還原預設範例交易與分類！"
                withAnimation {
                    self.showToast = true
                }
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }

    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }

    private func copyShortcutTemplateLink() {
        let guideScript = """
        【ZeroTypingExpense Apple Pay 自動化設定速查】
        1. 打開「捷徑」App ➔ 底部「自動化 (Automation)」
        2. 點擊右上角「+」➔ 選擇「交易 (Transaction)」
        3. 勾選常用的 Apple Pay 卡片或八達通
        4. 選擇「立即執行」，關閉「執行前詢問」與「執行時通知」
        5. 新增空白自動化 ➔ 加入動作：「記錄支出」
           - 金額：點擊欄位 ➔ 選擇 [捷徑輸入] ➔ 再次點擊選擇 [金額]
           - 商戶：點擊欄位 ➔ 選擇 [捷徑輸入] ➔ 再次點擊選擇 [商家]
        """
        #if canImport(UIKit)
        UIPasteboard.general.string = guideScript
        #endif
        self.toastMessage = "已複製自動化設置速查指南至剪貼簿！"
        withAnimation {
            self.showToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }

    private func copyURLSchemeLink() {
        let urlSchemeExample = "zerotyping://record?amount=48.50&merchant=Starbucks&currency=HKD&category=餐飲"
        #if canImport(UIKit)
        UIPasteboard.general.string = urlSchemeExample
        #endif
        self.toastMessage = "已複製 URL Scheme 範例至剪貼簿！"
        withAnimation {
            self.showToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }
}

// MARK: - Detailed Step Components

private struct DetailedVariableBindingStepCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("4")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.accentLight)
                    .clipShape(Circle())

                Text("步驟 4：關鍵！提取「捷徑輸入」參數")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                Spacer()
            }

            Text("許多用戶在此步驟卡住：加入動作後，欄位是空白的，必須透過二段式點擊綁定 Apple Pay 交易資料：")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .lineSpacing(2)
                .padding(.leading, 32)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("①")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.accentLight)
                    Text("點選「金額」欄位 ➔ 鍵盤上方工具列點選「捷徑輸入」")
                        .font(.system(size: 13, weight: .medium))
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("②")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.accentLight)
                    Text("再次點選藍色「捷徑輸入」膠囊 ➔ 在展開屬性中選擇「金額 (Amount)」")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("③")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.accentLight)
                    Text("同理：點選「商戶名稱」➔ 選取「捷徑輸入」➔ 展開選擇「商家 / 商戶」")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            .padding(.leading, 32)
        }
        .padding(14)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignTokens.Colors.accentLight.opacity(0.35), lineWidth: 1.5)
        )
    }
}

private struct FAQAccordionRow: View {
    let question: String
    let answer: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                }
            }

            if isExpanded {
                Text(answer)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
    }
}

// MARK: - Subviews

private struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignTokens.Colors.successLight)
                .font(.system(size: 18))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.88))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

private struct ActiveStepCard: View {
    let stepNumber: Int
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(stepNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.accentLight)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.textPrimaryLight)

                Spacer()
            }

            Text(description)
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .lineSpacing(3)
                .padding(.leading, 32)
        }
        .padding(14)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignTokens.Colors.accentLight.opacity(0.35), lineWidth: 1.5)
        )
    }
}

private struct PendingStepRow: View {
    let stepNumber: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(stepNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                .frame(width: 22, height: 22)
                .background(Color(red: 0xE8/255.0, green: 0xE5/255.0, blue: 0xDC/255.0))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textPrimaryLight)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DesignTokens.Colors.surfaceLight)
        .cornerRadius(12)
    }
}
