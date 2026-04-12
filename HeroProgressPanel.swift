import SwiftUI

struct HeroProgressPanel: View {

    @ObservedObject var viewModel: QuestViewModel
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {

        VStack(alignment: .leading, spacing: 22) {

            HStack(alignment: .top, spacing: 18) {

                LevelRingView(
                    progress: viewModel.xpProgress,
                    level: viewModel.currentLevel,
                    rankTitle: viewModel.currentRankTitle
                )
                .fixedSize(horizontal: true, vertical: false)

                streakBlock
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }
        }
        .padding(26)
        .questCardStyle(cornerRadius: 28)
        .shadow(color: theme.accent.opacity(0.12), radius: 24, y: 12)
    }

    private var streakBlock: some View {
        HStack(alignment: .center, spacing: 14) {

            StreakFlameBadge(streak: viewModel.streak)

            VStack(alignment: .leading, spacing: 6) {
                Text("Streak")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                Text("\(viewModel.streak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(streakValueGradient)

                Text("days in a row")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardSecondary(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.42, blue: 0.18).opacity(colorScheme == .dark ? 0.42 : 0.28),
                            Color(red: 1.0, green: 0.55, blue: 0.22).opacity(colorScheme == .dark ? 0.22 : 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(red: 1.0, green: 0.35, blue: 0.1).opacity(colorScheme == .dark ? 0.18 : 0.1), radius: 14, y: 5)
    }

    private var streakValueGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.48, blue: 0.2),
                Color(red: 1.0, green: 0.28, blue: 0.12)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Streak flame (52pt icon chip)

private struct StreakFlameBadge: View {

    let streak: Int

    @Environment(\.colorScheme) private var colorScheme

    @State private var pulse = false

    /// 0.22 … 1.0 — longer streaks read hotter without breaking layout.
    private var intensity: Double {
        let s = max(0, Double(streak))
        return min(1.0, 0.22 + 0.78 * (1.0 - exp(-s / 12.0)))
    }

    private var pulseDuration: Double { 0.95 - intensity * 0.35 }

    private var coreHot: Color {
        Color(
            red: 1.0,
            green: 0.88 + 0.08 * intensity,
            blue: 0.22 + 0.35 * intensity
        )
    }

    private var coreDeep: Color {
        Color(
            red: 1.0,
            green: 0.26 + 0.1 * intensity,
            blue: 0.04 + 0.06 * intensity
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.2).opacity(colorScheme == .dark ? 0.4 : 0.28),
                            Color(red: 0.95, green: 0.22, blue: 0.08).opacity(colorScheme == .dark ? 0.2 : 0.12)
                        ],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 4,
                        endRadius: 28
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.25).opacity(0.45 + 0.25 * intensity),
                            Color(red: 1.0, green: 0.35, blue: 0.12).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Image(systemName: "flame.fill")
                .font(.system(size: 22 + CGFloat(intensity * 3), weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [coreHot, coreDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.orange.opacity(0.35 + 0.35 * intensity), radius: pulse ? 5 : 3, y: 1)
                .scaleEffect(pulse ? 1.04 + CGFloat(intensity) * 0.05 : 1.0)
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .onAppear {
            pulse = false
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: streak) { _, _ in
            pulse = false
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
