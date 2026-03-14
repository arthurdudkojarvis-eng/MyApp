import Foundation
import SwiftData

@Model
final class AIReport {
    @Attribute(.unique) var ticker: String
    var bullPointsData: Data
    var bearPointsData: Data
    var generatedAt: Date
    var fetchedAt: Date

    var bullPoints: [String] {
        get { (try? JSONDecoder().decode([String].self, from: bullPointsData)) ?? [] }
        set { bullPointsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var bearPoints: [String] {
        get { (try? JSONDecoder().decode([String].self, from: bearPointsData)) ?? [] }
        set { bearPointsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(ticker: String, bullPoints: [String], bearPoints: [String], generatedAt: Date) {
        self.ticker = ticker.uppercased()
        self.bullPointsData = (try? JSONEncoder().encode(bullPoints)) ?? Data()
        self.bearPointsData = (try? JSONEncoder().encode(bearPoints)) ?? Data()
        self.generatedAt = generatedAt
        self.fetchedAt = .now
    }
}

extension AIReport: Cacheable {
    static let defaultTTL: TimeInterval = 259200 // 72 hours
}
