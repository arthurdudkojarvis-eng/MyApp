import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        MainTabView()
            .preferredColorScheme(settings.colorScheme.resolvedColorScheme)
            // .task(id:) fires on first appearance AND every time colorScheme
            // changes — more reliable than .onChange with @Observable on iOS 17.
            // The UIWindow override ensures UIKit-hosted views also switch.
            .task(id: settings.colorScheme) {
                applyWindowColorScheme(settings.colorScheme)
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
