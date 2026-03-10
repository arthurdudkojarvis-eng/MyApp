import SwiftUI
import SwiftData

private enum DashboardSheet: Identifiable {
    case settings, features
    var id: Self { self }
}

struct DashboardView: View {
    @State private var activeSheet: DashboardSheet?
    @State private var expandedCard: DashboardCardID?

    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(SettingsStore.self) private var settings
    @Environment(\.massiveService) private var massive
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var metrics: DashboardMetrics {
        DashboardMetrics(portfolios: portfolios)
    }

    var body: some View {
        NavigationStack {
            dashboardPage
                .background(Color(.systemGroupedBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            activeSheet = .features
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .fontWeight(.medium)
                        }
                        .tint(.primary)
                        .accessibilityLabel("Features menu")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            activeSheet = .settings
                        } label: {
                            Image(systemName: "gearshape")
                                .fontWeight(.regular)
                        }
                        .tint(.primary)
                        .accessibilityLabel("Settings")
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .settings:
                        SettingsView()
                            .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
                    case .features:
                        DashboardFeaturesSheet()
                    }
                }
        }
    }

    private var dashboardPage: some View {
        Group {
            if portfolios.isEmpty {
                ContentUnavailableView(
                    "No Holdings Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Go to Holdings to add your first position and start tracking dividend income.")
                )
            } else {
                mainContent
            }
        }
    }

    // MARK: - Main content (portfolios non-empty)

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = stockRefresh.lastRefreshError {
                    RefreshErrorBannerView(message: error) {
                        stockRefresh.dismissRefreshError()
                    }
                }
                IncomeHeroView(
                    metrics: metrics,
                    isRefreshing: stockRefresh.isRefreshing
                )
                DashboardCardGrid(expandedCard: $expandedCard)

                if let expandedCard {
                    expandedCardContent(expandedCard)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func expandedCardContent(_ card: DashboardCardID) -> some View {
        switch card {
        case .upcoming:
            UpcomingDividendsCard(holdings: metrics.allHoldings)
        case .yieldOverview:
            YieldOverviewCard(holdings: metrics.allHoldings)
        case .performance:
            PortfolioPerformanceCard(metrics: metrics)
        case .topEarners:
            TopEarnersCard(holdings: metrics.allHoldings)
        case .annualProgress:
            AnnualProgressCard(holdings: metrics.allHoldings)
        case .frequency:
            IncomeFrequencyCard(holdings: metrics.allHoldings)
        case .concentration:
            ConcentrationRiskCard(holdings: metrics.allHoldings, totalMarketValue: metrics.totalMarketValue)
        case .dividendGrowth:
            DividendGrowthCard(holdings: metrics.allHoldings)
        case .healthScore:
            HealthScoreCard(holdings: metrics.allHoldings, metrics: metrics)
        }
    }
}

// MARK: - Banners

private struct RefreshErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.title3)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss refresh error")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

// MARK: - Dashboard Features Sheet

private struct DashboardFeaturesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    featureLink(
                        icon: "chart.xyaxis.line",
                        title: "Income Forecast",
                        subtitle: "12-month projected dividend income"
                    ) { IncomeForecastView() }
                    featureLink(
                        icon: "chart.pie.fill",
                        title: "Sector Allocation",
                        subtitle: "Portfolio diversification by sector"
                    ) { SectorAllocationView() }
                    featureLink(
                        icon: "arrow.trianglehead.2.clockwise",
                        title: "DRIP Simulator",
                        subtitle: "Model reinvestment and long-term growth"
                    ) { DRIPSimulatorView() }
                    featureLink(
                        icon: "shield.lefthalf.filled",
                        title: "Dividend Safety",
                        subtitle: "Yield-based risk indicators per holding"
                    ) { DividendSafetyView() }
                    featureLink(
                        icon: "doc.text.fill",
                        title: "Tax Summary",
                        subtitle: "Annual income totals with CSV export"
                    ) { TaxSummaryView() }
                    featureLink(
                        icon: "eye.fill",
                        title: "Watchlist",
                        subtitle: "Track stocks before adding to a portfolio"
                    ) { WatchlistView() }
                    featureLink(
                        icon: "bell.fill",
                        title: "Alerts",
                        subtitle: "Ex-dividend date reminders for your holdings"
                    ) { AlertsView() }
                    featureLink(
                        icon: "calendar",
                        title: "Dividend Calendar",
                        subtitle: "Upcoming dividend payments and market holidays"
                    ) { DividendCalendarView() }
                    featureLink(
                        icon: "newspaper.fill",
                        title: "News & Events",
                        subtitle: "Market news for your holdings"
                    ) { NewsView() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func featureLink<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    settings.monthlyExpenseTarget = Decimal(string: "2000")!
    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}

#Preview("Empty state") {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}

