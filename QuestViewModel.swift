import SwiftUI
import Combine
import FirebaseAuth
import FirebaseCrashlytics

class QuestViewModel: ObservableObject {

    private let lastQuestRefreshKey = "lastQuestRefreshDate"
    private let rewardDateKey = "questmode_reward_date"
    private let questLogKey = "questmode_quest_log"
    private let legacyOnboardingKey = "hasCompletedSetup"

    /// Mirrors Firebase email verification so SwiftUI updates when `reload()` completes.
    @Published var isCurrentUserEmailVerified: Bool = true

    /// Email/password accounts must verify before onboarding or main UI; OAuth providers are not blocked here.
    /// Uses `isCurrentUserEmailVerified` (not only `User.isEmailVerified`) so SwiftUI updates after `reload()`.
    var needsEmailVerification: Bool {
        guard let user = currentUser else { return false }
        let usesPassword = user.providerData.contains { $0.providerID == EmailAuthProviderID }
        return usesPassword && !isCurrentUserEmailVerified
    }
    @Published private(set) var authStateRevision: Int = 0
    private let lastLocalWriteKey = "questmode_last_local_write"
    private let skipsDayKeyUD = "questmode_skips_day"
    private let skipsUsedKeyUD = "questmode_skips_used"

    // MARK: - Published Properties

    @Published var isProcessing: Bool = false
    @Published var xp: Int = 120 { didSet { saveProgress() } }
    @Published var streak: Int = 0 { didSet { saveProgress() } }
    @Published var username: String = "Kian" { didSet { saveProgress() } }
    @Published var quests: [Quest] = [] { didSet { saveProgress() } }
    @Published var appearance: AppAppearance = .system {
        didSet {
            saveProgress()
            objectWillChange.send()
        }
    }
    @Published var lastPlayedDate: Date = Date.distantPast { didSet { saveProgress() } }
    @Published var lastStreakDate: Date = Date.distantPast { didSet { saveProgress() } }
    @Published var selectedCategories: [String] = [] { didSet { saveProgress() } }
    /// Questionnaire answers; when set, daily quests use weighted picks + extra tailored templates.
    @Published var onboardingProfile: OnboardingProfile? = nil { didSet { saveProgress() } }
    @Published var hasCompletedOnboarding: Bool = false { didSet { saveProgress() } }
    @Published var questLog: [QuestLogEntry] = [] { didSet { saveProgress() } }
    @Published var dailyRewardAvailable: Bool = false
    @Published var lastRewardDate: Date = Date.distantPast { didSet { saveProgress() } }
    @Published var newlyUnlockedAchievement: Achievement?
    @Published var currentUser: User?
    @Published var cloudSyncError: String?
    @Published var skipQuestsUsedToday: Int = 0
    /// True while OpenAI is generating personalized quests (shows overlay in main tabs).
    @Published var isGeneratingQuests: Bool = false
    /// Last AI generation failure message (optional); cleared on next successful run.
    @Published var questGenerationError: String?
    /// `true` when the current daily quests came from OpenAI; `false` when using the built-in suggestion pool.
    @Published var lastDailyQuestsUsedAI: Bool = false
    /// Bumps when the user signs out so `LoginView` remounts (clean login vs signup).
    @Published var authSessionID = UUID()

    private let xpKey = "questmode_xp"
    private let xpInitializedKey = "questmode_xp_initialized"

    private let streakKey = "questmode_streak"
    private let usernameKey = "questmode_username"
    private let questsKey = "questmode_quests"
    private let appearanceKey = "questmode_appearance"
    private let lastPlayedDateKey = "questmode_last_played"
    private let streakDateKey = "questmode_streak_date"
    private let selectedCategoriesKey = "questmode_selected_categories"
    private let onboardingProfileKey = "questmode_onboarding_profile_v1"
    private let questTitleHistoryKey = "questmode_quest_title_history"

    private var syncWorkItem: DispatchWorkItem?
    private var lastRemoteUpdatedAt: TimeInterval = 0

