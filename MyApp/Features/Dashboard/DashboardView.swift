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
            ScrollView {
                VStack(spacing: 16) {
                    IncomeHeroView(
                        metrics: metrics,
                        isRefreshing: stockRefresh.isRefreshing
                    )
                    .padding(.top, 8)

                    CoverageMeterView(
                        monthlyEquivalent: metrics.monthlyEquivalent,
                        monthlyExpenseTarget: settings.monthlyExpenseTarget
                    )

                    // STORY-011+: dividend calendar goes here
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
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
}

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    settings.monthlyExpenseTarget = Decimal(string: "2000")!
    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
