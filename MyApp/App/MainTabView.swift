import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let tintColor = settings.fontTheme.color ?? Color.accentColor
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

            CryptoBrowserView()
                .tabItem {
                    Label("Crypto", systemImage: "bitcoinsign.circle")
                }
        }
        .tint(tintColor)
    }
}

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return MainTabView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}
