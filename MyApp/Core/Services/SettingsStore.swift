import Foundation
import UIKit
import Observation
import OSLog

// MARK: - AppColorScheme

enum AppColorScheme: String, CaseIterable {
    case light = "light"
    case dark  = "dark"

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.myapp.MyApp",
                            category: "SettingsStore")

/// Single source of truth for user-configurable settings.
/// API key is persisted in Keychain; all other prefs use UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    // MARK: - Keys
    private enum Keys {
        static let apiKey                 = "apiKey"
        static let monthlyExpenseTarget   = "monthlyExpenseTarget"
        static let colorScheme            = "colorScheme"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    // MARK: - Dependencies
    private let keychain: KeychainService
    private let defaults: UserDefaults

    // MARK: - Published state

    /// User-provided API key stored in Keychain. When empty, `apiKey` falls back
    /// to the built-in embedded key.
    var userAPIKey: String {
        didSet {
            do {
                try keychain.save(userAPIKey, forKey: Keys.apiKey)
            } catch {
                logger.error("Failed to save API key to Keychain: \(error.localizedDescription)")
            }
        }
    }

    /// Effective API key: prefers user-provided key, falls back to embedded key.
    var apiKey: String { userAPIKey.isEmpty ? EmbeddedAPIKey.key : userAPIKey }

    /// Whether the user has entered their own custom API key.
    var isUsingCustomKey: Bool { !userAPIKey.isEmpty }

    /// Monthly expense target in the user's base currency (USD). 0 means unset.
    var monthlyExpenseTarget: Decimal {
        didSet {
            defaults.set(monthlyExpenseTarget.description, forKey: Keys.monthlyExpenseTarget)
        }
    }

    var colorScheme: AppColorScheme {
        didSet {
            defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme)
            applyColorSchemeToWindows()
        }
    }

    /// Forces all UIWindows to match the stored color scheme.
    /// Called from didSet (immediate on every change) and once on app launch.
    func applyColorSchemeToWindows() {
        let style: UIUserInterfaceStyle
        switch colorScheme {
        case .light: style = .light
        case .dark:  style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.keyWindow?.overrideUserInterfaceStyle = style
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    // MARK: - Init
    init(keychain: KeychainService = KeychainService(),
         defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults

        // Migrate API key stored under the legacy "fmpAPIKey" Keychain entry.
        if let legacy = keychain.load(forKey: "fmpAPIKey"), !legacy.isEmpty {
            try? keychain.save(legacy, forKey: Keys.apiKey)
            keychain.delete(forKey: "fmpAPIKey")
            self.userAPIKey = legacy
        } else {
            self.userAPIKey = keychain.load(forKey: Keys.apiKey) ?? ""
        }

        // Store as String to avoid Decimal → Double precision loss.
        if let stored = defaults.string(forKey: Keys.monthlyExpenseTarget),
           let decimal = Decimal(string: stored), decimal >= 0 {
            self.monthlyExpenseTarget = decimal
        } else {
            self.monthlyExpenseTarget = 0
        }

        let raw = defaults.string(forKey: Keys.colorScheme) ?? AppColorScheme.light.rawValue
        // "system" was removed — migrate existing stored value to .light
        self.colorScheme = AppColorScheme(rawValue: raw) ?? .light

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}
