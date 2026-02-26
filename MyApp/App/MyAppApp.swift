import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(.app)
    }
}
