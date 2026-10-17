import SwiftUI
import HybridTrainingCore

/// 阻力訓練動作庫瀏覽檢視 (ResistanceLibraryView)
public struct ResistanceLibraryView: View {
    @State private var searchText: String = ""
    @State private var selectedPattern: MovementPattern? = nil
    
    private let allExercises: [ResistanceExercise] = ResistanceExerciseBank.allExercises
    
    public init() {}
    
    private var filteredExercises: [ResistanceExercise] = []
    
    public var body: some View {
        ZStack {
            Color(hex: "090C10").ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 搜尋列
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "8B949E"))
                    TextField("搜尋動作名稱、肌群或英文...", text: $searchText)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "161B22"))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                
                // 動作模式快速篩選 Chip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        patternChip(nil, title: "全部動作")
                        patternChip(.lowerQuad, title: "下肢深蹲")
                        patternChip(.lowerPosterior, title: "下肢硬舉")
                        patternChip(.upperPush, title: "上半身推")
                        patternChip(.upperPull, title: "上半身拉")
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
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(patternName(exercise.pattern))
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(patternColor(exercise.pattern).opacity(0.18))
                                    .foregroundColor(patternColor(exercise.pattern))
                                    .cornerRadius(4)
                            }
                            
                            Text(exercise.englishName)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B949E"))
                            
                            HStack(spacing: 6) {
                                Image(systemName: equipmentIcon(exercise.equipment))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "58A6FF"))
                                Text(exercise.equipment.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "58A6FF"))
                                
                                Text("•")
                                    .foregroundColor(Color(hex: "8B949E"))
                                
                                Text(exercise.primaryMuscles.joined(separator: ", "))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                            
                            if !exercise.techniqueCues.isEmpty {
                                Text("💡 " + exercise.techniqueCues)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "D29922"))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color(hex: "161B22"))
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
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = ResistanceExerciseBank.search(query: searchText)
            if let pattern = selectedPattern {
                result = result.filter { $0.pattern == pattern }
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
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(hex: "58A6FF") : Color(hex: "21262D"))
                .foregroundColor(isSelected ? Color(hex: "090C10") : Color(hex: "C9D1D9"))
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
        case .lowerQuad: return Color(hex: "F85149")
        case .lowerPosterior: return Color(hex: "D29922")
        case .upperPush: return Color(hex: "58A6FF")
        case .upperPull: return Color(hex: "3FB950")
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
