import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        MainTabView()
            .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
            .onAppear { settings.applyColorSchemeToWindows() }
            .fullScreenCover(isPresented: Binding(
                get: { !settings.hasCompletedOnboarding },
                set: { _ in }   // dismissal is driven only by setting the flag
            )) {
                OnboardingView()
                    .environment(settings)
                    .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
            }
    }
}

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return ContentView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(SettingsStore())
}
