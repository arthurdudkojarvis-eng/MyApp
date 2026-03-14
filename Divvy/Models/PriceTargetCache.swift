import Foundation
import SwiftData

@Model
final class PriceTargetCache {
    @Attribute(.unique) var ticker: String
    var targetHigh: Decimal
    var targetLow: Decimal
    var targetMean: Decimal
    var targetMedian: Decimal
    var lastUpdated: Date
    var fetchedAt: Date

    init(ticker: String, targetHigh: Decimal, targetLow: Decimal,
         targetMean: Decimal, targetMedian: Decimal, lastUpdated: Date) {
        self.ticker = ticker.uppercased()
        self.targetHigh = targetHigh
        self.targetLow = targetLow
        self.targetMean = targetMean
        self.targetMedian = targetMedian
        self.lastUpdated = lastUpdated
        self.fetchedAt = .now
    }

    var isExpired: Bool {
        Date.now.timeIntervalSince(fetchedAt) > 86400 // 24h TTL
    }
}
