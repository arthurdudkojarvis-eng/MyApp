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

// MARK: - FontTheme (STORY-050)

import SwiftUI

enum FontTheme: String, CaseIterable, Identifiable {
    case defaultTheme = "default"
    case green = "green"
    case teal = "teal"
    case ocean = "ocean"
    case purple = "purple"
    case indigo = "indigo"
    case gold = "gold"
    case coral = "coral"
    case rose = "rose"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .defaultTheme: return "Default"
        case .green: return "Green"
        case .teal: return "Teal"
        case .ocean: return "Ocean"
        case .purple: return "Purple"
        case .indigo: return "Indigo"
        case .gold: return "Gold"
        case .coral: return "Coral"
        case .rose: return "Rose"
        }
    }

    var color: Color? {
        switch self {
        case .defaultTheme: return nil
        case .green: return Color(red: 0.20, green: 0.70, blue: 0.30)
        case .teal: return Color(red: 0.0, green: 0.59, blue: 0.65)
        case .ocean: return Color(red: 0.15, green: 0.45, blue: 0.80)
        case .purple: return Color(red: 0.55, green: 0.30, blue: 0.75)
        case .indigo: return Color(red: 0.35, green: 0.30, blue: 0.70)
        case .gold: return Color(red: 0.80, green: 0.65, blue: 0.20)
        case .coral: return Color(red: 0.90, green: 0.40, blue: 0.30)
        case .rose: return Color(red: 0.85, green: 0.30, blue: 0.45)
        }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                            category: "SettingsStore")

/// Single source of truth for user-configurable settings.
/// All prefs use UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    // MARK: - Keys
    private enum Keys {
        static let monthlyExpenseTarget   = "monthlyExpenseTarget"
        static let colorScheme            = "colorScheme"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let fontTheme              = "fontTheme"
        static let lastActivePortfolioID  = "lastActivePortfolioID"
    }

    // MARK: - Dependencies
    private let defaults: UserDefaults

    // MARK: - Published state

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

    // STORY-050: Font theme
    var fontTheme: FontTheme {
        didSet { defaults.set(fontTheme.rawValue, forKey: Keys.fontTheme) }
    }

    // STORY-044: Last active portfolio UUID string
    var lastActivePortfolioID: String {
        didSet { defaults.set(lastActivePortfolioID, forKey: Keys.lastActivePortfolioID) }
    }

    // MARK: - Init
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

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

        let themeRaw = defaults.string(forKey: Keys.fontTheme) ?? FontTheme.defaultTheme.rawValue
        self.fontTheme = FontTheme(rawValue: themeRaw) ?? .defaultTheme

        self.lastActivePortfolioID = defaults.string(forKey: Keys.lastActivePortfolioID) ?? ""
    }
}
