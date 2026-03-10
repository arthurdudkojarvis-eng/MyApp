import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        let tintColor = settings.fontTheme.color ?? Color.accentColor
        TabView(selection: $settings.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)

            PortfoliosView()
                .tabItem {
                    Label("Portfolios", systemImage: "briefcase")
                }
                .tag(1)

            StockBrowserView()
                .tabItem {
                    Label("Stocks", systemImage: "magnifyingglass")
                }
                .tag(2)

            ETFBrowserView()
                .tabItem {
                    Label("ETFs", systemImage: "chart.pie")
                }
                .tag(3)

            CryptoBrowserView()
                .tabItem {
                    Label("Crypto", systemImage: "bitcoinsign.circle")
                }
                .tag(4)
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
