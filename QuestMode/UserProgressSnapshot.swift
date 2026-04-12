import Foundation

/// Firestore-serializable snapshot (quest log images omitted on upload; merged locally on download).
struct UserProgressSnapshot: Codable {
    var xp: Int
    var xpInitialized: Bool
    var streak: Int
    var username: String
    var appearanceRaw: String
    var lastPlayedInterval: TimeInterval
    var lastStreakInterval: TimeInterval
    var selectedCategories: [String]
    var hasCompletedOnboarding: Bool
    var lastRewardInterval: TimeInterval
    var quests: [Quest]
    /// Reflection-only entries for cloud (no image data).
    var questLog: [QuestLogEntry]
    var lastQuestRefreshInterval: TimeInterval?
    var skipsDayKey: String
    var skipsUsed: Int
    var updatedAt: TimeInterval
    /// Answers from onboarding questionnaire; drives personalized quests when present.
    var onboardingProfile: OnboardingProfile?
}

extension UserProgressSnapshot {

    func questLogMergedWithLocalImages(local: [QuestLogEntry]) -> [QuestLogEntry] {
        var map = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for remote in questLog {
            if let loc = map[remote.id] {
                if loc.imageData == nil {
                    map[remote.id] = remote
                }
            } else {
                map[remote.id] = remote
            }
        }
        return map.values.sorted { $0.completedAt > $1.completedAt }
    }
}

extension QuestLogEntry {
    /// Strips binary data for Firestore size limits.
    var cloudSafeCopy: QuestLogEntry {
        QuestLogEntry(
            id: id,
            title: title,
            category: category,
            xp: xp,
            reflection: reflection,
            imageData: nil,
            completedAt: completedAt,
            proofType: proofType,
            proofStatus: proofStatus
        )
    }
}
