import SwiftUI

struct HomeView: View {

    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var theme: ThemeManager

    @State private var animatedProgress: Double = 0
    @State private var percentBounce = false
    @State private var welcomeNudge = false

    /// Slightly zooms out main content so the dashboard fits more comfortably on screen.
    private var homeContentScale: CGFloat {
        horizontalSizeClass == .regular ? 0.94 : 0.87
    }

    var body: some View {

        NavigationStack {

            ZStack {

                QuestModeBackground()
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView {

                        VStack(alignment: .leading, spacing: 26) {

                            homeWelcomeHeader

                            HeroProgressPanel(viewModel: viewModel)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Level \(viewModel.currentLevel), \(viewModel.currentRankTitle). Streak \(viewModel.streak) days.")

                            dailyProgressCard

                            homeFooterHint
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .padding(.bottom, 36)
                        .frame(minWidth: 0, maxWidth: geo.size.width)
                        .scaleEffect(homeContentScale, anchor: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }

                if let achievement = viewModel.newlyUnlockedAchievement {

                    VStack {

                        Spacer()

                        VStack(spacing: 14) {

                            Text("Achievement unlocked")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                                .textCase(.uppercase)
                                .tracking(0.8)

                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [theme.accent.opacity(0.35), theme.accent.opacity(0.05)],
                                            center: .center,
                                            startRadius: 4,
                                            endRadius: 44
                                        )
                                    )
                                    .frame(width: 72, height: 72)

                                Image(systemName: achievement.icon)
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.yellow, Color.orange.opacity(0.9)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: Color.orange.opacity(0.45), radius: 8, y: 2)
                            }

                            Text(achievement.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                                .multilineTextAlignment(.center)

                            Text(achievement.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(AppTheme.card(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.accent.opacity(0.45),
                                            theme.accent.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 28, y: 14)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.newlyUnlockedAchievement != nil)
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    welcomeNudge = true
                }
            }
        }
    }

    private var homeWelcomeHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                theme.accent.opacity(colorScheme == .dark ? 0.35 : 0.22),
                                theme.accent.opacity(0.06)
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 2,
                            endRadius: 36
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        theme.accent.opacity(0.5),
                                        theme.accent.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(welcomeNudge ? 1.03 : 1.0)

                Image(systemName: homeWelcomeIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: theme.accent.opacity(0.35), radius: 8, y: 2)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(homeGreeting), \(homeDisplayName)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.textPrimary(for: colorScheme),
                                AppTheme.textPrimary(for: colorScheme).opacity(0.88),
                                theme.accent.opacity(0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent.opacity(0.85))

                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.accent.opacity(colorScheme == .dark ? 0.55 : 0.4),
                                theme.accent.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .frame(maxWidth: 112)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(homeGreeting), \(homeDisplayName). \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))")
    }

    private var homeWelcomeIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.horizon.fill"
        case 17..<22: return "moon.stars.fill"
        default: return "moon.zzz.fill"
        }
    }

    private var homeFooterHint: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.2 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("Open the Quests tab when you’re ready to complete or swap today’s tasks.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.card(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(colorScheme == .dark ? 0.35 : 0.22),
                            theme.accent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, y: 6)
    }

    private var homeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var homeDisplayName: String {
        let trimmed = viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Adventurer" : trimmed
    }

    private var dailyProgressCard: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 10) {

                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.35),
                                            theme.accent.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Image(systemName: "sun.max.fill")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.88, blue: 0.4),
                                            theme.accent
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolEffect(.pulse, options: .repeating, value: completedTodayCount)
                        }

                        Text("Today’s progress")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    }

                    Text("\(completedTodayCount) of \(totalTodayCount) quests finished for today.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        .lineSpacing(3)
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.accent.opacity(0.55),
                                            theme.accent.opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: 76, height: 58)

                    VStack(spacing: 3) {
                        Text("\(Int(round(animatedProgress * 100)))%")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [theme.accent, theme.accent.opacity(0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .contentTransition(.numericText())
                            .scaleEffect(percentBounce ? 1.06 : 1.0)

                        Text("done")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    }
                }
                .shadow(color: theme.accent.opacity(0.2), radius: 10, y: 3)
            }

            DailyQuestProgressBar(
                progress: animatedProgress,
                accent: theme.accent,
                colorScheme: colorScheme
            )
        }
        .padding(20)
        .questCardStyle(cornerRadius: 26)
        .shadow(color: theme.accent.opacity(0.1), radius: 20, y: 8)
        .onAppear {
            animatedProgress = 0
            withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                animatedProgress = progressFraction
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                percentBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    percentBounce = false
                }
            }
        }
        .onChange(of: progressFraction) { _, newValue in
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                animatedProgress = newValue
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                percentBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    percentBounce = false
                }
            }
        }
        .onChange(of: completedTodayCount) { _, _ in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                animatedProgress = progressFraction
            }
        }
    }

    private var completedTodayCount: Int {
        viewModel.quests.filter { $0.isCompleted }.count
    }

    private var totalTodayCount: Int {
        viewModel.quests.count
    }

    private var progressFraction: Double {
        guard totalTodayCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayCount)
    }
}

// MARK: - Today’s progress bar (animated fill + shimmer)

private struct DailyQuestProgressBar: View {
    let progress: Double
    let accent: Color
    let colorScheme: ColorScheme

    private let barHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(barHeight * 0.85, width * progress)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(AppTheme.cardSecondary(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 4, y: 2)

                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent,
                                accent.opacity(0.88),
                                Color(red: 0.55, green: 0.92, blue: 1.0).opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .padding(1)
                    )
                    .shadow(color: accent.opacity(0.45), radius: 8, y: 2)
                    .overlay {
                        TimelineView(.animation(minimumInterval: 1.0 / 40.0, paused: false)) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let phase = CGFloat((t * 0.65).truncatingRemainder(dividingBy: 1.0))
                            GeometryReader { geo in
                                let w = geo.size.width
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.45),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: w * 0.45)
                                .offset(x: -w * 0.35 + phase * w * 1.2)
                                .blendMode(.plusLighter)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: barHeight / 2))
                    }

                if progress > 0.02 {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color.white.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 6
                            )
                        )
                        .frame(width: 10, height: 10)
                        .offset(x: fillWidth - 5)
                        .shadow(color: Color.white.opacity(0.8), radius: 4)
                }
            }
        }
        .frame(height: barHeight)
    }
}
