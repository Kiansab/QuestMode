import Foundation

/// Maps onboarding answers → category preferences, time fit, and extra quest copy.
enum QuestPersonalization {

    // MARK: - Categories

    /// Picks a diverse set of categories so Profile toggles still make sense.
    static func derivedCategories(from profile: OnboardingProfile, maxCount: Int = 5) -> [String] {
        var scores = categoryScores(from: profile)
        let sorted = QuestCategory.allCases.map(\.rawValue).sorted {
            (scores[$0] ?? 0) > (scores[$1] ?? 0)
        }
        var result: [String] = []
        for cat in sorted where (scores[cat] ?? 0) > 0.01 {
            result.append(cat)
            if result.count >= maxCount { break }
        }
        if result.count < 3 {
            for cat in QuestCategory.allCases.map(\.rawValue) where !result.contains(cat) {
                result.append(cat)
                if result.count >= 4 { break }
            }
        }
        return result
    }

    private static func categoryScores(from profile: OnboardingProfile) -> [String: Double] {
        var scores = baseCategoryWeights(for: profile.primaryFocus)
        let obs = Set(profile.obstacles)
        if obs.contains(.none) || obs.isEmpty {
            return scores
        }
        for o in obs {
            applyObstacle(o, to: &scores)
        }
        return scores
    }

    private static func baseCategoryWeights(for focus: OnboardingPrimaryFocus) -> [String: Double] {
        var m = Dictionary(uniqueKeysWithValues: QuestCategory.allCases.map { ($0.rawValue, 0.25) })
        func bump(_ cats: [QuestCategory], _ amount: Double) {
            for c in cats { m[c.rawValue, default: 0] += amount }
        }
        switch focus {
        case .habits:
            bump([.health, .productivity, .mindfulness], 1.0)
            bump([.adventure], 0.35)
        case .calm:
            bump([.mindfulness, .health, .adventure], 0.9)
            bump([.creativity], 0.4)
        case .body:
            bump([.health, .adventure], 1.1)
            bump([.mindfulness], 0.45)
        case .explore:
            bump([.creativity, .adventure, .mindfulness], 0.85)
            bump([.social, .confidence], 0.35)
        case .social:
            bump([.social, .confidence], 1.05)
            bump([.mindfulness, .adventure], 0.4)
        case .work:
            bump([.productivity, .confidence, .mindfulness], 0.95)
            bump([.health], 0.35)
        }
        return m
    }

    private static func applyObstacle(_ o: OnboardingObstacle, to scores: inout [String: Double]) {
        func add(_ cat: QuestCategory, _ v: Double) {
            scores[cat.rawValue, default: 0] += v
        }
        switch o {
        case .energy:
            add(.health, 0.45)
            add(.mindfulness, 0.35)
            add(.adventure, 0.2)
        case .busy:
            add(.productivity, 0.35)
            add(.mindfulness, 0.25)
            add(.health, 0.2)
        case .procrastination:
            add(.productivity, 0.45)
            add(.confidence, 0.35)
        case .anxiety:
            add(.mindfulness, 0.55)
            add(.health, 0.25)
        case .screens:
            add(.mindfulness, 0.35)
            add(.productivity, 0.3)
            add(.adventure, 0.2)
        case .none:
            break
        }
    }

    // MARK: - Weighted selection (per quest in pool)

    static func weights(for profile: OnboardingProfile, pool: [Quest], categoryScores: [String: Double]) -> [Double] {
        let catBase = categoryScores
        return pool.map { quest in
            let catW = catBase[quest.category] ?? 0.5
            let timeW = timeWeight(for: profile.timeBudget, quest: quest)
            let personal = personalNoteBoost(note: profile.personalNote, category: quest.category)
            return max(0.05, catW * timeW * personal)
        }
    }

    /// Exposed for tests / snapshot of what we use for categories.
    static func categoryScoresPublic(from profile: OnboardingProfile) -> [String: Double] {
        categoryScores(from: profile)
    }

    private static func timeWeight(for budget: OnboardingTimeBudget, quest: Quest) -> Double {
        let mins = QuestTimeParsing.estimatedMinutes(quest.time)
        switch budget {
        case .light:
            if mins <= 8 { return 1.45 }
            if mins <= 12 { return 1.15 }
            if mins <= 18 { return 0.85 }
            return 0.55
        case .medium:
            if mins <= 12 { return 1.1 }
            if mins <= 22 { return 1.25 }
            return 0.95
        case .flexible:
            if mins >= 18 { return 1.2 }
            if mins >= 12 { return 1.1 }
            return 0.95
        }
    }

