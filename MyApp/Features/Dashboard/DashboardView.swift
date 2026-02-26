import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var showSettings = false
    // Start on page 1 (dashboard). Page 0 (placeholder) sits to the left,
    // so swiping right reveals it and swiping left returns to the dashboard.
    @State private var selectedPage = 1

    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(SettingsStore.self) private var settings
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
                if !settings.hasPolygonAPIKey {
                    NoAPIKeyBannerView { showSettings = true }
                }
                if let error = stockRefresh.lastRefreshError {
                    RefreshErrorBannerView(message: error) {
                        stockRefresh.dismissRefreshError()
                    }
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
    }
}

// MARK: - Banners

private struct NoAPIKeyBannerView: View {
    let onTapSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.slash")
                .foregroundStyle(.orange)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No API Key")
                    .font(.subheadline.bold())
                Text("Live prices unavailable. Add a Polygon API key in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Settings", action: onTapSettings)
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

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

// MARK: - Dashboard Second Page (placeholder)

private struct DashboardSecondPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                placeholderSection("Analytics")
                placeholderSection("Watchlist")
                placeholderSection("Insights")
                placeholderSection("News")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(Color.black)
    }

    private func placeholderSection(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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

#Preview("No API key") {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    settings.polygonAPIKey = ""          // force banner regardless of Keychain state
    settings.monthlyExpenseTarget = Decimal(string: "2000")!

    let portfolio = Portfolio(name: "Main")
    container.mainContext.insert(portfolio)

    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
