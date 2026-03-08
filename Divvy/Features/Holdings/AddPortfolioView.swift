import SwiftUI
import SwiftData

struct AddPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @FocusState private var nameFieldFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Dividend Growth", text: $name)
                        .focused($nameFieldFocused)
                        .autocorrectionDisabled()
                        .onSubmit { if isValid { save() } }
                        .accessibilityLabel("Portfolio name")
                } header: {
                    Text("Name")
                }
            }
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!isValid)
                        .accessibilityLabel("Add portfolio")
                }
            }
            .onAppear { nameFieldFocused = true }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        modelContext.insert(Portfolio(name: trimmedName))
        dismiss()
    }
}

#Preview {
    AddPortfolioView()
        .modelContainer(.preview)
}
