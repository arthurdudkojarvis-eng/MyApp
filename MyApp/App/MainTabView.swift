import SwiftUI

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
    MainTabView()
        .environment(SettingsStore())
}
