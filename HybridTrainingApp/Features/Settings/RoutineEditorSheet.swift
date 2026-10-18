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
                Color(hex: "090C10").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 課表基本資訊
                        VStack(alignment: .leading, spacing: 8) {
                            Text("課表名稱")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "8B949E"))

                            TextField("例如：週三下肢深蹲與爆發強化", text: $routineName)
                                .padding(12)
                                .background(Color(hex: "161B22"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "30363D"), lineWidth: 1)
                                )
                        }

                        // 2. 訓練類型與目標模式
                        VStack(alignment: .leading, spacing: 8) {
                            Text("涵蓋動作模式 (可複選)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "8B949E"))

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
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: "8B949E"))

                                Spacer()

                                Button {
                                    isShowingExercisePicker = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("添加動作")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "58A6FF"))
                                }
                            }

                            if items.isEmpty {
                                Text("尚未添加動作，點擊右上角「添加動作」從動作庫挑選。")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8B949E"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Color(hex: "161B22"))
                                    .cornerRadius(8)
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
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Slider(value: $estimatedMinutes, in: 20...120, step: 5)
                                    .frame(width: 160)
                                    .tint(Color(hex: "58A6FF"))
                            }

                            HStack {
                                Text("基準強度：\(String(format: "%.1f", defaultSRPE)) RPE")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Slider(value: $defaultSRPE, in: 4.0...10.0, step: 0.5)
                                    .frame(width: 160)
                                    .tint(Color(hex: "F0883E"))
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "161B22"))
                        .cornerRadius(8)

                        // 5. 課表備註
                        VStack(alignment: .leading, spacing: 6) {
                            Text("教練提示與備註 (選填)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "8B949E"))

                            TextField("例如：注意第二動離心控制3秒，維持骨盆正位", text: $notes)
                                .padding(12)
                                .background(Color(hex: "161B22"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        if let error = validationErrorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "F85149"))
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
                        .foregroundColor(Color(hex: "8B949E"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存課表") { saveRoutine() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "3FB950"))
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
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "58A6FF") : Color(hex: "161B22"))
                .foregroundColor(isSelected ? Color(hex: "090C10") : Color(hex: "C9D1D9"))
                .cornerRadius(6)
        }
    }

    private func exerciseItemCard(index: Int) -> some View {
        let item = items[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.exerciseName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Text(item.equipment.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: "21262D"))
                    .foregroundColor(Color(hex: "58A6FF"))
                    .cornerRadius(4)

                Spacer()

                Button {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "F85149"))
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
        .padding(10)
        .background(Color(hex: "161B22"))
        .cornerRadius(8)
    }

    private func stepperControl(label: String, step: Int = 1, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Button("-") { value.wrappedValue -= step }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "58A6FF"))
                .frame(width: 20, height: 20)
                .background(Color(hex: "090C10"))
                .cornerRadius(4)

            Text("\(value.wrappedValue)\(label)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 32)

            Button("+") { value.wrappedValue += step }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "58A6FF"))
                .frame(width: 20, height: 20)
                .background(Color(hex: "090C10"))
                .cornerRadius(4)
        }
        .padding(4)
        .background(Color(hex: "090C10"))
        .cornerRadius(6)
    }

    private var exercisePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(exercise.englishName)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8B949E"))
                                }
                                Spacer()
                                Text(exercise.equipment.displayName)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "58A6FF"))
                            }
                        }
                        .listRowBackground(Color(hex: "161B22"))
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
