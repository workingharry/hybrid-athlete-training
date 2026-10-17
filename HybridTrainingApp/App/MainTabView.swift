import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Version 2.0: 混合運動員全功能主導覽視圖 (MainTabView)
public struct MainTabView: View {
    private let healthKitAdapter = HealthKitAdapter()
    private let workoutKitAdapter = WorkoutKitAdapter()
    
    @State private var selectedTab: Int = 0
    
    public init() {
        // 設定深色風格 TabBar 外觀
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "0D1117"))
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(healthKitAdapter: healthKitAdapter, workoutKitAdapter: workoutKitAdapter)
                .tabItem {
                    Label("今日排課", systemImage: "flame.fill")
                }
                .tag(0)
            
            AnalyticsView(healthKitAdapter: healthKitAdapter)
                .tabItem {
                    Label("生理趨勢", systemImage: "chart.xyaxis.line")
                }
                .tag(1)
            
            LogbookView(healthKitAdapter: healthKitAdapter)
                .tabItem {
                    Label("訓練日誌", systemImage: "list.bullet.rectangle")
                }
                .tag(2)
            
            SettingsView(healthKitAdapter: healthKitAdapter)
                .tabItem {
                    Label("運動員配置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(Color(hex: "58A6FF"))
    }
}
