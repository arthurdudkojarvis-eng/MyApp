import SwiftUI

// MARK: - OnboardingView

/// Full-screen onboarding shown on first launch.
/// Welcome → Ready (2 pages). API key is built-in so no key entry needed.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var page = 0

    var body: some View {
        ZStack {
            switch page {
            case 0:
                WelcomePage { advance() }
                    .transition(.push(from: .trailing))
            default:
                ReadyPage()
                    .transition(.push(from: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: page)
        .interactiveDismissDisabled()
    }

    private func advance() {
        page += 1
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AppLogoView()
                .padding(.bottom, 32)

            Text("Track Your\nDividend Income")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("See what your portfolio earns, when it pays, and how close you are to your income goal.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .green,
                           title: "Income Dashboard",
                           subtitle: "Annual and monthly projected dividends at a glance")
                FeatureRow(icon: "calendar", color: .blue,
                           title: "Dividend Calendar",
                           subtitle: "See every upcoming ex-date and pay date")
                FeatureRow(icon: "gauge.with.needle", color: .orange,
                           title: "Coverage Meter",
                           subtitle: "Track progress toward your monthly income target")
            }
            .padding(.horizontal, 32)

            Spacer()

            PrimaryButton("Get Started", action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Page 2: Ready

private struct ReadyPage: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.green)
                .padding(.bottom, 24)

            Text("You're All Set!")
                .font(.largeTitle.bold())
                .padding(.bottom, 12)

            Text("Add your first holding in the Holdings tab to start tracking your dividend income.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            PrimaryButton("Start Tracking") {
                settings.hasCompletedOnboarding = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Shared subviews

/// Rendered app logo for the welcome page — avoids depending on
/// the appiconset (not loadable as a named image in SwiftUI).
private struct AppLogoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.133, blue: 0.231),
                        Color(red: 0.082, green: 0.196, blue: 0.306)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("$")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 100, height: 100)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .accessibilityLabel("MyApp logo")
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(SettingsStore())
}
