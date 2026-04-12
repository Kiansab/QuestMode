import Foundation

struct Quest: Identifiable, Codable {
    let id: UUID
    let category: String
    let title: String
    let difficulty: String
    let xp: Int
    let time: String
    var isCompleted: Bool
    
    init(
        id: UUID = UUID(),
        category: String,
        title: String,
        difficulty: String,
        xp: Int,
        time: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.difficulty = difficulty
        self.xp = xp
        self.time = time
        self.isCompleted = isCompleted
    }
}
