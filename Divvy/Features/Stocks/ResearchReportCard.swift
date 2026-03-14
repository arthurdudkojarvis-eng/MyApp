import SwiftUI

struct ResearchReportCard: View {
    let ticker: String
    @Environment(\.cacheStore) private var cacheStore
    @State private var report: AIReport?
    @State private var isLoading = false
    @State private var loadError = false
    @State private var bullExpanded = true
    @State private var bearExpanded = true

    private let service = AIReportService()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var isStale: Bool {
        guard let report else { return false }
        return Date.now.timeIntervalSince(report.fetchedAt) > AIReport.defaultTTL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Research Report").textStyle(.sectionTitle)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Generating report...")
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if loadError {
                Button {
                    Task { await loadReport() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Report unavailable. Tap to retry.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else if let report {
                DisclosureGroup(isExpanded: $bullExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.bullPoints, id: \.self) { point in
                            bulletRow(point, color: .green)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Bull Case", systemImage: "arrow.up.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }

                DisclosureGroup(isExpanded: $bearExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.bearPoints, id: \.self) { point in
                            bulletRow(point, color: .red)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Bear Case", systemImage: "arrow.down.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }

                if isStale {
                    VStack(spacing: 6) {
                        Text("This report is \(Self.relativeFormatter.localizedString(for: report.generatedAt, relativeTo: .now)) old")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Button {
                            Task { await loadReport(forceRefresh: true) }
                        } label: {
                            Text("Refresh Report")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Generated \(Self.relativeFormatter.localizedString(for: report.generatedAt, relativeTo: .now))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: ticker) { await loadReport() }
    }

    // MARK: - Row

    private func bulletRow(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Loading

    private func loadReport(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: AIReport = cacheStore?.get(ticker: ticker) {
            report = cached
            return
        }

        guard !isLoading else { return }
        isLoading = true
        loadError = false
        defer { isLoading = false }

        do {
            let response = try await service.fetchReport(ticker: ticker)
            let generatedDate = Self.iso8601Formatter.date(from: response.generatedAt) ?? .now
            let newReport = AIReport(
                ticker: ticker,
                bullPoints: response.bullCase,
                bearPoints: response.bearCase,
                generatedAt: generatedDate
            )
            cacheStore?.set(ticker: ticker, value: newReport)
            report = newReport
        } catch {
            loadError = true
        }
    }
}
