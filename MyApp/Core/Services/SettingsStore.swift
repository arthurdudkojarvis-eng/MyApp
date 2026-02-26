import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.myapp.MyApp",
                            category: "SettingsStore")

/// Single source of truth for user-configurable settings.
/// API key is persisted in Keychain; all other prefs use UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    // MARK: - Keys
    private enum Keys {
        static let polygonAPIKey = "polygonAPIKey"
        static let monthlyExpenseTarget = "monthlyExpenseTarget"
    }

    // MARK: - Dependencies
    private let keychain: KeychainService
    private let defaults: UserDefaults

    // MARK: - Published state
    var polygonAPIKey: String {
        didSet {
            do {
                try keychain.save(polygonAPIKey, forKey: Keys.polygonAPIKey)
            } catch {
                logger.error("Failed to save Polygon API key to Keychain: \(error.localizedDescription)")
            }
        }
    }

    /// Monthly expense target in the user's base currency (USD). 0 means unset.
    var monthlyExpenseTarget: Decimal {
        didSet {
            defaults.set(monthlyExpenseTarget.description, forKey: Keys.monthlyExpenseTarget)
        }
    }

    var hasPolygonAPIKey: Bool { !polygonAPIKey.isEmpty }

    // MARK: - Init
    init(keychain: KeychainService = KeychainService(),
         defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults

        self.polygonAPIKey = keychain.load(forKey: Keys.polygonAPIKey) ?? ""

        // Store as String to avoid Decimal → Double precision loss.
        if let stored = defaults.string(forKey: Keys.monthlyExpenseTarget),
           let decimal = Decimal(string: stored), decimal >= 0 {
            self.monthlyExpenseTarget = decimal
        } else {
            self.monthlyExpenseTarget = 0
        }
    }
}
