import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var showSettings = false

    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var metrics: DashboardMetrics {
        DashboardMetrics(portfolios: portfolios)
    }

    var body: some View {
        NavigationStack {
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
