import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 今日命令中心 (DashboardView)
public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var storedSessions: [SDWorkoutSession]
    @Query(sort: \SDDailyNutritionEntry.timestamp, order: .reverse) private var storedNutritionEntries: [SDDailyNutritionEntry]
    
    @State private var decision: DailyDecision?
    @State private var weeklySummary: WeeklyHybridSummary?
    @State private var isShowingQuickLog: Bool = false
    @State private var isShowingRoutineLibrary: Bool = false
    @State private var selectedTemplateForQuickLog: WorkoutRoutineTemplate? = nil
    @State private var isShowingAlternates: Bool = false
    @State private var isShowingAudit: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var scheduleStatusMessage: String?
    @State private var isShowingNutritionDetail: Bool = false
    
    // AI 食物視覺辨識與自訂精確輸入狀態
    @State private var isShowingCameraPicker: Bool = false
    @State private var cameraPickerSource: UIImagePickerController.SourceType = .camera
    @State private var isShowingSourceDialog: Bool = false
    @State private var isAnalyzingFood: Bool = false
    @State private var capturedFoodImage: UIImage? = nil
    @State private var activeFoodRecognitionResult: FoodRecognitionResult? = nil
    @State private var isShowingPreciseEntrySheet: Bool = false
    @State private var prefillPreciseEntryData: PreciseEntryPrefillData? = nil
    private let foodVisionAdapter = GeminiFoodVisionAdapter()
    
    @State private var nutritionModel: NutritionCapsuleViewModel = NutritionCapsuleViewModel(
        consumedKcal: 0,
        targetKcal: 2650,
        proteinGrams: 0,
        targetProteinGrams: 140,
        carbsGrams: 0,
        targetCarbsGrams: 280,
        mealsLoggedCount: 0,
        dayType: .heavyStrength,
        goal: .maximizeHypertrophy
    )
    
    private let healthKitAdapter: HealthKitAdapter
    private let workoutKitAdapter: WorkoutKitAdapter
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter(), workoutKitAdapter: WorkoutKitAdapter = WorkoutKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
        self.workoutKitAdapter = workoutKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 頂部狀態藥丸
                        if let decision = decision {
                            StatusCapsuleView(decision: decision)
                        } else {
                            ProgressView()
                                .tint(Color(hex: "58A6FF"))
                                .padding(.vertical, 8)
                        }
                        
                        // 1.5 今日微型營養補給膠囊
                        NutritionCapsuleView(
                            model: nutritionModel,
                            phase: FuelingPhaseResolver.resolve(
                                dayType: nutritionModel.dayType,
                                mealsLogged: nutritionModel.mealsLoggedCount
                            ),
                            onOpenDetail: {
                                isShowingNutritionDetail = true
                            },
                            onTriggerCamera: {
                                isShowingSourceDialog = true
                            },
                            onTriggerCustomEntry: {
                                prefillPreciseEntryData = nil
                                isShowingPreciseEntrySheet = true
                            },
                            onQuickAddProtein: {
                                nutritionModel = NutritionCapsuleViewModel(
                                    consumedKcal: nutritionModel.consumedKcal + 130,
                                    targetKcal: nutritionModel.targetKcal,
                                    proteinGrams: nutritionModel.proteinGrams + 30,
                                    targetProteinGrams: nutritionModel.targetProteinGrams,
                                    carbsGrams: nutritionModel.carbsGrams + 2,
                                    targetCarbsGrams: nutritionModel.targetCarbsGrams,
                                    mealsLoggedCount: nutritionModel.mealsLoggedCount + 1,
                                    dayType: nutritionModel.dayType,
                                    goal: nutritionModel.goal
                                )
                            },
                            onQuickAddCarb: {
                                nutritionModel = NutritionCapsuleViewModel(
                                    consumedKcal: nutritionModel.consumedKcal + 210,
                                    targetKcal: nutritionModel.targetKcal,
                                    proteinGrams: nutritionModel.proteinGrams + 3,
                                    targetProteinGrams: nutritionModel.targetProteinGrams,
                                    carbsGrams: nutritionModel.carbsGrams + 50,
                                    targetCarbsGrams: nutritionModel.targetCarbsGrams,
                                    mealsLoggedCount: nutritionModel.mealsLoggedCount + 1,
                                    dayType: nutritionModel.dayType,
                                    goal: nutritionModel.goal
                                )
                            },
                            onQuickAddWater: {
                                // 快速記錄水份
                            }
                        )
                        
                        // 2. 週週期雙軌平衡環 (耐力/肌力/模式三重環)
                        if let summary = weeklySummary {
                            WeeklyRingsCardView(summary: summary)
                        }

                        // 3. 今日推薦主卡片 (支援自由選用跑步/阻力/交叉方案)
                        if let decision = decision {
                            DailyHeroCardView(
                                workout: decision.primaryRecommendation,
                                runningOption: decision.todayRunningOption,
                                strengthOption: decision.todayStrengthOption,
                                crossOption: decision.todayCrossTrainingOption,
                                isLockedDueToFatigue: decision.primaryRecommendation.isLockedDueToFatigue,
                                onScheduleToWatch: { selectedWorkout in
                                    scheduleWorkout(selectedWorkout)
                                },
                                onSelectAlternates: {
                                    isShowingAlternates = true
                                }
                            )
                        }
                        
                        // 4. 4 大動作模式冷卻時鐘
                        if let decision = decision {
                            MuscleCooldownCardView(cooldowns: decision.cooldowns)
                        }
                        
                        // 5. 排程狀態提示
                        if let message = scheduleStatusMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "3FB950"))
                                Text(message)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hex: "161B22"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 90) // 預留底部雙按鈕高度
                }
                
                // 6. 底部常駐雙操作鈕 (常用課表庫 + 15 秒打卡)
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            isShowingRoutineLibrary = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                Text("常用課表")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color(hex: "161B22"))
                            .foregroundColor(Color(hex: "58A6FF"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "30363D"), lineWidth: 1)
                            )
                        }

                        Button {
                            selectedTemplateForQuickLog = nil
                            isShowingQuickLog = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("記錄訓練 (15 秒快速打卡)")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "3FB950"))
                            .foregroundColor(Color(hex: "090C10"))
                            .cornerRadius(12)
                            .shadow(color: Color(hex: "3FB950").opacity(0.3), radius: 10, y: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "090C10").opacity(0.0), Color(hex: "090C10").opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationTitle("Hybrid Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentDateString)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "8B949E"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            isShowingAudit = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "stethoscope")
                                Text("探針")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "0A84FF"))
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(healthKitAdapter: healthKitAdapter)
            }
            .sheet(isPresented: $isShowingQuickLog) {
                QuickLogSheet(initialTemplate: selectedTemplateForQuickLog) {
                    selectedTemplateForQuickLog = nil
                    refreshDailyDecision()
                }
            }
            .sheet(isPresented: $isShowingRoutineLibrary) {
                RoutineLibrarySheet { selectedTemplate in
                    selectedTemplateForQuickLog = selectedTemplate
                    isShowingQuickLog = true
                }
            }
            .sheet(isPresented: $isShowingAudit) {
                SpikeAuditView(healthKitAdapter: healthKitAdapter)
            }
            .sheet(isPresented: $isShowingAlternates) {
                alternatesSheet
            }
            .sheet(isPresented: $isShowingNutritionDetail) {
                NutritionDetailSheet(
                    model: $nutritionModel,
                    onTriggerCamera: {
                        isShowingSourceDialog = true
                    },
                    onTriggerCustomEntry: {
                        prefillPreciseEntryData = nil
                        isShowingPreciseEntrySheet = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog("記錄飲食方式", isPresented: $isShowingSourceDialog, titleVisibility: .visible) {
                Button("拍攝餐點照片") {
                    cameraPickerSource = .camera
                    isShowingCameraPicker = true
                }
                Button("從相簿選擇照片") {
                    cameraPickerSource = .photoLibrary
                    isShowingCameraPicker = true
                }
                Button("手動精細輸入 (熱量/蛋白質)") {
                    prefillPreciseEntryData = nil
                    isShowingPreciseEntrySheet = true
                }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isShowingCameraPicker) {
                CameraPickerView(sourceType: cameraPickerSource) { captured in
                    handleImageCaptured(captured)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingPreciseEntrySheet) {
                if let prefill = prefillPreciseEntryData {
                    PreciseNutritionEntrySheet(
                        initialFoodName: prefill.foodName,
                        initialCalories: prefill.calories,
                        initialProtein: prefill.protein,
                        initialCarbs: prefill.carbs,
                        initialFat: prefill.fat,
                        initialPortion: prefill.portion,
                        initialCategory: prefill.category,
                        athleteNote: prefill.notes,
                        photoImage: capturedFoodImage
                    ) { item, category in
                        commitSinglePreciseEntry(item, category: category)
                    }
                } else {
                    PreciseNutritionEntrySheet(
                        initialFoodName: "",
                        initialCalories: 0,
                        initialProtein: 0,
                        initialCarbs: 0,
                        initialFat: 0,
                        initialPortion: "1份",
                        initialCategory: .lunch,
                        athleteNote: nil,
                        photoImage: nil
                    ) { item, category in
                        commitSinglePreciseEntry(item, category: category)
                    }
                }
            }
            .sheet(item: Binding(
                get: { activeFoodRecognitionResult.map { IdentifiableRecognitionResult(result: $0) } },
                set: { activeFoodRecognitionResult = $0?.result }
            )) { identifiable in
                FoodRecognitionReviewSheet(
                    initialResult: identifiable.result,
                    capturedImage: capturedFoodImage
                ) { confirmedResult in
                    commitNutritionResult(confirmedResult)
                }
            }
            .overlay {
                if isAnalyzingFood {
                    ZStack {
                        Color.black.opacity(0.65).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .tint(Color(hex: "58A6FF"))
                                .scaleEffect(1.4)
                            Text("AI 正在分析餐點熱量與蛋白質...")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("請稍候，多模態視覺處理中")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                        .padding(24)
                        .background(Color(hex: "161B22"))
                        .cornerRadius(16)
                    }
                }
            }
            .task {
                refreshDailyDecision()
            }
        }
    }
    
    // MARK: - 換課備選視圖
    private var alternatesSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        Text("運動學互補安全備選")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8B949E"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let decision = decision, !decision.safeAlternates.isEmpty {
                            ForEach(decision.safeAlternates) { alt in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(alt.title)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(alt.estimatedDurationMinutes))m · \(Int(alt.estimatedLoadAU)) AU")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "58A6FF"))
                                    }
                                    Text(alt.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "8B949E"))
                                    
                                    Button {
                                        scheduleWorkout(alt)
                                        isShowingAlternates = false
                                    } label: {
                                        Text("選用並推播至手錶")
                                            .font(.system(size: 12, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(hex: "21262D"))
                                            .foregroundColor(Color(hex: "58A6FF"))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(14)
                                .background(Color(hex: "161B22"))
                                .cornerRadius(10)
                            }
                        } else {
                            Text("目前無其他安全備選課表")
                                .foregroundColor(Color(hex: "8B949E"))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("換課選單")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 業務邏輯觸發
    private func refreshDailyDecision() {
        Task {
            let calendar = Calendar.current
            let now = Date()
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            
            // 1. 抓取 HealthKit Workouts
            let hkWorkouts = (try? await healthKitAdapter.fetchWorkouts(from: sixtyDaysAgo, to: now)) ?? []
            
            // 2. 轉換本機 SwiftData sessions
            let localSessions = storedSessions.map { $0.toDomain() }
            
            // 3. 執行 SmartMerge 智慧合併
            let mergedSessions = SmartMergeEngine.processAndDeduplicate(sessions: hkWorkouts + localSessions)
            
            // 4. 取得當日晨間生理快照
            let snapshot = (try? await healthKitAdapter.fetchPhysiologicalSnapshot(date: now)) ?? PhysiologicalSnapshot(sleepDurationHours: 7.5)
            
            // 5. 執行政策仲裁引擎
            let evaluatedDecision = TrainingPolicyEngine.evaluateDailyDecision(
                history: mergedSessions,
                snapshot: snapshot,
                now: now,
                calendar: calendar,
                configuration: .default
            )
            
            // 6. 計算週週期雙軌平衡環指標
            let evaluatedWeeklySummary = WeeklyHybridSummary.calculate(
                sessions: mergedSessions,
                referenceDate: now,
                calendar: calendar
            )
            
            await MainActor.run {
                self.decision = evaluatedDecision
                self.weeklySummary = evaluatedWeeklySummary
            }
        }
    }
    
    private func scheduleWorkout(_ workout: RecommendedWorkout) {
        Task {
            let result = try? await workoutKitAdapter.scheduleWorkout(workout: workout, at: Date())
            await MainActor.run {
                switch result {
                case .scheduled:
                    self.scheduleStatusMessage = "課表「\(workout.title)」已推播至 Apple Watch！"
                case .pendingSync:
                    self.scheduleStatusMessage = "課表已就緒，等待手錶藍牙同步。"
                case .failed(let reason):
                    self.scheduleStatusMessage = "推播失敗: \(reason)"
                case .none:
                    self.scheduleStatusMessage = "已將課表排程至今日清單。"
                }
            }
        }
    }
    
    private func handleImageCaptured(_ image: UIImage) {
        self.capturedFoodImage = image
        self.isAnalyzingFood = true
        
        Task {
            // 壓縮至適合視覺 API 分析之 JPEG
            let resized = image.resized(maxDimension: 1024)
            let imageData = resized.jpegData(compressionQuality: 0.8) ?? Data()
            
            do {
                let result = try await foodVisionAdapter.recognizeFood(imageData: imageData, mimeType: "image/jpeg")
                await MainActor.run {
                    self.isAnalyzingFood = false
                    self.activeFoodRecognitionResult = result
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzingFood = false
                    // 容錯保底彈出
                    self.activeFoodRecognitionResult = FoodRecognitionResult(
                        items: [
                            FoodItemPrediction(
                                foodName: "運動員均衡餐點",
                                estimatedPortion: "1標準份",
                                calories: 450,
                                proteinGrams: 35,
                                carbsGrams: 45,
                                fatGrams: 12,
                                confidence: 0.7,
                                reasoning: "離線保底估算"
                            )
                        ],
                        athleteAdvice: "建議微調實際攝取量。"
                    )
                }
            }
        }
    }
    
    private func commitNutritionResult(_ result: FoodRecognitionResult) {
        // 若為單一食物辨識結果，直接打開精細面板讓運動員審閱並可直接手動輸入
        if let first = result.items.first {
            self.prefillPreciseEntryData = PreciseEntryPrefillData(
                foodName: first.foodName,
                portion: first.estimatedPortion,
                calories: first.calories,
                protein: first.proteinGrams,
                carbs: first.carbsGrams,
                fat: first.fatGrams,
                category: .lunch,
                notes: result.athleteAdvice ?? first.reasoning
            )
            self.isShowingPreciseEntrySheet = true
            return
        }

        // 1. 寫入 SwiftData
        for item in result.items {
            let entry = SDDailyNutritionEntry(
                foodName: item.foodName,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                mealTypeRaw: "ai_vision",
                notes: item.reasoning
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        
        // 2. 更新儀表板 UI ViewModel
        nutritionModel = NutritionCapsuleViewModel(
            consumedKcal: nutritionModel.consumedKcal + result.totalCalories,
            targetKcal: nutritionModel.targetKcal,
            proteinGrams: nutritionModel.proteinGrams + result.totalProteinGrams,
            targetProteinGrams: nutritionModel.targetProteinGrams,
            carbsGrams: nutritionModel.carbsGrams + result.totalCarbsGrams,
            targetCarbsGrams: nutritionModel.targetCarbsGrams,
            mealsLoggedCount: nutritionModel.mealsLoggedCount + 1,
            dayType: nutritionModel.dayType,
            goal: nutritionModel.goal
        )
    }

    private func commitSinglePreciseEntry(_ item: FoodItemPrediction, category: MealCategory) {
        let entry = SDDailyNutritionEntry(
            foodName: item.foodName,
            calories: item.calories,
            proteinGrams: item.proteinGrams,
            carbsGrams: item.carbsGrams,
            fatGrams: item.fatGrams,
            mealTypeRaw: category.rawValue,
            notes: item.reasoning
        )
        modelContext.insert(entry)
        try? modelContext.save()

        nutritionModel = NutritionCapsuleViewModel(
            consumedKcal: nutritionModel.consumedKcal + item.calories,
            targetKcal: nutritionModel.targetKcal,
            proteinGrams: nutritionModel.proteinGrams + item.proteinGrams,
            targetProteinGrams: nutritionModel.targetProteinGrams,
            carbsGrams: nutritionModel.carbsGrams + item.carbsGrams,
            targetCarbsGrams: nutritionModel.targetCarbsGrams,
            mealsLoggedCount: nutritionModel.mealsLoggedCount + 1,
            dayType: nutritionModel.dayType,
            goal: nutritionModel.goal
        )
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter.string(from: Date())
    }
}

// MARK: - 輔助預填資料模型
struct PreciseEntryPrefillData: Identifiable {
    let id = UUID()
    let foodName: String
    let portion: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let category: MealCategory
    let notes: String
}

// MARK: - 輔助 Identifiable 包裝
struct IdentifiableRecognitionResult: Identifiable {
    let id = UUID()
    let result: FoodRecognitionResult
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let currentMax = max(size.width, size.height)
        guard currentMax > maxDimension else { return self }
        let scale = maxDimension / currentMax
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
