import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Apple 原生極簡風格主導覽視圖 (MainTabView - 4 大核心標籤)
public struct MainTabView: View {
    private let healthKitAdapter = HealthKitAdapter()
    private let workoutKitAdapter = WorkoutKitAdapter()

    @State private var selectedTab: Int = 0

    public init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.shadowColor = UIColor(Color(hex: "2C2C2E"))

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: 今日排課
            DashboardView(healthKitAdapter: healthKitAdapter, workoutKitAdapter: workoutKitAdapter)
                .tabItem {
                    Label("今日", systemImage: "record.circle.fill")
                }
                .tag(0)

            // Tab 1: 我的週課表
            WeeklyScheduleView()
                .tabItem {
                    Label("課表", systemImage: "calendar")
                }
                .tag(1)

            // Tab 2: 逐組訓練
            WorkoutSessionRunnerView()
                .tabItem {
                    Label("訓練", systemImage: "dumbbell.fill")
                }
                .tag(2)

            // Tab 3: 歷史日誌與趨勢 (支援新增/編輯/刪除)
            LogbookView(healthKitAdapter: healthKitAdapter)
                .tabItem {
                    Label("趨勢", systemImage: "chart.xyaxis.line")
                }
                .tag(3)
        }
        .tint(Color(hex: "0A84FF"))
    }
}
