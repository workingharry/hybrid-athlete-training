import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Version 2: 訓練歷史與核銷日誌清單 (LogbookView)
public struct LogbookView: View {
    let healthKitAdapter: HealthKitAdapter
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]
    
    @State private var recentWorkouts: [WorkoutSession] = []
    @State private var isLoading: Bool = true
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                if isLoading {
                    ProgressView("讀取訓練歷史紀錄...")
                        .tint(Color(hex: "58A6FF"))
                        .foregroundColor(Color(hex: "8B949E"))
                } else if recentWorkouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "8B949E"))
                        Text("過去 30 天尚無訓練紀錄")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("請透過首頁完成 Apple Watch 訓練或點擊「記錄重量訓練」完成打卡。")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8B949E"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(recentWorkouts) { session in
                            workoutRow(session)
                                .listRowBackground(Color(hex: "161B22"))
                                .listRowSeparatorTint(Color(hex: "30363D"))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("訓練歷史日誌")
            .navigationBarTitleDisplayMode(.inline)
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
                        .foregroundColor(.white)
                }
                Spacer()
                Text(sessionDateString(session.startDate))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8B949E"))
            }
            
            HStack(spacing: 12) {
                Label("\(Int(session.durationMinutes)) 分鐘", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8B949E"))
                
                Label("\(Int(session.loadAU)) AU", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "58A6FF"))
                
                Text("sRPE: \(String(format: "%.1f", session.sRPE))")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "21262D"))
                    .foregroundColor(Color(hex: "3FB950"))
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
                .foregroundColor(Color(hex: "8B949E"))
        case .manualLog:
            Text("手動打卡")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "D29922"))
        case .smartMerged:
            Text("智慧合併")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "3FB950"))
        }
    }
    
    private func sessionTitle(_ session: WorkoutSession) -> String {
        switch session.discipline {
        case .running:
            return "路跑 / 有氧耐力"
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
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .rest: return "bed.double"
        }
    }
    
    private func sessionColor(_ discipline: TrainingDiscipline) -> Color {
        switch discipline {
        case .running: return Color(hex: "58A6FF")
        case .strength: return Color(hex: "F85149")
        case .mobility: return Color(hex: "3FB950")
        case .rest: return Color(hex: "8B949E")
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
