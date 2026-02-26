import SwiftUI
import SwiftData

// MARK: - Payment total helper (internal for testing)

/// Total dividend payment amount across holdings.
/// Each holding's amount = shares × amountPerShare.
func logPaymentTotal(sharesPerHolding: [Decimal], amountPerShare: Decimal) -> Decimal {
    sharesPerHolding.reduce(0) { $0 + $1 * amountPerShare }
}

// MARK: - LogPaymentView

struct LogPaymentView: View {
    let schedule: DividendSchedule

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @Query(sort: \Holding.purchaseDate) private var allHoldings: [Holding]

    @State private var receivedDate: Date
    @State private var reinvested           = false
    @State private var withholdingText      = ""
    @State private var isSaving             = false
    @State private var showSaveError        = false
    @State private var saveErrorMessage     = ""

    @FocusState private var withholdingFocused: Bool

    init(schedule: DividendSchedule) {
        self.schedule = schedule
        _receivedDate = State(initialValue: schedule.payDate)
    }

    // Holdings that belong to this schedule's stock.
    private var relevantHoldings: [Holding] {
        guard let stockId = schedule.stock?.persistentModelID else { return [] }
        return allHoldings.filter { $0.stock?.persistentModelID == stockId }
    }

    private var total: Decimal {
        logPaymentTotal(
            sharesPerHolding: relevantHoldings.map(\.shares),
            amountPerShare: schedule.amountPerShare
        )
    }

    /// Parses withholding tax text, normalising the locale decimal separator to "."
    /// so that `.decimalPad` input works on comma-decimal locales (e.g. French, German).
    private var withholdingTax: Decimal? {
        guard !withholdingText.isEmpty else { return nil }
        let normalized = withholdingText.replacingOccurrences(
            of: Locale.current.decimalSeparator ?? ",",
            with: "."
        )
        return Decimal(string: normalized)
    }

    private var isWithholdingValid: Bool {
        withholdingText.isEmpty || withholdingTax != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Per-holding breakdown
                Section("Holdings") {
                    if relevantHoldings.isEmpty {
                        Text("No holdings found for this stock.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(relevantHoldings) { holding in
                            HoldingPaymentRow(
                                holding: holding,
                                amountPerShare: schedule.amountPerShare
                            )
                        }
                        LabeledContent("Total") {
                            Text(total, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }
                    }
                }

                // MARK: Payment options
                Section {
                    DatePicker(
                        "Received on",
                        selection: $receivedDate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    Toggle("Reinvested (DRIP)", isOn: $reinvested)
                        .accessibilityLabel("Reinvested via Dividend Reinvestment Plan")
                }

                // MARK: Withholding tax
                Section("Withholding Tax") {
                    TextField("Optional — e.g. 3.50", text: $withholdingText)
                        .keyboardType(.decimalPad)
                        .focused($withholdingFocused)
                    if !isWithholdingValid {
                        Text("Enter a valid number")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(relevantHoldings.isEmpty || isSaving || !isWithholdingValid)
                        .accessibilityLabel(isSaving ? "Saving" : "Save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { withholdingFocused = false }
                }
            }
        }
        .alert("Could not Save Payment", isPresented: $showSaveError) {
            Button("OK") { showSaveError = false }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        // Capture status so we can roll back if the save fails.
        let previousStatus = schedule.status

        for holding in relevantHoldings {
            let payment = DividendPayment(
                sharesAtTime:   holding.shares,
                totalAmount:    holding.shares * schedule.amountPerShare,
                receivedDate:   receivedDate,
                reinvested:     reinvested,
                withholdingTax: withholdingTax
            )
            payment.holding          = holding
            payment.dividendSchedule = schedule
            modelContext.insert(payment)
        }
        schedule.status = .paid

        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Roll back the in-memory status mutation so the row remains actionable.
            schedule.status  = previousStatus
            saveErrorMessage = error.localizedDescription
            showSaveError    = true
            isSaving         = false
        }
    }
}

// MARK: - HoldingPaymentRow

private struct HoldingPaymentRow: View {
    let holding: Holding
    let amountPerShare: Decimal

    private var amount: Decimal { holding.shares * amountPerShare }
    private var ticker: String  { holding.stock?.ticker ?? "—" }

    var body: some View {
        LabeledContent {
            Text(amount, format: .currency(code: "USD"))
                .foregroundStyle(.secondary)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker)
                    .font(.subheadline)
                Text("\(holding.shares.formatted()) shares")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(ticker), \(holding.shares.formatted()) shares, " +
            "\(amount.formatted(.currency(code: "USD")))"
        )
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview

    let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    container.mainContext.insert(stock)

    let holding = Holding(shares: 100, averageCostBasis: 150)
    holding.stock = stock
    container.mainContext.insert(holding)

    let schedule = DividendSchedule(
        frequency: .quarterly,
        amountPerShare: Decimal(string: "0.25")!,
        exDate: .now,
        payDate: .now,
        status: .declared
    )
    schedule.stock = stock
    container.mainContext.insert(schedule)

    return LogPaymentView(schedule: schedule)
        .modelContainer(container)
}
