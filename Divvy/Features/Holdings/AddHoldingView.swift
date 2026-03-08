import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                            category: "AddHoldingView")

struct AddHoldingView: View {
    let portfolio: Portfolio
    var initialTicker: String = ""

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive
    @Environment(StockRefreshService.self) private var stockRefresh

    @State private var ticker: String = ""
    @State private var sharesText: String = ""
    @State private var purchaseDate: Date = .now
    @State private var currentPrice: Decimal?
    @State private var isFetchingPrice: Bool = false
    @State private var priceFetchTask: Task<Void, Never>?

    @FocusState private var focusedField: Field?

    private enum Field { case ticker, shares }

    // MARK: - Derived state

    private var trimmedTicker: String {
        ticker.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private var sharesDecimal: Decimal? {
        Decimal(string: sharesText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var isValid: Bool {
        !trimmedTicker.isEmpty && sharesDecimal != nil && (currentPrice ?? 0) > 0
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
                        .onChange(of: ticker) { _, new in
                            ticker = new.uppercased()
                            fetchPrice(for: new)
                        }
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
                        Text("Current Price")
                        Spacer()
                        if isFetchingPrice {
                            ProgressView()
                        } else if let price = currentPrice, price > 0 {
                            Text(price, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        } else if !trimmedTicker.isEmpty {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Current price")

                    if let price = currentPrice, price > 0, let shares = sharesDecimal {
                        HStack {
                            Text("Total Cost")
                            Spacer()
                            Text(shares * price, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
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
                if !initialTicker.isEmpty {
                    ticker = initialTicker
                    fetchPrice(for: initialTicker)
                }
                focusedField = initialTicker.isEmpty ? .ticker : .shares
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard isValid,
              let shares = sharesDecimal,
              let price = currentPrice else { return }

        let stock: Stock
        if let existing = existingStock(ticker: trimmedTicker) {
            stock = existing
        } else {
            stock = Stock(ticker: trimmedTicker)
            modelContext.insert(stock)
        }

        let holding = Holding(
            shares: shares,
            averageCostBasis: price,
            purchaseDate: purchaseDate
        )
        holding.portfolio = portfolio
        holding.stock = stock
        modelContext.insert(holding)

        let tickerToRefresh = trimmedTicker
        try? modelContext.save()
        dismiss()

        Task { await stockRefresh.refresh(ticker: tickerToRefresh) }
    }

    private func fetchPrice(for rawTicker: String) {
        priceFetchTask?.cancel()
        let cleaned = rawTicker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !cleaned.isEmpty else {
            currentPrice = nil
            isFetchingPrice = false
            return
        }

        // Check if stock already exists in DB with a valid price
        if let existing = existingStock(ticker: cleaned), existing.currentPrice > 0 {
            currentPrice = existing.currentPrice
            return
        }

        let service = massive.service
        priceFetchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            isFetchingPrice = true
            defer { isFetchingPrice = false }

            do {
                let price = try await service.fetchPreviousClose(ticker: cleaned)
                guard !Task.isCancelled else { return }
                currentPrice = price
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Failed to fetch price for \(cleaned): \(error.localizedDescription)")
                currentPrice = nil
            }
        }
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
        .environment(StockRefreshService(container: container))
}
