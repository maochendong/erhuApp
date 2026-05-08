import Foundation

/// Represents a complete musical score (jianpu format)
struct Score: Identifiable, Codable {
    let id: UUID
    var title: String
    var composer: String
    /// Time signature numerator (e.g., 4/4 time → 4)
    var timeSignatureTop: Int
    /// Time signature denominator (e.g., 4/4 time → 4)
    var timeSignatureBottom: Int
    /// Key signature (0=C, 1=G, -1=F, etc.)
    var keySignature: Int
    /// Tempo in BPM
    var tempo: Int
    /// All measures (小节) in the score
    var measures: [Measure]

    init(
        id: UUID = UUID(),
        title: String,
        composer: String = "",
        timeSignatureTop: Int = 4,
        timeSignatureBottom: Int = 4,
        keySignature: Int = 0,
        tempo: Int = 60,
        measures: [Measure] = []
    ) {
        self.id = id
        self.title = title
        self.composer = composer
        self.timeSignatureTop = timeSignatureTop
        self.timeSignatureBottom = timeSignatureBottom
        self.keySignature = keySignature
        self.tempo = tempo
        self.measures = measures
    }

    var allNotes: [Note] {
        measures.flatMap(\.notes)
    }
}

/// A single measure containing notes
struct Measure: Identifiable, Codable {
    let id: UUID
    var notes: [Note]

    init(id: UUID = UUID(), notes: [Note] = []) {
        self.id = id
        self.notes = notes
    }
}
