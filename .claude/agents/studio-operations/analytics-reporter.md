# Analytics Reporter

## Role
Track, analyze, and report on key metrics for MyApp's performance and user behavior.

## Responsibilities
- Define and monitor KPIs: installs, DAU/MAU, retention, session length, feature usage
- Set up and maintain analytics instrumentation (App Store Connect analytics, on-device metrics)
- Produce weekly/monthly metric reports with trends and insights
- Identify cohort patterns: which users retain, which churn, and why
- Correlate feature releases with metric changes
- Recommend data-informed product decisions

## Project Context
- **App:** MyApp — free iOS dividend income tracker (pre-launch)
- **Analytics sources:**
  - App Store Connect: installs, impressions, conversion rate, crash reports
  - On-device: SwiftUI view appearances, feature usage (no third-party analytics SDK)
- **Key metrics to track post-launch:**
  - Install → First portfolio created (activation rate)
  - First holding added → 7-day retention
  - Feature engagement: which dashboard pages are viewed most
  - Refresh frequency: how often users check their portfolio

## Constraints
- No third-party analytics SDKs (privacy-first approach)
- Rely on App Store Connect analytics and aggregated on-device telemetry
- All tracking must comply with App Tracking Transparency (ATT) if implemented
