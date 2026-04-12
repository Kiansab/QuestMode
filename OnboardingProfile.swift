import Foundation

// MARK: - Questionnaire (stored and used to personalize daily quests)

enum OnboardingPrimaryFocus: String, Codable, CaseIterable, Identifiable {
    case habits = "habits"
    case calm = "calm"
    case body = "body"
    case explore = "explore"
    case social = "social"
    case work = "work"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .habits: return "Build habits & consistency"
        case .calm: return "Stress less & be more present"
        case .body: return "Move more & feel healthier"
        case .explore: return "Learn, create, or explore"
        case .social: return "Connection & confidence"
        case .work: return "Focus & productivity"
        }
    }

    var subtitle: String {
        switch self {
        case .habits: return "Small wins that stack into lasting change."
        case .calm: return "Ground yourself and quiet the noise."
        case .body: return "Energy, movement, and feeling good in your body."
        case .explore: return "Curiosity, making things, and trying new angles."
        case .social: return "Conversations, courage, and showing up for people."
        case .work: return "Deep work, clarity, and getting things done."
        }
    }
}

enum OnboardingTimeBudget: String, Codable, CaseIterable, Identifiable {
    case light = "light"
    case medium = "medium"
    case flexible = "flexible"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Just a few minutes"
        case .medium: return "A solid chunk most days"
        case .flexible: return "I can go deeper when I want"
        }
    }

    var detail: String {
        switch self {
        case .light: return "Usually about 5–10 minutes at a time."
        case .medium: return "Roughly 15–25 minutes when I quest."
        case .flexible: return "Often 30+ minutes for bigger quests."
        }
    }
}

enum OnboardingObstacle: String, Codable, CaseIterable, Identifiable {
    case energy = "energy"
    case busy = "busy"
    case procrastination = "procrastination"
    case anxiety = "anxiety"
    case screens = "screens"
    case none = "none"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy: return "Low energy or motivation"
        case .busy: return "Busy or chaotic schedule"
        case .procrastination: return "Procrastination"
        case .anxiety: return "Anxiety or overthinking"
        case .screens: return "Screens & distraction"
        case .none: return "None of these — I’m in a good spot"
        }
    }

    /// Selecting “none” clears other obstacles.
    var isExclusive: Bool {
        self == .none
    }
}

struct OnboardingProfile: Codable, Equatable {
    var primaryFocus: OnboardingPrimaryFocus
    var timeBudget: OnboardingTimeBudget
    var obstacles: [OnboardingObstacle]
    /// Short free text — used to flavor copy and weighted quests (trimmed on save).
    var personalNote: String

    init(
        primaryFocus: OnboardingPrimaryFocus,
        timeBudget: OnboardingTimeBudget,
        obstacles: [OnboardingObstacle],
        personalNote: String
    ) {
        self.primaryFocus = primaryFocus
        self.timeBudget = timeBudget
        self.obstacles = obstacles
        self.personalNote = personalNote
    }
}
