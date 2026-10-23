import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 歷史訓練記錄新增與編輯彈窗 (SessionEditorSheet)
public struct SessionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let existingSession: SDWorkoutSession?

    @State private var discipline: TrainingDiscipline = .strength
    @State private var startDate: Date = Date()
    @State private var durationMinutes: Double = 60.0
    @State private var sRPE: Double = 7.5
    @State private var movementPatterns: Set<MovementPattern> = [.upperPush]
    @State private var executedExercises: [ExecutedExerciseDetail] = []
    @State private var isShowingExercisePicker: Bool = false

    public init(sessionToEdit: SDWorkoutSession? = nil) {
        self.existingSession = sessionToEdit
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()

                Form {
                    // 1. 訓練類型與時間
                    Section(header: Text("基本訓練資訊").foregroundColor(HybridTheme.textSecondary)) {
                        Picker("運動類型", selection: $discipline) {
                            Text("重量訓練").tag(TrainingDiscipline.strength)
                            Text("路跑耐力").tag(TrainingDiscipline.running)
                            Text("自行車").tag(TrainingDiscipline.cycling)
                            Text("游泳").tag(TrainingDiscipline.swimming)
                            Text("划船機").tag(TrainingDiscipline.rowing)
                            Text("活動度伸展").tag(TrainingDiscipline.mobility)
                            Text("完全休息").tag(TrainingDiscipline.rest)
                        }
                        .foregroundColor(HybridTheme.textPrimary)
                        .tint(HybridTheme.accentBlue)

                        DatePicker("訓練時間", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .foregroundColor(HybridTheme.textPrimary)
                            .tint(HybridTheme.accentBlue)

                        HStack {
                            Text("訓練時長")
                                .foregroundColor(HybridTheme.textPrimary)
                            Spacer()
                            TextField("60", value: $durationMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(HybridTheme.accentBlue)
                                .frame(width: 50)
                            Text("分鐘")
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)

                    // 2. 自覺強度與運動負荷
                    Section(header: Text("自覺強度 (Foster sRPE)").foregroundColor(HybridTheme.textSecondary)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("RPE 強度：\(String(format: "%.1f", sRPE))")
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text("預估負荷：\(Int(durationMinutes * sRPE)) AU")
                                    .foregroundColor(HybridTheme.accentBlue)
                            }
                            Slider(value: $sRPE, in: 1.0...10.0, step: 0.5)
                                .tint(HybridTheme.accentBlue)
                        }
                    }
                    .listRowBackground(HybridTheme.cardBackground)

                    // 3. 重量訓練動作明細 (僅在肌力時顯示)
                    if discipline == .strength {
                        Section(
                            header: HStack {
                                Text("已完成動作清單 (\(executedExercises.count))")
                                    .foregroundColor(HybridTheme.textSecondary)
                                Spacer()
                                Button("+ 加動作") {
                                    isShowingExercisePicker = true
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(HybridTheme.accentBlue)
                            }
                        ) {
                            if executedExercises.isEmpty {
                                Text("目前無個別動作紀錄，點擊右上角新增。")
                                    .font(.system(size: 12))
                                    .foregroundColor(HybridTheme.textSecondary)
                            } else {
                                ForEach(executedExercises.indices, id: \.self) { idx in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(executedExercises[idx].exerciseName)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(HybridTheme.textPrimary)
                                            Spacer()
                                            Button {
                                                executedExercises.remove(at: idx)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(HybridTheme.dangerRed)
                                            }
                                        }

                                        HStack(spacing: 12) {
                                            HStack(spacing: 2) {
                                                Text("組數:")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(HybridTheme.textSecondary)
                                                TextField("組", value: Binding(
                                                    get: { executedExercises[idx].sets ?? 3 },
                                                    set: { executedExercises[idx].sets = $0 }
                                                ), format: .number)
                                                .frame(width: 32)
                                                .foregroundColor(HybridTheme.textPrimary)
                                            }

                                            HStack(spacing: 2) {
                                                Text("次數:")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(HybridTheme.textSecondary)
                                                TextField("次", value: Binding(
                                                    get: { executedExercises[idx].reps ?? 10 },
                                                    set: { executedExercises[idx].reps = $0 }
                                                ), format: .number)
                                                .frame(width: 32)
                                                .foregroundColor(HybridTheme.textPrimary)
                                            }

                                            HStack(spacing: 2) {
                                                Text("kg:")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(HybridTheme.textSecondary)
                                                TextField("kg", value: Binding(
                                                    get: { executedExercises[idx].weightKg ?? 0 },
                                                    set: { executedExercises[idx].weightKg = $0 }
                                                ), format: .number)
                                                .frame(width: 44)
                                                .foregroundColor(HybridTheme.textPrimary)
                                            }
                                        }
                                        .font(.system(size: 12))
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .listRowBackground(HybridTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(existingSession == nil ? "手動補錄訓練紀錄" : "編輯訓練紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(HybridTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { saveSession() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HybridTheme.successGreen)
                }
            }
            .sheet(isPresented: $isShowingExercisePicker) {
                exercisePickerSheet
            }
            .onAppear {
                populateInitialData()
            }
        }
    }

    private var exercisePickerSheet: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                List {
                    ForEach(ResistanceExerciseBank.allExercises) { ex in
                        Button {
                            let detail = ExecutedExerciseDetail(
                                exerciseName: ex.name,
                                pattern: ex.pattern,
                                equipment: ex.equipment,
                                sets: ex.defaultSets,
                                reps: ex.defaultReps,
                                weightKg: 60.0,
                                restSeconds: ex.defaultRestSeconds
                            )
                            executedExercises.append(detail)
                            movementPatterns.insert(ex.pattern)
                            isShowingExercisePicker = false
                        } label: {
                            HStack {
                                Text(ex.name)
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text(ex.equipment.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(HybridTheme.accentBlue)
                            }
                        }
                        .listRowBackground(HybridTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("選擇動作")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func populateInitialData() {
        guard let existing = existingSession else { return }
        let domain = existing.toDomain()
        self.discipline = domain.discipline
        self.startDate = domain.startDate
        self.durationMinutes = domain.durationMinutes
        self.sRPE = domain.sRPE
        self.movementPatterns = Set(domain.movementPatterns)
        self.executedExercises = domain.executedExercises
    }

    private func saveSession() {
        let endDate = startDate.addingTimeInterval(durationMinutes * 60.0)
        let patternsArray = Array(movementPatterns)

        if let existing = existingSession {
            // 更新現有紀錄
            existing.startDate = startDate
            existing.endDate = endDate
            existing.disciplineRaw = discipline.rawValue
            existing.durationMinutes = durationMinutes
            existing.sRPE = sRPE
            existing.movementPatternsRaw = patternsArray.map(\.rawValue)
            existing.loadAU = durationMinutes * sRPE
            existing.executedExercisesJSON = try? JSONEncoder().encode(executedExercises)
        } else {
            // 新增手動紀錄
            let newDomain = WorkoutSession(
                startDate: startDate,
                endDate: endDate,
                discipline: discipline,
                durationMinutes: durationMinutes,
                sRPE: sRPE,
                movementPatterns: patternsArray,
                executedExercises: executedExercises,
                source: .manualLog
            )
            let sdSession = SDWorkoutSession(domain: newDomain)
            modelContext.insert(sdSession)
        }

        try? modelContext.save()
        dismiss()
    }
}
