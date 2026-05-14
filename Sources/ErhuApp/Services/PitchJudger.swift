import Foundation

/// Compares played notes against the score and evaluates accuracy
final class PitchJudger {
    struct Judgment: Codable {
        let note: Note
        let playedDegree: Int
        let playedOctave: Int
        let isCorrect: Bool
        let centsOff: Double // cents deviation (negative = flat, positive = sharp)
        let timestamp: TimeInterval // seconds since recording start
        /// Absolute cent error (always positive, for grading)
        let absoluteCentError: Double
    }

    /// Tolerance in cents for a note to be considered in-tune.
    /// ±30 cents = within ~1/4 semitone, appropriate for erhu practice.
    static let centTolerance: Double = 30

    /// Wider tolerance for beginners (±50 cents = 1 semitone / 2)
    static let beginnerCentTolerance: Double = 50

    /// Judge whether the played frequency matches the target note
    func judge(playedFrequency: Double, targetNote: Note, isBeginner: Bool = false) -> Judgment {
        let playedFreq = playedFrequency
        let targetFreq = targetNote.frequency

        guard targetFreq > 0, playedFreq > 0 else {
            return Judgment(
                note: targetNote,
                playedDegree: 0,
                playedOctave: 0,
                isCorrect: false,
                centsOff: 0,
                timestamp: 0,
                absoluteCentError: 0
            )
        }

        // Calculate cents difference from target
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

        let tolerance = isBeginner ? Self.beginnerCentTolerance : Self.centTolerance
        let isCorrect = abs(cents) <= tolerance && degree == targetNote.degree && octave == targetNote.octave

        return Judgment(
            note: targetNote,
            playedDegree: degree,
            playedOctave: octave,
            isCorrect: isCorrect,
            centsOff: cents,
            timestamp: 0,
            absoluteCentError: abs(cents)
        )
    }

    /// Process a full performance result
    struct PerformanceResult {
        let score: Score
        let judgments: [Judgment]
        var correctCount: Int { judgments.filter(\.isCorrect).count }
        var totalCount: Int { judgments.count }
        var accuracy: Double { totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0 }
        /// Average cent error (lower = more in-tune)
        var averageCentError: Double {
            guard !judgments.isEmpty else { return 0 }
            return judgments.map(\.absoluteCentError).reduce(0, +) / Double(judgments.count)
        }
    }
}
