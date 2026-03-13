import SwiftUI

enum AppTextStyle {
    case sectionTitle, rowDetail, statLabel, statValue, metricValue
    case heroDisplay, scoreDisplay, microLabel, badge, chartAxis
    case cardTitle, tickerSymbol
    case cardHero, rowTitle, controlLabel, captionBold, microBadge, smallCaption
}

struct TextStyleModifier: ViewModifier {
    let style: AppTextStyle

    func body(content: Content) -> some View {
        switch style {
        case .sectionTitle:  content.font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
        case .rowDetail:     content.font(.caption).foregroundStyle(.secondary)
        case .statLabel:     content.font(.caption2).foregroundStyle(.secondary)
        case .statValue:     content.font(.system(size: 14, weight: .bold)).monospacedDigit()
        case .metricValue:   content.font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
        case .heroDisplay:   content.font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
        case .scoreDisplay:  content.font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
        case .microLabel:    content.font(.system(size: 9)).foregroundStyle(.tertiary)
        case .badge:         content.font(.caption2.bold())
        case .chartAxis:     content.font(.caption2)
        case .cardTitle:     content.font(.system(size: 15, weight: .semibold, design: .rounded)).tracking(0.2)
        case .tickerSymbol:  content.font(.system(size: 14, weight: .bold)).tracking(0.3)
        case .cardHero:      content.font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
        case .rowTitle:      content.font(.subheadline.bold())
        case .controlLabel:  content.font(.system(size: 13)).foregroundStyle(.secondary)
        case .captionBold:   content.font(.caption.bold())
        case .microBadge:    content.font(.system(size: 9, weight: .semibold))
        case .smallCaption:  content.font(.system(size: 10))
        }
    }
}

extension View {
    func textStyle(_ style: AppTextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
