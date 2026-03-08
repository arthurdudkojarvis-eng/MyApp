import Foundation
import SwiftData

@Model
final class DividendPayment {
    @Attribute(.unique) var id: UUID
    var sharesAtTime: Decimal       // snapshot — Holding.shares may change later
    var totalAmount: Decimal
    var receivedDate: Date
    var reinvested: Bool
    var withholdingTax: Decimal?    // foreign dividend withholding — needed for tax reporting

    // Both are optional at the SwiftData layer; both must be set on creation.
    // Holding.dividendPayments is cascade-deleted; DividendSchedule.payments is nullify.
    var holding: Holding?
    var dividendSchedule: DividendSchedule?

    init(
        sharesAtTime: Decimal,
        totalAmount: Decimal,
        receivedDate: Date = .now,
        reinvested: Bool = false,
        withholdingTax: Decimal? = nil
    ) {
        id = UUID()
        self.sharesAtTime = sharesAtTime
        self.totalAmount = totalAmount
        self.receivedDate = receivedDate
        self.reinvested = reinvested
        self.withholdingTax = withholdingTax
    }

    /// Net amount after withholding tax.
    var netAmount: Decimal {
        totalAmount - (withholdingTax ?? 0)
    }
}
