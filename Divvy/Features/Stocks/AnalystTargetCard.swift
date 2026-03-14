import SwiftUI

struct AnalystTargetCard: View {
    let target: FinnhubPriceTarget
    let currentPrice: Decimal

    // MARK: - Formatters

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    // MARK: - Computed

    private var consensusPercent: Decimal? {
        guard currentPrice > 0 else { return nil }
        return ((target.targetMean - currentPrice) / currentPrice) * 100
    }

    private var isSingleEstimate: Bool {
        target.targetHigh == target.targetLow
    }

    private var tickPosition: CGFloat {
        let range = target.targetHigh - target.targetLow
        guard range > 0 else { return 0.5 }
        let raw = (currentPrice - target.targetLow) / range
        let clamped = min(max(raw, 0), 1)
        return CGFloat((clamped as NSDecimalNumber).doubleValue)
    }

    private var updatedDate: Date? {
        Self.dateParser.date(from: target.lastUpdated)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analyst Targets").textStyle(.sectionTitle)

            if let pct = consensusPercent {
                let isUpside = pct >= 0
                let formatted = abs((pct as NSDecimalNumber).doubleValue)
                    .formatted(.number.precision(.fractionLength(1)))
                Text("\(isUpside ? "+" : "−")\(formatted)% to consensus")
                    .font(.subheadline.bold())
                    .foregroundStyle(isUpside ? .green : .red)
            } else {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            if isSingleEstimate {
                Text(formatPrice(target.targetMean))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                Text("1 analyst estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                // Target mean label above bar
                Text(formatPrice(target.targetMean))
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)

                // Gradient bar with tick
                GeometryReader { geo in
                    let barWidth = geo.size.width

                    ZStack(alignment: .leading) {
                        // Gradient bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .gray, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 12)

                        // Current price tick
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 2, height: 20)
                            .offset(x: tickPosition * barWidth - 1)
                    }
                }
                .frame(height: 20)

                // Bear / Bull labels
                HStack {
                    Text(formatPrice(target.targetLow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatPrice(target.targetHigh))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let date = updatedDate {
                Text("Updated \(Self.relativeFormatter.localizedString(for: date, relativeTo: .now))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func formatPrice(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }
}