    init() {
        loadProgress()
        currentUser = Auth.auth().currentUser
        if let u = currentUser {
            Crashlytics.crashlytics().setUserID(u.uid)
            isCurrentUserEmailVerified = u.isEmailVerified
            hasCompletedOnboarding = loadOnboardingStatus(for: u.uid, user: u)
        }
        ensureDailyQuestsIfNeeded()

        _ = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.currentUser = user
                if let user = user {
                    Crashlytics.crashlytics().setUserID(user.uid)
                    self.isCurrentUserEmailVerified = user.isEmailVerified
                    self.hasCompletedOnboarding = self.loadOnboardingStatus(for: user.uid, user: user)
                    self.refreshSkipQuotaForToday()
                    self.ensureDailyQuestsIfNeeded()
                    self.pullRemoteProgressIfNeeded()
                } else {
                    Crashlytics.crashlytics().setUserID("")
                    self.isCurrentUserEmailVerified = true
                }
                self.authStateRevision += 1
                self.cloudSyncError = nil
            }
        }
    }

    /// Reloads the Firebase user (e.g. after tapping the email verification link).
    func refreshAuthUser(completion: (() -> Void)? = nil) {
        Auth.auth().currentUser?.reload { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }
                self.currentUser = Auth.auth().currentUser
                self.isCurrentUserEmailVerified = self.currentUser?.isEmailVerified ?? true
                self.authStateRevision += 1
                completion?()
            }
        } ?? completion?()
    }

    /// New accounts must complete welcome onboarding on this device for this uid.
    /// Writes UserDefaults synchronously first so auth state listeners see the flag before inferring "returning user".
    func resetOnboardingForNewAccount(uid: String) {
        UserDefaults.standard.set(false, forKey: perUserOnboardingKey(uid: uid))
        DispatchQueue.main.async { [weak self] in
            self?.hasCompletedOnboarding = false
        }
    }

    private func perUserOnboardingKey(uid: String) -> String {
        "questmode_onboarding_done_\(uid)"
    }

    /// Per-user onboarding, with one-time migration from legacy single-device key.
    /// Signed-in users who already have local progress (quests, log, daily refresh) are treated as past onboarding
    /// so a stale `false` flag or missing key cannot trap them in the welcome flow every launch.
    private func loadOnboardingStatus(for uid: String, user: User) -> Bool {
        let key = perUserOnboardingKey(uid: uid)
        let evidence = hasEvidenceUserFinishedSetupLocally()

        if UserDefaults.standard.object(forKey: key) != nil {
            let stored = UserDefaults.standard.bool(forKey: key)
            if stored { return true }
            if evidence {
                UserDefaults.standard.set(true, forKey: key)
                return true
            }
            return false
        }
        if UserDefaults.standard.bool(forKey: legacyOnboardingKey) {
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.removeObject(forKey: legacyOnboardingKey)
            return true
        }
        if evidence {
            UserDefaults.standard.set(true, forKey: key)
            return true
        }
        let created = user.metadata.creationDate ?? .distantPast
        let lastSignIn = user.metadata.lastSignInDate ?? created
        let signInDelta = abs(lastSignIn.timeIntervalSince(created))
        // Brand-new account: require welcome until finishOnboarding writes `true` or local progress appears.
        if signInDelta < 120 {
            return false
        }
        // Established account, first launch on this device, no progress file yet — skip welcome.
        UserDefaults.standard.set(true, forKey: key)
        return true
    }

    /// True when local data shows the user has already completed setup (not still on step 1–3 with empty state).
    private func hasEvidenceUserFinishedSetupLocally() -> Bool {
        if !quests.isEmpty { return true }
        if !questLog.isEmpty { return true }
        if UserDefaults.standard.object(forKey: lastQuestRefreshKey) != nil { return true }
        return false
    }

    private func persistOnboardingForCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: perUserOnboardingKey(uid: uid))
    }

    // MARK: - Core Progress (Computed Props)

    var completedQuestCount: Int { questLog.count }
    var currentLevel: Int { max(1, xp / 200 + 1) }
    var xpProgress: Double { Double(xp % 200) / 200.0 }
    var todaysQuest: Quest? { quests.first(where: { !$0.isCompleted }) }

    /// True if the user can still swap a quest today; must not mutate state (SwiftUI reads this in view bodies).
    var canSkipQuestToday: Bool {
        skipQuestsUsedToday < 1
    }

    var currentRankTitle: String {
        switch currentLevel {
        case 1: return "Wanderer"
        case 2: return "Explorer"
        case 3: return "Challenger"
        case 4: return "Adventurer"
        default: return "Legend"
        }
    }

    var achievements: [Achievement] {
        [
            Achievement(id: "first_quest", title: "First Quest", subtitle: "Complete your first quest", icon: "star.fill", tier: .bronze, isUnlocked: completedQuestCount >= 1),
            Achievement(id: "momentum", title: "Momentum", subtitle: "Complete 5 quests", icon: "bolt.fill", tier: .bronze, isUnlocked: completedQuestCount >= 5),
            Achievement(id: "explorer_level", title: "Explorer", subtitle: "Reach Level 2", icon: "map.fill", tier: .bronze, isUnlocked: currentLevel >= 2),
            Achievement(id: "dedicated", title: "Dedicated", subtitle: "Complete 10 quests", icon: "flame.fill", tier: .silver, isUnlocked: completedQuestCount >= 10),
            Achievement(id: "veteran", title: "Veteran", subtitle: "Reach Level 5", icon: "shield.fill", tier: .silver, isUnlocked: currentLevel >= 5),
            Achievement(id: "streak_7", title: "Week of Power", subtitle: "Maintain a 7-day streak", icon: "calendar", tier: .silver, isUnlocked: streak >= 7),
            Achievement(id: "centurion", title: "Centurion", subtitle: "Earn 500 total XP", icon: "crown.fill", tier: .gold, isUnlocked: xp >= 500),
            Achievement(id: "legend_level", title: "Rising Legend", subtitle: "Reach Level 10", icon: "sparkles", tier: .gold, isUnlocked: currentLevel >= 10),
            Achievement(id: "master", title: "Quest Master", subtitle: "Complete 25 quests", icon: "medal.fill", tier: .gold, isUnlocked: completedQuestCount >= 25),
            Achievement(id: "mythic_streak", title: "Unbroken", subtitle: "Maintain a 30-day streak", icon: "bolt.heart.fill", tier: .mythic, isUnlocked: streak >= 30),
            Achievement(id: "mythic_xp", title: "Mythic Wealth", subtitle: "Earn 2000 total XP", icon: "diamond.fill", tier: .mythic, isUnlocked: xp >= 2000)
        ]
    }

    // MARK: - Authentication Actions

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isProcessing = false
                self.syncWorkItem?.cancel()
                self.authSessionID = UUID()
            }
        } catch {
            // ignore
        }
    }

    /// Deletes Firebase Auth account after re-authentication and clears remote + local state.
    func deleteAccount(password: String, completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion("No signed-in user with an email on file.")
            return
        }
        guard user.providerData.contains(where: { $0.providerID == EmailAuthProviderID }) else {
            completion("Account deletion with a password only works for email sign-in. Reset your password or contact support.")
            return
        }
        let uid = user.uid
        isProcessing = true
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(error.localizedDescription)
                }
                return
            }
            FirestoreProgressSync.deleteRemoteProgress { _ in
                DispatchQueue.main.async {
                    user.delete { err in
                        DispatchQueue.main.async {
                            self.isProcessing = false
                            if let err = err {
                                completion(err.localizedDescription)
                            } else {
                                self.resetAllProgress(clearingUid: uid)
                                self.currentUser = nil
                                self.cloudSyncError = nil
                                self.authSessionID = UUID()
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
    }

    func completeQuest(_ quest: Quest, reflection: String, imageData: Data?) {
        guard let index = quests.firstIndex(where: { $0.id == quest.id }) else { return }
        guard !quests[index].isCompleted else { return }

        let proofType = QuestCategory(rawValue: quest.category)?.proofType ?? .reflection
        let proofStatus: ProofStatus = {
            switch proofType {
            case .reflection:
                return .reflectionSubmitted
            case .selfCheck:
                return .selfCheckCompleted
            case .photo:
                return (imageData != nil) ? .reflectionSubmitted : .photoPending
            }
        }()

        let unlockedBefore = Set(achievements.filter(\.isUnlocked).map(\.id))

        quests[index].isCompleted = true
        xp += quest.xp

        let streakUpdate = StreakCalculator.updateAfterQuestCompletion(
            now: Date(),
            previousStreak: streak,
            lastPlayed: lastPlayedDate
        )
        streak = streakUpdate.newStreak
        lastPlayedDate = streakUpdate.lastPlayedDate
        lastStreakDate = streakUpdate.lastStreakDate

        let entry = QuestLogEntry(
            title: quest.title,
            category: quest.category,
            xp: quest.xp,
            reflection: reflection,
            imageData: imageData,
            proofType: proofType,
            proofStatus: proofStatus
        )
        questLog.insert(entry, at: 0)

        let newlyUnlocked = achievements.filter { $0.isUnlocked && !unlockedBefore.contains($0.id) }
        newlyUnlockedAchievement = newlyUnlocked.first

        if newlyUnlockedAchievement != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
                self?.newlyUnlockedAchievement = nil
            }
        }

        saveProgress()
        NotificationScheduler.refreshStreakReminder(hasActiveStreak: streak > 0)
    }

    func finishOnboarding(name: String, profile: OnboardingProfile) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        username = trimmed.isEmpty ? "Player" : trimmed
        var p = profile
        p.personalNote = String(p.personalNote.prefix(200))
        onboardingProfile = p
        selectedCategories = QuestPersonalization.derivedCategories(from: p)
        hasCompletedOnboarding = true

        if let uid = Auth.auth().currentUser?.uid {
            UserDefaults.standard.set(true, forKey: perUserOnboardingKey(uid: uid))
        }
        UserDefaults.standard.removeObject(forKey: legacyOnboardingKey)
        generateDailyQuests()
        if UserDefaults.standard.object(forKey: lastQuestRefreshKey) == nil {
            UserDefaults.standard.set(Date(), forKey: lastQuestRefreshKey)
        }
        saveProgress()
    }

    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.removeAll { $0 == category }
        } else {
            selectedCategories.append(category)
        }
    }

    func skipQuest(_ quest: Quest) {
        guard canSkipQuestToday else { return }
        guard let index = quests.firstIndex(where: { $0.id == quest.id }) else { return }
        let takenTitles = Set(quests.map(\.title))

        if shouldGenerateQuestsWithAI, let profile = onboardingProfile {
            Task {
                let allExcluded = collectExcludedTitleStrings()
                let day = DailyQuestSelector.dayKey(for: Date())
                let cats = selectedCategories.isEmpty ? QuestCategory.allCases.map(\.rawValue) : selectedCategories
                do {
                    let replacement = try await AIQuestGenerator.generateReplacementQuest(
                        profile: profile,
                        username: username,
                        calendarDayKey: day,
                        excludedTitles: allExcluded,
                        allowedCategories: cats
                    )
                    await MainActor.run {
                        self.quests[index] = replacement
                        self.recordQuestTitlesInHistory([replacement.title])
                        self.questGenerationError = nil
                        self.registerSkipUse()
                        self.saveProgress()
                    }
                } catch {
                    await MainActor.run {
                        self.questGenerationError = AIQuestGenerator.friendlyMessage(for: error)
                        self.skipQuestLegacy(at: index, takenTitles: takenTitles)
                    }
                }
            }
            return
        }

        skipQuestLegacy(at: index, takenTitles: takenTitles)
    }

    private func skipQuestLegacy(at index: Int, takenTitles: Set<String>) {
        let pool = filteredQuestPool()
        let uid = Auth.auth().currentUser?.uid ?? "guest"
        let day = DailyQuestSelector.dayKey(for: Date())
        let seed = DailyQuestSelector.seed(userId: uid, dayKey: day) + "-skip-\(skipQuestsUsedToday)"
        let orderedIndices = pool.indices.sorted {
            DailyQuestSelector.hash64("\(seed)|\($0)") < DailyQuestSelector.hash64("\(seed)|\($1)")
        }
        guard let pickIdx = orderedIndices.first(where: { !takenTitles.contains(pool[$0].title) })
            ?? orderedIndices.first else { return }

        quests[index] = pool[pickIdx]
        recordQuestTitlesInHistory([pool[pickIdx].title])
        registerSkipUse()
        saveProgress()
    }

    func resetAllProgress(clearingUid: String? = nil) {
        xp = 0
        streak = 0
        username = "Player"
        quests = []
        questLog = []
        selectedCategories = []
        onboardingProfile = nil
        hasCompletedOnboarding = false
        lastPlayedDate = Date.distantPast
        lastStreakDate = Date.distantPast
        lastRewardDate = Date.distantPast
        dailyRewardAvailable = false
        newlyUnlockedAchievement = nil
        skipQuestsUsedToday = 0
        lastRemoteUpdatedAt = 0

        UserDefaults.standard.removeObject(forKey: xpInitializedKey)
        let uidToClear = clearingUid ?? Auth.auth().currentUser?.uid
        if let uid = uidToClear {
            UserDefaults.standard.removeObject(forKey: perUserOnboardingKey(uid: uid))
        }
        UserDefaults.standard.removeObject(forKey: legacyOnboardingKey)
        [xpKey, streakKey, usernameKey, questsKey, selectedCategoriesKey, questLogKey, lastPlayedDateKey, streakDateKey, lastQuestRefreshKey, rewardDateKey, skipsDayKeyUD, skipsUsedKeyUD, lastLocalWriteKey, onboardingProfileKey, questTitleHistoryKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        generateDailyQuests()
    }

    /// Fills `quests` when onboarding is done but the list is empty (e.g. cloud sync overwrote with `[]`, or stale local state).
    private func ensureDailyQuestsIfNeeded() {
        guard hasCompletedOnboarding else { return }
        guard quests.isEmpty else { return }
        guard !isGeneratingQuests else { return }
        generateDailyQuests()
        saveProgressLocalOnly()
    }

    // MARK: - Daily / rewards

    /// When an API key and saved questionnaire exist, generates via OpenAI from those answers (goal text prioritized in prompts); otherwise preset pool.
    func generateDailyQuests() {
        if shouldGenerateQuestsWithAI {
            guard !isGeneratingQuests else { return }
            isGeneratingQuests = true
            questGenerationError = nil
            guard let profile = onboardingProfile else {
                isGeneratingQuests = false
                lastDailyQuestsUsedAI = false
                generateDailyQuestsLegacy()
                return
            }
            Task {
                let excluded = collectExcludedTitleStrings()
                let day = DailyQuestSelector.dayKey(for: Date())
                let cats = selectedCategories.isEmpty ? QuestCategory.allCases.map(\.rawValue) : selectedCategories
                do {
                    let generated = try await AIQuestGenerator.generateDailyQuests(
                        profile: profile,
                        username: username,
                        calendarDayKey: day,
                        excludedTitles: excluded,
                        allowedCategories: cats
                    )
                    await MainActor.run {
                        self.quests = generated
                        self.recordQuestTitlesInHistory(generated.map(\.title))
                        self.questGenerationError = nil
                        self.lastDailyQuestsUsedAI = true
                        self.isGeneratingQuests = false
                        self.saveProgress()
                    }
                } catch {
                    await MainActor.run {
                        self.generateDailyQuestsLegacy()
                        self.lastDailyQuestsUsedAI = false
                        let detail = AIQuestGenerator.friendlyMessage(for: error)
                        self.questGenerationError = "Couldn’t generate personalized quests. Using suggested quests for now. \(detail)"
                        self.isGeneratingQuests = false
                        self.saveProgress()
                    }
                }
            }
        } else {
            lastDailyQuestsUsedAI = false
            generateDailyQuestsLegacy()
        }
    }

    /// Call after the user saves or removes their OpenAI key in Profile so hints and quests refresh.
    func openAIUserKeyDidChange() {
        objectWillChange.send()
        generateDailyQuests()
    }

    private var shouldGenerateQuestsWithAI: Bool {
        guard onboardingProfile != nil else { return false }
        let signedIn = Auth.auth().currentUser != nil
        if QuestModeRemoteAI.shouldUseCustomBackendHTTP(signedIn: signedIn) { return true }
        if QuestModeRemoteAI.isProxyEnabled, signedIn { return true }
        return AIQuestGenerator.resolvedAPIKey() != nil
    }

    /// Profile line: how daily quests are produced (no “toggle”—generation follows questionnaire + key when configured).
    var aiQuestSetupHint: String {
        let hasProfile = onboardingProfile != nil
        let signedIn = Auth.auth().currentUser != nil
        let customReady = QuestModeRemoteAI.shouldUseCustomBackendHTTP(signedIn: signedIn)
        let firebaseProxyReady = QuestModeRemoteAI.isProxyEnabled && signedIn
        let hasBYOK = AIQuestGenerator.resolvedAPIKey() != nil
        let hasKeyPath = customReady || firebaseProxyReady || hasBYOK
        if hasKeyPath && hasProfile {
            return "Daily quests are generated from your questionnaire—especially the goal you wrote—when you open the app, on a new day, or when you refresh below."
        }
        if !hasKeyPath {
            if QuestModeRemoteAI.hasCustomQuestBackendURL {
                return "Personalized generation uses your QuestModeQuestBackendURL server when you’re signed in. Set the URL in Info.plist, deploy the backend folder, then sign in—or add your own OpenAI key in Profile. Until then, the app uses suggested quests."
            }
            if QuestModeRemoteAI.isProxyEnabled {
                return "Personalized generation uses Quest Mode’s Firebase server when you’re signed in. Sign in, or add your own OpenAI key in Profile for offline-style use. Until then, the app uses suggested quests."
            }
            return "Personalized generation needs an OpenAI API key. Add yours in Profile (stored on this device) or, for developers, OpenAISecrets.plist / the Xcode scheme. Until then, the app uses suggested quests."
        }
        return "Your questionnaire wasn’t saved on this account yet, so quests use suggestions. Complete onboarding on a new sign-in to capture your answers."
    }

    private func generateDailyQuestsLegacy() {
        lastDailyQuestsUsedAI = false
        let pool = filteredQuestPool()
        let uid = Auth.auth().currentUser?.uid ?? "guest"
        let day = DailyQuestSelector.dayKey(for: Date())
        let seed = DailyQuestSelector.seed(userId: uid, dayKey: day)
        if let profile = onboardingProfile {
            let scores = QuestPersonalization.categoryScoresPublic(from: profile)
            let weights = QuestPersonalization.weights(for: profile, pool: pool, categoryScores: scores)
            quests = DailyQuestSelector.pickQuests(from: pool, count: 3, seed: seed, weights: weights)
        } else {
            quests = DailyQuestSelector.pickQuests(from: pool, count: 3, seed: seed)
        }
        recordQuestTitlesInHistory(quests.map(\.title))
    }

    private func collectExcludedTitleStrings() -> [String] {
        var set = Set<String>()
        for q in quests { set.insert(q.title) }
        for e in questLog { set.insert(e.title) }
        if let h = UserDefaults.standard.stringArray(forKey: questTitleHistoryKey) {
            for t in h { set.insert(t) }
        }
        return Array(set)
    }

    private func recordQuestTitlesInHistory(_ titles: [String]) {
        var h = UserDefaults.standard.stringArray(forKey: questTitleHistoryKey) ?? []
        for t in titles {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            h.removeAll { $0 == trimmed }
            h.insert(trimmed, at: 0)
        }
        h = Array(h.prefix(120))
        UserDefaults.standard.set(h, forKey: questTitleHistoryKey)
    }

    private func filteredQuestPool() -> [Quest] {
        let base = allQuestPool()
        let extras = onboardingProfile.map { QuestPersonalization.personalizedQuests(for: $0) } ?? []
        let combined = base + extras
        let filtered = combined.filter { selectedCategories.contains($0.category) }
        return filtered.isEmpty ? combined : filtered
    }

    private func allQuestPool() -> [Quest] {
        [
            Quest(category: "Adventure", title: "Take a 10 minute walk somewhere unfamiliar.", difficulty: "Easy", xp: 50, time: "10 min"),
            Quest(category: "Adventure", title: "Visit a park or trail you have not used this month.", difficulty: "Medium", xp: 65, time: "20 min"),
            Quest(category: "Social", title: "Compliment one person genuinely today.", difficulty: "Easy", xp: 40, time: "5 min"),
            Quest(category: "Social", title: "Start a short conversation with someone new.", difficulty: "Medium", xp: 55, time: "10 min"),
            Quest(category: "Mindfulness", title: "Five minutes of quiet breathing with no phone.", difficulty: "Easy", xp: 35, time: "5 min"),
            Quest(category: "Mindfulness", title: "Write three things you are grateful for.", difficulty: "Easy", xp: 40, time: "8 min"),
            Quest(category: "Productivity", title: "Clear your inbox or desk for ten focused minutes.", difficulty: "Easy", xp: 45, time: "10 min"),
            Quest(category: "Productivity", title: "Finish one task you have been avoiding.", difficulty: "Medium", xp: 70, time: "25 min"),
            Quest(category: "Confidence", title: "Speak up once in a meeting or group.", difficulty: "Medium", xp: 60, time: "15 min"),
            Quest(category: "Confidence", title: "Practice a two-minute mirror pep talk.", difficulty: "Easy", xp: 35, time: "5 min"),
            Quest(category: "Creativity", title: "Sketch or photograph something that caught your eye.", difficulty: "Easy", xp: 50, time: "15 min"),
            Quest(category: "Creativity", title: "Spend twenty minutes on a creative hobby.", difficulty: "Medium", xp: 65, time: "20 min"),
            Quest(category: "Health", title: "Drink water before your first coffee and log it.", difficulty: "Easy", xp: 30, time: "2 min"),
            Quest(category: "Health", title: "Move for fifteen minutes: stretch, walk, or mobility.", difficulty: "Easy", xp: 45, time: "15 min")
        ]
    }

    func checkDailyReward() {
        let calendar = Calendar.current
        if !calendar.isDate(lastRewardDate, inSameDayAs: Date()) {
            dailyRewardAvailable = true
        }
    }

    func checkForDailyReset() {
        let calendar = Calendar.current
        let now = Date()

        if UserDefaults.standard.object(forKey: lastQuestRefreshKey) == nil {
            UserDefaults.standard.set(now, forKey: lastQuestRefreshKey)
            ensureDailyQuestsIfNeeded()
            refreshSkipQuotaForToday()
            checkDailyReward()
            return
        }

        if let saved = UserDefaults.standard.object(forKey: lastQuestRefreshKey) as? Date {
            if !calendar.isDate(saved, inSameDayAs: now) {
                generateDailyQuests()
                UserDefaults.standard.set(now, forKey: lastQuestRefreshKey)
                resetSkipsForNewDay()
            }
        }

        refreshSkipQuotaForToday()
        checkDailyReward()
        ensureDailyQuestsIfNeeded()
    }

    // MARK: - Skip quota

    /// Syncs skip quota from UserDefaults when the calendar day changes. Safe to call from `onAppear` (not from computed getters).
    func refreshSkipQuotaForTodayIfNeeded() {
        refreshSkipQuotaForToday()
    }

    private func refreshSkipQuotaForToday() {
        let day = DailyQuestSelector.dayKey(for: Date())
        if UserDefaults.standard.string(forKey: skipsDayKeyUD) != day {
            UserDefaults.standard.set(day, forKey: skipsDayKeyUD)
            UserDefaults.standard.set(0, forKey: skipsUsedKeyUD)
            skipQuestsUsedToday = 0
        } else {
            skipQuestsUsedToday = UserDefaults.standard.integer(forKey: skipsUsedKeyUD)
        }
    }

    private func resetSkipsForNewDay() {
        let day = DailyQuestSelector.dayKey(for: Date())
        UserDefaults.standard.set(day, forKey: skipsDayKeyUD)
        UserDefaults.standard.set(0, forKey: skipsUsedKeyUD)
        skipQuestsUsedToday = 0
    }

    private func registerSkipUse() {
        refreshSkipQuotaForToday()
        skipQuestsUsedToday += 1
        UserDefaults.standard.set(skipQuestsUsedToday, forKey: skipsUsedKeyUD)
    }

    // MARK: - Persistence + cloud

    func makeProgressSnapshot() -> UserProgressSnapshot {
        let lastRefresh = UserDefaults.standard.object(forKey: lastQuestRefreshKey) as? Date
        let day = DailyQuestSelector.dayKey(for: Date())
        return UserProgressSnapshot(
            xp: xp,
            xpInitialized: UserDefaults.standard.bool(forKey: xpInitializedKey),
            streak: streak,
            username: username,
            appearanceRaw: appearance.rawValue,
            lastPlayedInterval: lastPlayedDate.timeIntervalSince1970,
            lastStreakInterval: lastStreakDate.timeIntervalSince1970,
            selectedCategories: selectedCategories,
            hasCompletedOnboarding: hasCompletedOnboarding,
            lastRewardInterval: lastRewardDate.timeIntervalSince1970,
            quests: quests,
            questLog: questLog.map { $0.cloudSafeCopy },
            lastQuestRefreshInterval: lastRefresh?.timeIntervalSince1970,
            skipsDayKey: day,
            skipsUsed: skipQuestsUsedToday,
            updatedAt: Date().timeIntervalSince1970,
            onboardingProfile: onboardingProfile
        )
    }

    private func applySnapshot(_ snap: UserProgressSnapshot, mergeLocalImages: Bool) {
        xp = snap.xp
        UserDefaults.standard.set(snap.xpInitialized, forKey: xpInitializedKey)
        streak = snap.streak
        username = snap.username
        appearance = AppAppearance(rawValue: snap.appearanceRaw) ?? .system
        lastPlayedDate = Date(timeIntervalSince1970: snap.lastPlayedInterval)
        lastStreakDate = Date(timeIntervalSince1970: snap.lastStreakInterval)
        selectedCategories = snap.selectedCategories
        let profileBeforeMerge = onboardingProfile
        // Prefer remote profile; never wipe local profile when Firestore omits it (older documents).
        if let rp = snap.onboardingProfile {
            onboardingProfile = rp
        } else if snap.hasCompletedOnboarding {
            if onboardingProfile == nil,
               let data = UserDefaults.standard.data(forKey: onboardingProfileKey),
               let p = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
                onboardingProfile = p
            }
        } else {
            onboardingProfile = nil
        }
        let profileRecovered = profileBeforeMerge == nil && onboardingProfile != nil
        // Never let stale cloud data clear onboarding completion on this device.
        if let uid = Auth.auth().currentUser?.uid {
            let key = perUserOnboardingKey(uid: uid)
            hasCompletedOnboarding = snap.hasCompletedOnboarding || UserDefaults.standard.bool(forKey: key)
        } else {
            hasCompletedOnboarding = snap.hasCompletedOnboarding
        }
        lastRewardDate = Date(timeIntervalSince1970: snap.lastRewardInterval)
        quests = snap.quests
        if mergeLocalImages {
            questLog = snap.questLogMergedWithLocalImages(local: questLog)
        } else {
            questLog = snap.questLog
        }
        if let lr = snap.lastQuestRefreshInterval {
            UserDefaults.standard.set(Date(timeIntervalSince1970: lr), forKey: lastQuestRefreshKey)
        }
        UserDefaults.standard.set(snap.skipsDayKey, forKey: skipsDayKeyUD)
        UserDefaults.standard.set(snap.skipsUsed, forKey: skipsUsedKeyUD)
        skipQuestsUsedToday = snap.skipsUsed
        lastRemoteUpdatedAt = snap.updatedAt
        persistOnboardingForCurrentUser()

        if snap.hasCompletedOnboarding && quests.isEmpty {
            generateDailyQuests()
        } else if profileRecovered, shouldGenerateQuestsWithAI {
            generateDailyQuests()
        }
        saveProgressLocalOnly()
    }

    private func pullRemoteProgressIfNeeded() {
        guard Auth.auth().currentUser != nil else { return }
        FirestoreProgressSync.pull { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    self.cloudSyncError = err.localizedDescription
                }
            case .success(let remote):
                guard let remote = remote else {
                    self.scheduleCloudPush()
                    return
                }
                let localWrite = UserDefaults.standard.double(forKey: lastLocalWriteKey)
                DispatchQueue.main.async {
                    if remote.updatedAt > localWrite + 0.5 {
                        self.applySnapshot(remote, mergeLocalImages: true)
                    }
                }
            }
        }
    }

    private func scheduleCloudPush() {
        syncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, Auth.auth().currentUser != nil else { return }
            var snap = self.makeProgressSnapshot()
            FirestoreProgressSync.push(snap) { err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.cloudSyncError = err.localizedDescription
                    }
                }
            }
        }
        syncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func saveProgressLocalOnly() {
        UserDefaults.standard.set(true, forKey: xpInitializedKey)
        UserDefaults.standard.set(xp, forKey: xpKey)
        UserDefaults.standard.set(streak, forKey: streakKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
        UserDefaults.standard.set(lastPlayedDate, forKey: lastPlayedDateKey)
        UserDefaults.standard.set(lastStreakDate, forKey: streakDateKey)
        UserDefaults.standard.set(selectedCategories, forKey: selectedCategoriesKey)
        if let p = onboardingProfile, let encodedProfile = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(encodedProfile, forKey: onboardingProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: onboardingProfileKey)
        }
        persistOnboardingForCurrentUser()
        UserDefaults.standard.set(lastRewardDate, forKey: rewardDateKey)

        if let encodedQuests = try? JSONEncoder().encode(quests) {
            UserDefaults.standard.set(encodedQuests, forKey: questsKey)
        }
        if let encodedLog = try? JSONEncoder().encode(questLog) {
            UserDefaults.standard.set(encodedLog, forKey: questLogKey)
        }
    }

    private func saveProgress() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastLocalWriteKey)
        saveProgressLocalOnly()
        scheduleCloudPush()
    }

    private func loadProgress() {
        if UserDefaults.standard.bool(forKey: xpInitializedKey) {
            xp = UserDefaults.standard.integer(forKey: xpKey)
        } else {
            xp = 120
        }

        streak = UserDefaults.standard.integer(forKey: streakKey)
        username = UserDefaults.standard.string(forKey: usernameKey) ?? "Kian"
        let savedAppearance = UserDefaults.standard.string(forKey: appearanceKey) ?? "system"
        appearance = AppAppearance(rawValue: savedAppearance) ?? .system
        lastPlayedDate = UserDefaults.standard.object(forKey: lastPlayedDateKey) as? Date ?? Date.distantPast
        lastStreakDate = UserDefaults.standard.object(forKey: streakDateKey) as? Date ?? Date.distantPast
        selectedCategories = UserDefaults.standard.stringArray(forKey: selectedCategoriesKey) ?? []
        if let data = UserDefaults.standard.data(forKey: onboardingProfileKey),
           let p = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
            onboardingProfile = p
        } else {
            onboardingProfile = nil
        }
        lastRewardDate = UserDefaults.standard.object(forKey: rewardDateKey) as? Date ?? Date.distantPast

        if let data = UserDefaults.standard.data(forKey: questsKey),
           let decoded = try? JSONDecoder().decode([Quest].self, from: data) {
            quests = decoded
        }
        if let logData = UserDefaults.standard.data(forKey: questLogKey),
           let decodedLog = try? JSONDecoder().decode([QuestLogEntry].self, from: logData) {
            questLog = decodedLog
        }

        refreshSkipQuotaForToday()
    }
}

#if DEBUG
extension QuestViewModel {
    /// Does not contact Firebase; only bypasses the in-app email gate for faster simulator testing.
    func debugSkipEmailVerificationGate() {
        isCurrentUserEmailVerified = true
        authStateRevision += 1
    }

    /// Same end state as finishing onboarding: sample questionnaire + main tabs (Debug builds only).
    func debugCompleteOnboardingWithSampleData() {
        let profile = OnboardingProfile(
            primaryFocus: .habits,
            timeBudget: .medium,
            obstacles: [.busy],
            personalNote: "Debug sample"
        )
        finishOnboarding(name: "Dev", profile: profile)
    }
}
#endif
