import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.myapp.MyApp",
                            category: "AddHoldingView")

struct AddHoldingView: View {
    let portfolio: Portfolio
    var initialTicker: String = ""

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StockRefreshService.self) private var stockRefresh

    @State private var ticker: String = ""
    @State private var sharesText: String = ""
    @State private var costBasisText: String = ""
    @State private var purchaseDate: Date = .now

    @FocusState private var focusedField: Field?

    private enum Field { case ticker, shares, costBasis }

    // MARK: - Derived state

    private var trimmedTicker: String {
        ticker.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private var sharesDecimal: Decimal? {
        Decimal(string: sharesText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var costBasisDecimal: Decimal? {
        Decimal(string: costBasisText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var isValid: Bool {
        !trimmedTicker.isEmpty && sharesDecimal != nil && costBasisDecimal != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("AAPL", text: $ticker)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .ticker)
                        .onChange(of: ticker) { _, new in ticker = new.uppercased() }
                        .accessibilityLabel("Ticker symbol")
                } header: {
                    Text("Ticker")
                }

                Section {
                    TextField("100", text: $sharesText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .shares)
                        .accessibilityLabel("Number of shares")
                } header: {
                    Text("Shares")
                }

                Section {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $costBasisText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .costBasis)
                            .accessibilityLabel("Cost basis per share")
                    }
                } header: {
                    Text("Cost Basis per Share")
                }

                Section {
                    DatePicker(
                        "Purchase Date",
                        selection: $purchaseDate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Add Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!isValid)
                        .accessibilityLabel("Add holding")
                }
            }
            .onAppear {
                if !initialTicker.isEmpty { ticker = initialTicker }
                focusedField = initialTicker.isEmpty ? .ticker : .shares
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard isValid,
              let shares = sharesDecimal,
              let costBasis = costBasisDecimal else { return }

        let stock: Stock
        if let existing = existingStock(ticker: trimmedTicker) {
            stock = existing
        } else {
            stock = Stock(ticker: trimmedTicker)
            modelContext.insert(stock)
        }

        let holding = Holding(
            shares: shares,
            averageCostBasis: costBasis,
            purchaseDate: purchaseDate
        )
        holding.portfolio = portfolio
        holding.stock = stock
        modelContext.insert(holding)

        let tickerToRefresh = trimmedTicker
        dismiss()

        Task { await stockRefresh.refresh(ticker: tickerToRefresh) }
    }

    private func existingStock(ticker: String) -> Stock? {
        let descriptor = FetchDescriptor<Stock>(
            predicate: #Predicate<Stock> { $0.ticker == ticker }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch stock for ticker \(ticker): \(error.localizedDescription)")
            return nil
        }
    }
}

#Preview {
    let container = ModelContainer.preview
    let portfolio = Portfolio(name: "Preview Portfolio")
    container.mainContext.insert(portfolio)
    let settings = SettingsStore()
    return AddHoldingView(portfolio: portfolio)
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
