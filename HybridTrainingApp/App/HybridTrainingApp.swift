import SwiftUI
import SwiftData
import HybridTrainingStorage

@main
struct HybridTrainingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SDWorkoutSession.self,
            SDRoutineTemplate.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("無法建立 SwiftData ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
