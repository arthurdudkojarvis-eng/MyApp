import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            PortfoliosView()
                .tabItem {
                    Label("Portfolios", systemImage: "briefcase")
                }

            StockBrowserView()
                .tabItem {
                    Label("Stocks", systemImage: "magnifyingglass")
                }

            ETFBrowserView()
                .tabItem {
                    Label("ETFs", systemImage: "chart.pie")
                }

            DividendCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
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
