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
    @State private var selectedSetIndex: Int = 0
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
                HybridTheme.background.ignoresSafeArea()

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

                        // 4.5 極速快捷調整列 (快速微調重量、次數與同上一組)
                        quickStepperTraySection

                        // 5. 新增組數按鈕
                        Button(action: addNewSet) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("新增一組")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HybridTheme.accentBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(HybridTheme.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
                            )
                        }

                        // 6. 下一個動作或完成按鈕
                        if let next = nextExercise {
                            Button(action: finishAndProceed) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("下一個動作")
                                            .font(.system(size: 11))
                                            .foregroundColor(HybridTheme.textSecondary)
                                        Text("\(next.name) · \(next.defaultRepRange)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(HybridTheme.textPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(HybridTheme.textSecondary)
                                }
                                .padding(14)
                                .background(HybridTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 1)
                                )
                            }
                        } else {
                            Button(action: finishAndProceed) {
                                Text("完成並儲存此動作")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(HybridTheme.successGreen)
                                    .foregroundColor(.white)
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
                        .foregroundColor(HybridTheme.accentBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成動作") {
                        finishAndProceed()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HybridTheme.successGreen)
                }
            }
            .task {
                loadPrefillData()
            }
            .onDisappear {
                timerSubscription?.invalidate()
                timerSubscription = nil
                isRestTimerRunning = false
            }
        }
    }

    // MARK: - 1. 標題與上次記錄
    private var exerciseHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(HybridTheme.textPrimary)

            Text("上次 \(lastPerformedSummary)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HybridTheme.textSecondary)

            // 肌群分攤權重膠囊
            HStack(spacing: 8) {
                ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                    Text("\(muscle) 1.0")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(HybridTheme.accentBlue.opacity(0.12))
                        .foregroundColor(HybridTheme.accentBlue)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(HybridTheme.accentBlue.opacity(0.25), lineWidth: 1)
                        )
                }
                Text(exercise.equipment.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.textSecondary)
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
                .foregroundColor(HybridTheme.textPrimary)

            Text("雙重進階 · 經驗法則")
                .font(.system(size: 11))
                .foregroundColor(HybridTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - 3. 組間休息計時器
    private var restTimerCardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("組間休息")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text(formatTimerSeconds(restTimerRemaining))
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(HybridTheme.energyOrange)
            }

            // 進度條
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(HybridTheme.surfaceElevated)
                        .frame(height: 6)
                    Capsule()
                        .fill(HybridTheme.energyOrange)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(restTimerRemaining) / CGFloat(max(1, restTimerSeconds)))), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
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
            .foregroundColor(HybridTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(HybridTheme.surfaceElevated)

            Divider().background(HybridTheme.cardBorder)

            // 表列
            ForEach(sets.indices, id: \.self) { idx in
                setRowView(index: idx)
                if idx < sets.count - 1 {
                    Divider().background(HybridTheme.cardBorder)
                }
            }
        }
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 1)
        )
    }

    private func setRowView(index: Int) -> some View {
        let isSelected = selectedSetIndex == index
        let isDone = sets[index].isCompleted

        return HStack(spacing: 0) {
            // 組號 (點擊可切換選中此組)
            Text("\(sets[index].setNumber)")
                .font(.system(size: 13, weight: isSelected ? .heavy : .bold))
                .foregroundColor(isSelected ? HybridTheme.accentBlue : HybridTheme.textPrimary)
                .frame(width: 32, alignment: .center)

            // 上次數值
            Text(sets[index].previousDescription ?? "–")
                .font(.system(size: 11))
                .foregroundColor(HybridTheme.textSecondary)
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
                .foregroundColor(HybridTheme.textPrimary)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
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
                .foregroundColor(HybridTheme.textPrimary)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
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
                .foregroundColor(HybridTheme.textSecondary)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
                .cornerRadius(6)
            }
            .frame(width: 44)
            .padding(.horizontal, 2)

            Spacer()

            // 完成打勾按鈕 (一鍵打卡確認)
            Button {
                toggleSetCompleted(at: index)
            } label: {
                Image(systemName: isDone ? "checkmark" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(isDone ? HybridTheme.successGreen : HybridTheme.surfaceElevated)
                    .foregroundColor(isDone ? .white : HybridTheme.textSecondary)
                    .cornerRadius(6)
            }
            .frame(width: 44, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? HybridTheme.accentBlue.opacity(0.08)
                : (isDone ? HybridTheme.successGreen.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSetIndex = index
        }
    }

    // MARK: - 4.5 極速快捷調整列 (Quick Stepper Control Tray)
    @ViewBuilder
    private var quickStepperTraySection: some View {
        if !sets.isEmpty && selectedSetIndex >= 0 && selectedSetIndex < sets.count {
            let currentSet = sets[selectedSetIndex]

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(HybridTheme.energyOrange)
                        Text("第 \(currentSet.setNumber) 組極速微調")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(HybridTheme.textPrimary)
                    }

                    Spacer()

                    // 同上一組快捷鈕
                    if selectedSetIndex > 0 {
                        Button {
                            copyFromPreviousSet(targetIndex: selectedSetIndex)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 10))
                                Text("同上一組 (\(Int(sets[selectedSetIndex - 1].weightKg))kg × \(sets[selectedSetIndex - 1].reps))")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HybridTheme.surfaceElevated)
                            .foregroundColor(HybridTheme.accentBlue)
                            .cornerRadius(6)
                        }
                    }

                    // 一鍵套用至所有組數
                    Button {
                        applyToAllSets(fromIndex: selectedSetIndex)
                    } label: {
                        Text("全部同重量")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HybridTheme.surfaceElevated)
                            .foregroundColor(HybridTheme.textSecondary)
                            .cornerRadius(6)
                    }
                }

                // 重量快捷微調膠囊: -5kg, -2.5kg, +2.5kg, +5kg
                HStack(spacing: 8) {
                    Text("重量")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HybridTheme.textSecondary)
                        .frame(width: 32, alignment: .leading)

                    stepperWeightChip(title: "-5 kg", delta: -5.0)
                    stepperWeightChip(title: "-2.5", delta: -2.5)

                    Text("\(String(format: "%.1f", currentSet.weightKg)) kg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HybridTheme.textPrimary)
                        .frame(minWidth: 54, alignment: .center)

                    stepperWeightChip(title: "+2.5", delta: 2.5)
                    stepperWeightChip(title: "+5 kg", delta: 5.0)
                }

                // 次數快捷微調: -1, +1, 次數顯示
                HStack(spacing: 8) {
                    Text("次數")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HybridTheme.textSecondary)
                        .frame(width: 32, alignment: .leading)

                    stepperRepChip(title: "-1 次", delta: -1)

                    Text("\(currentSet.reps) 次")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HybridTheme.textPrimary)
                        .frame(minWidth: 54, alignment: .center)

                    stepperRepChip(title: "+1 次", delta: 1)

                    Spacer()

                    // RIR 快捷標記
                    HStack(spacing: 4) {
                        Text("RIR:")
                            .font(.system(size: 11))
                            .foregroundColor(HybridTheme.textSecondary)
                        ForEach([0, 1, 2, 3], id: \.self) { rirVal in
                            Button {
                                sets[selectedSetIndex].rir = rirVal
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("\(rirVal)")
                                    .font(.system(size: 11, weight: currentSet.rir == rirVal ? .bold : .medium))
                                    .frame(width: 24, height: 24)
                                    .background(currentSet.rir == rirVal ? HybridTheme.energyOrange : HybridTheme.surfaceElevated)
                                    .foregroundColor(currentSet.rir == rirVal ? .white : HybridTheme.textSecondary)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(HybridTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private func stepperWeightChip(title: String, delta: Double) -> some View {
        Button {
            let cur = sets[selectedSetIndex].weightKg
            let next = max(0.0, cur + delta)
            sets[selectedSetIndex].weightKg = next
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
                .foregroundColor(HybridTheme.textPrimary)
                .cornerRadius(6)
        }
    }

    private func stepperRepChip(title: String, delta: Int) -> some View {
        Button {
            let cur = sets[selectedSetIndex].reps
            let next = max(1, cur + delta)
            sets[selectedSetIndex].reps = next
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
                .foregroundColor(HybridTheme.textPrimary)
                .cornerRadius(6)
        }
    }

    private func copyFromPreviousSet(targetIndex: Int) {
        guard targetIndex > 0 else { return }
        let prev = sets[targetIndex - 1]
        sets[targetIndex].weightKg = prev.weightKg
        sets[targetIndex].reps = prev.reps
        sets[targetIndex].rir = prev.rir
        sets[targetIndex].isCompleted = true
        sets[targetIndex].completedAt = Date()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startRestTimer()
        if targetIndex + 1 < sets.count {
            selectedSetIndex = targetIndex + 1
        }
    }

    private func applyToAllSets(fromIndex: Int) {
        let baseWeight = sets[fromIndex].weightKg
        let baseReps = sets[fromIndex].reps
        let baseRir = sets[fromIndex].rir
        for i in 0..<sets.count {
            sets[i].weightKg = baseWeight
            sets[i].reps = baseReps
            if sets[i].rir == nil {
                sets[i].rir = baseRir
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

        if let onComplete = onCompleteExercise {
            onComplete(detail)
        } else {
            // 獨立單項動作打卡：若未透過訓練流程開啟，直接建立完整會話持久化至 SwiftData
            let completedSets = sets.filter { $0.isCompleted }
            let validSets = completedSets.isEmpty ? sets : completedSets
            let estDuration = Double(validSets.count * (exercise.defaultRestSeconds + 45)) / 60.0
            let durationMin = max(10.0, estDuration)
            let rirList = validSets.compactMap { $0.rir }
            let avgRir = rirList.isEmpty ? 2.0 : (Double(rirList.reduce(0, +)) / Double(rirList.count))
            let estSRPE = max(1.0, min(10.0, 10.0 - avgRir))
            
            let now = Date()
            let session = WorkoutSession(
                startDate: now.addingTimeInterval(-durationMin * 60.0),
                endDate: now,
                discipline: .strength,
                durationMinutes: durationMin,
                sRPE: estSRPE,
                movementPatterns: [exercise.pattern],
                executedExercises: [detail],
                source: .manualLog
            )
            let sdSession = SDWorkoutSession(domain: session)
            modelContext.insert(sdSession)
            try? modelContext.save()
        }
        dismiss()
    }
}
