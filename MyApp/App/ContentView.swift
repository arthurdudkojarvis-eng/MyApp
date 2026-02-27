import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        MainTabView()
            // .preferredColorScheme propagates via SwiftUI preferences.
            // The explicit UIWindow override below is the reliable fallback
            // for iOS 17+ where the preference path can be inconsistent.
            .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
            .onAppear { applyWindowColorScheme(settings.colorScheme) }
            .onChange(of: settings.colorScheme) { _, scheme in
                applyWindowColorScheme(scheme)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !settings.hasCompletedOnboarding },
                set: { _ in }   // dismissal is driven only by setting the flag
            )) {
                OnboardingView()
                    .environment(settings)
            }
    }

    private func applyWindowColorScheme(_ scheme: AppColorScheme) {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
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
