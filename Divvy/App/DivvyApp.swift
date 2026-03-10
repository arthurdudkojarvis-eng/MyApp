import SwiftUI
import SwiftData
import UserNotifications

@main
struct DivvyApp: App {
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
                        if settings.weeklyQuotesEnabled {
                            rescheduleWeeklyQuote()
                        }
                    }
                }
        }
        .modelContainer(.app)
    }

    private func rescheduleWeeklyQuote() {
        let center = UNUserNotificationCenter.current()
        let identifier = "weekly-quote"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        Task {
            let quote = investingQuotes.randomElement()!
            let content = UNMutableNotificationContent()
            content.title = "Weekly Investor Quote"
            content.subtitle = quote.author
            content.body = quote.text
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.weekday = 2  // Monday
            dateComponents.hour = 9
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
