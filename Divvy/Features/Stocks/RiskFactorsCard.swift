import SwiftUI

struct RiskFactorsCard: View {
    let factors: [RiskFactor]

    private var highestSeverity: RiskSeverity? {
        factors.map(\.severity).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Risk Factors").textStyle(.sectionTitle)
                Spacer()
                if !factors.isEmpty, let severity = highestSeverity {
                    Text("\(factors.count) \(severity.label)")
                        .textStyle(.microBadge)
                        .foregroundStyle(severityColor(severity))
                }
            }

            if factors.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("No major risks detected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            } else {
                ForEach(factors) { factor in
                    riskRow(factor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Row

    private func riskRow(_ factor: RiskFactor) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(factor.severity.label)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severityColor(factor.severity))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.title)
                    .font(.subheadline.bold())
                Text(factor.description)
                    .textStyle(.rowDetail)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Helpers

    private func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .critical: .red
        case .high:     .orange
        case .medium:   .yellow
        case .low:      .green
        }
    }
}
