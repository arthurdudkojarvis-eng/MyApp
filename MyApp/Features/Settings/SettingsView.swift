import SwiftUI

/// Placeholder — full implementation in STORY-003.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    // STORY-003: Polygon.io API key (Keychain)
                    // STORY-003: Expense target (UserDefaults)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
