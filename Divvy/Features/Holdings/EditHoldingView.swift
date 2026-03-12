import SwiftUI

struct EditHoldingView: View {
    let holding: Holding

    @Environment(\.dismiss) private var dismiss

    @State private var sharesText: String = ""
    @State private var costBasisText: String = ""
    @State private var purchaseDate: Date = .now

    @FocusState private var focusedField: Field?
    private enum Field { case shares, costBasis }

    private var sharesDecimal: Decimal? {
        Decimal(string: sharesText).flatMap { $0 > 0 ? $0 : nil }
    }
    private var costBasisDecimal: Decimal? {
        Decimal(string: costBasisText).flatMap { $0 > 0 ? $0 : nil }
    }
    private var isValid: Bool { sharesDecimal != nil && costBasisDecimal != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0", text: $sharesText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .shares)
                        .accessibilityLabel("Number of shares")
                } header: { Text("Shares") }

                Section {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $costBasisText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .costBasis)
                            .accessibilityLabel("Cost basis per share")
                    }
                } header: { Text("Cost Basis per Share") }

                Section {
                    DatePicker(
                        "Purchase Date",
                        selection: $purchaseDate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityLabel("Save changes")
                }
            }
            .onAppear {
                // Use description (POSIX locale, period separator) so Decimal(string:)
                // round-trips correctly in all locales.
                sharesText = holding.shares.description
                costBasisText = holding.averageCostBasis.description
                purchaseDate = holding.purchaseDate
                focusedField = .shares
            }
        }
    }

    private func save() {
        guard let shares = sharesDecimal, let costBasis = costBasisDecimal else { return }
        holding.shares = shares
        holding.averageCostBasis = costBasis
        holding.purchaseDate = purchaseDate
        holding.isManuallyConfigured = true
        dismiss()
    }
}

#Preview {
    let holding = Holding(shares: 10, averageCostBasis: 150)
    return EditHoldingView(holding: holding)
}
