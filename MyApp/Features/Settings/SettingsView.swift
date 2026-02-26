import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput: String = ""
    @State private var expenseTargetInput: String = ""
    @State private var showAPIKey = false
    @State private var expenseInputIsInvalid = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section {
                    apiKeyRow
                } header: {
                    Text("Market Data")
                } footer: {
                    Text("Required for live stock prices and dividend data. Get a free key at polygon.io.")
                }

                Section {
                    expenseTargetRow
                } header: {
                    Text("Income Goal")
                } footer: {
                    Text("Your target monthly dividend income. Used to calculate coverage on the Dashboard.")
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
                apiKeyInput = settings.polygonAPIKey
                expenseTargetInput = settings.monthlyExpenseTarget > 0
                    ? NSDecimalNumber(decimal: settings.monthlyExpenseTarget).stringValue
                    : ""
            }
            .onDisappear {
                commitAPIKey()
                commitExpenseTarget()
            }
        }
    }

    // MARK: - Rows

    private var apiKeyRow: some View {
        HStack {
            if showAPIKey {
                TextField("Paste API key", text: $apiKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { commitAPIKey() }
                    .accessibilityLabel("Polygon API key")
            } else {
                SecureField("Paste API key", text: $apiKeyInput)
                    .onSubmit { commitAPIKey() }
                    .accessibilityLabel("Polygon API key")
            }

            Button {
                showAPIKey.toggle()
            } label: {
                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showAPIKey ? "Hide API key" : "Show API key")

            if !apiKeyInput.isEmpty {
                Button {
                    apiKeyInput = ""
                    commitAPIKey()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear API key")
            }
        }
    }

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

    private func commitAPIKey() {
        settings.polygonAPIKey = apiKeyInput
    }

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
