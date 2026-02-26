import SwiftUI

struct DashboardView: View {
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
                        // STORY-003: Present SettingsView as sheet
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.regular)
                    }
                    .tint(.primary)
                }
            }
        }
    }
}

#Preview {
    DashboardView()
}
