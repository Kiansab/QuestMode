import SwiftUI

/// Renamed from `ProgressView` to avoid shadowing SwiftUI's progress indicator.
struct GameProgressDashboardView: View {

    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // HEADER
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            
                            Text("Track your growth in real life.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        }
                        
                        // RANK CARD
                        
                        VStack(spacing: 20) {
                            
                            Text("Current Rank")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            
                            LevelRingView(
                                progress: viewModel.xpProgress,
                                level: viewModel.currentLevel,
                                rankTitle: viewModel.currentRankTitle
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .questCardStyle()
                        
                        // STATS
                        
                        HStack(spacing: 12) {
                            statCard(
                                value: "\(viewModel.xp)",
                                title: "Total XP",
                                icon: "bolt.fill"
                            )
                            
                            statCard(
                                value: "\(viewModel.streak)",
                                title: "Day Streak",
                                icon: "flame.fill"
                            )
                        }
                        
                        statCard(
                            value: "\(viewModel.completedQuestCount)",
                            title: "Quests Completed",
                            icon: "checkmark.circle.fill"
                        )
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func statCard(value: String, title: String, icon: String) -> some View {
        
        VStack(spacing: 10) {
            
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .questCardStyle(cornerRadius: 20)
    }
}
