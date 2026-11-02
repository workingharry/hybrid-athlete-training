import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 自訂課表範本編輯器 (RoutineEditorSheet)
public struct RoutineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var routineName: String = ""
    @State private var discipline: TrainingDiscipline = .strength
    @State private var selectedPatterns: Set<MovementPattern> = [.lowerQuad, .lowerPosterior]
    @State private var items: [TemplateExerciseItem] = []
    @State private var estimatedMinutes: Double = 45.0
    @State private var defaultSRPE: Double = 7.5
    @State private var notes: String = ""
    @State private var isShowingExercisePicker: Bool = false
    @State private var validationErrorMessage: String? = nil

    public let onSaved: ((WorkoutRoutineTemplate) -> Void)?

    public init(onSaved: ((WorkoutRoutineTemplate) -> Void)? = nil) {
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 課表基本資訊
                        VStack(alignment: .leading, spacing: 8) {
                            Text("課表名稱")
                                .font(HybridTheme.Typography.subheadline.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            TextField("例如：週三下肢深蹲與爆發強化", text: $routineName)
                                .padding(12)
                                .background(HybridTheme.cardBackground)
                                .foregroundColor(HybridTheme.textPrimary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                                )
                        }

                        // 2. 訓練類型與目標模式
                        VStack(alignment: .leading, spacing: 8) {
                            Text("涵蓋動作模式 (可複選)")
                                .font(HybridTheme.Typography.subheadline.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                patternButton(title: "上肢推 (Push)", pattern: .upperPush)
                                patternButton(title: "上肢拉 (Pull)", pattern: .upperPull)
                                patternButton(title: "前側鏈/蹲 (Quad)", pattern: .lowerQuad)
                                patternButton(title: "後側鏈/鉸鏈 (Hinge)", pattern: .lowerPosterior)
                            }
                        }

                        // 3. 動作清單
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("動作排程清單 (\(items.count) 個動作)")
                                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                                    .foregroundColor(HybridTheme.textSecondary)

                                Spacer()

                                Button {
                                    isShowingExercisePicker = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("添加動作")
                                    }
                                    .font(HybridTheme.Typography.badge.weight(.bold))
                                    .foregroundColor(HybridTheme.accentBlue)
                                }
                            }

                            if items.isEmpty {
                                Text("尚未添加動作，點擊右上角「添加動作」從動作庫挑選。")
                                    .font(HybridTheme.Typography.subheadline)
                                    .foregroundColor(HybridTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(HybridTheme.cardBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                                    )
                            } else {
                                ForEach(items.indices, id: \.self) { idx in
                                    exerciseItemCard(index: idx)
                                }
                            }
                        }

                        // 4. 預估時間與自覺強度
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("預估時長：\(Int(estimatedMinutes)) 分鐘")
                                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Slider(value: $estimatedMinutes, in: 20...120, step: 5)
                                    .frame(width: 160)
                                    .tint(HybridTheme.accentBlue)
                            }

                            HStack {
                                Text("基準強度：\(String(format: "%.1f", defaultSRPE)) RPE")
                                    .font(HybridTheme.Typography.subheadline.weight(.bold))
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Slider(value: $defaultSRPE, in: 4.0...10.0, step: 0.5)
                                    .frame(width: 160)
                                    .tint(HybridTheme.energyOrange)
                            }
                        }
                        .padding(14)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                        )

                        // 5. 課表備註
                        VStack(alignment: .leading, spacing: 6) {
                            Text("教練提示與備註 (選填)")
                                .font(HybridTheme.Typography.subheadline.weight(.bold))
                                .foregroundColor(HybridTheme.textSecondary)

                            TextField("例如：注意第二動離心控制3秒，維持骨盆正位", text: $notes)
                                .padding(12)
                                .background(HybridTheme.cardBackground)
                                .foregroundColor(HybridTheme.textPrimary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                                )
                        }

                        if let error = validationErrorMessage {
                            Text(error)
                                .font(HybridTheme.Typography.badge.weight(.semibold))
                                .foregroundColor(HybridTheme.dangerRed)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("建立自訂課表範本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(HybridTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存課表") { saveRoutine() }
                        .font(HybridTheme.Typography.cardTitle)
                        .foregroundColor(HybridTheme.successGreen)
                }
            }
            .sheet(isPresented: $isShowingExercisePicker) {
                exercisePickerSheet
            }
        }
    }

    private func patternButton(title: String, pattern: MovementPattern) -> some View {
        let isSelected = selectedPatterns.contains(pattern)
        return Button {
            if isSelected {
                if selectedPatterns.count > 1 {
                    selectedPatterns.remove(pattern)
                }
            } else {
                selectedPatterns.insert(pattern)
            }
        } label: {
            Text(title)
                .font(HybridTheme.Typography.badge.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? HybridTheme.accentBlue : HybridTheme.surfaceElevated)
                .foregroundColor(isSelected ? .white : HybridTheme.textPrimary)
                .cornerRadius(8)
        }
    }

    private func exerciseItemCard(index: Int) -> some View {
        let item = items[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.exerciseName)
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)

                Text(item.equipment.displayName)
                    .font(HybridTheme.Typography.badge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HybridTheme.accentBlue.opacity(0.15))
                    .foregroundColor(HybridTheme.accentBlue)
                    .cornerRadius(4)

                Spacer()

                Button {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(HybridTheme.dangerRed)
                }
            }

            HStack(spacing: 8) {
                stepperControl(label: "組", value: Binding(
                    get: { items[index].targetSets },
                    set: { items[index].targetSets = max(1, min(10, $0)) }
                ))
                stepperControl(label: "次", value: Binding(
                    get: { items[index].targetReps },
                    set: { items[index].targetReps = max(1, min(50, $0)) }
                ))
                stepperControl(label: "秒休", step: 15, value: Binding(
                    get: { items[index].targetRestSeconds },
                    set: { items[index].targetRestSeconds = max(0, min(300, $0)) }
                ))
            }
        }
        .padding(12)
        .background(HybridTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private func stepperControl(label: String, step: Int = 1, value: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Button("-") { value.wrappedValue -= step }
                .font(HybridTheme.Typography.badge.weight(.bold))
                .foregroundColor(HybridTheme.accentBlue)
                .frame(width: 24, height: 24)
                .background(HybridTheme.surfaceElevated)
                .cornerRadius(6)

            Text("\(value.wrappedValue)\(label)")
                .font(HybridTheme.Typography.chartAxis.weight(.bold))
                .foregroundColor(HybridTheme.textPrimary)
                .frame(minWidth: 34)

            Button("+") { value.wrappedValue += step }
                .font(HybridTheme.Typography.badge.weight(.bold))
                .foregroundColor(HybridTheme.accentBlue)
                .frame(width: 24, height: 24)
                .background(HybridTheme.surfaceElevated)
                .cornerRadius(6)
        }
        .padding(5)
        .background(HybridTheme.surfaceElevated.opacity(0.5))
        .cornerRadius(8)
    }

    private var exercisePickerSheet: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                List {
                    ForEach(ResistanceExerciseBank.allExercises) { exercise in
                        Button {
                            let newItem = TemplateExerciseItem(
                                exerciseName: exercise.name,
                                pattern: exercise.pattern,
                                equipment: exercise.equipment,
                                targetSets: exercise.defaultSets,
                                targetReps: exercise.defaultReps,
                                targetWeightKg: nil,
                                targetRestSeconds: exercise.defaultRestSeconds
                            )
                            items.append(newItem)
                            selectedPatterns.insert(exercise.pattern)
                            isShowingExercisePicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.name)
                                        .font(HybridTheme.Typography.cardTitle)
                                        .foregroundColor(HybridTheme.textPrimary)
                                    Text(exercise.englishName)
                                        .font(HybridTheme.Typography.subheadline)
                                        .foregroundColor(HybridTheme.textSecondary)
                                }
                                Spacer()
                                Text(exercise.equipment.displayName)
                                    .font(HybridTheme.Typography.badge)
                                    .foregroundColor(HybridTheme.accentBlue)
                            }
                        }
                        .listRowBackground(HybridTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("挑選動作")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveRoutine() {
        let trimmed = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationErrorMessage = "請輸入課表名稱"
            return
        }
        guard !items.isEmpty else {
            validationErrorMessage = "請至少加入 1 個動作"
            return
        }

        let routine = WorkoutRoutineTemplate(
            name: trimmed,
            discipline: discipline,
            targetPatterns: Array(selectedPatterns),
            exercises: items,
            estimatedDurationMinutes: estimatedMinutes,
            defaultSRPE: defaultSRPE,
            notes: notes,
            isBuiltIn: false
        )

        let sdRoutine = SDRoutineTemplate(domain: routine)
        modelContext.insert(sdRoutine)
        try? modelContext.save()

        onSaved?(routine)
        dismiss()
    }
}
