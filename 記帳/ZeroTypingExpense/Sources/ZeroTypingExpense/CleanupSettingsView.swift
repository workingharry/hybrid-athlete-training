import SwiftUI

/// Screen S09: Weekly Screenshot Cleanup Settings
/// User configuration for PhotoKit screenshot cleanup:
/// - Auto cleanup toggle
/// - Schedule: Every Sunday 20:00
/// - Retention period: 7 days / 14 days / 30 days
/// - Scope: All recognized screenshots vs. Only confirmed transactions
/// - Trigger manual cleanup button
public struct CleanupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cleanup_auto_enabled") private var autoCleanupEnabled: Bool = true
    @AppStorage("cleanup_retention_days") private var retentionDays: Int = 7
    @AppStorage("cleanup_only_confirmed") private var onlyConfirmed: Bool = true
    @State private var showingPreviewSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("定期自動清理")) {
                    Toggle("啟用每週截圖清理提醒", isOn: $autoCleanupEnabled)
                        .tint(DesignTokens.Colors.accentLight)

                    if autoCleanupEnabled {
                        HStack {
                            Text("提醒排程")
                                .foregroundColor(DesignTokens.Colors.textPrimaryLight)
                            Spacer()
                            Text("每週日 20:00")
                                .foregroundColor(DesignTokens.Colors.textSecondaryLight)
                        }
                    }
                }

                Section(header: Text("保留天數門檻"), footer: Text("超過所選天數且已成功入帳的截圖才會列入清理清單。")) {
                    Picker("保留天數", selection: $retentionDays) {
                        Text("7 天 (推薦)").tag(7)
                        Text("14 天").tag(14)
                        Text("30 天").tag(30)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("清理範圍"), footer: Text("為保護財務資料完整性，強烈建議只清理已確認無誤的交易截圖。")) {
                    Toggle("只清理已確認的交易", isOn: $onlyConfirmed)
                        .tint(DesignTokens.Colors.accentLight)
                }

                Section {
                    Button(action: { showingPreviewSheet = true }) {
                        HStack {
                            Spacer()
                            Text("立即檢查可清理的截圖")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.accentLight)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("截圖清理設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.accentLight)
                }
            }
            .sheet(isPresented: $showingPreviewSheet) {
                CleanupPreviewView()
            }
        }
    }
}
