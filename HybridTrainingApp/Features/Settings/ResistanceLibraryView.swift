import SwiftUI
import HybridTrainingCore

/// 阻力訓練動作庫瀏覽檢視 (ResistanceLibraryView)
public struct ResistanceLibraryView: View {
    @State private var searchText: String = ""
    @State private var selectedPattern: MovementPattern? = nil
    @State private var selectedEquipment: EquipmentType? = nil
    
    private let allExercises: [ResistanceExercise] = ResistanceExerciseBank.allExercises
    
    public init() {}
    
    public var body: some View {
        ZStack {
            HybridTheme.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 搜尋列
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(HybridTheme.textSecondary)
                    TextField("搜尋動作名稱、肌群、器材或英文...", text: $searchText)
                        .foregroundColor(HybridTheme.textPrimary)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                    }
                }
                .padding(10)
                .background(HybridTheme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                )
                .padding(.horizontal, 16)
                
                // 動作模式快速篩選 Chip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        patternChip(nil, title: "全部部位")
                        patternChip(.lowerQuad, title: "下肢深蹲")
                        patternChip(.lowerPosterior, title: "下肢硬舉")
                        patternChip(.upperPush, title: "上半身推")
                        patternChip(.upperPull, title: "上半身拉")
                    }
                    .padding(.horizontal, 16)
                }

                // 器材種類快速篩選 Chip (Free Weight vs Machine)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        equipmentChip(nil, title: "全部器材")
                        equipmentChip(.barbell, title: "槓鈴 (Barbell)")
                        equipmentChip(.dumbbell, title: "啞鈴 (Dumbbell)")
                        equipmentChip(.machine, title: "固定器械 (Machine)")
                        equipmentChip(.cable, title: "滑輪纜繩 (Cable)")
                        equipmentChip(.bodyweight, title: "自重 (Bodyweight)")
                    }
                    .padding(.horizontal, 16)
                }
                
                // 列表
                let currentList = computeFilteredExercises()
                
                List {
                    ForEach(currentList) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(exercise.name)
                                    .font(HybridTheme.Typography.cardTitle)
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                                Text(patternName(exercise.pattern))
                                    .font(HybridTheme.Typography.badge)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(patternColor(exercise.pattern).opacity(0.18))
                                    .foregroundColor(patternColor(exercise.pattern))
                                    .cornerRadius(6)
                            }
                            
                            Text(exercise.englishName)
                                .font(HybridTheme.Typography.subheadline)
                                .foregroundColor(HybridTheme.textSecondary)
                            
                            HStack(spacing: 6) {
                                Image(systemName: equipmentIcon(exercise.equipment))
                                    .font(HybridTheme.Typography.badge)
                                    .foregroundColor(HybridTheme.accentBlue)
                                Text(exercise.equipment.displayName)
                                    .font(HybridTheme.Typography.badge)
                                    .foregroundColor(HybridTheme.accentBlue)
                                
                                Text("•")
                                    .foregroundColor(HybridTheme.textSecondary)
                                
                                Text(exercise.primaryMuscles.joined(separator: ", "))
                                    .font(HybridTheme.Typography.badge)
                                    .foregroundColor(HybridTheme.textSecondary)

                                Text("•")
                                    .foregroundColor(HybridTheme.textSecondary)

                                Text("休 \(exercise.defaultRestSeconds)s")
                                    .font(HybridTheme.Typography.badge.weight(.semibold))
                                    .foregroundColor(HybridTheme.successGreen)
                            }
                            
                            if !exercise.techniqueCues.isEmpty {
                                Text("💡 " + exercise.techniqueCues)
                                    .font(HybridTheme.Typography.subheadline)
                                    .foregroundColor(HybridTheme.energyOrange)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(HybridTheme.cardBackground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.top, 8)
        }
        .navigationTitle("阻力訓練動作庫")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func computeFilteredExercises() -> [ResistanceExercise] {
        var result = allExercises
        if let pattern = selectedPattern {
            result = result.filter { $0.pattern == pattern }
        }
        if let equipment = selectedEquipment {
            result = result.filter { $0.equipment == equipment }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = ResistanceExerciseBank.search(query: searchText)
            if let pattern = selectedPattern {
                result = result.filter { $0.pattern == pattern }
            }
            if let equipment = selectedEquipment {
                result = result.filter { $0.equipment == equipment }
            }
        }
        return result
    }
    
    private func patternChip(_ pattern: MovementPattern?, title: String) -> some View {
        let isSelected = selectedPattern == pattern
        return Button {
            selectedPattern = pattern
        } label: {
            Text(title)
                .font(HybridTheme.Typography.badge.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? HybridTheme.accentBlue : HybridTheme.surfaceElevated)
                .foregroundColor(isSelected ? .white : HybridTheme.textPrimary)
                .cornerRadius(16)
        }
    }

    private func equipmentChip(_ eq: EquipmentType?, title: String) -> some View {
        let isSelected = selectedEquipment == eq
        return Button {
            selectedEquipment = eq
        } label: {
            Text(title)
                .font(HybridTheme.Typography.badge.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? HybridTheme.successGreen : HybridTheme.surfaceElevated)
                .foregroundColor(isSelected ? .white : HybridTheme.textPrimary)
                .cornerRadius(16)
        }
    }
    
    private func patternName(_ p: MovementPattern) -> String {
        switch p {
        case .lowerQuad: return "下肢深蹲"
        case .lowerPosterior: return "下肢硬舉"
        case .upperPush: return "上半身推"
        case .upperPull: return "上半身拉"
        }
    }
    
    private func patternColor(_ p: MovementPattern) -> Color {
        switch p {
        case .lowerQuad: return HybridTheme.dangerRed
        case .lowerPosterior: return HybridTheme.energyOrange
        case .upperPush: return HybridTheme.accentBlue
        case .upperPull: return HybridTheme.successGreen
        }
    }
    
    private func equipmentIcon(_ eq: EquipmentType) -> String {
        switch eq {
        case .barbell: return "scalemass.fill"
        case .dumbbell: return "dumbbell.fill"
        case .cable: return "cable.connector"
        case .machine: return "gearshape.2.fill"
        case .bodyweight: return "figure.walk"
        }
    }
}
