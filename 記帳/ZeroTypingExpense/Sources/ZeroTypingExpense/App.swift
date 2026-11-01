import SwiftUI

@main
public struct ZeroTypingExpenseApp: App {
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            TabView(selection: $appState.selectedTab) {
                DashboardView(appState: appState)
                    .tabItem {
                        Image(systemName: "house")
                        Text("首頁")
                    }
                    .tag(0)

                InsightsView(appState: appState)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("分析")
                    }
                    .tag(1)

                BudgetView(appState: appState)
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text("預算")
                    }
                    .tag(2)

                LedgerView(appState: appState)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("帳本")
                    }
                    .tag(3)
            }
            .tint(DesignTokens.Colors.accentLight)
            .sheet(isPresented: $appState.showingOnboardingFromURL) {
                ApplePayOnboardingView()
            }
            .overlay(alignment: .top) {
                if let msg = appState.urlActionToastMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(DesignTokens.Colors.accentLight)
                        Text(msg)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                appState.urlActionToastMessage = nil
                            }
                        }
                    }
                }
            }
            .task {
                await appState.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: AppState.didIngestTransactionNotification)) { _ in
                Task { await appState.load() }
            }
            .onOpenURL { url in
                Task {
                    _ = await appState.handleIncomingURL(url)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task { await appState.load() }
                }
            }
        }
    }
}
