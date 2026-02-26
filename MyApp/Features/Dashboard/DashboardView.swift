import SwiftUI

struct DashboardView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            // STORY-009: Income dashboard content goes here
            ContentUnavailableView(
                "Add your first holding",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Your income dashboard will appear here.")
            )
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
    DashboardView()
        .environment(SettingsStore())
}
