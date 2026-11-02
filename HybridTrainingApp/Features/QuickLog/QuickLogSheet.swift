// File: HybridTrainingApp/Features/QuickLog/QuickLogSheet.swift

import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage


// MARK: - QuickLogSheet View

/// 15 秒極簡 FITT 重量訓練打卡視圖 (QuickLogSheet)
public struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft = QuickLogDraft()
    @State private var expandedCueExerciseName: String? = nil
    @State private var saveErrorMessage: String? = nil
    @State private var isShowingRoutineLibrary: Bool = false
    @FocusState private var focusedWeightExerciseName: String?

    public let onSaved: (() -> Void)?

    public init(initialTemplate: WorkoutRoutineTemplate? = nil, onSaved: (() -> Void)? = nil) {
        if let template = initialTemplate {
            var initialDraft = QuickLogDraft()
            initialDraft.applyTemplate(template)
            _draft = State(initialValue: initialDraft)
        }
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 0. 訓練類型快速選擇 (肌力 / 跑步 / 單車 / 游泳)
                        disciplineSelectorSection

                        // 1. 時間點快速切換膠囊
                        timeOffsetHeaderSection

                        // 2. 部位快速多選 (僅在肌力訓練時展示)
                        if draft.discipline == .strength {
                            patternSelectionSection
                            fittExerciseSection
                        }

                        // 3. 訓練時間長度
                        durationSection

                        // 4. Foster sRPE 自覺強度滑桿 (1.0 ~ 10.0)
                        sRPESection

                        // 5. 運動負荷與 FITT 摘要卡片
                        loadSummaryBanner

                        if let saveErrorMessage {
                            Text(saveErrorMessage)
                                .font(HybridTheme.Typography.subheadline.weight(.medium))
                                .foregroundColor(HybridTheme.dangerRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                bottomSaveBar
            }
            .navigationTitle(navTitleForDiscipline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(HybridTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingRoutineLibrary = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                            Text("常用課表")
                        }
                        .font(HybridTheme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(HybridTheme.accentBlue)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedWeightExerciseName = nil
                    }
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.accentBlue)
                }
            }
            .sheet(isPresented: $isShowingRoutineLibrary) {
                RoutineLibrarySheet { selectedTemplate in
                    draft.applyTemplate(selectedTemplate)
                }
            }
        }
    }

    // MARK: - Section 0: Discipline Selector

    private var disciplineSelectorSection: some View {
        HStack(spacing: 8) {
            disciplineTabButton(discipline: .strength, title: "肌力", icon: "dumbbell.fill")
            disciplineTabButton(discipline: .running, title: "路跑", icon: "figure.run")
            disciplineTabButton(discipline: .cycling, title: "單車", icon: "figure.outdoor.cycle")
            disciplineTabButton(discipline: .swimming, title: "游泳", icon: "figure.pool.swim")
            disciplineTabButton(discipline: .mobility, title: "伸展", icon: "figure.cooldown")
        }
    }

    private func disciplineTabButton(discipline: TrainingDiscipline, title: String, icon: String) -> some View {
        let isSelected = draft.discipline == discipline
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                draft.discipline = discipline
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(HybridTheme.Typography.badge.weight(isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? HybridTheme.accentBlue : HybridTheme.surfaceElevated)
            .foregroundColor(isSelected ? .white : HybridTheme.textSecondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? HybridTheme.accentBlue : HybridTheme.cardBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 1: Time Offset

    private var timeOffsetHeaderSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12))
                .foregroundColor(HybridTheme.textSecondary)

            Text("訓練時段")
                .font(HybridTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(HybridTheme.textSecondary)

            Spacer()

            HStack(spacing: 6) {
                ForEach(QuickLogTimeOffset.allCases) { offset in
                    let isSelected = draft.timeOffset == offset
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            draft.timeOffset = offset
                        }
                    } label: {
                        Text(offset.displayName)
                            .font(HybridTheme.Typography.badge.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? HybridTheme.accentBlue.opacity(0.18) : HybridTheme.surfaceElevated)
                            .foregroundColor(isSelected ? HybridTheme.accentBlue : HybridTheme.textSecondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? HybridTheme.accentBlue : HybridTheme.cardBorder, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section 1: Movement Patterns

    private var patternSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("1. 訓練部位 (可複選)")
                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text("已選 \(draft.selectedPatterns.count) 部位")
                    .font(HybridTheme.Typography.badge.weight(.medium))
                    .foregroundColor(HybridTheme.accentBlue)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                patternCapsule(title: "上肢推 (Push)", pattern: .upperPush)
                patternCapsule(title: "上肢拉 (Pull)", pattern: .upperPull)
                patternCapsule(title: "深蹲/前側鏈 (Quad)", pattern: .lowerQuad)
                patternCapsule(title: "硬舉/後側鏈 (Hinge)", pattern: .lowerPosterior)
            }
        }
    }

    private func patternCapsule(title: String, pattern: MovementPattern) -> some View {
        let isSelected = draft.selectedPatterns.contains(pattern)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                draft.togglePattern(pattern)
            }
        } label: {
            Text(title)
                .font(HybridTheme.Typography.badge.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? HybridTheme.accentBlue : HybridTheme.surfaceElevated)
                .foregroundColor(isSelected ? .white : HybridTheme.textPrimary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? HybridTheme.accentBlue : HybridTheme.cardBorder, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2: FITT Exercise Chips & Stepper Cards

    private var fittExerciseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("2. FITT 動作明細 (點擊晶片帶入預設組數，可選填)")
                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                if !draft.selectedExercises.isEmpty {
                    Text("\(draft.selectedExercises.count) 動作 · \(draft.totalCompletedSets) 組")
                        .font(HybridTheme.Typography.badge.weight(.bold))
                        .foregroundColor(HybridTheme.successGreen)
                }
            }

            // 依選取部位顯示動作晶片橫向捲軸
            VStack(alignment: .leading, spacing: 8) {
                ForEach(draft.availableExercisesByPattern, id: \.pattern) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(patternLabel(for: group.pattern))
                            .font(HybridTheme.Typography.chartAxis.weight(.semibold))
                            .foregroundColor(HybridTheme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(group.exercises) { exercise in
                                    exerciseChip(for: exercise)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(10)
            .background(HybridTheme.surfaceElevated.opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
            )

            // 已選取動作的 FITT 快速編輯卡片清單 (組數/次數步進鈕 + 重量選填)
            if !draft.selectedExercises.isEmpty {
                VStack(spacing: 8) {
                    ForEach(draft.selectedExercises) { detail in
                        fittDetailRow(for: detail)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func exerciseChip(for exercise: ResistanceExercise) -> some View {
        let isSelected = draft.isExerciseSelected(exercise)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                draft.toggleExercise(exercise)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 11, weight: .bold))
                Text(exercise.name)
                    .font(HybridTheme.Typography.badge.weight(.semibold))
                Text(exercise.equipment.displayName)
                    .font(HybridTheme.Typography.chartAxis)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(HybridTheme.surfaceElevated)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? HybridTheme.successGreen : HybridTheme.cardBackground)
            .foregroundColor(isSelected ? .white : HybridTheme.textPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? HybridTheme.successGreen : HybridTheme.cardBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func fittDetailRow(for detail: ExecutedExerciseDetail) -> some View {
        let matchedExercise = ResistanceExerciseBank.allExercises.first { $0.name == detail.exerciseName }
        let isShowingCue = expandedCueExerciseName == detail.exerciseName

        return VStack(alignment: .leading, spacing: 8) {
            // 第一列：動作名稱、器材標籤、FITT 即時摘要、技術提示按鈕、移除鈕
            HStack(spacing: 6) {
                Text(detail.exerciseName)
                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                    .foregroundColor(HybridTheme.textPrimary)

                Text(detail.equipment.displayName)
                    .font(HybridTheme.Typography.badge)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.accentBlue)
                    .cornerRadius(4)

                if let matchedExercise {
                    Text(matchedExercise.defaultRepRange)
                        .font(HybridTheme.Typography.chartAxis)
                        .foregroundColor(HybridTheme.textSecondary)
                }

                Spacer()

                Text(detail.summaryDescription)
                    .font(HybridTheme.Typography.badge.weight(.bold))
                    .foregroundColor(HybridTheme.accentBlue)

                if matchedExercise != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expandedCueExerciseName = isShowingCue ? nil : detail.exerciseName
                        }
                    } label: {
                        Image(systemName: isShowingCue ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let matchedExercise {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            draft.toggleExercise(matchedExercise)
                        }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(HybridTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if isShowingCue, let cue = matchedExercise?.techniqueCues {
                Text("提示：\(cue)")
                    .font(HybridTheme.Typography.chartAxis)
                    .foregroundColor(HybridTheme.energyOrange)
                    .padding(.vertical, 2)
            }

            // 第二列：組數步進器、次數步進器、休息步進器、重量輸入框
            HStack(spacing: 6) {
                // 組數 (Sets)
                compactStepperControl(
                    label: "組數",
                    valueText: "\(detail.sets ?? 3)組",
                    onDecrement: { draft.adjustSets(for: detail.exerciseName, delta: -1) },
                    onIncrement: { draft.adjustSets(for: detail.exerciseName, delta: 1) }
                )

                // 次數 (Reps)
                compactStepperControl(
                    label: "次數",
                    valueText: "\(detail.reps ?? 10)次",
                    onDecrement: { draft.adjustReps(for: detail.exerciseName, delta: -1) },
                    onIncrement: { draft.adjustReps(for: detail.exerciseName, delta: 1) }
                )

                // 組間休息 (Rest Time)
                compactStepperControl(
                    label: "休息",
                    valueText: "\(detail.restSeconds ?? 90)s",
                    onDecrement: { draft.adjustRestSeconds(for: detail.exerciseName, delta: -15) },
                    onIncrement: { draft.adjustRestSeconds(for: detail.exerciseName, delta: 15) }
                )

                // 重量選填 (Weight kg)
                HStack(spacing: 2) {
                    TextField(
                        "負重",
                        text: Binding(
                            get: { draft.weightTextMap[detail.exerciseName] ?? "" },
                            set: { draft.updateWeightText($0, for: detail.exerciseName) }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .focused($focusedWeightExerciseName, equals: detail.exerciseName)
                    .font(HybridTheme.Typography.badge.weight(.bold))
                    .foregroundColor(HybridTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 38)

                    Text("kg")
                        .font(HybridTheme.Typography.chartAxis)
                        .foregroundColor(HybridTheme.textSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(HybridTheme.surfaceElevated)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            focusedWeightExerciseName == detail.exerciseName
                                ? HybridTheme.accentBlue
                                : HybridTheme.cardBorder,
                            lineWidth: 0.8
                        )
                )
            }
        }
        .padding(10)
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private func compactStepperControl(
        label: String,
        valueText: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.accentBlue)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Text(valueText)
                .font(HybridTheme.Typography.badge.weight(.bold))
                .foregroundColor(HybridTheme.textPrimary)
                .frame(minWidth: 36)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(HybridTheme.surfaceElevated)
                    .foregroundColor(HybridTheme.accentBlue)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(HybridTheme.surfaceElevated.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(valueText)")
    }

    // MARK: - Section 3: Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("3. 訓練時長")
                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text("\(Int(draft.durationMinutes)) 分鐘")
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)
            }

            HStack(spacing: 12) {
                Button("- 5m") {
                    draft.adjustDuration(by: -5.0)
                }
                .buttonStyle(BorderedButtonStyle())
                .tint(HybridTheme.accentBlue)

                Slider(
                    value: Binding(
                        get: { draft.durationMinutes },
                        set: { draft.durationMinutes = $0 }
                    ),
                    in: QuickLogDraft.minDurationMinutes...QuickLogDraft.maxDurationMinutes,
                    step: 5
                )
                .tint(HybridTheme.accentBlue)

                Button("+ 5m") {
                    draft.adjustDuration(by: 5.0)
                }
                .buttonStyle(BorderedButtonStyle())
                .tint(HybridTheme.accentBlue)
            }
        }
    }

    // MARK: - Section 4: Foster sRPE

    private var sRPESection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("4. Foster sRPE 自覺強度")
                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text(String(format: "%.1f", draft.sRPE))
                    .font(HybridTheme.Typography.metricHero)
                    .foregroundColor(rpeColor)
                Text("(\(rpeDescription))")
                    .font(HybridTheme.Typography.subheadline)
                    .foregroundColor(HybridTheme.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { draft.sRPE },
                    set: { draft.updateSRPE($0) }
                ),
                in: QuickLogDraft.minSRPE...QuickLogDraft.maxSRPE,
                step: 0.5
            )
            .tint(rpeColor)
        }
    }

    // MARK: - Section 5: Load Summary Banner

    private var loadSummaryBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Text("累計肌力負荷貨幣:")
                    .font(HybridTheme.Typography.subheadline)
                    .foregroundColor(HybridTheme.textSecondary)
                Spacer()
                Text("\(Int(draft.calculatedLoadAU)) AU")
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.accentBlue)
            }

            if !draft.selectedExercises.isEmpty {
                Divider()
                    .background(HybridTheme.cardBorder)

                HStack {
                    Text("FITT 執行統計:")
                        .font(HybridTheme.Typography.subheadline)
                        .foregroundColor(HybridTheme.textSecondary)
                    Spacer()
                    Text(volumeSummaryText)
                        .font(HybridTheme.Typography.badge.weight(.semibold))
                        .foregroundColor(HybridTheme.successGreen)
                }
            }
        }
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomSaveBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(HybridTheme.cardBorder)
            Button(action: saveSession) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("完成記錄 (寫入本機 SwiftData)")
                        .font(HybridTheme.Typography.cardTitle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(HybridTheme.successGreen)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(HybridTheme.cardBackground)
        }
    }

    // MARK: - Helpers

    private var navTitleForDiscipline: String {
        switch draft.discipline {
        case .strength: return "15 秒肌力打卡"
        case .running: return "15 秒路跑打卡"
        case .cycling: return "15 秒單車打卡"
        case .swimming: return "15 秒游泳打卡"
        case .rowing: return "15 秒划船打卡"
        case .mobility: return "15 秒活動度打卡"
        case .rest: return "完全休息記錄"
        }
    }

    private func patternLabel(for pattern: MovementPattern) -> String {
        switch pattern {
        case .upperPush: return "上肢推 (Upper Push)"
        case .upperPull: return "上肢拉 (Upper Pull)"
        case .lowerQuad: return "深蹲/前側鏈 (Lower Quad)"
        case .lowerPosterior: return "硬舉/後側鏈 (Lower Posterior)"
        }
    }

    private var volumeSummaryText: String {
        let base = "\(draft.selectedExercises.count) 動作 / 共 \(draft.totalCompletedSets) 組"
        if draft.totalVolumeKg > 0 {
            return "\(base) · 總容量 \(Int(draft.totalVolumeKg)) kg"
        }
        return base
    }

    private var rpeColor: Color {
        if draft.sRPE <= 4.0 { return HybridTheme.successGreen }
        if draft.sRPE <= 7.0 { return HybridTheme.energyOrange }
        return HybridTheme.dangerRed
    }

    private var rpeDescription: String {
        switch draft.sRPE {
        case ..<3.0: return "極輕鬆"
        case 3.0..<5.0: return "中等有感"
        case 5.0..<7.0: return "稍微吃力"
        case 7.0..<8.5: return "吃力 / 接近力竭"
        default: return "最大極限力竭"
        }
    }

    private func saveSession() {
        focusedWeightExerciseName = nil
        saveErrorMessage = nil

        let domainSession = draft.buildWorkoutSession()
        let sdSession = SDWorkoutSession(domain: domainSession)
        modelContext.insert(sdSession)

        do {
            try modelContext.save()
            onSaved?()
            dismiss()
        } catch {
            saveErrorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }
}
