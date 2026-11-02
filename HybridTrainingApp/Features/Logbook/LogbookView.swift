import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Apple 原生極簡風格：訓練歷史日誌清單 (LogbookView)
public struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    let healthKitAdapter: HealthKitAdapter
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]

    @State private var recentWorkouts: [WorkoutSession] = []
    @State private var isLoading: Bool = true
    @State private var isShowingAddSheet: Bool = false
    @State private var sessionToEdit: SDWorkoutSession? = nil

    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView("讀取訓練歷史紀錄...")
                        .tint(HybridTheme.accentBlue)
                        .foregroundColor(HybridTheme.textSecondary)
                } else if recentWorkouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundColor(HybridTheme.textSecondary)
                        Text("過去 30 天尚無訓練紀錄")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(HybridTheme.textPrimary)
                        Text("點擊右上角「+」手動補錄，或透過「訓練」頁完成逐組打卡。")
                            .font(.system(size: 13))
                            .foregroundColor(HybridTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(recentWorkouts) { session in
                            Button {
                                if let matched = storedSessions.first(where: { $0.id == session.id }) {
                                    sessionToEdit = matched
                                }
                            } label: {
                                workoutRow(session)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if let matched = storedSessions.first(where: { $0.id == session.id }) {
                                    Button(role: .destructive) {
                                        deleteSession(matched)
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowBackground(HybridTheme.cardBackground)
                            .listRowSeparatorTint(HybridTheme.cardBorder)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("訓練歷史日誌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(HybridTheme.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                SessionEditorSheet()
                    .onDisappear {
                        Task { await loadMergedWorkouts() }
                    }
            }
            .sheet(item: $sessionToEdit) { sdSession in
                SessionEditorSheet(sessionToEdit: sdSession)
                    .onDisappear {
                        Task { await loadMergedWorkouts() }
                    }
            }
            .task {
                await loadMergedWorkouts()
            }
            .refreshable {
                await loadMergedWorkouts()
            }
        }
    }

    private func workoutRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: sessionIcon(session.discipline))
                        .foregroundColor(sessionColor(session.discipline))
                    Text(sessionTitle(session))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(HybridTheme.textPrimary)
                }
                Spacer()
                Text(sessionDateString(session.startDate))
                    .font(.system(size: 12))
                    .foregroundColor(HybridTheme.textSecondary)
            }

            if !session.executedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.executedExercises) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(HybridTheme.accentBlue)
                                .frame(width: 4, height: 4)
                            Text(item.summaryDescription)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(HybridTheme.textPrimary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 12) {
                Label("\(Int(session.durationMinutes)) 分鐘", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(HybridTheme.textSecondary)

                Label("\(Int(session.loadAU)) AU", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HybridTheme.accentBlue)

                Text("sRPE: \(String(format: "%.1f", session.sRPE))")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.successGreen)
                    .cornerRadius(4)

                Spacer()

                sourceBadge(session.source)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sourceBadge(_ source: SessionSource) -> some View {
        switch source {
        case .healthKitWorkout:
            Text("Apple Watch")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(HybridTheme.textSecondary)
        case .manualLog:
            Text("手動紀錄")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(HybridTheme.energyOrange)
        case .smartMerged:
            Text("智慧合併")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(HybridTheme.successGreen)
        }
    }

    private func deleteSession(_ session: SDWorkoutSession) {
        modelContext.delete(session)
        try? modelContext.save()
        Task {
            await loadMergedWorkouts()
        }
    }

    private func sessionTitle(_ session: WorkoutSession) -> String {
        switch session.discipline {
        case .running:
            return "路跑 / 有氧耐力"
        case .cycling:
            return "自行車 / 單車巡航"
        case .swimming:
            return "游泳 / 水中有氧"
        case .rowing:
            return "划船機 / 水上划船"
        case .strength:
            let patterns = session.movementPatterns.map { patternName($0) }.joined(separator: " + ")
            return patterns.isEmpty ? "肌力重量訓練" : patterns
        case .mobility:
            return "活動度 / 伸展放鬆"
        case .rest:
            return "完全休息"
        }
    }

    private func patternName(_ p: MovementPattern) -> String {
        switch p {
        case .lowerQuad: return "下肢深蹲"
        case .lowerPosterior: return "下肢硬舉"
        case .upperPush: return "上半身推"
        case .upperPull: return "上半身拉"
        }
    }

    private func sessionIcon(_ discipline: TrainingDiscipline) -> String {
        switch discipline {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .rest: return "bed.double"
        }
    }

    private func sessionColor(_ discipline: TrainingDiscipline) -> Color {
        switch discipline {
        case .running: return HybridTheme.accentBlue
        case .cycling: return HybridTheme.energyOrange
        case .swimming: return HybridTheme.healthTeal
        case .rowing: return HybridTheme.activityPurple
        case .strength: return HybridTheme.dangerRed
        case .mobility: return HybridTheme.successGreen
        case .rest: return HybridTheme.textSecondary
        }
    }

    private func sessionDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func loadMergedWorkouts() async {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let hkWorkouts = (try? await healthKitAdapter.fetchWorkouts(from: thirtyDaysAgo, to: now)) ?? []
        let localWorkouts = storedSessions.map { $0.toDomain() }
        let merged = SmartMergeEngine.processAndDeduplicate(sessions: hkWorkouts + localWorkouts)

        await MainActor.run {
            self.recentWorkouts = merged.sorted(by: { $0.startDate > $1.startDate })
            self.isLoading = false
        }
    }
}
