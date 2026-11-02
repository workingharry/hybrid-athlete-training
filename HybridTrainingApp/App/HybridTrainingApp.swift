import SwiftUI
import SwiftData
import HybridTrainingStorage
import HybridTrainingCore
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct HybridTrainingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SDWorkoutSession.self,
            SDRoutineTemplate.self,
            SDDailyNutritionEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ SwiftData ModelContainer 初始化失敗: \(error)，嘗試重置舊版架構資料庫...")
            let fileManager = FileManager.default
            let storeURL = modelConfiguration.url
            let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? fileManager.removeItem(at: storeURL)
            try? fileManager.removeItem(at: shmURL)
            try? fileManager.removeItem(at: walURL)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                print("🚨 重置資料庫後仍無法建立持久化 ModelContainer，降級為 InMemory 模式: \(error)")
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let memoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) {
                    return memoryContainer
                }
                fatalError("無法建立 SwiftData ModelContainer: \(error)")
            }
        }
    }()

    @AppStorage("app_theme_mode") private var themeModeRaw: String = AppThemeMode.system.rawValue

    private var currentColorScheme: ColorScheme? {
        AppThemeMode(rawValue: themeModeRaw)?.colorScheme
    }

    #if canImport(HealthKit)
    @State private var syncCoordinator: HealthKitBackgroundSyncCoordinator?
    #endif

    init() {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            let recompute = RecomputeCoordinator(debounceSeconds: 3.0) {
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                await MainActor.run {
                    NotificationCenter.default.post(name: .healthKitBackgroundSyncDidUpdate, object: nil)
                }
            }
            let coordinator = HealthKitBackgroundSyncCoordinator(coordinator: recompute)
            var sampleTypes: [HKSampleType] = [
                HKObjectType.workoutType(),
                HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            ]
            if #available(iOS 16.0, *) {
                if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                    sampleTypes.append(wristTemp)
                }
            }
            coordinator.registerAll(types: sampleTypes)
            _syncCoordinator = State(initialValue: coordinator)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(currentColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
