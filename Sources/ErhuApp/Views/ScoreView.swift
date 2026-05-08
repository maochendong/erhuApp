import SwiftUI

struct ScoreView: View {
    let score: Score
    let currentNoteIndex: Int
    let judgments: [PitchJudger.Judgment]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Score header
            HStack {
                VStack(alignment: .leading) {
                    Text(score.title)
                        .font(.title2.weight(.bold))
                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(score.tempo) BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(score.timeSignatureTop)/\(score.timeSignatureBottom)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            // Score staff (jianpu)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(score.measures.enumerated()), id: \.element.id) { measureIdx, measure in
                        HStack(spacing: 0) {
                            // Measure number
                            Text("\(measureIdx + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            // Notes in measure
                            ForEach(Array(measure.notes.enumerated()), id: \.element.id) { noteIdx, note in
                                let globalIdx = measureNotesPrefixSum(upTo: measureIdx) + noteIdx
                                let isCurrent = globalIdx == currentNoteIndex && currentNoteIndex < judgments.count
                                let judgment = globalIdx < judgments.count ? judgments[globalIdx] : nil

                                NoteCell(
                                    note: note,
                                    isCurrent: isCurrent,
                                    judgment: judgment
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }

    private func measureNotesPrefixSum(upTo measureIdx: Int) -> Int {
        score.measures[0..<measureIdx].reduce(0) { $0 + $1.notes.count }
    }
}

struct NoteCell: View {
    let note: Note
    let isCurrent: Bool
    let judgment: PitchJudger.Judgment?

    var body: some View {
        VStack(spacing: 2) {
            // Octave indicators (dots above for high, dots below for low)
            if note.octave > 0 {
                Text(String(repeating: "·", count: note.octave))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // The note degree number
            Text(note.displayText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(noteColor)

            // Octave indicators (dots below for low)
            if note.octave < 0 {
                Text(String(repeating: "·", count: -note.octave))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Underline for low octave in jianpu style
            if note.octave == -1 {
                Rectangle()
                    .fill(.foreground)
                    .frame(height: 1)
            } else if note.octave <= -2 {
                Rectangle()
                    .fill(.foreground)
                    .frame(height: 1)
                Rectangle()
                    .fill(.foreground)
                    .frame(height: 1)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }

    private var noteColor: Color {
        guard let j = judgment else {
            return note.isRest ? .secondary : .primary
        }
        if j.isCorrect { return .green }
        if abs(j.centsOff) > PitchJudger.centTolerance { return .red }
        return .orange
    }
}

#Preview {
    ScoreView(
        score: ScoreService.shared.scores[0],
        currentNoteIndex: 2,
        judgments: [
            PitchJudger.Judgment(
                note: Note(degree: 1),
                playedDegree: 1,
                playedOctave: 0,
                isCorrect: true,
                centsOff: 10
            )
        ]
    )
}
