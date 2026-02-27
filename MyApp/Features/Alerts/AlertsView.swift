import SwiftUI
import SwiftData
import UserNotifications

struct AlertsView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    @State private var notificationsAuthorized: Bool? = nil
    @State private var scheduledCount = 0

    private var upcomingSchedules: [UpcomingAlert] {
        let allSchedules = portfolios
            .flatMap(\.holdings)
            .compactMap { holding -> (holding: Holding, schedule: DividendSchedule)? in
                guard let stock = holding.stock else { return nil }
                guard let next = stock.dividendSchedules.filter({ $0.isUpcoming }).sorted(by: { $0.exDate < $1.exDate }).first else { return nil }
                return (holding, next)
            }
        return allSchedules
            .map { pair in
                UpcomingAlert(
                    ticker: pair.holding.stock?.ticker ?? "—",
                    companyName: pair.holding.stock?.companyName ?? "",
                    exDate: pair.schedule.exDate,
                    payDate: pair.schedule.payDate,
                    amountPerShare: pair.schedule.amountPerShare,
                    shares: pair.holding.shares
                )
            }
            .filter { Calendar.current.startOfDay(for: $0.exDate) >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.exDate < $1.exDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                notificationPermissionBanner
                if upcomingSchedules.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Ex-Dates",
                        systemImage: "bell",
                        description: Text("Upcoming ex-dividend dates will appear here when dividend schedules are available for your holdings.")
                    )
                    .padding(.top, 40)
                } else {
                    scheduleCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.large)
        .task { await checkNotificationStatus() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notificationPermissionBanner: some View {
        if notificationsAuthorized == false {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications Disabled")
                        .font(.subheadline.bold())
                    Text("Enable notifications in Settings to receive ex-dividend date reminders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Enable") {
                    openSettings()
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.1))
            )
        } else if notificationsAuthorized == true, !upcomingSchedules.isEmpty {
            Button(action: scheduleAllNotifications) {
                Label(
                    scheduledCount > 0
                        ? "Reschedule \(upcomingSchedules.count) Reminders"
                        : "Schedule \(upcomingSchedules.count) Reminders",
                    systemImage: "bell.badge"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upcoming Ex-Dividend Dates")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ForEach(upcomingSchedules) { alert in
                AlertRow(alert: alert)
                if alert.id != upcomingSchedules.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Notification Helpers

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            notificationsAuthorized = true
        case .denied:
            notificationsAuthorized = false
        case .notDetermined:
            // Request permission
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                notificationsAuthorized = granted
            } catch {
                notificationsAuthorized = false
            }
            return
        @unknown default:
            notificationsAuthorized = false
        }
    }

    private func scheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let schedules = upcomingSchedules
        Task {
            var count = 0
            for alert in schedules {
                // Schedule a notification 1 day before ex-date at 9 AM
                let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: alert.exDate) ?? alert.exDate
                var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                components.hour = 9
                components.minute = 0

                let content = UNMutableNotificationContent()
                content.title = "Ex-Dividend Tomorrow: \(alert.ticker)"
                content.body = "You must own \(alert.ticker) by today to receive \(alert.estimatedPayment.formatted(.currency(code: "USD")))."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "exdate-\(alert.ticker)-\(Int(alert.exDate.timeIntervalSince1970))",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                    count += 1
                } catch {
                    // Individual notification failed — continue scheduling the rest
                }
            }
            await MainActor.run { scheduledCount = count }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    let alert: UpcomingAlert

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(alert.ticker).font(.headline)
                    daysLabel
                }
                if !alert.companyName.isEmpty {
                    Text(alert.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(alert.exDate, style: .date)
                    .font(.caption.bold())
                Text("Ex-Date")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(alert.estimatedPayment, format: .currency(code: "USD"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.ticker) ex-dividend \(alert.exDate.formatted(date: .abbreviated, time: .omitted)), estimated payment \(alert.estimatedPayment.formatted(.currency(code: "USD")))")
    }

    private var daysLabel: some View {
        let days = Calendar.current.dateComponents([.day], from: .now, to: alert.exDate).day ?? 0
        return Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : "in \(days)d")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(days <= 3 ? Color.orange.opacity(0.15) : Color.accentColor.opacity(0.1))
            .foregroundStyle(days <= 3 ? .orange : .accentColor)
            .clipShape(Capsule())
    }
}

// MARK: - Data model

private struct UpcomingAlert: Identifiable {
    let ticker: String
    let companyName: String
    let exDate: Date
    let payDate: Date
    let amountPerShare: Decimal
    let shares: Decimal

    var id: String { "\(ticker)-\(exDate.timeIntervalSince1970)" }
    var estimatedPayment: Decimal { amountPerShare * shares }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        AlertsView()
    }
    .modelContainer(container)
    .environment(settings)
}
