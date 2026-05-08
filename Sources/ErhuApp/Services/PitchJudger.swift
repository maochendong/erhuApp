import Foundation

/// Compares played notes against the score and evaluates accuracy
final class PitchJudger {
    struct Judgment {
        let note: Note
        let playedDegree: Int
        let playedOctave: Int
        let isCorrect: Bool
        let centsOff: Double // cents deviation (-50 to +50 = in tune)
    }

    /// Tolerance in cents (±50 cents = 1 semitone / 2)
    static let centTolerance: Double = 50

    /// Judge whether the played frequency matches the target note
    func judge(playedFrequency: Double, targetNote: Note) -> Judgment {
        let playedFreq = playedFrequency
        let targetFreq = targetNote.frequency

        guard targetFreq > 0, playedFreq > 0 else {
            return Judgment(
                note: targetNote,
                playedDegree: 0,
                playedOctave: 0,
                isCorrect: false,
                centsOff: 0
            )
        }

        // Calculate cents difference
        let cents = 1200 * log2(playedFreq / targetFreq)

        // Convert played frequency to note info
        let playedMidi = 12 * log2(playedFreq / 440.0) + 69
        let roundedMidi = Int(round(playedMidi))
        let noteInOctave = ((roundedMidi - 12) % 12 + 12) % 12
        let octave = (roundedMidi - 12) / 12 - 1

        let degree: Int
        switch noteInOctave {
        case 0:  degree = 1
        case 2:  degree = 2
        case 4:  degree = 3
        case 5:  degree = 4
        case 7:  degree = 5
        case 9:  degree = 6
        case 11: degree = 7
        default: degree = 0
        }

        let isCorrect = abs(cents) <= Self.centTolerance && degree == targetNote.degree

        return Judgment(
            note: targetNote,
            playedDegree: degree,
            playedOctave: octave,
            isCorrect: isCorrect,
            centsOff: cents
        )
    }

    /// Process a full performance result
    struct PerformanceResult {
        let score: Score
        let judgments: [Judgment]
        var correctCount: Int { judgments.filter(\.isCorrect).count }
        var totalCount: Int { judgments.count }
        var accuracy: Double { totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0 }
    }
}
