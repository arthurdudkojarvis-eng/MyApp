import SwiftUI

struct DashboardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal)
    }
}

extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}

// MARK: - Card Grid

enum DashboardCardID: String, CaseIterable, Identifiable {
    case upcoming, yieldOverview, performance
    case topEarners, annualProgress, frequency
    case concentration, dividendGrowth, healthScore

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .upcoming:        return "calendar.badge.clock"
        case .yieldOverview:   return "percent"
        case .performance:     return "chart.line.uptrend.xyaxis"
        case .topEarners:      return "star.fill"
        case .annualProgress:  return "target"
        case .frequency:       return "clock.arrow.2.circlepath"
        case .concentration:   return "circle.grid.3x3.fill"
        case .dividendGrowth:  return "arrow.up.forward"
        case .healthScore:     return "heart.text.clipboard"
        }
    }

    var title: String {
        switch self {
        case .upcoming:        return "Upcoming"
        case .yieldOverview:   return "Yield"
        case .performance:     return "Performance"
        case .topEarners:      return "Top Earners"
        case .annualProgress:  return "Annual"
        case .frequency:       return "Frequency"
        case .concentration:   return "Concentration"
        case .dividendGrowth:  return "Growth"
        case .healthScore:     return "Health"
        }
    }
}

struct DashboardCardGrid: View {
    @Binding var expandedCard: DashboardCardID?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DashboardCardID.allCases) { card in
                let isSelected = expandedCard == card
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expandedCard = isSelected ? nil : card
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: card.icon)
                            .font(.title3)
                            .foregroundStyle(isSelected ? .white : Color.accentColor)
                        Text(card.title)
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected
                                  ? Color.accentColor
                                  : Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(card.title)
            }
        }
        .padding(.horizontal)
    }
}
