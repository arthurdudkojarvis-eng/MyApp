import SwiftUI
import UIKit

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

                Section("Appearance") {
                    Picker("Color Scheme", selection: $settings.colorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Color scheme")
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
