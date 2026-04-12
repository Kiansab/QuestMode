import SwiftUI

enum AchievementTier: Hashable {
    case bronze
    case silver
    case gold
    case mythic

    var color: Color {
        switch self {
        case .bronze: return .orange
        case .silver: return .gray
        case .gold: return .yellow
        case .mythic: return .purple
        }
    }
}

struct Achievement: Identifiable, Hashable {

    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tier: AchievementTier

    var isUnlocked: Bool
}
