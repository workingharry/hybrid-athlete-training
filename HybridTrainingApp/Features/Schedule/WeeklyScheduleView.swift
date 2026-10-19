import SwiftUI
import HybridTrainingCore

/// Apple 原生極簡風格：我的週課表與衝衝突軟性建議 (WeeklyScheduleView)
public struct WeeklyScheduleView: View {
    @State private var focusMode: Int = 1 // 0: 增肌優先, 1: 平衡, 2: 跑步優先
    @State private var isSoftSuggestionDismissed: Bool = false
    @State private var isShowingRoutineLibrary: Bool = false

    // 一週排程項目
    @State private var weeklyDays: [(day: String, title: String, tag: String, category: String, hasWarning: Bool)] = [
        ("一", "推：胸、肩、三頭", "力量", "力量", false),
        ("二", "輕鬆跑 40 分鐘 · Zone 2", "跑步", "跑步", false),
        ("三", "拉：背、二頭", "力量", "力量", false),
        ("四", "完全休息 · 活動度伸展", "恢復", "恢復", false),
        ("五", "腿：深蹲、硬舉", "力量", "力量", false),
        ("六", "長跑 90 分鐘", "需留意", "跑步", true),
        ("日", "完全休息", "恢復", "恢復", false)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 日期區間
                        Text(currentWeekRangeString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "8E8E93"))

                        // 2. 側重分段選擇器 (增肌優先 / 平衡 / 跑步優先)
                        Picker("訓練側重", selection: $focusMode) {
                            Text("增肌優先").tag(0)
                            Text("平衡").tag(1)
                            Text("跑步優先").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)

                        // 3. 週一至週日課表清單
                        VStack(spacing: 8) {
                            ForEach(weeklyDays.indices, id: \.self) { idx in
                                scheduleRow(index: idx)
                            }
                        }

                        // 4. 運動學衝突軟性建議橫幅 (Screenshot 2)
                        if !isSoftSuggestionDismissed {
                            clashSuggestionCard
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("我的週課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingRoutineLibrary = true
                    } label: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(hex: "0A84FF"))
                    }
                }
            }
            .sheet(isPresented: $isShowingRoutineLibrary) {
                RoutineLibrarySheet()
            }
        }
    }

    private func scheduleRow(index: Int) -> some View {
        let item = weeklyDays[index]
        return HStack(spacing: 12) {
            // 星期
            Text(item.day)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, alignment: .leading)

            // 課表內容
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // 需留意標籤
            if item.hasWarning {
                Text(item.tag)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "FF9F0A").opacity(0.2))
                    .foregroundColor(Color(hex: "FF9F0A"))
                    .cornerRadius(4)
            }

            // 類別標籤 (力量 / 跑步 / 恢復)
            Text(item.category)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(10)
    }

    private var clashSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("週六長跑與週五腿日太近")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "FF9F0A"))
                Spacer()
                Text("軟性建議")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Text("相隔不足 24 小時，長跑屬高腿部負荷。你可以縮短、改日，或直接維持原計劃，引擎會記住你的選擇。")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "E5E5EA"))
                .lineSpacing(4)

            HStack(spacing: 8) {
                Button {
                    weeklyDays[5].title = "長跑 70 分鐘 · 降載"
                    weeklyDays[5].hasWarning = false
                    isSoftSuggestionDismissed = true
                } label: {
                    Text("縮短為 70 分鐘")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(hex: "0A84FF"))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }

                Button {
                    let run = weeklyDays[5].title
                    weeklyDays[5].title = "完全休息"
                    weeklyDays[5].category = "恢復"
                    weeklyDays[5].hasWarning = false
                    weeklyDays[6].title = run
                    weeklyDays[6].category = "跑步"
                    isSoftSuggestionDismissed = true
                } label: {
                    Text("移到週日")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(hex: "2C2C2E"))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                Spacer()

                Button {
                    isSoftSuggestionDismissed = true
                } label: {
                    Text("維持")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FF9F0A").opacity(0.3), lineWidth: 1)
        )
    }

    private var currentWeekRangeString: String {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: endOfWeek))"
    }
}
