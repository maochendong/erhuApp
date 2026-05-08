import Foundation

/// Represents a single note in jianpu (numbered musical notation)
struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    /// The scale degree (1-7 for do-si, 0 for rest)
    let degree: Int
    /// Octave offset from middle: -1 = low, 0 = middle, 1 = high
    let octave: Int
    /// Duration in beats
    let duration: Double
    /// Whether this note has a dot (staccato/extended)
    let isDotted: Bool
    /// Whether this is a rest (degree == 0)
    var isRest: Bool { degree == 0 }

    init(
        id: UUID = UUID(),
        degree: Int,
        octave: Int = 0,
        duration: Double = 1.0,
        isDotted: Bool = false
    ) {
        self.id = id
        self.degree = degree
        self.octave = octave
        self.duration = duration
        self.isDotted = isDotted
    }

    /// The solfège name in Mandarin
    var solfege: String {
        switch degree {
        case 1: return "do"
        case 2: return "re"
        case 3: return "mi"
        case 4: return "fa"
        case 5: return "sol"
        case 6: return "la"
        case 7: return "si"
        default: return "—"
        }
    }

    /// The display number (degree with octave dots shown in jianpu)
    var displayText: String {
        isRest ? "0" : "\(degree)"
    }

    /// Approximate frequency in Hz (A4 = 440Hz equal temperament)
    var frequency: Double {
        guard degree > 0 else { return 0 }
        // C4 = 261.63, using A4=440 as reference
        let a4: Double = 440.0
        // Note index relative to A4. In jianpu, 1=C, 2=D, 3=E, 4=F, 5=G, 6=A, 7=B
        // Assuming 1=C (do), and middle octave = octave 0
        let semitonesFromA4: Double = {
            let baseNote: [Int: Double] = [1: -9, 2: -7, 3: -5, 4: -4, 5: -2, 6: 0, 7: 2]
            return (baseNote[degree] ?? 0) + Double(octave * 12)
        }()
        return a4 * pow(2, semitonesFromA4 / 12.0)
    }
}
