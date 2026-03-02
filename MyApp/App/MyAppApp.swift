import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @State private var settings: SettingsStore
    @State private var stockRefresh: StockRefreshService

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let s = SettingsStore()
        _settings = State(initialValue: s)
        _stockRefresh = State(initialValue: StockRefreshService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(stockRefresh)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await stockRefresh.refreshStaleStocks() }
                    }
                }
        }
        .modelContainer(.app)
    }
}
