import SwiftUI

struct LevelRingView: View {

    var progress: Double
    var level: Int
    var rankTitle: String

    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private let ringSize: CGFloat = 108
    private let lineWidth: CGFloat = 12

    @State private var glowPulse = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ringContent(phase: t)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .onAppear {
                appeared = false
                withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 1.85).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            Text(rankTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

            Text("\(Int(progress * 200)) / 200 XP")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme).opacity(0.9))
        }
        .frame(width: 118)
    }

    @ViewBuilder
    private func ringContent(phase: TimeInterval) -> some View {
        let spin = phase * 38.0
        let shimmer = (sin(phase * 2.4) * 0.5 + 0.5)

        ZStack {
            // Outer RPG-style bezel
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.cardSecondary(for: colorScheme).opacity(colorScheme == .dark ? 0.95 : 0.88),
                            AppTheme.card(for: colorScheme).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth + 5
                )
                .blur(radius: 1.2)

            // Track (etched groove)
            Circle()
                .stroke(
                    AppTheme.cardSecondary(for: colorScheme),
                    lineWidth: lineWidth
                )

            Circle()
                .stroke(
                    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                    lineWidth: lineWidth - 3
                )
                .padding(2.5)
                .blur(radius: 0.5)

            // Soft glow under progress arc
            Circle()
                .trim(from: 0, to: appeared ? progress : 0)
                .stroke(
                    theme.accent.opacity(0.45 + 0.25 * shimmer),
                    style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: glowPulse ? 10 : 6)
                .opacity(0.85)

            // Rotating energy tick (subtle RPG “charge” feel)
            Circle()
                .trim(from: 0, to: 0.14)
                .stroke(
                    AngularGradient(
                        colors: [
                            theme.accent.opacity(0.05),
                            theme.accent.opacity(0.55),
                            Color.white.opacity(0.35),
                            theme.accent.opacity(0.05)
                        ],
                        center: .center,
                        angle: .degrees(spin.truncatingRemainder(dividingBy: 360))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 2)
                .opacity(0.35 + 0.2 * shimmer)

            // Main XP arc
            Circle()
                .trim(from: 0, to: appeared ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: xpArcColors,
                        center: .center,
                        angle: .degrees(-90 + spin * 0.15)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.accent.opacity(0.55), radius: glowPulse ? 10 : 5, y: 1)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: progress)

            // Level badge (center)
            VStack(spacing: 3) {
                Text("LVL")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                Text("\(level)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.textPrimary(for: colorScheme),
                                AppTheme.textPrimary(for: colorScheme).opacity(0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: theme.accent.opacity(0.25), radius: 2, y: 1)
            }
            .scaleEffect(appeared ? 1.0 : 0.88)
            .opacity(appeared ? 1.0 : 0.7)

            // Progress gem at arc tip
            if progress > 0.02 {
                RingProgressGem(
                    progress: progress,
                    ringSize: ringSize,
                    lineWidth: lineWidth,
                    accent: theme.accent,
                    pulse: glowPulse
                )
            }
        }
    }

    private var xpArcColors: [Color] {
        [
            theme.accent.opacity(0.75),
            theme.accent,
            Color.white.opacity(0.92),
            theme.accent.opacity(0.9),
            Color(red: 0.55, green: 0.95, blue: 1.0).opacity(0.85),
            theme.accent.opacity(0.8)
        ]
    }
}

// MARK: - Gem at arc end

private struct RingProgressGem: View {
    let progress: Double
    let ringSize: CGFloat
    let lineWidth: CGFloat
    let accent: Color
    let pulse: Bool

    var body: some View {
        let r = Double((ringSize - lineWidth) / 2)
        let angle = progress * 2 * Double.pi - Double.pi / 2
        let cx = Double(ringSize) / 2
        let cy = Double(ringSize) / 2
        let x = cx + cos(angle) * r
        let y = cy + sin(angle) * r

        ZStack {
            Circle()
                .fill(accent.opacity(0.45))
                .frame(width: 18, height: 18)
                .blur(radius: pulse ? 6 : 3)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, accent, accent.opacity(0.5)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 10
                    )
                )
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.8), radius: 4, y: 1)
        }
        .position(x: CGFloat(x), y: CGFloat(y))
    }
}
