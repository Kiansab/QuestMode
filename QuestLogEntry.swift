import Foundation

struct QuestLogEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let category: String
    let xp: Int
    let reflection: String
    let imageData: Data? // 1. Added this property
    let completedAt: Date
    let proofType: ProofType
    let proofStatus: ProofStatus
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        xp: Int,
        reflection: String,
        imageData: Data? = nil, // 2. Added this to the initializer
        completedAt: Date = Date(),
        proofType: ProofType,
        proofStatus: ProofStatus
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.xp = xp
        self.reflection = reflection
        self.imageData = imageData // 3. Set the data here
        self.completedAt = completedAt
        self.proofType = proofType
        self.proofStatus = proofStatus
    }
}
