import SwiftUI

// MARK: - CoverageMetrics

/// Pure value-type that encapsulates coverage ratio arithmetic.
/// Extracted from the view so it can be unit-tested directly.
struct CoverageMetrics {
    let monthlyEquivalent: Decimal
    let monthlyExpenseTarget: Decimal

    var hasTarget: Bool { monthlyExpenseTarget > 0 }

    /// Raw (unclamped) coverage ratio as a Decimal fraction (1.27 = 127%).
    /// Returns 0 when `monthlyExpenseTarget` is zero.
    var coverageRatio: Decimal {
        guard hasTarget else { return 0 }
        return monthlyEquivalent / monthlyExpenseTarget
    }

    /// `coverageRatio` clamped to [0.0, 1.0] as a Double for `ProgressView.value`.
    /// This is the only Decimal → Double conversion in the coverage path.
    var clampedProgressValue: Double {
        let raw = NSDecimalNumber(decimal: coverageRatio).doubleValue
        return max(0.0, min(1.0, raw))
    }
}

// MARK: - CoverageMeterView

struct CoverageMeterView: View {
    let monthlyEquivalent: Decimal
    let monthlyExpenseTarget: Decimal

    @State private var showSettings = false

    private var coverage: CoverageMetrics {
        CoverageMetrics(
            monthlyEquivalent: monthlyEquivalent,
            monthlyExpenseTarget: monthlyExpenseTarget
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coverage.hasTarget {
                meterContent
            } else {
                emptyContent
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Content states

    private var meterContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + unclamped percentage (not capped at 100%)
            HStack {
                Text("Coverage")
                    .font(.headline)
                Spacer()
                Text(coverage.coverageRatio, format: .percent.precision(.fractionLength(1)))
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityHidden(true) // combined label on bar below
            }

            // Progress bar — visually capped at 100%, label shows real value
            ProgressView(value: coverage.clampedProgressValue)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .accessibilityLabel(
                    "Coverage \(coverage.coverageRatio.formatted(.percent.precision(.fractionLength(1))))"
                )

            // "covering $X of $Y monthly target"
            Text(
                "covering \(monthlyEquivalent.formatted(.currency(code: "USD"))) " +
                "of \(monthlyExpenseTarget.formatted(.currency(code: "USD"))) monthly target"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyContent: some View {
        Button {
            showSettings = true
        } label: {
            HStack {
                Text("Set a monthly income target")
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Set a monthly income target")
        .accessibilityHint("Opens Settings")
    }
}

// MARK: - Previews

#Preview("73% covered") {
    CoverageMeterView(
        monthlyEquivalent: Decimal(string: "1468")!,
        monthlyExpenseTarget: Decimal(string: "2000")!
    )
    .environment(SettingsStore())
}

#Preview("127% covered") {
    CoverageMeterView(
        monthlyEquivalent: Decimal(string: "2540")!,
        monthlyExpenseTarget: Decimal(string: "2000")!
    )
    .environment(SettingsStore())
}

#Preview("No target set") {
    CoverageMeterView(
        monthlyEquivalent: Decimal(string: "1468")!,
        monthlyExpenseTarget: 0
    )
    .environment(SettingsStore())
}
