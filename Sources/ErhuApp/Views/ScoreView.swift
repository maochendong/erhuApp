import SwiftUI

struct ScoreView: View {
    let score: Score
    let currentNoteIndex: Int
    let judgments: [PitchJudger.Judgment]
    let lastAttemptJudgment: PitchJudger.Judgment?
    let loopStartIndex: Int?
    let loopEndIndex: Int?
    let onLongPressNote: ((Int) -> Void)?
    let onTapNote: ((Note) -> Void)?
    let isFullScreen: Bool
    let onToggleFullScreen: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    init(
        score: Score,
        currentNoteIndex: Int,
        judgments: [PitchJudger.Judgment],
        lastAttemptJudgment: PitchJudger.Judgment? = nil,
        loopStartIndex: Int? = nil,
        loopEndIndex: Int? = nil,
        onLongPressNote: ((Int) -> Void)? = nil,
        onTapNote: ((Note) -> Void)? = nil,
        isFullScreen: Bool = false,
        onToggleFullScreen: (() -> Void)? = nil
    ) {
        self.score = score
        self.currentNoteIndex = currentNoteIndex
        self.judgments = judgments
        self.lastAttemptJudgment = lastAttemptJudgment
        self.loopStartIndex = loopStartIndex
        self.loopEndIndex = loopEndIndex
        self.onLongPressNote = onLongPressNote
        self.onTapNote = onTapNote
        self.isFullScreen = isFullScreen
        self.onToggleFullScreen = onToggleFullScreen
    }

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

            // Score staff (jianpu) with full-screen support
            ScrollViewReader { proxy in
                ZStack(alignment: .topTrailing) {
                    Group {
                        if isFullScreen {
                            ScrollView(.vertical) {
                                innerScoreContent
                            }
                        } else {
                            innerScoreContent
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: isFullScreen ? 300 : 120)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Full-screen toggle button
                    Button {
                        onToggleFullScreen?()
                    } label: {
                        Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
                .padding(.horizontal)
                .onChange(of: currentNoteIndex) { _, _ in
                    let measureIdx = measureIndex(for: currentNoteIndex)
                    withAnimation {
                        proxy.scrollTo("m\(measureIdx)", anchor: .leading)
                    }
                }
            }
        }
    }

    private func measureView(measureIdx: Int, measure: Measure) -> some View {
        HStack(spacing: 0) {
            Text("\(measureIdx + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            ForEach(Array(measure.notes.enumerated()), id: \.element.id) { noteIdx, note in
                let globalIdx = measureNotesPrefixSum(upTo: measureIdx) + noteIdx
                let isCurrent = globalIdx == currentNoteIndex
                let judgment = globalIdx < judgments.count ? judgments[globalIdx] : nil
                let isInLoop = isLoopNote(globalIdx)

                NoteCell(
                    note: note,
                    isCurrent: isCurrent,
                    judgment: judgment,
                    lastAttempt: isCurrent ? lastAttemptJudgment : nil,
                    isInLoop: isInLoop,
                    isLoopEnd: globalIdx == loopEndIndex,
                    onLongPress: { onLongPressNote?(globalIdx) },
                    onTap: { onTapNote?(note) }
                )
            }
        }
    }

    private func measureNotesPrefixSum(upTo measureIdx: Int) -> Int {
        score.measures[0..<measureIdx].reduce(0) { $0 + $1.notes.count }
    }

    private func measureIndex(for globalNoteIndex: Int) -> Int {
        var count = 0
        for (idx, m) in score.measures.enumerated() {
            count += m.notes.count
            if globalNoteIndex < count { return idx }
        }
        return score.measures.count - 1
    }

    private func isLoopNote(_ idx: Int) -> Bool {
        guard let start = loopStartIndex, let end = loopEndIndex else { return false }
        return idx >= start && idx <= end
    }

    @ViewBuilder
    private var innerScoreContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if isRegularWidth {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 8) {
                    ForEach(Array(score.measures.enumerated()), id: \.element.id) { measureIdx, measure in
                        measureView(measureIdx: measureIdx, measure: measure)
                            .id("m\(measureIdx)")
                    }
                }
                .padding()
                .frame(minWidth: 400)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(score.measures.enumerated()), id: \.element.id) { measureIdx, measure in
                        measureView(measureIdx: measureIdx, measure: measure)
                            .id("m\(measureIdx)")
                    }
                }
                .padding()
            }
        }
    }
}

