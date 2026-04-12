import SwiftUI

struct QuestsView: View {
    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var theme: ThemeManager

    /// Matches Home: slightly zoom out so the quests list fits more comfortably on screen.
    private var questsContentScale: CGFloat {
        horizontalSizeClass == .regular ? 0.94 : 0.87
    }

    @State private var showXPBurst = false
    @State private var xpBurstText = "+0 XP"
    @State private var showLevelUpBanner = false
    @State private var levelUpText = "Level Up!"
    @State private var rankUpText = ""
    @State private var selectedQuest: Quest?

    @State private var showSwapConfirm = false
    @State private var showSwapQuestPicker = false

    private let swapsPerDay = 1

    private var allQuestsCompleted: Bool {
        !viewModel.quests.isEmpty && viewModel.quests.allSatisfy { $0.isCompleted }
    }

    private var incompleteQuests: [Quest] {
        viewModel.quests.filter { !$0.isCompleted }
    }

    private var swapsRemaining: Int {
        max(0, swapsPerDay - viewModel.skipQuestsUsedToday)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestModeBackground()
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ScreenGuideHeader(
                                title: "Quests",
                                guide: "Complete today’s list for XP and streak progress. One swap per day if you need a different task."
                            )

                            if viewModel.hasCompletedOnboarding {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.lastDailyQuestsUsedAI ? "sparkles" : "list.bullet.rectangle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(viewModel.lastDailyQuestsUsedAI ? theme.accent : AppTheme.textSecondary(for: colorScheme))
                                    Text(
                                        viewModel.lastDailyQuestsUsedAI
                                            ? "Personalized by AI from your questionnaire"
                                            : "Suggested quests (add OpenAI key + profile for AI)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                            }

                            swapQuotaCard

                            dailyProgressCard

                            if allQuestsCompleted {
                                completedStateCard
                            }

                            ForEach(viewModel.quests) { quest in
                                questCard(for: quest)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                        .frame(minWidth: 0, maxWidth: geo.size.width)
                        .scaleEffect(questsContentScale, anchor: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }

                VStack(spacing: 10) {
                    if showLevelUpBanner {
                        VStack(spacing: 6) {
                            Text(levelUpText)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(rankUpText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(theme.vividAccentGradient)
                        )
                        .shadow(radius: 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if showXPBurst {
                        Text(xpBurstText)
                            .font(.system(size: 26, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(theme.accent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: theme.accent.opacity(0.4), radius: 14)
                            .offset(y: showXPBurst ? -30 : 0)
                            .scaleEffect(showXPBurst ? 1.1 : 0.8)
                            .opacity(showXPBurst ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showXPBurst)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Quests")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Use your daily swap?", isPresented: $showSwapConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Swap") {
                    beginSwapAfterConfirmation()
                }
            } message: {
                Text("Are you sure? You only get one swap per day, and it can’t be undone.")
            }
            .confirmationDialog("Which quest should we replace?", isPresented: $showSwapQuestPicker, titleVisibility: .visible) {
                ForEach(incompleteQuests) { quest in
                    Button(quest.title) {
                        viewModel.skipQuest(quest)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            viewModel.refreshSkipQuotaForTodayIfNeeded()
        }
        .sheet(item: $selectedQuest) { quest in
            QuestCompletionSheet(
                viewModel: viewModel,
                quest: quest,
                onSubmitted: { completedQuest in
                    let oldLevel = max(1, (viewModel.xp - completedQuest.xp) / 200 + 1)
                    let newLevel = viewModel.currentLevel

                    withAnimation(.spring()) {
                        xpBurstText = "+\(completedQuest.xp) XP"
                        showXPBurst = true
                    }

                    HapticsManager.shared.success()

                    if newLevel > oldLevel {
                        levelUpText = "Level \(newLevel) Reached!"
                        rankUpText = "\(viewModel.currentRankTitle) rank unlocked"

                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showLevelUpBanner = true
                        }

                        HapticsManager.shared.levelUp()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showLevelUpBanner = false
                            }
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showXPBurst = false
                        }
                    }
                }
            )
        }
    }

    private var canUseSwapButton: Bool {
        viewModel.canSkipQuestToday && !incompleteQuests.isEmpty
    }

    private func beginSwapAfterConfirmation() {
        let open = incompleteQuests
        guard !open.isEmpty else { return }
        if open.count == 1 {
            viewModel.skipQuest(open[0])
        } else {
            showSwapQuestPicker = true
        }
    }

    private var swapQuotaCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily swap")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                Text(swapsRemaining > 0 ? "Replace one quest with a new pick from your pool." : "You’ve used today’s swap.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Text("\(swapsRemaining)/\(swapsPerDay)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(theme.accent.opacity(0.35), lineWidth: 1)
                    )

                Button {
                    showSwapConfirm = true
                } label: {
                    Text("Swap")
                        .font(.caption.weight(.bold))
                        .frame(minWidth: 72)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(
                                    canUseSwapButton
                                        ? AnyShapeStyle(theme.vividAccentGradient)
                                        : AnyShapeStyle(AppTheme.cardSecondary(for: colorScheme))
                                )
                        )
                        .foregroundStyle(canUseSwapButton ? Color.white : AppTheme.textSecondary(for: colorScheme))
                }
                .disabled(!canUseSwapButton)
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.card(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(colorScheme == .dark ? 0.38 : 0.24),
                            theme.accent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily swap. \(swapsRemaining) of \(swapsPerDay) remaining.")
    }

    private var dailyProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today’s progress")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    Text("\(completedTodayCount) of \(totalTodayCount) quests finished for today.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Text("\(Int(progressFraction * 100))%")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.cardSecondary(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.vividAccentGradient)
                        .frame(width: max(12, geometry.size.width * progressFraction), height: 12)
                        .shadow(color: theme.accent.opacity(0.35), radius: 6, y: 2)
                }
            }
            .frame(height: 12)
        }
        .padding(20)
        .questCardStyle(cornerRadius: 24)
        .shadow(color: theme.accent.opacity(0.08), radius: 18, y: 6)
    }

    private var completedStateCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("All daily quests completed")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            Text("Nice work. You cleared today’s quests and earned your progress.")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .questCardStyle(cornerRadius: 24)
        .shadow(color: theme.accent.opacity(0.12), radius: 20, y: 8)
    }

    private func questCard(for quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(quest.category)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.16))
                    )
                    .foregroundStyle(theme.accent)
                    .overlay(
                        Capsule()
                            .stroke(theme.accent.opacity(0.35), lineWidth: 1)
                    )

                Spacer()

                Text(quest.difficulty)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.cardSecondary(for: colorScheme))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                proofTypeBadge(for: quest)

                if quest.isCompleted {
                    completedBadge
                }

                Spacer()
            }

            Text(quest.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            HStack(spacing: 14) {
                Label(quest.time, systemImage: "clock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                Spacer()

                Label("\(quest.xp) XP", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent.opacity(0.95))
            }

            Button(action: {
                selectedQuest = quest
            }) {
                Text(quest.isCompleted ? "Completed" : "Complete quest")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    quest.isCompleted
                                        ? AnyShapeStyle(theme.accent.opacity(0.85))
                                        : AnyShapeStyle(theme.vividAccentGradient)
                                )
                            if !quest.isCompleted {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                        }
                    )
                    .shadow(color: theme.accent.opacity(quest.isCompleted ? 0.15 : 0.35), radius: 12, y: 5)
            }
            .disabled(quest.isCompleted)
            .buttonStyle(.plain)
            .accessibilityLabel(quest.isCompleted ? "Quest completed" : "Complete quest")
        }
        .padding(20)
        .questCardStyle(cornerRadius: 24)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 14, y: 5)
    }

    private func proofTypeBadge(for quest: Quest) -> some View {
        let proofType = resolvedProofType(for: quest)

        return HStack(spacing: 6) {
            Image(systemName: proofTypeIcon(for: proofType))
                .font(.caption2)

            Text(proofTypeLabel(for: proofType))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.cardSecondary(for: colorScheme))
        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
        .clipShape(Capsule())
    }

    private var completedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)

            Text("Done")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.accent.opacity(0.14))
        .foregroundStyle(theme.accent)
        .clipShape(Capsule())
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

    private func resolvedProofType(for quest: Quest) -> ProofType {
        QuestCategory(rawValue: quest.category)?.proofType ?? .reflection
    }

    private func proofTypeLabel(for proofType: ProofType) -> String {
        switch proofType {
        case .photo: return "Photo Ready"
        case .reflection: return "Reflection"
        case .selfCheck: return "Self Check In"
        }
    }

    private func proofTypeIcon(for proofType: ProofType) -> String {
        switch proofType {
        case .photo: return "camera.fill"
        case .reflection: return "text.bubble.fill"
        case .selfCheck: return "checkmark.seal.fill"
        }
    }
}
