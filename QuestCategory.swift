import Foundation

enum QuestCategory: String, CaseIterable, Identifiable, Codable {
    case adventure = "Adventure"
    case social = "Social"
    case mindfulness = "Mindfulness"
    case productivity = "Productivity"
    case confidence = "Confidence"
    case creativity = "Creativity"
    case health = "Health"
    
    var id: String { rawValue }
    
    var proofType: ProofType {
        switch self {
        case .adventure:
            return .photo
        case .health:
            return .photo
        case .creativity:
            return .photo
        case .social:
            return .reflection
        case .mindfulness:
            return .reflection
        case .confidence:
            return .reflection
        case .productivity:
            return .selfCheck
        }
    }
}
