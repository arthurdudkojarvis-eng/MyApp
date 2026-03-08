import Foundation
import SwiftData

@Model
final class WatchlistItem {
    var id: UUID
    @Attribute(.unique) var ticker: String
    var companyName: String
    var addedDate: Date
    var notes: String

    init(ticker: String, companyName: String = "", notes: String = "") {
        id = UUID()
        self.ticker = ticker.uppercased()
        self.companyName = companyName
        self.addedDate = .now
        self.notes = notes
    }
}
