import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            DividendCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            HoldingsView()
                .tabItem {
                    Label("Holdings", systemImage: "square.stack")
                }
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return MainTabView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
