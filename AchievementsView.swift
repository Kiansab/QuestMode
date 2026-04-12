import SwiftUI

struct AchievementsView: View {

    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    var body: some View {

        NavigationStack {

            ZStack {

                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {

                    VStack(alignment: .leading, spacing: 32) {

                        ScreenGuideHeader(
                            title: "Achievements",
                            guide: "Badges you unlock by playing: finishing quests, building streaks, and hitting milestones."
                        )

                        tierSection(title: "Bronze", achievements: bronze)

                        tierSection(title: "Silver", achievements: silver)

                        tierSection(title: "Gold", achievements: gold)

                        tierSection(title: "Mythic", achievements: mythic)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func tierSection(title: String, achievements: [Achievement]) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            VStack(spacing: 12) {

                ForEach(achievements) { achievement in
                    achievementCard(achievement)
                }
            }
        }
    }

    private func achievementCard(_ achievement: Achievement) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack {

                Image(systemName: achievement.icon)
                    .foregroundStyle(iconColor(for: achievement))

                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                Spacer()

                if achievement.isUnlocked {

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(iconColor(for: achievement))
                }
            }

            Text(achievement.subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .padding()
        .opacity(achievement.isUnlocked ? 1 : 0.45)
        .questCardStyle()
    }

    private func iconColor(for achievement: Achievement) -> Color {

        switch achievement.tier {

        case .bronze:
            return Color.orange

        case .silver:
            return Color.gray

        case .gold:
            return Color.yellow

        case .mythic:
            return Color.purple
        }
    }

    private var bronze: [Achievement] {
        viewModel.achievements.filter { $0.tier == .bronze }
    }

    private var silver: [Achievement] {
        viewModel.achievements.filter { $0.tier == .silver }
    }

    private var gold: [Achievement] {
        viewModel.achievements.filter { $0.tier == .gold }
    }

    private var mythic: [Achievement] {
        viewModel.achievements.filter { $0.tier == .mythic }
    }
}
