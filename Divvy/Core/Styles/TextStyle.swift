import SwiftUI

enum AppTextStyle {
    case sectionTitle, rowDetail, statLabel, statValue, metricValue
    case heroDisplay, scoreDisplay, microLabel, badge, chartAxis
    case cardTitle, tickerSymbol
}

struct TextStyleModifier: ViewModifier {
    let style: AppTextStyle

    func body(content: Content) -> some View {
        switch style {
        case .sectionTitle:  content.font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
        case .rowDetail:     content.font(.caption).foregroundStyle(.secondary)
        case .statLabel:     content.font(.caption2).foregroundStyle(.secondary)
        case .statValue:     content.font(.subheadline.bold()).monospacedDigit()
        case .metricValue:   content.font(.title3.bold()).monospacedDigit()
        case .heroDisplay:   content.font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
        case .scoreDisplay:  content.font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
        case .microLabel:    content.font(.system(size: 9)).foregroundStyle(.tertiary)
        case .badge:         content.font(.caption2.bold())
        case .chartAxis:     content.font(.caption2)
        case .cardTitle:     content.font(.system(.headline, design: .rounded, weight: .semibold)).tracking(0.2)
        case .tickerSymbol:  content.font(.subheadline.weight(.bold)).tracking(0.3)
        }
    }
}

extension View {
    func textStyle(_ style: AppTextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
