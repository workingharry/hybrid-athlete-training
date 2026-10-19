import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// Apple 原生極簡風格：逐組訓練記錄器 (SetBySetLoggingView)
public struct SetBySetLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]

    public let exercise: ResistanceExercise
    public let nextExercise: ResistanceExercise?
    public let onCompleteExercise: ((ExecutedExerciseDetail) -> Void)?

    @State private var sets: [ExerciseSetEntry] = []
    @State private var progressionText: String = ""
    @State private var lastPerformedSummary: String = "無近期記錄"
    @State private var restTimerSeconds: Int = 90
    @State private var isRestTimerRunning: Bool = false
    @State private var restTimerRemaining: Int = 90
    @State private var timerSubscription: Timer? = nil

    public init(
        exercise: ResistanceExercise = ResistanceExerciseBank.allExercises[0],
        nextExercise: ResistanceExercise? = nil,
        onCompleteExercise: ((ExecutedExerciseDetail) -> Void)? = nil
    ) {
        self.exercise = exercise
        self.nextExercise = nextExercise
        self.onCompleteExercise = onCompleteExercise
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 動作標題與上次紀錄
                        exerciseHeaderSection

                        // 2. 雙重進階建議橫幅
                        progressionBannerSection

                        // 3. 組間休息倒數計時器
                        restTimerCardSection

                        // 4. 逐組執行表格 (組 / 上次 / kg / 次 / RIR / 打勾)
                        setTableViewSection

                        // 5. 新增組數按鈕
                        Button(action: addNewSet) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("新增一組")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "0A84FF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "1C1C1E"))
                            .cornerRadius(8)
                        }

                        // 6. 下一個動作按鈕
                        if let next = nextExercise {
                            Button(action: finishAndProceed) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("下一個動作")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "8E8E93"))
                                        Text("\(next.name) · \(next.defaultRepRange)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "8E8E93"))
                                }
                                .padding(14)
                                .background(Color(hex: "1C1C1E"))
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: finishAndProceed) {
                                Text("完成並儲存此動作")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(hex: "30D158"))
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(Color(hex: "0A84FF"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成動作") {
                        finishAndProceed()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "30D158"))
                }
            }
            .task {
                loadPrefillData()
            }
        }
    }

    // MARK: - 1. 標題與上次記錄
    private var exerciseHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)

            Text("上次 \(lastPerformedSummary)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "8E8E93"))

            // 肌群分攤權重膠囊
            HStack(spacing: 8) {
                ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                    Text("\(muscle) 1.0")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "0A84FF").opacity(0.15))
                        .foregroundColor(Color(hex: "0A84FF"))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "0A84FF").opacity(0.3), lineWidth: 1)
                        )
                }
                Text(exercise.equipment.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "2C2C2E"))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .cornerRadius(6)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 2. 雙重進階建議橫幅
    private var progressionBannerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressionText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Text("雙重進階 · 經驗法則")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(10)
    }

    // MARK: - 3. 組間休息計時器
    private var restTimerCardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("組間休息")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E93"))
                Spacer()
                Text(formatTimerSeconds(restTimerRemaining))
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "0A84FF"))
            }

            // 進度條
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "2C2C2E"))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color(hex: "0A84FF"))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(restTimerRemaining) / CGFloat(max(1, restTimerSeconds)))), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(10)
    }

    // MARK: - 4. 逐組執行表格
    private var setTableViewSection: some View {
        VStack(spacing: 0) {
            // 表頭
            HStack(spacing: 0) {
                Text("組")
                    .frame(width: 32, alignment: .center)
                Text("上次")
                    .frame(width: 68, alignment: .center)
                Text("kg")
                    .frame(width: 60, alignment: .center)
                Text("次")
                    .frame(width: 48, alignment: .center)
                Text("RIR")
                    .frame(width: 44, alignment: .center)
                Spacer()
                Text("完成")
                    .frame(width: 44, alignment: .center)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color(hex: "8E8E93"))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "161618"))

            Divider().background(Color(hex: "2C2C2E"))

            // 表列
            ForEach(sets.indices, id: \.self) { idx in
                setRowView(index: idx)
                if idx < sets.count - 1 {
                    Divider().background(Color(hex: "2C2C2E"))
                }
            }
        }
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "2C2C2E"), lineWidth: 1)
        )
    }

    private func setRowView(index: Int) -> some View {
        HStack(spacing: 0) {
            // 組號
            Text("\(sets[index].setNumber)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, alignment: .center)

            // 上次數值
            Text(sets[index].previousDescription ?? "–")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: 68, alignment: .center)

            // 負重 kg 輸入
            HStack(spacing: 2) {
                TextField(
                    "0",
                    value: Binding(
                        get: { sets[index].weightKg },
                        set: { sets[index].weightKg = $0 }
                    ),
                    format: .number
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .background(Color(hex: "2C2C2E"))
                .cornerRadius(6)
            }
            .frame(width: 60)
            .padding(.horizontal, 2)

            // 次數輸入
            HStack(spacing: 2) {
                TextField(
                    "0",
                    value: Binding(
                        get: { sets[index].reps },
                        set: { sets[index].reps = $0 }
                    ),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .background(Color(hex: "2C2C2E"))
                .cornerRadius(6)
            }
            .frame(width: 48)
            .padding(.horizontal, 2)

            // RIR (保留次數)
            HStack(spacing: 2) {
                TextField(
                    "–",
                    value: Binding(
                        get: { sets[index].rir ?? 2 },
                        set: { sets[index].rir = $0 }
                    ),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.vertical, 6)
                .background(Color(hex: "2C2C2E"))
                .cornerRadius(6)
            }
            .frame(width: 44)
            .padding(.horizontal, 2)

            Spacer()

            // 完成打勾按鈕 (一鍵打卡確認)
            Button {
                toggleSetCompleted(at: index)
            } label: {
                Image(systemName: sets[index].isCompleted ? "checkmark" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(sets[index].isCompleted ? Color(hex: "0A84FF") : Color(hex: "2C2C2E"))
                    .foregroundColor(sets[index].isCompleted ? .white : Color(hex: "8E8E93"))
                    .cornerRadius(6)
            }
            .frame(width: 44, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(sets[index].isCompleted ? Color(hex: "0A84FF").opacity(0.08) : Color.clear)
    }

    // MARK: - Actions & Logic
    private func toggleSetCompleted(at index: Int) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        sets[index].isCompleted.toggle()
        if sets[index].isCompleted {
            sets[index].completedAt = Date()
            if sets[index].rir == nil {
                sets[index].rir = 2
            }
            startRestTimer()
        }
    }

    private func addNewSet() {
        let nextNumber = (sets.map(\.setNumber).max() ?? 0) + 1
        let lastWeight = sets.last?.weightKg ?? 60.0
        let lastReps = sets.last?.reps ?? 8
        let prevDesc = sets.last?.previousDescription

        sets.append(
            ExerciseSetEntry(
                setNumber: nextNumber,
                previousDescription: prevDesc,
                weightKg: lastWeight,
                reps: lastReps,
                rir: nil,
                isCompleted: false
            )
        )
    }

    private func startRestTimer() {
        restTimerRemaining = restTimerSeconds
        isRestTimerRunning = true
        timerSubscription?.invalidate()
        timerSubscription = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if restTimerRemaining > 0 {
                restTimerRemaining -= 1
            } else {
                timerSubscription?.invalidate()
                isRestTimerRunning = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func formatTimerSeconds(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func loadPrefillData() {
        let history = storedSessions.map { $0.toDomain() }
        let prefilled = SetLogPrefillEngine.prefillSets(
            for: exercise.name,
            targetSetsCount: exercise.defaultSets,
            defaultWeightKg: 60.0,
            defaultReps: exercise.defaultReps,
            history: history
        )
        self.sets = prefilled
        self.restTimerSeconds = exercise.defaultRestSeconds
        self.restTimerRemaining = exercise.defaultRestSeconds

        // 搜尋上次執行日期與組數
        if let lastMatch = history.first(where: { $0.executedExercises.contains { $0.exerciseName == exercise.name } }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日"
            let dateStr = formatter.string(from: lastMatch.startDate)
            let setsCount = lastMatch.executedExercises.first { $0.exerciseName == exercise.name }?.sets ?? 4
            self.lastPerformedSummary = "\(dateStr) · \(setsCount) 組"
        }

        // 計算進階建議
        let suggestion = SetLogPrefillEngine.calculateProgression(
            exerciseName: exercise.name,
            targetRepUpper: exercise.defaultReps,
            pastSets: prefilled
        )
        self.progressionText = suggestion.explanation
    }

    private func finishAndProceed() {
        let detail = ExecutedExerciseDetail(
            exerciseName: exercise.name,
            pattern: exercise.pattern,
            equipment: exercise.equipment,
            restSeconds: exercise.defaultRestSeconds,
            setsList: sets
        )

        onCompleteExercise?(detail)
        dismiss()
    }
}