    private static func personalNoteBoost(note: String, category: String) -> Double {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard t.count >= 3 else { return 1.0 }

        func matches(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if matches(["friend", "talk", "social", "people", "date"]), category == "Social" { return 1.1 }
        if matches(["work", "job", "study", "exam", "focus", "career"]), category == "Productivity" { return 1.1 }
        if matches(["gym", "run", "sleep", "eat", "weight"]), category == "Health" { return 1.1 }
        if matches(["stress", "calm", "anxious", "meditat", "peace"]), category == "Mindfulness" { return 1.08 }
        if matches(["run", "walk", "outside"]), category == "Adventure" || category == "Health" { return 1.06 }
        if matches(["read", "write", "draft"]), category == "Creativity" || category == "Productivity" { return 1.06 }

        return 1.0
    }

    // MARK: - Extra quests (tied to answers)

    static func personalizedQuests(for profile: OnboardingProfile) -> [Quest] {
        var list: [Quest] = []
        list.append(contentsOf: focusQuests(profile.primaryFocus))
        list.append(contentsOf: obstacleQuests(profile.obstacles))
        let note = profile.personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.count >= 4 {
            list.append(
                Quest(
                    category: "Mindfulness",
                    title: "Spend five minutes journaling about the goal or intention you described when you joined.",
                    difficulty: "Easy",
                    xp: 40,
                    time: "8 min"
                )
            )
        }
        return list
    }

    private static func focusQuests(_ focus: OnboardingPrimaryFocus) -> [Quest] {
        switch focus {
        case .habits:
            return [
                Quest(category: "Health", title: "Pick one tiny habit for tomorrow: same cue, same time, two minutes max.", difficulty: "Easy", xp: 45, time: "5 min"),
                Quest(category: "Productivity", title: "Stack one new habit onto something you already do every day (after coffee, after brushing teeth…).", difficulty: "Easy", xp: 50, time: "8 min")
            ]
        case .calm:
            return [
                Quest(category: "Mindfulness", title: "Name three sensations you feel right now—no fixing, just notice.", difficulty: "Easy", xp: 38, time: "5 min"),
                Quest(category: "Mindfulness", title: "Take five slow breaths before you open any app today.", difficulty: "Easy", xp: 35, time: "5 min")
            ]
        case .body:
            return [
                Quest(category: "Health", title: "Do a five-minute warm-up: ankles, hips, shoulders, neck.", difficulty: "Easy", xp: 48, time: "8 min"),
                Quest(category: "Adventure", title: "Walk outside without headphones—listen to the world for ten minutes.", difficulty: "Easy", xp: 52, time: "12 min")
            ]
        case .explore:
            return [
                Quest(category: "Creativity", title: "Spend fifteen minutes on something you’ve been curious about but haven’t started.", difficulty: "Medium", xp: 62, time: "18 min"),
                Quest(category: "Creativity", title: "Make one messy first draft: no editing, just output.", difficulty: "Easy", xp: 50, time: "15 min")
            ]
        case .social:
            return [
                Quest(category: "Social", title: "Send a check-in message to someone you appreciate—specific, not generic.", difficulty: "Easy", xp: 45, time: "6 min"),
                Quest(category: "Confidence", title: "Introduce yourself or say one clear sentence you’d usually skip.", difficulty: "Medium", xp: 58, time: "12 min")
            ]
        case .work:
            return [
                Quest(category: "Productivity", title: "Work in one 20-minute sprint with phone in another room.", difficulty: "Medium", xp: 60, time: "22 min"),
                Quest(category: "Productivity", title: "Write tomorrow’s top three outcomes—not tasks—on paper.", difficulty: "Easy", xp: 48, time: "10 min")
            ]
        }
    }

    private static func obstacleQuests(_ obstacles: [OnboardingObstacle]) -> [Quest] {
        var out: [Quest] = []
        let set = Set(obstacles)
        if set.contains(.busy) {
            out.append(Quest(category: "Productivity", title: "Time-box one chore to ten minutes—then stop, win or lose.", difficulty: "Easy", xp: 44, time: "12 min"))
        }
        if set.contains(.procrastination) {
            out.append(Quest(category: "Confidence", title: "Do the two-minute version of the thing you’re avoiding—then decide if you continue.", difficulty: "Easy", xp: 48, time: "5 min"))
        }
        if set.contains(.anxiety) {
            out.append(Quest(category: "Mindfulness", title: "Ground yourself: 5-4-3-2-1 senses, then one self-compassionate sentence.", difficulty: "Easy", xp: 40, time: "8 min"))
        }
        if set.contains(.screens) {
            out.append(Quest(category: "Mindfulness", title: "Charge your phone outside the bedroom tonight—or one hour before bed.", difficulty: "Easy", xp: 42, time: "5 min"))
        }
        if set.contains(.energy) {
            out.append(Quest(category: "Health", title: "Two minutes of daylight or bright light—then one glass of water.", difficulty: "Easy", xp: 36, time: "5 min"))
        }
        return out
    }
}

enum QuestTimeParsing {
    static func estimatedMinutes(_ time: String) -> Int {
        let lowered = time.lowercased()
        if let r = lowered.range(of: #"\d+"#, options: .regularExpression) {
            let num = String(lowered[r])
            return Int(num) ?? 15
        }
        return 15
    }
}
