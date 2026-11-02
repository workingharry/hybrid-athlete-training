import SwiftUI
import SwiftData
import HybridTrainingCore
import HybridTrainingStorage

/// 今日命令中心 (DashboardView)
public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var circadianOutcome: CircadianPlanOutcome? = nil
    @State private var isShowingCircadianDetail: Bool = false
    
    // AI 食物視覺辨識與自訂精確輸入狀態
    @State private var isShowingCameraPicker: Bool = false
    @State private var cameraPickerSource: UIImagePickerController.SourceType = .camera
    @State private var isShowingSourceDialog: Bool = false
    @State private var isAnalyzingFood: Bool = false
    @State private var capturedFoodImage: UIImage? = nil
    @State private var activeFoodRecognitionResult: FoodRecognitionResult? = nil
    @State private var isShowingPreciseEntrySheet: Bool = false
    @State private var prefillPreciseEntryData: PreciseEntryPrefillData? = nil
    @State private var editingNutritionEntry: SDDailyNutritionEntry? = nil
    private let foodVisionAdapter = OpenRouterFoodVisionAdapter()
    
    private var todayNutritionEntries: [SDDailyNutritionEntry] {
        let calendar = Calendar.current
        let todayKey = TrainingDayKey(date: Date(), calendar: calendar).dateString
        return storedNutritionEntries.filter {
            TrainingDayKey(date: $0.timestamp, calendar: calendar).dateString == todayKey
        }
    }

    private var currentDayType: TrainingDayType {
        guard let recommendation = decision?.primaryRecommendation else {
            return .heavyStrength
        }
        switch recommendation.discipline {
        case .running:
            if recommendation.estimatedDurationMinutes >= 60 || recommendation.runningType == .longRun {
                return .longRun
            } else {
                return .easyRunZone2
            }
        case .strength:
            return .heavyStrength
        case .cycling, .swimming, .rowing:
            return .twoADaySession
        case .mobility, .rest:
            return .activeRest
        }
    }

    private var activeMacroTarget: MacroTarget {
        HybridNutritionEngine.calculateDailyTarget(
            bmr: 1650.0,
            weightKg: 70.0,
            fatFreeMassKg: 60.0,
            dayType: currentDayType,
            goal: .maximizeHypertrophy
        )
    }

    private var currentNutritionViewModel: NutritionCapsuleViewModel {
        let entries = todayNutritionEntries
        let totalKcal = entries.reduce(0.0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0.0) { $0 + $1.proteinGrams }
        let totalCarbs = entries.reduce(0.0) { $0 + $1.carbsGrams }
        let target = activeMacroTarget

        return NutritionCapsuleViewModel(
            consumedKcal: totalKcal,
            targetKcal: target.calories,
            proteinGrams: totalProtein,
            targetProteinGrams: target.proteinGrams,
            carbsGrams: totalCarbs,
            targetCarbsGrams: target.carbsGrams,
            mealsLoggedCount: entries.count,
            dayType: currentDayType,
            goal: .maximizeHypertrophy
        )
    }
    
    private let healthKitAdapter: HealthKitAdapter
    private let workoutKitAdapter: WorkoutKitAdapter
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter(), workoutKitAdapter: WorkoutKitAdapter = WorkoutKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
        self.workoutKitAdapter = workoutKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 頂部狀態藥丸
                        if let decision = decision {
                            StatusCapsuleView(decision: decision)
                        } else {
                            ProgressView()
                                .tint(HybridTheme.accentBlue)
                                .padding(.vertical, 8)
                        }
                        
                        // 1.5 今日微型營養補給膠囊
                        NutritionCapsuleView(
                            model: currentNutritionViewModel,
                            phase: FuelingPhaseResolver.resolve(
                                dayType: currentDayType,
                                mealsLogged: todayNutritionEntries.count
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
                                addQuickNutritionEntry(
                                    name: "快捷補充高蛋白 (乳清/雞胸)",
                                    kcal: 130,
                                    protein: 30,
                                    carbs: 2,
                                    fat: 1,
                                    category: "訓練加餐"
                                )
                            },
                            onQuickAddCarb: {
                                addQuickNutritionEntry(
                                    name: "快捷補充碳水 (香蕉/能量棒)",
                                    kcal: 210,
                                    protein: 3,
                                    carbs: 50,
                                    fat: 1,
                                    category: "訓練加餐"
                                )
                            },
                            onQuickAddWater: {
                                addQuickNutritionEntry(
                                    name: "運動補水 500ml",
                                    kcal: 0,
                                    protein: 0,
                                    carbs: 0,
                                    fat: 0,
                                    category: "水份補給"
                                )
                            }
                        )
                        
                        // 1.8 今日晝夜精力節律卡片
                        if let circadianOutcome = circadianOutcome {
                            CircadianEnergyCurveCardView(
                                outcome: circadianOutcome,
                                onTapDetail: {
                                    isShowingCircadianDetail = true
                                },
                                onLogCaffeine: { mg in
                                    logQuickCaffeine(mg: mg)
                                }
                            )
                        }
                        
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
                                    .foregroundColor(HybridTheme.successGreen)
                                Text(message)
                                    .font(HybridTheme.Typography.subheadline.weight(.semibold))
                                    .foregroundColor(HybridTheme.textPrimary)
                                Spacer()
                            }
                            .padding(14)
                            .background(HybridTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 96) // 預留底部雙按鈕高度
                }
                
                // 6. 底部常駐雙操作鈕 (常用課表庫 + 15 秒打卡)
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            isShowingRoutineLibrary = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                Text("常用課表")
                            }
                            .font(HybridTheme.Typography.body.weight(.semibold))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(HybridTheme.cardBackground)
                            .foregroundColor(HybridTheme.accentBlue)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(HybridTheme.cardBorder, lineWidth: 1)
                            )
                        }

                        Button {
                            selectedTemplateForQuickLog = nil
                            isShowingQuickLog = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("記錄訓練 (15 秒打卡)")
                            }
                            .font(HybridTheme.Typography.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(HybridTheme.successGreen)
                            .foregroundColor(Color.white)
                            .cornerRadius(14)
                            .shadow(color: HybridTheme.successGreen.opacity(0.35), radius: 10, y: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [HybridTheme.background.opacity(0.0), HybridTheme.background.opacity(0.95)],
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
                            .font(HybridTheme.Typography.badge.weight(.semibold))
                            .foregroundColor(HybridTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            isShowingAudit = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "stethoscope")
                                Text("探針")
                            }
                            .font(HybridTheme.Typography.subheadline.weight(.semibold))
                            .foregroundColor(HybridTheme.accentBlue)
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundColor(HybridTheme.textSecondary)
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
                    model: currentNutritionViewModel,
                    onTriggerCamera: {
                        isShowingSourceDialog = true
                    },
                    onTriggerCustomEntry: {
                        editingNutritionEntry = nil
                        prefillPreciseEntryData = nil
                        isShowingPreciseEntrySheet = true
                    },
                    onTriggerEditEntry: { entry in
                        editingNutritionEntry = entry
                        let cat = MealCategory(rawValue: entry.mealTypeRaw) ?? .lunch
                        prefillPreciseEntryData = PreciseEntryPrefillData(
                            foodName: entry.foodName,
                            portion: "1份",
                            calories: entry.calories,
                            protein: entry.proteinGrams,
                            carbs: entry.carbsGrams,
                            fat: entry.fatGrams,
                            caffeineMg: entry.caffeineMg,
                            category: cat,
                            notes: entry.notes
                        )
                        isShowingPreciseEntrySheet = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingCircadianDetail) {
                if let circadianOutcome = circadianOutcome {
                    CircadianScheduleDetailSheet(outcome: circadianOutcome)
                }
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
                        initialCaffeineMg: prefill.caffeineMg,
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
                        initialCaffeineMg: 0,
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
                                .tint(HybridTheme.accentBlue)
                                .scaleEffect(1.4)
                            Text("AI 正在分析餐點熱量與蛋白質...")
                                .font(HybridTheme.Typography.cardTitle)
                                .foregroundColor(HybridTheme.textPrimary)
                            Text("請稍候，多模態視覺處理中")
                                .font(HybridTheme.Typography.subheadline)
                                .foregroundColor(HybridTheme.textSecondary)
                        }
                        .padding(24)
                        .background(HybridTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(HybridTheme.cardBorder, lineWidth: 0.8)
                        )
                    }
                }
            }
            .task {
                refreshDailyDecision()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthKitBackgroundSyncDidUpdate)) { _ in
                refreshDailyDecision()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshDailyDecision()
                }
            }
        }
    }
    
    // MARK: - 換課備選視圖
    private var alternatesSheet: some View {
        NavigationStack {
            ZStack {
                HybridTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        Text("運動學互補安全備選")
                            .font(HybridTheme.Typography.subheadline)
                            .foregroundColor(HybridTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let decision = decision, !decision.safeAlternates.isEmpty {
                            ForEach(decision.safeAlternates) { alt in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(alt.title)
                                            .font(HybridTheme.Typography.cardTitle)
                                            .foregroundColor(HybridTheme.textPrimary)
                                        Spacer()
                                        Text("\(Int(alt.estimatedDurationMinutes))m · \(Int(alt.estimatedLoadAU)) AU")
                                            .font(HybridTheme.Typography.chartAxis.weight(.bold))
                                            .foregroundColor(HybridTheme.accentBlue)
                                    }
                                    Text(alt.subtitle)
                                        .font(HybridTheme.Typography.subheadline)
                                        .foregroundColor(HybridTheme.textSecondary)
                                    
                                    Button {
                                        scheduleWorkout(alt)
                                        isShowingAlternates = false
                                    } label: {
                                        Text("選用並推播至手錶")
                                            .font(HybridTheme.Typography.badge.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(HybridTheme.surfaceElevated)
                                            .foregroundColor(HybridTheme.accentBlue)
                                            .cornerRadius(8)
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
                        } else {
                            Text("目前無其他安全備選課表")
                                .font(HybridTheme.Typography.subheadline)
                                .foregroundColor(HybridTheme.textSecondary)
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
            
            // 7. 計算晝夜精力節律排程 (結合 HealthKit 清醒時間、習慣作息、睡眠債、睡眠結構、真實歷史睡眠與咖啡因攝取)
            let circadianInputs = await healthKitAdapter.fetchCircadianInputs(targetDate: now)
            let circadianEngine = CircadianRhythmEngine()
            
            // 查詢過去 36 小時體內未完全代謝之咖啡因攝取 (Bateman 藥物動力學疊加)
            let relevantCaffeineIntakes: [CaffeineIntakeDose] = storedNutritionEntries
                .filter { $0.caffeineMg > 0 && $0.timestamp >= now.addingTimeInterval(-36 * 3600) && $0.timestamp <= now.addingTimeInterval(24 * 3600) }
                .map { entry in
                    CaffeineIntakeDose(
                        id: entry.id,
                        timestamp: entry.timestamp,
                        milligrams: entry.caffeineMg,
                        sourceName: entry.foodName
                    )
                }
            
            let evaluatedCircadian = circadianEngine.plan(
                todayWake: circadianInputs.todayWake,
                habitualWake: circadianInputs.habitualWake,
                sleepDebtHours: circadianInputs.sleepDebtHours,
                deepSleepHours: snapshot.deepSleepHours,
                remSleepHours: snapshot.remSleepHours,
                daylightMinutes: circadianInputs.daylightMinutes,
                recentWorkouts: mergedSessions,
                readiness: snapshot.biomarkerAssessment,
                wristTemperatureDeviation: snapshot.biomarkerAssessment?.wristTemperatureBaselineDeltaCelsius,
                caffeineIntakes: relevantCaffeineIntakes,
                recentSleepRecords: circadianInputs.recentSleepRecords,
                targetDate: now,
                calendar: calendar
            )
            
            await MainActor.run {
                self.decision = evaluatedDecision
                self.weeklySummary = evaluatedWeeklySummary
                self.circadianOutcome = evaluatedCircadian
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
                caffeineMg: first.caffeineMg,
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
                notes: item.reasoning,
                caffeineMg: item.caffeineMg
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        refreshDailyDecision()
    }

    private func commitSinglePreciseEntry(_ item: FoodItemPrediction, category: MealCategory) {
        if let existing = editingNutritionEntry {
            existing.foodName = item.foodName
            existing.calories = item.calories
            existing.proteinGrams = item.proteinGrams
            existing.carbsGrams = item.carbsGrams
            existing.fatGrams = item.fatGrams
            existing.caffeineMg = item.caffeineMg
            existing.mealTypeRaw = category.rawValue
            existing.notes = item.reasoning
            try? modelContext.save()
            editingNutritionEntry = nil
        } else {
            let entry = SDDailyNutritionEntry(
                foodName: item.foodName,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                mealTypeRaw: category.rawValue,
                notes: item.reasoning,
                caffeineMg: item.caffeineMg
            )
            modelContext.insert(entry)
            try? modelContext.save()
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        refreshDailyDecision()
    }

    private func logQuickCaffeine(mg: Double) {
        let entry = SDDailyNutritionEntry(
            foodName: "快捷補充咖啡因 (\(Int(mg))mg)",
            calories: 5,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            mealTypeRaw: "水份補給",
            notes: "快捷記錄",
            caffeineMg: mg
        )
        modelContext.insert(entry)
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        refreshDailyDecision()
    }

    private func addQuickNutritionEntry(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, category: String, caffeineMg: Double = 0.0) {
        let entry = SDDailyNutritionEntry(
            foodName: name,
            calories: kcal,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            mealTypeRaw: category,
            notes: "快捷記錄",
            caffeineMg: caffeineMg
        )
        modelContext.insert(entry)
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        refreshDailyDecision()
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
    let caffeineMg: Double
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
