import SwiftUI
import HybridTrainingCore

/// Apple 原生極簡風格：我的週課表與衝衝突軟性建議 (WeeklyScheduleView)
public struct WeeklyScheduleView: View {
    @State private var focusMode: Int = 1 // 0: 增肌優先, 1: 平衡, 2: 跑步優先
    @State private var plan: WeeklySchedulePlan = WeeklyScheduleEngine.schedule(for: .balanced)
    @State private var isSoftSuggestionDismissed: Bool = false
    @State private var isShowingRoutineLibrary: Bool = false

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
                        Picker("訓練側重", selection: Binding(
                            get: { focusMode },
                            set: { newValue in
                                focusMode = newValue
                                if let pref = WeeklyFocusPreference(rawValue: newValue) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        plan = WeeklyScheduleEngine.schedule(for: pref)
                                        isSoftSuggestionDismissed = false
                                    }
                                }
                            }
                        )) {
                            ForEach(WeeklyFocusPreference.allCases, id: \.rawValue) { pref in
                                Text(pref.displayName).tag(pref.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)

                        // 3. 週一至週日課表清單
                        VStack(spacing: 8) {
                            ForEach(plan.items.indices, id: \.self) { idx in
                                scheduleRow(index: idx)
                            }
                        }

                        // 4. 運動學衝突軟性建議橫幅
                        if !isSoftSuggestionDismissed, let suggestion = plan.softClashSuggestion {
                            clashSuggestionCard(suggestion)
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
        let item = plan.items[index]
        return HStack(spacing: 12) {
            // 星期
            Text(item.dayOfWeek)
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
            Text(item.category.rawValue)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(10)
    }

    private func clashSuggestionCard(_ suggestion: SoftClashSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(suggestion.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "FF9F0A"))
                Spacer()
                Text(suggestion.badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Text(suggestion.explanation)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "E5E5EA"))
                .lineSpacing(4)

            HStack(spacing: 8) {
                Button {
                    // 縮短長跑時長
                    if let satIdx = plan.items.firstIndex(where: { $0.dayOfWeek == "六" }) {
                        plan.items[satIdx].title = "長跑 70 分鐘 · 降載"
                        plan.items[satIdx].hasWarning = false
                    }
                    isSoftSuggestionDismissed = true
                } label: {
                    Text(suggestion.optionShortenTitle)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(hex: "0A84FF"))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }

                Button {
                    // 移至週日
                    if let satIdx = plan.items.firstIndex(where: { $0.dayOfWeek == "六" }),
                       let sunIdx = plan.items.firstIndex(where: { $0.dayOfWeek == "日" }) {
                        let originalTitle = plan.items[satIdx].title
                        let originalDiscipline = plan.items[satIdx].discipline
                        plan.items[satIdx].title = "完全休息"
                        plan.items[satIdx].category = .recovery
                        plan.items[satIdx].discipline = .rest
                        plan.items[satIdx].tag = "恢復"
                        plan.items[satIdx].hasWarning = false

                        plan.items[sunIdx].title = originalTitle
                        plan.items[sunIdx].category = .running
                        plan.items[sunIdx].discipline = originalDiscipline
                        plan.items[sunIdx].tag = "跑步"
                    }
                    isSoftSuggestionDismissed = true
                } label: {
                    Text(suggestion.optionMoveTitle)
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
