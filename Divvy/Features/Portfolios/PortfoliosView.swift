import SwiftUI
import SwiftData

// MARK: - PortfoliosView

struct PortfoliosView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(StockRefreshService.self) private var stockRefresh
    @State private var showAddPortfolio = false
    @State private var showStrategies = false
    @State private var portfolioToDelete: Portfolio?

    private var activePortfolioID: String {
        settings.lastActivePortfolioID
    }

    var body: some View {
        NavigationStack {
            Group {
                if portfolios.isEmpty {
                    ContentUnavailableView(
                        "No Portfolios Yet",
                        systemImage: "briefcase",
                        description: Text("Tap + to create your first portfolio.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(portfolios) { portfolio in
                                NavigationLink {
                                    PortfolioHoldingsView(portfolio: portfolio)
                                } label: {
                                    PortfolioCardView(
                                        portfolio: portfolio,
                                        isActive: portfolio.id.uuidString == activePortfolioID
                                    )
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    settings.lastActivePortfolioID = portfolio.id.uuidString
                                })
                                .contextMenu {
                                    Button(role: .destructive) {
                                        portfolioToDelete = portfolio
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                    .refreshable {
                        await stockRefresh.refreshStaleStocks(force: true)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStrategies = true
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                    .accessibilityLabel("Dividend strategies")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPortfolio = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add portfolio")
                }
            }
            .sheet(isPresented: $showAddPortfolio) {
                AddPortfolioView()
            }
            .sheet(isPresented: $showStrategies) {
                PortfolioStrategiesView()
            }
            .alert(
                "Delete Portfolio",
                isPresented: Binding(
                    get: { portfolioToDelete != nil },
                    set: { if !$0 { portfolioToDelete = nil } }
                ),
                presenting: portfolioToDelete
            ) { portfolio in
                Button("Delete", role: .destructive) {
                    modelContext.delete(portfolio)
                    if settings.lastActivePortfolioID == portfolio.id.uuidString {
                        settings.lastActivePortfolioID = ""
                    }
                    portfolioToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    portfolioToDelete = nil
                }
            } message: { portfolio in
                Text("Delete '\(portfolio.name)' and all its holdings?")
            }
            .onAppear {
                // Auto-select if only one portfolio and none selected
                if portfolios.count == 1, settings.lastActivePortfolioID.isEmpty {
                    settings.lastActivePortfolioID = portfolios[0].id.uuidString
                }
            }
            .task { await stockRefresh.refreshStaleStocks() }
        }
    }
}

// MARK: - Portfolio Card

private struct PortfolioCardView: View {
    let portfolio: Portfolio
    var isActive: Bool = false
    @Environment(SettingsStore.self) private var settings

    private var tint: Color { settings.fontTheme.color ?? Color.accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text(portfolio.name)
                    .textStyle(.cardTitle)
                    .foregroundStyle(.primary)
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Spacer()
            }

            Divider()

            // Metrics row
            HStack(spacing: 0) {
                MetricCell(
                    label: "Market Value",
                    value: portfolio.totalMarketValue > 0
                        ? portfolio.totalMarketValue.formatted(.currency(code: portfolio.currency))
                        : "—"
                )
                Spacer()
                MetricCell(
                    label: "Monthly Income",
                    value: portfolio.projectedMonthlyIncome > 0
                        ? portfolio.projectedMonthlyIncome.formatted(.currency(code: portfolio.currency))
                        : "—"
                )
                Spacer()
                PerformanceCell(portfolio: portfolio)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint, lineWidth: 2)
                .opacity(isActive ? 1 : 0)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }
}

private struct PerformanceCell: View {
    let portfolio: Portfolio

    private var gain: Decimal { portfolio.totalUnrealizedGain }
    private var gainPercent: Decimal? { portfolio.totalUnrealizedGainPercent }

    private var color: Color {
        if gain > 0 { return .green }
        if gain < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Gain / Loss")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let pct = gainPercent {
                Text(percentString(pct))
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            } else {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func percentString(_ value: Decimal) -> String {
        let prefix = value >= 0 ? "+" : ""
        let formatted = (value as NSDecimalNumber)
            .doubleValue
            .formatted(.number.precision(.fractionLength(2)))
        return "\(prefix)\(formatted)%"
    }
}

// MARK: - Portfolio Holdings (drill-down)

struct PortfolioHoldingsView: View {
    let portfolio: Portfolio
    @Environment(\.modelContext) private var modelContext
    @Environment(StockRefreshService.self) private var stockRefresh
    @State private var showAddHolding = false
    @State private var holdingToEdit: Holding?
    @State private var holdingToDelete: Holding?
    @State private var holdingForFutureValue: Holding?

    private var sortedHoldings: [Holding] {
        portfolio.holdings.sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") }
    }

    var body: some View {
        Group {
            if portfolio.holdings.isEmpty {
                ContentUnavailableView(
                    "No Holdings",
                    systemImage: "tray",
                    description: Text("Tap + to add a holding to this portfolio.")
                )
            } else {
                List {
                    Section {
                        ForEach(sortedHoldings) { holding in
                            NavigationLink {
                                if let stock = holding.stock {
                                    StockDetailView(result: MassiveTickerSearchResult(
                                        ticker: stock.ticker,
                                        name: stock.companyName,
                                        market: nil,
                                        type: nil,
                                        primaryExchange: nil
                                    ))
                                } else {
                                    ContentUnavailableView(
                                        "Stock Unavailable",
                                        systemImage: "questionmark.circle",
                                        description: Text("This holding's stock data is not yet available.")
                                    )
                                }
                            } label: {
                                PortfolioHoldingRowView(holding: holding) {
                                    holdingForFutureValue = holding
                                }
                            }
                                .contextMenu {
                                    Button {
                                        holdingToEdit = holding
                                    } label: {
                                        Label("Edit Holding", systemImage: "pencil")
                                    }
                                    Button {
                                        holdingForFutureValue = holding
                                    } label: {
                                        Label("Future Value", systemImage: "chart.line.uptrend.xyaxis")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        holdingToDelete = holding
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        holdingToEdit = holding
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        holdingToDelete = holding
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await stockRefresh.refreshStaleStocks(force: true)
                }
            }
        }
        .navigationTitle(portfolio.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddHolding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add holding")
            }
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingView(portfolio: portfolio)
        }
        .sheet(item: $holdingToEdit) { holding in
            EditHoldingView(holding: holding)
        }
        .sheet(item: $holdingForFutureValue) { holding in
            HoldingFutureValueView(holding: holding)
        }
        .alert(
            "Delete Holding",
            isPresented: Binding(
                get: { holdingToDelete != nil },
                set: { if !$0 { holdingToDelete = nil } }
            ),
            presenting: holdingToDelete
        ) { holding in
            Button("Delete", role: .destructive) {
                modelContext.delete(holding)
                holdingToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                holdingToDelete = nil
            }
        } message: { holding in
            Text("Remove \(holding.stock?.ticker ?? "this holding") from \(portfolio.name)?")
        }
    }
}

// MARK: - Holding Row with performance

private struct PortfolioHoldingRowView: View {
    let holding: Holding
    var onShowGrowth: () -> Void
    @Environment(\.massiveService) private var massive

    private var ticker: String { holding.stock?.ticker ?? "—" }
    private var companyName: String { holding.stock?.companyName ?? "" }

    private var gainColor: Color {
        guard let pct = holding.unrealizedGainPercent else { return .secondary }
        if pct > 0 { return .green }
        if pct < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CompanyLogoView(
                branding: nil,
                ticker: ticker,
                service: massive.service,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker).textStyle(.tickerSymbol)
                if !companyName.isEmpty {
                    Text(companyName).textStyle(.rowDetail).lineLimit(1)
                }
                Text("\(holding.shares.formatted()) shares")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if holding.currentValue > 0 {
                    Text(holding.currentValue.formatted(.currency(code: holding.currency)))
                        .font(.subheadline.bold())
                } else {
                    Text("—").font(.subheadline.bold()).foregroundStyle(.secondary)
                }
                if let pct = holding.unrealizedGainPercent {
                    let prefix = pct >= 0 ? "+" : ""
                    let formatted = (pct as NSDecimalNumber)
                        .doubleValue
                        .formatted(.number.precision(.fractionLength(2)))
                    Text("\(prefix)\(formatted)%")
                        .font(.caption)
                        .foregroundStyle(gainColor)
                } else {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button {
                onShowGrowth()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Growth projection for \(ticker)")
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return PortfoliosView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}
