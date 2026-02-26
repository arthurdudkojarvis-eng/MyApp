import SwiftUI

extension AppColorScheme {
    /// The `ColorScheme` to pass to `.preferredColorScheme(_:)`.
    /// `nil` means "follow the system setting" — the SwiftUI default.
    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
