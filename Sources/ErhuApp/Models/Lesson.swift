import Foundation

/// Represents a lesson or exercise
struct Lesson: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var difficulty: Difficulty
    var score: Score

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        difficulty: Difficulty = .beginner,
        score: Score
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.difficulty = difficulty
        self.score = score
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner = "入门"
    case elementary = "初级"
    case intermediate = "中级"
    case advanced = "高级"

    var color: String {
        switch self {
        case .beginner: return "green"
        case .elementary: return "blue"
        case .intermediate: return "orange"
        case .advanced: return "red"
        }
    }
}
