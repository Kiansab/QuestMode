import SwiftUI
import UIKit

struct MainTabView: View {

    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var viewModel: QuestViewModel

    var body: some View {

        ZStack {
        VStack(spacing: 0) {
            TabView {
                HomeView(viewModel: viewModel)
                    .accessibilityHint("Level, streak, XP, and today’s completion progress. Use Quests to complete tasks.")
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                QuestsView(viewModel: viewModel)
                    .accessibilityHint("Today’s quests, daily swap at the top, and complete buttons on each card.")
                    .tabItem {
                        Label("Quests", systemImage: "list.bullet.rectangle")
                    }

                AchievementsView(viewModel: viewModel)
                    .accessibilityHint("Badges and milestones you unlock by playing.")
                    .tabItem {
                        Label("Achievements", systemImage: "rosette")
                    }

                QuestLogView(viewModel: viewModel)
                    .accessibilityHint("History of finished quests and your notes.")
                    .tabItem {
                        Label("Log", systemImage: "book.closed.fill")
                    }

                ProfileView(viewModel: viewModel)
                    .accessibilityHint("Account, appearance, categories, and sign out.")
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(theme.accent)
        }

        if viewModel.isGeneratingQuests {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Creating your quests…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityLabel("Generating personalized quests")
        }
        }
        .onAppear {
            viewModel.checkForDailyReset()
            viewModel.refreshSkipQuotaForTodayIfNeeded()
            NotificationScheduler.requestAuthorizationIfNeeded()
            NotificationScheduler.scheduleDailyQuestReminder()
            NotificationScheduler.refreshStreakReminder(hasActiveStreak: viewModel.streak > 0)
            MainTabBarAppearance.apply(theme: theme.selectedTheme)
        }
        .onChange(of: viewModel.streak) { _, new in
            NotificationScheduler.refreshStreakReminder(hasActiveStreak: new > 0)
        }
        .onChange(of: theme.selectedTheme) { _, newTheme in
            DispatchQueue.main.async {
                MainTabBarAppearance.apply(theme: newTheme)
            }
        }
    }
}

private extension UIView {
    func allTabBars() -> [UITabBar] {
        var bars: [UITabBar] = []
        if let b = self as? UITabBar { bars.append(b) }
        for sub in subviews { bars.append(contentsOf: sub.allTabBars()) }
        return bars
    }
}

private enum MainTabBarAppearance {
    /// Uses explicit `UIColor` from `ThemeColor` (not `UIColor(Color)`), and updates live `UITabBar` instances — SwiftUI often ignores `UITabBar.appearance()` until relaunch.
    static func apply(theme: ThemeColor) {
        let selected = theme.uiAccent
        let muted = selected.withAlphaComponent(0.58)
        let appearance = buildAppearance(selected: selected, muted: muted)

        let proxy = UITabBar.appearance()
        proxy.tintColor = selected
        proxy.unselectedItemTintColor = muted
        proxy.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            proxy.scrollEdgeAppearance = appearance
        }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                guard let root = window.rootViewController?.view else { continue }
                for tabBar in root.allTabBars() {
                    tabBar.tintColor = selected
                    tabBar.unselectedItemTintColor = muted
                    tabBar.standardAppearance = appearance
                    if #available(iOS 15.0, *) {
                        tabBar.scrollEdgeAppearance = appearance
                    }
                }
            }
        }
    }

    private static func buildAppearance(selected: UIColor, muted: UIColor) -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        func configure(_ item: UITabBarItemAppearance) {
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [
                .foregroundColor: selected,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [
                .foregroundColor: muted,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
        }

        configure(appearance.stackedLayoutAppearance)
        configure(appearance.inlineLayoutAppearance)
        configure(appearance.compactInlineLayoutAppearance)
        return appearance
    }
}
