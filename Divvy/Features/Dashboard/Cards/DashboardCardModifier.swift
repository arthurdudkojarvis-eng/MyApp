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
        case .upcoming:        return "banknote.fill"
        case .yieldOverview:   return "gauge.open.with.lines.needle.33percent.and.arrowtriangle"
        case .performance:     return "chart.line.uptrend.xyaxis.circle.fill"
        case .topEarners:      return "crown.fill"
        case .annualProgress:  return "rosette"
        case .frequency:       return "metronome.fill"
        case .concentration:   return "chart.pie.fill"
        case .dividendGrowth:  return "leaf.fill"
        case .healthScore:     return "heart.circle.fill"
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

    @State private var pressedCard: DashboardCardID?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DashboardCardID.allCases) { card in
                let isSelected = expandedCard == card
                Button {
                    haptic.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expandedCard = isSelected ? nil : card
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: card.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? .white : Color.accentColor)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isSelected
                                          ? Color.white.opacity(0.2)
                                          : Color.accentColor.opacity(0.12))
                            )
                            .symbolEffect(.bounce, value: isSelected)
                        Text(card.title)
                            .textStyle(.badge)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected
                                  ? AnyShapeStyle(Color.accentColor.gradient)
                                  : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
                            radius: 8, y: 4)
                    .scaleEffect(pressedCard == card ? 0.92 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(card.title)
                .onLongPressGesture(minimumDuration: 0.5) {} onPressingChanged: { pressing in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        pressedCard = pressing ? card : nil
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
