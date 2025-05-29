import SwiftUI
import SwiftData

@main
struct Lumi_LightApp: App {
    @StateObject private var llmService = LlmInferenceService()
    @StateObject private var userData = UserData.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConversationSession.self,
            ChatMessageModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(llmService)
                .environmentObject(userData)
        }
        .modelContainer(sharedModelContainer)
    }
}
