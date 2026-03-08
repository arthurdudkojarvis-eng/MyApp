import Foundation
import SwiftData

@Model
final class DividendSchedule {
    @Attribute(.unique) var id: UUID
    var frequency: DividendFrequency
    var amountPerShare: Decimal
    var exDate: Date
    var payDate: Date
    var declaredDate: Date
    var status: DividendScheduleStatus
    var externalId: String?     // data-provider event ID — required for sync deduplication

    var stock: Stock?

    // .nullify: deleting a DividendSchedule does NOT delete payment records.
    // A DividendPayment is a real financial event (cash received); it must not
    // be silently destroyed if the associated schedule is corrected or re-declared.
    @Relationship(deleteRule: .nullify, inverse: \DividendPayment.dividendSchedule)
    var payments: [DividendPayment] = []

    init(
        frequency: DividendFrequency,
        amountPerShare: Decimal,
        exDate: Date,
        payDate: Date,
        declaredDate: Date = .now,
        status: DividendScheduleStatus = .declared
    ) {
        id = UUID()
        self.frequency = frequency
        self.amountPerShare = amountPerShare
        self.exDate = exDate
        self.payDate = payDate
        self.declaredDate = declaredDate
        self.status = status
    }

    /// Annualised dividend per share based on declared frequency.
    var annualizedAmountPerShare: Decimal {
        amountPerShare * Decimal(frequency.paymentsPerYear)
    }

    /// True if the ex-date is today or in the future (date-only comparison).
    var isUpcoming: Bool {
        Calendar.current.startOfDay(for: exDate) >= Calendar.current.startOfDay(for: .now)
    }

    var isPaid: Bool { status == .paid }
    var isDeclared: Bool { status == .declared }
    var isEstimated: Bool { status == .estimated }
}
