import Foundation

enum DividendFrequency: String, Codable, CaseIterable {
    case annual     = "Annual"
    case semiAnnual = "Semi-Annual"
    case quarterly  = "Quarterly"
    case monthly    = "Monthly"

    var paymentsPerYear: Int {
        switch self {
        case .annual:     return 1
        case .semiAnnual: return 2
        case .quarterly:  return 4
        case .monthly:    return 12
        }
    }
}

enum DividendScheduleStatus: String, Codable {
    case estimated
    case declared
    case paid
}
