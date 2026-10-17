import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 今日命令中心 (DashboardView)
public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]
    
    @State private var decision: DailyDecision?
    @State private var isShowingQuickLog: Bool = false
    @State private var isShowingAlternates: Bool = false
    @State private var isShowingAudit: Bool = false
    @State private var scheduleStatusMessage: String?
    
    private let healthKitAdapter: HealthKitAdapter
    private let workoutKitAdapter: WorkoutKitAdapter
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter(), workoutKitAdapter: WorkoutKitAdapter = WorkoutKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
        self.workoutKitAdapter = workoutKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 頂部狀態藥丸
                        if let decision = decision {
                            StatusCapsuleView(decision: decision)
                        } else {
                            ProgressView()
                                .tint(Color(hex: "58A6FF"))
                                .padding(.vertical, 8)
                        }
                        
                        // 2. 今日推薦主卡片 (支援自由選用跑步/阻力/交叉方案)
                        if let decision = decision {
                            DailyHeroCardView(
                                workout: decision.primaryRecommendation,
                                runningOption: decision.todayRunningOption,
                                strengthOption: decision.todayStrengthOption,
                                crossOption: decision.todayCrossTrainingOption,
                                isLockedDueToFatigue: decision.primaryRecommendation.isLockedDueToFatigue,
                                onScheduleToWatch: { selectedWorkout in
                                    scheduleWorkout(selectedWorkout)
                                },
                                onSelectAlternates: {
                                    isShowingAlternates = true
                                }
                            )
                        }
                        
                        // 3. 4 大動作模式冷卻時鐘
                        if let decision = decision {
                            MuscleCooldownCardView(cooldowns: decision.cooldowns)
                        }
                        
                        // 4. 排程狀態提示
                        if let message = scheduleStatusMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "3FB950"))
                                Text(message)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hex: "161B22"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80) // 預留底部按鈕高度
                }
                
                // 5. 底部常駐 15 秒打卡操作鈕
                VStack {
                    Spacer()
                    Button {
                        isShowingQuickLog = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("記錄今日訓練 (15 秒快速打卡)")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "3FB950"))
                        .foregroundColor(Color(hex: "090C10"))
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "3FB950").opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Hybrid Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentDateString)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "8B949E"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAudit = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope")
                            Text("探針與回放")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "58A6FF"))
                    }
                }
            }
            .sheet(isPresented: $isShowingQuickLog) {
                QuickLogSheet {
                    refreshDailyDecision()
                }
            }
            .sheet(isPresented: $isShowingAudit) {
                SpikeAuditView(healthKitAdapter: healthKitAdapter)
            }
            .sheet(isPresented: $isShowingAlternates) {
                alternatesSheet
            }
            .task {
                refreshDailyDecision()
            }
        }
    }
    
    // MARK: - 換課備選視圖
    private var alternatesSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        Text("運動學互補安全備選")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8B949E"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let decision = decision, !decision.safeAlternates.isEmpty {
                            ForEach(decision.safeAlternates) { alt in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(alt.title)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(alt.estimatedDurationMinutes))m · \(Int(alt.estimatedLoadAU)) AU")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "58A6FF"))
                                    }
                                    Text(alt.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "8B949E"))
                                    
                                    Button {
                                        scheduleWorkout(alt)
                                        isShowingAlternates = false
                                    } label: {
                                        Text("選用並推播至手錶")
                                            .font(.system(size: 12, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(hex: "21262D"))
                                            .foregroundColor(Color(hex: "58A6FF"))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(14)
                                .background(Color(hex: "161B22"))
                                .cornerRadius(10)
                            }
                        } else {
                            Text("目前無其他安全備選課表")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("換課選單")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 業務邏輯觸發
    private func refreshDailyDecision() {
        Task {
            let calendar = Calendar.current
            let now = Date()
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            
            // 1. 抓取 HealthKit Workouts
            let hkWorkouts = (try? await healthKitAdapter.fetchWorkouts(from: sixtyDaysAgo, to: now)) ?? []
            
            // 2. 轉換本機 SwiftData sessions
            let localSessions = storedSessions.map { $0.toDomain() }
            
            // 3. 執行 SmartMerge 智慧合併
            let mergedSessions = SmartMergeEngine.processAndDeduplicate(sessions: hkWorkouts + localSessions)
            
            // 4. 取得當日晨間生理快照
            let snapshot = (try? await healthKitAdapter.fetchPhysiologicalSnapshot(date: now)) ?? PhysiologicalSnapshot(sleepDurationHours: 7.5)
            
            // 5. 執行政策仲裁引擎
            let evaluatedDecision = TrainingPolicyEngine.evaluateDailyDecision(
                history: mergedSessions,
                snapshot: snapshot,
                now: now,
                calendar: calendar,
                configuration: .default
            )
            
            await MainActor.run {
                self.decision = evaluatedDecision
            }
        }
    }
    
    private func scheduleWorkout(_ workout: RecommendedWorkout) {
        Task {
            let result = try? await workoutKitAdapter.scheduleWorkout(workout: workout, at: Date())
            await MainActor.run {
                switch result {
                case .scheduled:
                    self.scheduleStatusMessage = "課表「\(workout.title)」已推播至 Apple Watch！"
                case .pendingSync:
                    self.scheduleStatusMessage = "課表已就緒，等待手錶藍牙同步。"
                case .failed(let reason):
                    self.scheduleStatusMessage = "推播失敗: \(reason)"
                case .none:
                    self.scheduleStatusMessage = "已將課表排程至今日清單。"
                }
            }
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter.string(from: Date())
    }
}
