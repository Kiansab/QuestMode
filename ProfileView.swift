import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    @State private var showDeleteSheet = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var openAIKeyDraft = ""
    @State private var openAIKeyBanner: String?
    @State private var openAIKeyError: String?
    @State private var hasSavedOpenAIKey = false
    @State private var openAIKeyTestMessage: String?
    @State private var isTestingOpenAIKey = false
    @State private var showOptionalOwnOpenAIKey = false
    #if DEBUG
    @State private var openAIDiagnosticsExpanded = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        ScreenGuideHeader(
                            title: "Profile",
                            guide: "Change colors and light/dark mode, pick quest categories, export your data, or sign out safely."
                        )

                        if let err = viewModel.cloudSyncError {
                            Text("Sync: \(err)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(AppTheme.card(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(theme.accent.opacity(0.15))
                                    .frame(width: 100, height: 100)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(theme.accent)
                            }

                            Text(viewModel.username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                            Text(viewModel.currentRankTitle)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            Text(memberSinceLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .questCardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your stats")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text("A quick summary of your progress.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            profileRow(title: "Current Rank", value: viewModel.currentRankTitle)
                            profileRow(title: "Total XP", value: "\(viewModel.xp)")
                            profileRow(title: "Day Streak", value: "\(viewModel.streak)")
                            profileRow(title: "Quests Completed", value: "\(viewModel.completedQuestCount)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Light or dark mode")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text("Choose what is easiest to read. “System” follows your phone’s setting.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            Picker("Appearance", selection: $viewModel.appearance) {
                                ForEach(AppAppearance.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Accent color")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text("Buttons and highlights use this color across the app.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            Picker("Theme Color", selection: $theme.selectedTheme) {
                                ForEach(ThemeColor.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            Text(QuestModeRemoteAI.usesEveryoneServerAI ? "AI quests (everyone)" : "OpenAI API key")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

                            if QuestModeRemoteAI.usesEveryoneServerAI {
                                Text(
                                    QuestModeRemoteAI.hasCustomQuestBackendURL
                                    ? "Players do not paste any code. You run the small server in the `backend` folder, put your OpenAI key there, and set QuestModeQuestBackendURL in Info.plist to your public https URL. People only sign in."
                                    : "Players do not paste any code. You add one API key via Firebase Cloud Functions. People only sign in — then AI can work for all of them."
                                )
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                                Button {
                                    Task { @MainActor in
                                        isTestingOpenAIKey = true
                                        openAIKeyTestMessage = nil
                                        do {
                                            try await AIQuestGenerator.verifyOpenAIAPICredentials()
                                            openAIKeyTestMessage = "Connection OK — server AI is ready (or your own key works)."
                                        } catch {
                                            openAIKeyTestMessage = AIQuestGenerator.friendlyMessage(for: error)
                                        }
                                        isTestingOpenAIKey = false
                                    }
                                } label: {
                                    Text(isTestingOpenAIKey ? "Testing…" : "Test AI connection")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardSecondary(for: colorScheme)))
                                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                                }
                                .disabled(isTestingOpenAIKey)

                                if let testMsg = openAIKeyTestMessage {
                                    Text(testMsg)
                                        .font(.caption2)
                                        .foregroundStyle(testMsg.contains("OK") ? AppTheme.textSecondary(for: colorScheme) : Color.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                DisclosureGroup("Optional: use my own OpenAI key on this device only", isExpanded: $showOptionalOwnOpenAIKey) {
                                    optionalOpenAIKeyFields(colorScheme: colorScheme)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                            } else {
                                Text("Add your OpenAI secret key here for testing. It stays only on this device.")
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                                Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                                    Label("Open API keys page", systemImage: "link")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.accent)

                                optionalOpenAIKeyFields(colorScheme: colorScheme)

                                Button {
                                    Task { @MainActor in
                                        isTestingOpenAIKey = true
                                        openAIKeyTestMessage = nil
                                        do {
                                            try await AIQuestGenerator.verifyOpenAIAPICredentials()
                                            openAIKeyTestMessage = "OpenAI accepted this key (models list OK)."
                                        } catch {
                                            openAIKeyTestMessage = AIQuestGenerator.friendlyMessage(for: error)
                                        }
                                        isTestingOpenAIKey = false
                                    }
                                } label: {
                                    Text(isTestingOpenAIKey ? "Testing…" : "Test OpenAI connection")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardSecondary(for: colorScheme)))
                                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                                }
                                .disabled(isTestingOpenAIKey)

                                if let testMsg = openAIKeyTestMessage {
                                    Text(testMsg)
                                        .font(.caption2)
                                        .foregroundStyle(testMsg.hasPrefix("OpenAI accepted") ? AppTheme.textSecondary(for: colorScheme) : Color.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            #if DEBUG
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    openAIDiagnosticsExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Safe key diagnostics (no full secret)")
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Image(systemName: openAIDiagnosticsExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                            }
                            .buttonStyle(.plain)

                            if openAIDiagnosticsExpanded {
                                Text(AIQuestGenerator.openAIKeyDiagnosticsSummary())
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .padding(.vertical, 4)
                            }
                            #endif
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()
                        .onAppear {
                            hasSavedOpenAIKey = OpenAIAPIKeyStore.hasStoredKey
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quest categories")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text("We use these to build your daily quests. Tap to turn categories on or off.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            Text(viewModel.aiQuestSetupHint)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)

                            if let genErr = viewModel.questGenerationError {
                                Text("Last AI error: \(genErr)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            ForEach(QuestCategory.allCases) { category in
                                Button {
                                    withAnimation(.spring()) {
                                        viewModel.toggleCategory(category.rawValue)
                                    }
                                } label: {
                                    HStack {
                                        Text(category.rawValue)
                                            .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                                        Spacer()
                                        Image(systemName: viewModel.selectedCategories.contains(category.rawValue) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(viewModel.selectedCategories.contains(category.rawValue) ? theme.accent : AppTheme.textSecondary(for: colorScheme))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityLabel("Category \(category.rawValue)")
                            }

                            Button {
                                viewModel.generateDailyQuests()
                            } label: {
                                Text("Refresh Daily Quests")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.vividAccentGradient))
                                    .foregroundStyle(.white)
                            }
                            .accessibilityLabel("Refresh daily quests")
                            .disabled(viewModel.isGeneratingQuests)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Data and legal")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            Text("Export a copy of your data, or read privacy and terms.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                            Button {
                                exportDataTapped()
                            } label: {
                                Text("Export my data (JSON)")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardSecondary(for: colorScheme)))
                                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            }
                            .accessibilityHint("Exports quests and progress as a JSON file")

                            if let exportError = exportError {
                                Text(exportError)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.danger)
                            }

                            NavigationLink {
                                LegalDocumentView(kind: .privacy)
                            } label: {
                                rowLinkLabel("Privacy Policy")
                            }

                            NavigationLink {
                                LegalDocumentView(kind: .terms)
                            } label: {
                                rowLinkLabel("Terms of Use")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .questCardStyle()

                        VStack(spacing: 12) {
                            Button {
                                viewModel.signOut()
                            } label: {
                                Text("Log Out")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.2)))
                                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                            }
                            .accessibilityLabel("Log out")

                            Button {
                                showDeleteSheet = true
                            } label: {
                                Text("Delete Account & Reset Progress")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.danger))
                                    .foregroundStyle(.white)
                            }
                            .accessibilityLabel("Delete account and reset progress")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showDeleteSheet) {
                DeleteAccountSheet(viewModel: viewModel)
                    .environmentObject(theme)
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { exportURL = nil }) {
                if let url = exportURL {
                    ActivityShareSheet(items: [url])
                }
            }
        }
    }

    private func rowLinkLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardSecondary(for: colorScheme)))
    }

    private func exportDataTapped() {
        exportError = nil
        do {
            let url = try DataExportService.makeExportFile(from: viewModel)
            exportURL = url
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var memberSinceLabel: String {
        if let created = Auth.auth().currentUser?.metadata.creationDate {
            return "Joined \(created.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Member"
    }

    private func profileRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
        }
    }

    @ViewBuilder
    private func optionalOpenAIKeyFields(colorScheme: ColorScheme) -> some View {
        if hasSavedOpenAIKey {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(theme.accent)
                Text("A key is saved on this device.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            }
        }

        SecureField("Paste sk-… key, then Save", text: $openAIKeyDraft)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(12)
            .background(AppTheme.cardSecondary(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        Button {
            openAIKeyBanner = nil
            openAIKeyError = nil
            guard let normalized = AIQuestGenerator.normalizedSecretKeyIfValid(openAIKeyDraft) else {
                openAIKeyError = "Paste a full secret key starting with sk-."
                return
            }
            do {
                try OpenAIAPIKeyStore.saveNormalizedKey(normalized)
                openAIKeyDraft = ""
                hasSavedOpenAIKey = OpenAIAPIKeyStore.hasStoredKey
                openAIKeyBanner = "Saved. Your key stays only on this device."
                viewModel.openAIUserKeyDidChange()
            } catch {
                openAIKeyError = error.localizedDescription
            }
        } label: {
            Text("Save key")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardSecondary(for: colorScheme)))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
        }

        Button(role: .destructive) {
            openAIKeyBanner = nil
            openAIKeyError = nil
            do {
                try OpenAIAPIKeyStore.delete()
                openAIKeyDraft = ""
                hasSavedOpenAIKey = false
                openAIKeyBanner = "Removed saved key."
                viewModel.openAIUserKeyDidChange()
            } catch {
                openAIKeyError = error.localizedDescription
            }
        } label: {
            Text("Remove saved key")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.danger.opacity(0.5)))
                .foregroundStyle(AppTheme.danger)
        }
        .disabled(!hasSavedOpenAIKey)

        if let banner = openAIKeyBanner {
            Text(banner)
                .font(.caption2)
                .foregroundStyle(theme.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let err = openAIKeyError {
            Text(err)
                .font(.caption2)
                .foregroundStyle(AppTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
