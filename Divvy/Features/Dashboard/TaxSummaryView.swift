import SwiftUI
import SwiftData

struct TaxSummaryView: View {
    @Query(sort: \DividendPayment.receivedDate) private var allPayments: [DividendPayment]

    private var paymentsByYear: [(year: Int, payments: [DividendPayment])] {
        let grouped = Dictionary(grouping: allPayments) { payment -> Int in
            Calendar.current.component(.year, from: payment.receivedDate)
        }
        return grouped
            .map { (year: $0.key, payments: $0.value) }
            .sorted { $0.year > $1.year }
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private func csvDecimal(_ d: Decimal) -> String {
        (d as NSDecimalNumber).description(withLocale: Self.posixLocale)
    }

    private var csvString: String {
        var lines = ["Year,Gross Income,Withholding Tax,Net Income,Payment Count"]
        for entry in paymentsByYear {
            let gross = entry.payments.reduce(Decimal(0)) { $0 + $1.totalAmount }
            let withholding = entry.payments.reduce(Decimal(0)) { $0 + ($1.withholdingTax ?? 0) }
            let net = gross - withholding
            let count = entry.payments.count
            lines.append("\(entry.year),\(csvDecimal(gross)),\(csvDecimal(withholding)),\(csvDecimal(net)),\(count)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if allPayments.isEmpty {
                    ContentUnavailableView(
                        "No Payments Logged",
                        systemImage: "doc.text",
                        description: Text("Log dividend payments from the Calendar tab to see your tax summary.")
                    )
                    .padding(.top, 60)
                } else {
                    totalsCard
                    ForEach(paymentsByYear, id: \.year) { entry in
                        YearSummaryCard(year: entry.year, payments: entry.payments)
                    }
                    exportCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tax Summary")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var totalsCard: some View {
        let gross = allPayments.reduce(Decimal(0)) { $0 + $1.totalAmount }
        let withholding = allPayments.reduce(Decimal(0)) { $0 + ($1.withholdingTax ?? 0) }
        let net = gross - withholding

        return VStack(spacing: 12) {
            Text("All-Time Totals")
                .textStyle(.rowTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                summaryCell(label: "Gross Income", value: gross, color: .primary)
                Divider().frame(height: 50)
                summaryCell(label: "Withholding", value: withholding, color: .red)
                Divider().frame(height: 50)
                summaryCell(label: "Net Income", value: net, color: .green)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryCell(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .currency(code: "USD"))
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .textStyle(.statLabel)
        }
        .frame(maxWidth: .infinity)
    }

    private var exportCard: some View {
        ShareLink(
            item: csvString,
            subject: Text("Dividend Tax Summary"),
            message: Text("My dividend income summary from Divvy")
        ) {
            Label("Export as CSV", systemImage: "square.and.arrow.up")
                .textStyle(.rowTitle)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Year Summary Card

private struct YearSummaryCard: View {
    let year: Int
    let payments: [DividendPayment]

    private var gross: Decimal { payments.reduce(0) { $0 + $1.totalAmount } }
    private var withholding: Decimal { payments.reduce(0) { $0 + ($1.withholdingTax ?? 0) } }
    private var net: Decimal { gross - withholding }
    private var hasWithholding: Bool { withholding > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(year))
                    .textStyle(.rowTitle)
                Spacer()
                Text("\(payments.count) payments")
                    .textStyle(.rowDetail)
            }

            HStack(spacing: 20) {
                taxRow(label: "Gross", value: gross)
                if hasWithholding {
                    taxRow(label: "Withholding", value: withholding, isNegative: true)
                    taxRow(label: "Net", value: net)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func taxRow(label: String, value: Decimal, isNegative: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .textStyle(.rowDetail)
            Text(value, format: .currency(code: "USD"))
                .font(.subheadline.bold())
                .foregroundStyle(isNegative ? .red : .primary)
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        TaxSummaryView()
    }
    .modelContainer(container)
    .environment(settings)
}