struct NoteCell: View {
    let note: Note
    let isCurrent: Bool
    let judgment: PitchJudger.Judgment?
    let lastAttempt: PitchJudger.Judgment?
    let isInLoop: Bool
    let isLoopEnd: Bool
    let onLongPress: (() -> Void)?
    let onTap: (() -> Void)?

    init(
        note: Note,
        isCurrent: Bool,
        judgment: PitchJudger.Judgment?,
        lastAttempt: PitchJudger.Judgment? = nil,
        isInLoop: Bool = false,
        isLoopEnd: Bool = false,
        onLongPress: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.note = note
        self.isCurrent = isCurrent
        self.judgment = judgment
        self.lastAttempt = lastAttempt
        self.isInLoop = isInLoop
        self.isLoopEnd = isLoopEnd
        self.onLongPress = onLongPress
        self.onTap = onTap
    }

    /// The effective judgment: completed judgment or live attempt
    private var effectiveJudgment: PitchJudger.Judgment? {
        lastAttempt ?? judgment
    }

    var body: some View {
        VStack(spacing: 2) {
            // Octave indicators (dots above for high, dots below for low)
            if note.octave > 0 {
                Text(String(repeating: "·", count: note.octave))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Arrow indicator for pitch deviation (sharp/flat)
            if let j = effectiveJudgment, !j.isCorrect, !note.isRest {
                pitchDeviationArrow(cents: j.centsOff)
            }

            // Loop marker for end point
            if isLoopEnd {
                Text("B")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
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

            // Cents deviation display for current or judged notes
            if let j = effectiveJudgment, !note.isRest {
                Text(String(format: "%+.0f¢", j.centsOff))
                    .font(.system(size: 10))
                    .foregroundStyle(centsColor(cents: j.centsOff))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Frequency display for current note
            if isCurrent, let j = effectiveJudgment {
                Text(String(format: "%.0f Hz", note.frequency))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: isLoopEnd ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isCurrent)
        .animation(.easeInOut(duration: 0.3), value: effectiveJudgment != nil)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Visual feedback helpers

    private func pitchDeviationArrow(cents: Double) -> some View {
        let arrow = cents > 0 ? "↑" : "↓"
        let color = cents > 0 ? Color.red : Color.blue
        return Text(arrow)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
    }

    private func centsColor(cents: Double) -> Color {
        if abs(cents) <= 50 { return .green }
        if abs(cents) <= 100 { return .orange }
        return .red
    }

    private var backgroundColor: Color {
        if isInLoop && effectiveJudgment == nil && !isCurrent {
            return .orange.opacity(0.12)
        }
        if note.isRest {
            return isCurrent ? Color.accentColor.opacity(0.2) : Color.clear
        }
        guard let j = effectiveJudgment else {
            return isCurrent ? Color.accentColor.opacity(0.2) : Color.clear
        }
        if j.isCorrect { return .green.opacity(0.15) }
        if abs(j.centsOff) > PitchJudger.centTolerance { return .red.opacity(0.15) }
        return .orange.opacity(0.15)
    }

    private var borderColor: Color {
        if isCurrent { return .accentColor }
        if isLoopEnd { return .orange }
        return .clear
    }

    private var noteColor: Color {
        guard let j = effectiveJudgment else {
            return note.isRest ? .secondary : .primary
        }
        if j.isCorrect { return .green }
        if abs(j.centsOff) > PitchJudger.centTolerance { return .red }
        return .orange
    }
}
