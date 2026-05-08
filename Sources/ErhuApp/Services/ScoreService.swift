import Foundation

/// Provides built-in erhu scores and manages score data
final class ScoreService {
    static let shared = ScoreService()

    var scores: [Score] = []

    private init() {
        scores = builtInScores()
    }

    func score(by id: UUID) -> Score? {
        scores.first { $0.id == id }
    }

    // MARK: - Built-in scores

    private func builtInScores() -> [Score] {
        [
            makeScore(
                title: "小星星",
                composer: "传统儿歌",
                tempo: 100,
                notes: [
                    1,1,5,5,6,6,5, 4,4,3,3,2,2,1,
                    5,5,4,4,3,3,2, 5,5,4,4,3,3,2,
                    1,1,5,5,6,6,5, 4,4,3,3,2,2,1
                ]
            ),
            makeScore(
                title: "两只老虎",
                composer: "传统儿歌",
                tempo: 110,
                notes: [
                    1,2,3,1, 1,2,3,1,
                    3,4,5,  3,4,5,
                    5,6,5,4,3,1, 5,6,5,4,3,1,
                    2,5,1,  2,5,1
                ]
            ),
            makeScore(
                title: "茉莉花",
                composer: "江苏民歌",
                tempo: 80,
                notes: [
                    5,5,6,1,6,5, 5,5,6,1,6,5,
                    6,1,3,2,3,  6,1,3,2,3,
                    5,6,5,3,2,3,5,3,2,
                    3,2,1,3,2,1, 3,2,1,3,2,1,
                    1,2,3,2,1,
                    6,1,5,6,1,5,
                    3,2,3,5,3,2,
                    1,3,2,1, 1,3,2,1
                ]
            ),
            makeScore(
                title: "摇篮曲",
                composer: "东北民歌",
                tempo: 70,
                notes: [
                    1,1,5,  5,6,5,  3,3,2,  1,0,
                    5,5,3,  3,2,1,  6,5,3,  2,0,
                    1,1,5,  5,6,5,  3,3,2,  1,0,
                    5,5,3,  3,2,1,  2,2,1,  1,0,
                    3,3,5,  6,5,3,  5,3,2,  1,0,
                    5,5,3,  3,2,1,  6,5,3,  2,0,
                    1,1,5,  5,6,5,  3,3,2,  1,0,
                    5,5,3,  3,2,1,  2,2,1,  1,0,
                    3,3,5,  6,5,3,  5,3,2,  1,0,
                    5,5,3,  3,2,1,  2,2,1,  1,0,
                ]
            ),
            makeScore(
                title: "赛马",
                composer: "黄海怀",
                tempo: 150,
                notes: [
                    3,3,5,  6,6,5,  3,3,5,  6,6,5,
                    1,1,2,  3,3,2,  1,1,2,  3,3,2,
                    5,5,3,  2,2,1,  5,5,3,  2,2,1,
                    6,6,5,  3,3,2,  1,1,2,  3,3,5,
                    6,6,5,  3,3,5,  6,6,1,  2,2,1,
                    6,6,5,  3,3,5,  6,6,5,  3,3,5,
                    1,1,2,  3,3,2,  1,1,2,  3,3,2,
                    5,5,3,  2,2,1,  5,5,3,  2,2,1,
                    6,6,5,  3,3,2,  1,1,2,  3,3,5,
                    6,6,5,  3,3,5,  6,6,1,  2,2,1,
                ]
            )
        ]
    }

    private func makeScore(title: String, composer: String, tempo: Int, notes: [Int]) -> Score {
        var measures: [Measure] = []
        var currentNotes: [Note] = []

        for value in notes {
            if value == 0 {
                currentNotes.append(Note(degree: 0, duration: 1.0))
            } else {
                currentNotes.append(Note(degree: value, duration: 1.0))
            }

            // Every 4 notes form a measure in 4/4 time
            if currentNotes.count == 4 {
                measures.append(Measure(notes: currentNotes))
                currentNotes = []
            }
        }

        if !currentNotes.isEmpty {
            measures.append(Measure(notes: currentNotes))
        }

        return Score(
            title: title,
            composer: composer,
            tempo: tempo,
            measures: measures
        )
    }
}
