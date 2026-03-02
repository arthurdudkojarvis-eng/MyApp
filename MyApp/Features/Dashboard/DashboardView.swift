import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var showSettings = false
    // Start on page 1 (dashboard). Page 0 (placeholder) sits to the left,
    // so swiping right reveals it and swiping left returns to the dashboard.
    @State private var selectedPage = 1
    @State private var marketStatus: MassiveMarketStatus?

    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(SettingsStore.self) private var settings
    @Environment(\.massiveService) private var massive
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var metrics: DashboardMetrics {
        DashboardMetrics(portfolios: portfolios)
    }

    var body: some View {
        NavigationStack {
            // ZStack is needed because .background() is ignored by the UIPageViewController
            // backing a .page TabView — the scroll view bleeds through. Placing the color
            // behind the TabView at the ZStack level and extending it into safe-area fills
            // all gaps including the page-dot region.
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                TabView(selection: $selectedPage) {
                    // Page 0 — placeholder (future features), sits to the LEFT
                    DashboardSecondPage()
                        .tag(0)

                    // Page 1 — income dashboard (default), swipe right to reach page 0
                    dashboardPage
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.regular)
                    }
                    .tint(.primary)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
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
                if let status = marketStatus {
                    MarketStatusPill(status: status)
                        .padding(.horizontal)
                }
                IncomeHeroView(
                    metrics: metrics,
                    isRefreshing: stockRefresh.isRefreshing
                )
                CoverageMeterView(
                    monthlyEquivalent: metrics.monthlyEquivalent,
                    monthlyExpenseTarget: settings.monthlyExpenseTarget
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .task { await loadMarketStatus() }
    }

    private func loadMarketStatus() async {
        marketStatus = try? await massive.service.fetchMarketStatus(apiKey: settings.apiKey)
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

// MARK: - Market Status Pill (STORY-032)

private struct MarketStatusPill: View {
    let status: MassiveMarketStatus

    private var label: String {
        switch status.market.lowercased() {
        case "open":            return "Market Open"
        case "extended-hours":  return "After Hours"
        case "closed":          return "Market Closed"
        default:                return status.market.capitalized
        }
    }

    private var color: Color {
        switch status.market.lowercased() {
        case "open":            return .green
        case "extended-hours":  return .orange
        default:                return .secondary
        }
    }

    private var icon: String {
        switch status.market.lowercased() {
        case "open":            return "circle.fill"
        case "extended-hours":  return "moon.fill"
        default:                return "moon.zzz.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Dashboard Second Page

private struct DashboardSecondPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                featureLink(
                    icon: "chart.xyaxis.line",
                    title: "Income Forecast",
                    subtitle: "12-month projected dividend income",
                    destination: IncomeForecastView()
                )
                featureLink(
                    icon: "chart.pie.fill",
                    title: "Sector Allocation",
                    subtitle: "Portfolio diversification by sector",
                    destination: SectorAllocationView()
                )
                featureLink(
                    icon: "arrow.trianglehead.2.clockwise",
                    title: "DRIP Simulator",
                    subtitle: "Model reinvestment and long-term growth",
                    destination: DRIPSimulatorView()
                )
                featureLink(
                    icon: "shield.lefthalf.filled",
                    title: "Dividend Safety",
                    subtitle: "Yield-based risk indicators per holding",
                    destination: DividendSafetyView()
                )
                featureLink(
                    icon: "doc.text.fill",
                    title: "Tax Summary",
                    subtitle: "Annual income totals with CSV export",
                    destination: TaxSummaryView()
                )
                featureLink(
                    icon: "eye.fill",
                    title: "Watchlist",
                    subtitle: "Track stocks before adding to a portfolio",
                    destination: WatchlistView()
                )
                featureLink(
                    icon: "bell.fill",
                    title: "Alerts",
                    subtitle: "Ex-dividend date reminders for your holdings",
                    destination: AlertsView()
                )
                featureLink(
                    icon: "calendar",
                    title: "Dividend Calendar",
                    subtitle: "Upcoming dividend payments and market holidays",
                    destination: DividendCalendarView()
                )
                featureLink(
                    icon: "newspaper.fill",
                    title: "News & Events",
                    subtitle: "Market news for your holdings",
                    destination: NewsView()
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func featureLink<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        destination: Destination
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
        .environment(StockRefreshService(settings: settings, container: container))
}

#Preview("Empty state") {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}

