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
                HybridTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 本次訓練累積成果卡片
                        if !loggedDetailsInCurrentWorkout.isEmpty {
                            activeWorkoutBanner
                        }

                        // 2. 最近常練動作 (1 鍵快速開啟打卡)
                        if !recentExercises.isEmpty {
                            recentExercisesSection
                        }

                        // 3. 經典課表快速排程 (Push / Pull / Legs)
                        routinePresetSection

                        // 4. 4 大動作模式快速篩選膠囊
                        patternFilterBar

                        // 5. 動作清單 (點擊進入逐組打卡)
                        exerciseListSection
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .searchable(text: $searchKeyword, prompt: "搜尋動作 (如: 臥推, 深蹲, 引體, 划船)")
            .navigationTitle("今日訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !loggedDetailsInCurrentWorkout.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("儲存整場") {
                            saveCurrentWorkoutSession()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HybridTheme.successGreen)
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

    // MARK: - 最近常練動作 (Recent Exercises)
    private var recentExercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.accentBlue)
                Text("最近常練動作")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentExercises) { ex in
                        Button {
                            selectedExercise = ex
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(HybridTheme.accentBlue)
                                    Text(ex.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(HybridTheme.textPrimary)
                                        .lineLimit(1)
                                }

                                HStack(spacing: 4) {
                                    Text(ex.equipment.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(HybridTheme.surfaceElevated)
                                        .foregroundColor(HybridTheme.textSecondary)
                                        .cornerRadius(4)

                                    Text(ex.defaultRepRange)
                                        .font(.system(size: 10))
                                        .foregroundColor(HybridTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(HybridTheme.cardBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 經典課表快速載入
    private var routinePresetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HybridTheme.energyOrange)
                Text("快速載入經典課表")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
            }

            HStack(spacing: 8) {
                routinePresetChip(title: "上肢推力量", pattern: .upperPush)
                routinePresetChip(title: "上肢拉力量", pattern: .upperPull)
                routinePresetChip(title: "下肢深蹲日", pattern: .lowerQuad)
            }
        }
    }

    private func routinePresetChip(title: String, pattern: MovementPattern) -> some View {
        Button {
            selectedPattern = pattern
            if let first = ResistanceExerciseBank.allExercises.first(where: { $0.pattern == pattern }) {
                selectedExercise = first
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(HybridTheme.cardBackground)
            .foregroundColor(HybridTheme.textPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private var activeWorkoutBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(HybridTheme.coralPink)
                Text("本次訓練已記錄 \(loggedDetailsInCurrentWorkout.count) 個動作")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HybridTheme.textPrimary)
                Spacer()
                Text("\(totalCompletedSetsInWorkout) 組")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HybridTheme.successGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(loggedDetailsInCurrentWorkout) { d in
                    HStack {
                        Circle()
                            .fill(HybridTheme.successGreen)
                            .frame(width: 5, height: 5)
                        Text(d.exerciseName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(HybridTheme.textPrimary)
                        Spacer()
                        Text("\(d.completedSetsCount) 組 · 總重 \(Int(d.totalVolumeLoadKg)) kg")
                            .font(.system(size: 11))
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(HybridTheme.surfaceElevated)
            .cornerRadius(8)

            Button {
                saveCurrentWorkoutSession()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("儲存整場訓練 (\(loggedDetailsInCurrentWorkout.count) 項動作)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(HybridTheme.successGreen)
                .cornerRadius(8)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
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
                .background(isSelected ? HybridTheme.accentBlue : HybridTheme.cardBackground)
                .foregroundColor(isSelected ? .white : HybridTheme.textSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? HybridTheme.accentBlue : HybridTheme.cardBorder, lineWidth: 1)
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
                                .foregroundColor(HybridTheme.textPrimary)

                            HStack(spacing: 6) {
                                Text(ex.equipment.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(HybridTheme.surfaceElevated)
                                    .foregroundColor(HybridTheme.accentBlue)
                                    .cornerRadius(4)

                                Text(ex.defaultRepRange)
                                    .font(.system(size: 11))
                                    .foregroundColor(HybridTheme.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                    .padding(14)
                    .background(HybridTheme.cardBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(HybridTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentExercises: [ResistanceExercise] {
        var names: [String] = []
        for session in storedSessions {
            for ex in session.toDomain().executedExercises {
                if !names.contains(ex.exerciseName) {
                    names.append(ex.exerciseName)
                }
                if names.count >= 6 { break }
            }
            if names.count >= 6 { break }
        }
        
        let found = names.compactMap { name in
            ResistanceExerciseBank.allExercises.first(where: { $0.name == name })
        }
        
        if found.isEmpty {
            // 預設常用黃金複合動作
            return [
                ResistanceExerciseBank.allExercises[0], // 槓鈴臥推
                ResistanceExerciseBank.allExercises[5], // 槓鈴深蹲
                ResistanceExerciseBank.allExercises[3], // 引體向上
                ResistanceExerciseBank.allExercises[6]  // 羅馬尼亞硬舉
            ]
        }
        return found
    }

    private var filteredExercises: [ResistanceExercise] {
        ResistanceExerciseBank.allExercises.filter { ex in
            if let pat = selectedPattern, ex.pattern != pat { return false }
            if !searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let kw = searchKeyword.lowercased()
                let matchName = ex.name.lowercased().contains(kw)
                let matchEquip = ex.equipment.displayName.lowercased().contains(kw)
                let matchMuscles = ex.primaryMuscles.contains { $0.lowercased().contains(kw) }
                if !matchName && !matchEquip && !matchMuscles { return false }
            }
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
