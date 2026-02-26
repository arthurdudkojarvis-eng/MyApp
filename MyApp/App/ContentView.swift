import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        MainTabView()
            // preferredColorScheme must live here (not in App.body) so that
            // @Observable change tracking fires reliably when colorScheme mutates.
            .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
            .fullScreenCover(isPresented: Binding(
                get: { !settings.hasCompletedOnboarding },
                set: { _ in }   // dismissal is driven only by setting the flag
            )) {
                OnboardingView()
                    .environment(settings)
            }
    }
}

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return ContentView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(SettingsStore())
}
