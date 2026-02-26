import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var showSettings = false

    @Environment(StockRefreshService.self) private var stockRefresh
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

                    // STORY-010+: portfolio list and coverage meter go here
                }
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
    return DashboardView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
