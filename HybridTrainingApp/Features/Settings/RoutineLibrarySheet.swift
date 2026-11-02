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
                HybridTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 我的自訂課表
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("我的自訂課表 (\(storedCustomRoutines.count))")
                                    .font(HybridTheme.Typography.cardTitle)
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Button {
                                    isShowingEditor = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("新增課表")
                                    }
                                    .font(HybridTheme.Typography.badge.weight(.bold))
                                    .foregroundColor(HybridTheme.accentBlue)
                                }
                            }

                            if storedCustomRoutines.isEmpty {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundColor(HybridTheme.textSecondary)
                                    Text("尚未建立自訂課表，點擊右上角新增您專屬的訓練排程。")
                                        .font(HybridTheme.Typography.subheadline)
                                        .foregroundColor(HybridTheme.textSecondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HybridTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                                )
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
                                .font(HybridTheme.Typography.cardTitle)
                                .foregroundColor(HybridTheme.accentBlue)

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
                        .foregroundColor(HybridTheme.textSecondary)
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
                    .font(HybridTheme.Typography.cardTitle)
                    .foregroundColor(HybridTheme.textPrimary)

                if template.isBuiltIn {
                    Text("官方推薦")
                        .font(HybridTheme.Typography.badge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HybridTheme.accentBlue.opacity(0.15))
                        .foregroundColor(HybridTheme.accentBlue)
                        .cornerRadius(6)
                }

                Spacer()

                if isDeletable, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(HybridTheme.dangerRed)
                    }
                }
            }

            // 涵蓋動作模式標籤
            HStack(spacing: 6) {
                ForEach(template.targetPatterns, id: \.self) { pattern in
                    Text(patternDisplayName(pattern))
                        .font(HybridTheme.Typography.badge)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(HybridTheme.surfaceElevated)
                        .foregroundColor(HybridTheme.textSecondary)
                        .cornerRadius(6)
                }

                Spacer()

                Text("\(template.exercises.count)動作 · \(template.totalTargetSets)組 · \(Int(template.estimatedDurationMinutes))分")
                    .font(HybridTheme.Typography.chartAxis)
                    .foregroundColor(HybridTheme.textSecondary)
            }

            // 動作清單摘要
            VStack(alignment: .leading, spacing: 6) {
                ForEach(template.exercises.prefix(3)) { item in
                    HStack {
                        Circle()
                            .fill(HybridTheme.accentBlue)
                            .frame(width: 5, height: 5)
                        Text(item.exerciseName)
                            .font(HybridTheme.Typography.subheadline)
                            .foregroundColor(HybridTheme.textPrimary)
                        Spacer()
                        Text("\(item.targetSets)組 x \(item.targetReps)次")
                            .font(HybridTheme.Typography.chartAxis)
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                }
                if template.exercises.count > 3 {
                    Text("...及其他 \(template.exercises.count - 3) 個動作")
                        .font(HybridTheme.Typography.chartAxis)
                        .foregroundColor(HybridTheme.textSecondary)
                        .padding(.leading, 10)
                }
            }
            .padding(10)
            .background(HybridTheme.surfaceElevated.opacity(0.5))
            .cornerRadius(8)

            if !template.notes.isEmpty {
                Text(template.notes)
                    .font(HybridTheme.Typography.subheadline)
                    .foregroundColor(HybridTheme.textSecondary)
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
                .font(HybridTheme.Typography.badge.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(HybridTheme.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(HybridTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
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
