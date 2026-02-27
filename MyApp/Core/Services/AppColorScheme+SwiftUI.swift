import SwiftUI

extension AppColorScheme {
    var resolvedColorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        }
    }
}
