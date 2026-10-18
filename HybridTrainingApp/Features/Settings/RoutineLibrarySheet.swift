import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 自訂與內建課表範本庫 (RoutineLibrarySheet)
public struct RoutineLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SDRoutineTemplate.createdAt, order: .reverse) private var storedCustomRoutines: [SDRoutineTemplate]

    @State private var isShowingEditor: Bool = false
    public let onSelectTemplate: ((WorkoutRoutineTemplate) -> Void)?

    public init(onSelectTemplate: ((WorkoutRoutineTemplate) -> Void)? = nil) {
        self.onSelectTemplate = onSelectTemplate
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 我的自訂課表
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("我的自訂課表 (\(storedCustomRoutines.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    isShowingEditor = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("新增課表")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "58A6FF"))
                                }
                            }

                            if storedCustomRoutines.isEmpty {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundColor(Color(hex: "8B949E"))
                                    Text("尚未建立自訂課表，點擊右上角新增您專屬的訓練排程。")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "8B949E"))
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "161B22"))
                                .cornerRadius(8)
                            } else {
                                ForEach(storedCustomRoutines) { sdRoutine in
                                    routineCard(
                                        template: sdRoutine.toDomain(),
                                        isDeletable: true,
                                        onDelete: {
                                            modelContext.delete(sdRoutine)
                                            try? modelContext.save()
                                        }
                                    )
                                }
                            }
                        }

                        // 2. 官方精選混合運動員課表
                        VStack(alignment: .leading, spacing: 12) {
                            Text("官方精選混合運動員範本 (4大肌群均衡)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "58A6FF"))

                            ForEach(WorkoutRoutineTemplate.builtInTemplates) { template in
                                routineCard(
                                    template: template,
                                    isDeletable: false,
                                    onDelete: nil
                                )
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("常用訓練課表庫")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundColor(Color(hex: "8B949E"))
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                RoutineEditorSheet()
            }
        }
    }

    private func routineCard(
        template: WorkoutRoutineTemplate,
        isDeletable: Bool,
        onDelete: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題、自訂/官方標籤、刪除鈕
            HStack {
                Text(template.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                if template.isBuiltIn {
                    Text("官方推薦")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "58A6FF").opacity(0.2))
                        .foregroundColor(Color(hex: "58A6FF"))
                        .cornerRadius(4)
                }

                Spacer()

                if isDeletable, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "F85149"))
                    }
                }
            }

            // 涵蓋動作模式標籤
            HStack(spacing: 6) {
                ForEach(template.targetPatterns, id: \.self) { pattern in
                    Text(patternDisplayName(pattern))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "21262D"))
                        .foregroundColor(Color(hex: "8B949E"))
                        .cornerRadius(4)
                }

                Spacer()

                Text("\(template.exercises.count)動作 · \(template.totalTargetSets)組 · \(Int(template.estimatedDurationMinutes))分")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8B949E"))
            }

            // 動作清單摘要
            VStack(alignment: .leading, spacing: 4) {
                ForEach(template.exercises.prefix(3)) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: "58A6FF"))
                            .frame(width: 4, height: 4)
                        Text(item.exerciseName)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "C9D1D9"))
                        Spacer()
                        Text("\(item.targetSets)組 x \(item.targetReps)次")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "8B949E"))
                    }
                }
                if template.exercises.count > 3 {
                    Text("...及其他 \(template.exercises.count - 3) 個動作")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "8B949E"))
                        .padding(.leading, 8)
                }
            }
            .padding(8)
            .background(Color(hex: "090C10").opacity(0.5))
            .cornerRadius(6)

            if !template.notes.isEmpty {
                Text(template.notes)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8B949E"))
                    .lineLimit(2)
            }

            // 一鍵套用至快速打卡
            Button {
                onSelectTemplate?(template)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("套用此課表開始打卡")
                }
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(hex: "58A6FF"))
                .foregroundColor(Color(hex: "090C10"))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(hex: "161B22"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }

    private func patternDisplayName(_ pattern: MovementPattern) -> String {
        switch pattern {
        case .upperPush: return "推"
        case .upperPull: return "拉"
        case .lowerQuad: return "蹲"
        case .lowerPosterior: return "鉸鏈"
        }
    }
}
