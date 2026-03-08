import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var expenseTargetInput: String = ""
    @State private var expenseInputIsInvalid = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section {
                    expenseTargetRow
                } header: {
                    Text("Income Goal")
                } footer: {
                    Text("Your target monthly dividend income. Used to calculate coverage on the Dashboard.")
                }

                Section {
                    Toggle("Weekly Investor Quotes", isOn: $settings.weeklyQuotesEnabled)
                        .onChange(of: settings.weeklyQuotesEnabled) { _, _ in
                            scheduleWeeklyQuoteNotification()
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive a motivational investing quote every Monday at 9:00 AM")
                }

                Section("Appearance") {
                    Picker("Color Scheme", selection: $settings.colorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Color scheme")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Theme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) {
                            ForEach(FontTheme.allCases.filter { $0 != .defaultTheme }) { theme in
                                let fill = theme.color ?? Color(.systemGray4)
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(fill)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if settings.fontTheme == theme {
                                                Circle()
                                                    .strokeBorder(fill, lineWidth: 2.5)
                                                    .frame(width: 46, height: 46)
                                            }
                                        }
                                        .frame(width: 46, height: 46)
                                    Text(theme.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel(theme.label)
                                .onTapGesture {
                                    settings.fontTheme = theme
                                }
                            }
                        }
                    }
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                expenseTargetInput = settings.monthlyExpenseTarget > 0
                    ? NSDecimalNumber(decimal: settings.monthlyExpenseTarget).stringValue
                    : ""
            }
            .onDisappear {
                commitExpenseTarget()
            }
        }
    }

    // MARK: - Rows

    private var expenseTargetRow: some View {
        HStack {
            Text("Monthly Target")
            Spacer()
            HStack(spacing: 2) {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0", text: $expenseTargetInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 60)
                    .foregroundStyle(expenseInputIsInvalid ? .red : .primary)
                    .accessibilityLabel("Monthly income target")
                    .onChange(of: expenseTargetInput) { _, new in
                        if new.isEmpty {
                            expenseInputIsInvalid = false
                        } else if let decimal = Decimal(string: new), decimal >= 0 {
                            expenseInputIsInvalid = false
                            settings.monthlyExpenseTarget = decimal
                        } else {
                            expenseInputIsInvalid = true
                        }
                    }
            }
        }
    }

    // MARK: - Weekly Quote Notification

    private func scheduleWeeklyQuoteNotification() {
        let center = UNUserNotificationCenter.current()
        let identifier = "weekly-quote"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard settings.weeklyQuotesEnabled else { return }

        Task {
            let notifSettings = await center.notificationSettings()
            if notifSettings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            }

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

    // MARK: - Helpers

    private func commitExpenseTarget() {
        guard !expenseTargetInput.isEmpty,
              let decimal = Decimal(string: expenseTargetInput), decimal >= 0 else { return }
        settings.monthlyExpenseTarget = decimal
    }
}

#Preview {
    SettingsView()
        .environment(SettingsStore())
}
