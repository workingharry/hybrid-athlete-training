import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Apple 原生極簡風格：訓練主頁與動作選擇器 (WorkoutSessionRunnerView)
public struct WorkoutSessionRunnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]

    @State private var selectedExercise: ResistanceExercise? = nil
    @State private var searchKeyword: String = ""
    @State private var selectedPattern: MovementPattern? = nil
    @State private var loggedDetailsInCurrentWorkout: [ExecutedExerciseDetail] = []
    @State private var isShowingSaveWorkoutAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 本次訓練累積成果卡片
                        if !loggedDetailsInCurrentWorkout.isEmpty {
                            activeWorkoutBanner
                        }

                        // 2. 4 大動作模式快速篩選膠囊
                        patternFilterBar

                        // 3. 動作清單 (點擊進入逐組打卡)
                        exerciseListSection
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("今日訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !loggedDetailsInCurrentWorkout.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("儲存整場") {
                            saveCurrentWorkoutSession()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "30D158"))
                    }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                SetBySetLoggingView(
                    exercise: exercise,
                    nextExercise: findNextExercise(after: exercise)
                ) { detail in
                    loggedDetailsInCurrentWorkout.append(detail)
                }
            }
        }
    }

    private var activeWorkoutBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Color(hex: "0A84FF"))
                Text("本次訓練已記錄 \(loggedDetailsInCurrentWorkout.count) 個動作")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalCompletedSetsInWorkout) 組")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "30D158"))
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(loggedDetailsInCurrentWorkout) { d in
                    HStack {
                        Circle()
                            .fill(Color(hex: "30D158"))
                            .frame(width: 4, height: 4)
                        Text(d.exerciseName)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "E5E5EA"))
                        Spacer()
                        Text("\(d.completedSetsCount) 組 · 總重 \(Int(d.totalVolumeLoadKg)) kg")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }
            }
            .padding(10)
            .background(Color(hex: "2C2C2E"))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "0A84FF").opacity(0.3), lineWidth: 1)
        )
    }

    private var patternFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                patternFilterChip(title: "全部動作", pattern: nil)
                patternFilterChip(title: "上肢推", pattern: .upperPush)
                patternFilterChip(title: "上肢拉", pattern: .upperPull)
                patternFilterChip(title: "前側鏈/蹲", pattern: .lowerQuad)
                patternFilterChip(title: "後側鏈/鉸鏈", pattern: .lowerPosterior)
            }
        }
    }

    private func patternFilterChip(title: String, pattern: MovementPattern?) -> some View {
        let isSelected = selectedPattern == pattern
        return Button {
            selectedPattern = pattern
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color(hex: "0A84FF") : Color(hex: "1C1C1E"))
                .foregroundColor(isSelected ? .white : Color(hex: "8E8E93"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: "0A84FF") : Color(hex: "2C2C2E"), lineWidth: 1)
                )
        }
    }

    private var exerciseListSection: some View {
        VStack(spacing: 10) {
            ForEach(filteredExercises) { ex in
                Button {
                    selectedExercise = ex
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 6) {
                                Text(ex.equipment.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "2C2C2E"))
                                    .foregroundColor(Color(hex: "0A84FF"))
                                    .cornerRadius(4)

                                Text(ex.defaultRepRange)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .padding(14)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredExercises: [ResistanceExercise] {
        ResistanceExerciseBank.allExercises.filter { ex in
            if let pat = selectedPattern, ex.pattern != pat { return false }
            return true
        }
    }

    private var totalCompletedSetsInWorkout: Int {
        loggedDetailsInCurrentWorkout.reduce(0) { $0 + $1.completedSetsCount }
    }

    private func findNextExercise(after current: ResistanceExercise) -> ResistanceExercise? {
        guard let idx = ResistanceExerciseBank.allExercises.firstIndex(where: { $0.id == current.id }),
              idx + 1 < ResistanceExerciseBank.allExercises.count else {
            return nil
        }
        return ResistanceExerciseBank.allExercises[idx + 1]
    }

    private func saveCurrentWorkoutSession() {
        guard !loggedDetailsInCurrentWorkout.isEmpty else { return }
        let now = Date()
        let totalDuration = Double(loggedDetailsInCurrentWorkout.count * 12) // 約每動 12 分鐘
        let patterns = Array(Set(loggedDetailsInCurrentWorkout.map(\.pattern)))

        let session = WorkoutSession(
            startDate: now.addingTimeInterval(-totalDuration * 60.0),
            endDate: now,
            discipline: .strength,
            durationMinutes: max(20.0, totalDuration),
            sRPE: 7.5,
            movementPatterns: patterns,
            executedExercises: loggedDetailsInCurrentWorkout,
            source: .manualLog
        )

        let sdSession = SDWorkoutSession(domain: session)
        modelContext.insert(sdSession)
        try? modelContext.save()

        loggedDetailsInCurrentWorkout.removeAll()
    }
}
