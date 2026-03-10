import SwiftUI
import SwiftData
import UserNotifications

struct AlertsView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive
    @Environment(\.scenePhase) private var scenePhase

    @State private var notificationsAuthorized: Bool? = nil
    @State private var scheduledCount = 0
    @State private var animateCards = false
    @State private var showScheduledConfirmation = false
    @State private var isScheduling = false

    // MARK: - Data

    private var upcomingAlerts: [UpcomingAlert] {
        let allSchedules = portfolios
            .flatMap(\.holdings)
            .compactMap { holding -> (holding: Holding, schedule: DividendSchedule)? in
                guard let stock = holding.stock else { return nil }
                guard let next = stock.dividendSchedules
                    .filter({ $0.isUpcoming })
                    .sorted(by: { $0.exDate < $1.exDate })
                    .first else { return nil }
                return (holding, next)
            }

        // Deduplicate by ticker — merge shares across portfolios
        var mergedByTicker: [String: UpcomingAlert] = [:]
        for pair in allSchedules {
            let ticker = pair.holding.stock?.ticker ?? "—"
            if var existing = mergedByTicker[ticker] {
                existing.shares += pair.holding.shares
                mergedByTicker[ticker] = existing
            } else {
                mergedByTicker[ticker] = UpcomingAlert(
                    ticker: ticker,
                    companyName: pair.holding.stock?.companyName ?? "",
                    exDate: pair.schedule.exDate,
                    payDate: pair.schedule.payDate,
                    amountPerShare: pair.schedule.amountPerShare,
                    shares: pair.holding.shares,
                    frequency: pair.schedule.frequency
                )
            }
        }

        let today = Calendar.current.startOfDay(for: .now)
        return mergedByTicker.values
            .filter { Calendar.current.startOfDay(for: $0.exDate) >= today }
            .sorted { $0.exDate < $1.exDate }
    }

    var body: some View {
        let alerts = upcomingAlerts
        let totalIncome = alerts.reduce(Decimal.zero) { $0 + $1.estimatedPayment }
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: .now)) ?? .now
        let weekCount = alerts.filter { cal.startOfDay(for: $0.exDate) < weekEnd }.count

        ScrollView {
            VStack(spacing: 16) {
                if alerts.isEmpty {
                    emptyState
                } else {
                    summaryCard(alerts: alerts, totalIncome: totalIncome, weekCount: weekCount)
                    notificationBanner(alertCount: alerts.count)
                    timelineCard(alerts: alerts)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.large)
        .task { await checkNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await checkNotificationStatus() }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No Upcoming Ex-Dates")
                .font(.title3.bold())
            Text("Upcoming ex-dividend dates will appear here when dividend schedules are available for your holdings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    // MARK: - Summary Card

    private func summaryCard(alerts: [UpcomingAlert], totalIncome: Decimal, weekCount: Int) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming Dividends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(totalIncome, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("estimated income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Summary ring
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: animateCards ? min(CGFloat(weekCount) / max(CGFloat(alerts.count), 1), 1) : 0)
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateCards)
                    VStack(spacing: 0) {
                        Text("\(weekCount)")
                            .font(.title3.bold())
                            .monospacedDigit()
                        Text("this week")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Quick stats
            HStack(spacing: 0) {
                QuickStat(
                    icon: "calendar.badge.clock",
                    label: "Total",
                    value: "\(alerts.count)",
                    color: .accentColor
                )
                Spacer()
                QuickStat(
                    icon: "dollarsign.circle",
                    label: "Per Event",
                    value: (totalIncome / Decimal(alerts.count)).formatted(.currency(code: "USD")),
                    color: .green
                )
                Spacer()
                QuickStat(
                    icon: "calendar",
                    label: "Next",
                    value: alerts.first.map { $0.exDate.formatted(.dateTime.month(.abbreviated).day()) } ?? "—",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .onAppear {
            guard !animateCards else { return }
            animateCards = true
        }
    }

    // MARK: - Notification Banner

    @ViewBuilder
    private func notificationBanner(alertCount: Int) -> some View {
        if notificationsAuthorized == false {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications Disabled")
                        .font(.subheadline.bold())
                    Text("Enable notifications to get reminders before ex-dividend dates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Enable") { openSettings() }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        } else if notificationsAuthorized == true {
            Button(action: scheduleAllNotifications) {
                HStack(spacing: 10) {
                    Image(systemName: showScheduledConfirmation ? "checkmark.circle.fill" : "bell.badge.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(showScheduledConfirmation
                             ? "\(scheduledCount) Reminders Scheduled"
                             : scheduledCount > 0
                             ? "Reschedule \(alertCount) Reminders"
                             : "Schedule \(alertCount) Reminders")
                            .font(.subheadline.bold())
                        Text("Get notified on each pay date at 9:00 AM")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    if isScheduling {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.6)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(showScheduledConfirmation ? Color.green : Color.accentColor)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isScheduling)
            .animation(.easeInOut(duration: 0.3), value: showScheduledConfirmation)
        }
    }

    // MARK: - Timeline Card

    private func timelineCard(alerts: [UpcomingAlert]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ex-Date Timeline")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                AlertTimelineRow(
                    alert: alert,
                    service: massive.service,
                    isLast: index == alerts.count - 1,
                    animateCards: animateCards,
                    animationDelay: min(Double(index) * 0.06, 0.5)
                )
            }
        }
        .padding(.bottom)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
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
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                notificationsAuthorized = granted
            } catch {
                notificationsAuthorized = false
            }
            return
        @unknown default:
            notificationsAuthorized = nil
        }
    }

    private func scheduleAllNotifications() {
        guard !isScheduling else { return }
        isScheduling = true

        let schedules = upcomingAlerts
        let center = UNUserNotificationCenter.current()
        Task {
            center.removeAllPendingNotificationRequests()

            var count = 0
            for alert in schedules.prefix(64) {
                guard !Task.isCancelled else { break }
                var components = Calendar.current.dateComponents([.year, .month, .day], from: alert.payDate)
                components.hour = 9
                components.minute = 0

                let content = UNMutableNotificationContent()
                content.title = "Dividend Paid: \(alert.ticker)"
                content.body = "You received \(alert.estimatedPayment.formatted(.currency(code: "USD"))) from \(alert.ticker)"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "paydate-\(alert.id)",
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

            guard !Task.isCancelled else { return }
            await MainActor.run {
                isScheduling = false
                scheduledCount = count
                showScheduledConfirmation = true
            }
            do {
                try await Task.sleep(for: .seconds(3))
                await MainActor.run { showScheduledConfirmation = false }
            } catch {
                // Cancelled — don't touch state
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Timeline Row

private struct AlertTimelineRow: View {
    let alert: UpcomingAlert
    let service: any MassiveFetching
    let isLast: Bool
    let animateCards: Bool
    let animationDelay: Double

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: alert.exDate)).day ?? 0
    }

    private var urgencyColor: Color {
        if daysUntil == 0 { return .red }
        if daysUntil <= 3 { return .orange }
        if daysUntil <= 7 { return .yellow }
        return .green
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animateCards ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6).delay(animationDelay),
                        value: animateCards
                    )
                if !isLast {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Main row
                HStack(spacing: 10) {
                    CompanyLogoView(
                        branding: nil,
                        ticker: alert.ticker,
                        service: service,
                        size: 36
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(alert.ticker)
                                .font(.headline)
                            urgencyBadge
                        }
                        if !alert.companyName.isEmpty {
                            Text(alert.companyName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(alert.estimatedPayment, format: .currency(code: "USD"))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("\(alert.shares.formatted()) shares")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Date details
                HStack(spacing: 16) {
                    dateDetail(
                        icon: "calendar.badge.exclamationmark",
                        label: "Ex-Date",
                        date: alert.exDate,
                        highlight: true
                    )
                    dateDetail(
                        icon: "banknote",
                        label: "Pay Date",
                        date: alert.payDate,
                        highlight: false
                    )
                    Spacer()
                    if alert.amountPerShare > 0 {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Per Share")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(alert.amountPerShare, format: .currency(code: "USD"))
                                .font(.caption.bold())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 46) // align with text (36 logo + 10 spacing)

                if !isLast {
                    Divider()
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.ticker), ex-dividend \(alert.exDate.formatted(date: .abbreviated, time: .omitted)), estimated payment \(alert.estimatedPayment.formatted(.currency(code: "USD")))")
    }

    private var urgencyBadge: some View {
        Text(daysUntil == 0 ? "Today" : daysUntil == 1 ? "Tomorrow" : "in \(daysUntil)d")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(urgencyColor.opacity(0.15))
            .foregroundStyle(urgencyColor)
            .clipShape(Capsule())
    }

    private func dateDetail(icon: String, label: String, date: Date, highlight: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(highlight ? urgencyColor : Color.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption.bold())
                    .foregroundStyle(highlight ? .primary : .secondary)
            }
        }
    }
}

// MARK: - Quick Stat

private struct QuickStat: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Data Model

private struct UpcomingAlert: Identifiable {
    let ticker: String
    let companyName: String
    let exDate: Date
    let payDate: Date
    let amountPerShare: Decimal
    var shares: Decimal
    let frequency: DividendFrequency

    var id: String { "\(ticker)-\(Int(exDate.timeIntervalSince1970))" }
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
