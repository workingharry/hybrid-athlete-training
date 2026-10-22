import SwiftUI
import SwiftData
import HybridTrainingStorage

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
            fatalError("無法建立 SwiftData ModelContainer: \(error)")
        }
    }()

    @AppStorage("app_theme_mode") private var themeModeRaw: String = AppThemeMode.system.rawValue

    private var currentColorScheme: ColorScheme? {
        AppThemeMode(rawValue: themeModeRaw)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(currentColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
