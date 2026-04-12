import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var nameInput: String = ""
    @State private var step: Int = 1

    @State private var selectedFocus: OnboardingPrimaryFocus?
    @State private var selectedTime: OnboardingTimeBudget?
    @State private var selectedObstacles: Set<OnboardingObstacle> = []
    @State private var personalNote: String = ""

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            ZStack {

                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    header

                    TabView(selection: $step) {

                        welcomeStep
                            .tag(1)

                        primaryFocusStep
                            .tag(2)

                        timeBudgetStep
                            .tag(3)

                        obstaclesAndNoteStep
                            .tag(4)

                        appearanceStep
                            .tag(5)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    footer
                }
            }
        }
    }

    // MARK: - Header

    var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quest Mode")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                Spacer()

                Text("Step \(step) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.cardSecondary(for: colorScheme))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.AuthFlow.accentGradient)
                        .frame(
                            width: geometry.size.width * CGFloat(step) / CGFloat(totalSteps),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding()
    }

    // MARK: - Step 1

    var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    Text("Turn your real life into a game with daily quests, streaks, and level ups.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What should we call you?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    TextField("Enter your name", text: $nameInput)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(AppTheme.card(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.AuthFlow.outlineGradient, lineWidth: 1)
                        )
                        .shadow(color: AppTheme.AuthFlow.accent.opacity(0.12), radius: 10, y: 4)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                }

                onboardingTip(
                    icon: "gamecontroller.fill",
                    title: "Level up your real life",
                    subtitle: "Complete small quests, gain XP, and build momentum every day."
                )
            }
            .padding()
        }
    }

    // MARK: - Step 2

    private var primaryFocusStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepIntro(
                    title: "What matters most?",
                    subtitle: "We’ll shape your daily quests around this—pick the one that fits best right now."
                )

                VStack(spacing: 12) {
                    ForEach(OnboardingPrimaryFocus.allCases) { focus in
                        selectionCard(
                            title: focus.title,
                            subtitle: focus.subtitle,
                            isSelected: selectedFocus == focus
                        ) {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                                selectedFocus = focus
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 3

    private var timeBudgetStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepIntro(
                    title: "How much time do you have?",
                    subtitle: "We’ll favor quests that fit the time you usually have—not a rigid rule, just a better match."
                )

                VStack(spacing: 12) {
                    ForEach(OnboardingTimeBudget.allCases) { budget in
                        selectionCard(
                            title: budget.title,
                            subtitle: budget.detail,
                            isSelected: selectedTime == budget
                        ) {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                                selectedTime = budget
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 4

    private var obstaclesAndNoteStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepIntro(
                    title: "What gets in the way?",
                    subtitle: "Optional—select anything that sounds like you. This helps us tune quest ideas."
                )

                VStack(spacing: 12) {
                    ForEach(OnboardingObstacle.allCases) { obstacle in
                        toggleRow(
                            title: obstacle.title,
                            isOn: selectedObstacles.contains(obstacle)
                        ) {
                            toggleObstacle(obstacle)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything specific you’re working toward?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    Text("This is what your daily quests will lean on most—a sentence or two is enough.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                    TextField("e.g. run a 5K, speak up at work, sleep better…", text: $personalNote, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(AppTheme.card(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.AuthFlow.outlineGradient, lineWidth: 1)
                        )
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                }
            }
            .padding()
        }
    }

    private func toggleObstacle(_ obstacle: OnboardingObstacle) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            if obstacle.isExclusive {
                selectedObstacles = [.none]
            } else {
                selectedObstacles.remove(.none)
                if selectedObstacles.contains(obstacle) {
                    selectedObstacles.remove(obstacle)
                } else {
                    selectedObstacles.insert(obstacle)
                }
            }
        }
    }

    // MARK: - Step 5

    var appearanceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make it yours")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    Text("Choose how Quest Mode should look.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Appearance")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                    appearanceOptionRow
                }
                .padding()
                .background(AppTheme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.AuthFlow.outlineGradient, lineWidth: 1)
                )

                onboardingTip(
                    icon: "sparkles",
                    title: "You’re all set",
                    subtitle: "Your daily quests will be built from your answers—especially what you wrote in “working toward”—and the categories we picked (you can change categories anytime in Profile)."
                )
            }
            .padding()
        }
    }

    // MARK: - Footer

    var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if step > 1 {
                    Button {
                        withAnimation(.spring()) {
                            step -= 1
                        }
                    } label: {
                        Text("Back")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.card(for: colorScheme))
                            .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }

                Button(action: handlePrimaryAction) {
                    Text(primaryButtonTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    primaryButtonEnabled
                                        ? AnyShapeStyle(AppTheme.AuthFlow.accentGradient)
                                        : AnyShapeStyle(AppTheme.cardSecondary(for: colorScheme))
                                )
                        )
                        .foregroundStyle(primaryButtonEnabled ? Color.white : AppTheme.textSecondary(for: colorScheme))
                }
                .disabled(!primaryButtonEnabled)
            }

            #if DEBUG
            Button {
                viewModel.debugCompleteOnboardingWithSampleData()
            } label: {
                Text("Skip onboarding — sample profile (DEBUG)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding()
    }

    // MARK: - Helpers

    private func stepIntro(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectionCard(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.AuthFlow.accent : AppTheme.textSecondary(for: colorScheme))
            }
            .padding()
            .background(AppTheme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppTheme.AuthFlow.accent.opacity(0.55) : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AppTheme.AuthFlow.accent : AppTheme.textSecondary(for: colorScheme))
            }
            .padding()
            .background(AppTheme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    var primaryButtonTitle: String {
        step == totalSteps ? "Start Journey" : "Continue"
    }

    var primaryButtonEnabled: Bool {
        switch step {
        case 1: return true
        case 2: return selectedFocus != nil
        case 3: return selectedTime != nil
        case 4: return true
        case 5: return true
        default: return false
        }
    }

    private func handlePrimaryAction() {
        if step < totalSteps {
            withAnimation(.spring()) {
                step += 1
            }
        } else {
            guard let focus = selectedFocus, let time = selectedTime else { return }
            let obstacles = normalizedObstacles()
            let note = String(personalNote.prefix(200))
            let profile = OnboardingProfile(
                primaryFocus: focus,
                timeBudget: time,
                obstacles: obstacles,
                personalNote: note
            )
            viewModel.finishOnboarding(name: nameInput, profile: profile)
        }
    }

    private func normalizedObstacles() -> [OnboardingObstacle] {
        if selectedObstacles.contains(.none) { return [.none] }
        return Array(selectedObstacles).sorted { $0.rawValue < $1.rawValue }
    }

    private var appearanceOptionRow: some View {
        VStack(spacing: 10) {
            ForEach(AppAppearance.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.appearance = option
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: appearanceIcon(for: option))
                            .font(.title3)
                            .foregroundStyle(AppTheme.AuthFlow.accent)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.AuthFlow.accent.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text(appearanceSubtitle(for: option))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        }

                        Spacer(minLength: 8)

                        Image(systemName: viewModel.appearance == option ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(viewModel.appearance == option ? AppTheme.AuthFlow.accent : AppTheme.textSecondary(for: colorScheme).opacity(0.5))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(viewModel.appearance == option ? AppTheme.AuthFlow.accent.opacity(0.14) : AppTheme.cardSecondary(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                viewModel.appearance == option ? AppTheme.AuthFlow.accent.opacity(0.55) : Color.clear,
                                lineWidth: viewModel.appearance == option ? 1.5 : 0
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func appearanceIcon(for option: AppAppearance) -> String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    private func appearanceSubtitle(for option: AppAppearance) -> String {
        switch option {
        case .system: return "Match your device setting"
        case .light: return "Bright surfaces, easy to read in daylight"
        case .dark: return "Easier on the eyes in low light"
        }
    }

    func onboardingTip(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.AuthFlow.accent.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .foregroundStyle(AppTheme.AuthFlow.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.AuthFlow.outlineGradient, lineWidth: 1)
        )
        .shadow(color: AppTheme.AuthFlow.accent.opacity(colorScheme == .dark ? 0.08 : 0.06), radius: 14, y: 6)
    }
}
