import SwiftUI

extension AppColorScheme {
    /// Returns the `ColorScheme?` expected by `.preferredColorScheme(_:)`.
    /// Always non-nil since system-follow is no longer an option.
    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        }
    }
}
