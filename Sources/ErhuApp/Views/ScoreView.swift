import SwiftUI

struct ScoreView: View {
    let score: Score
    let currentNoteIndex: Int
    let judgments: [PitchJudger.Judgment]
    let lastAttemptJudgment: PitchJudger.Judgment?
    let onTapNote: ((Note) -> Void)?
    let isFullScreen: Bool
    let onToggleFullScreen: (() -> Void)?

    init(
        score: Score,
        currentNoteIndex: Int,
        judgments: [PitchJudger.Judgment],
        lastAttemptJudgment: PitchJudger.Judgment? = nil,
        onTapNote: ((Note) -> Void)? = nil,
        isFullScreen: Bool = false,
        onToggleFullScreen: (() -> Void)? = nil
    ) {
        self.score = score
        self.currentNoteIndex = currentNoteIndex
        self.judgments = judgments
        self.lastAttemptJudgment = lastAttemptJudgment
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

            // Score staff (五线谱) with full-screen support
            ZStack(alignment: .topTrailing) {
                JianpuView(
                    score: score,
                    currentNoteIndex: currentNoteIndex,
                    judgments: judgments,
                    lastAttemptJudgment: lastAttemptJudgment,
                    onTapNote: onTapNote
                )
                .frame(maxWidth: .infinity, maxHeight: isFullScreen ? nil : 250)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Full-screen toggle button
                Button {
                    onToggleFullScreen?()
                } label: {
                    Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.body)
                        .padding(10)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                }
                .padding(8)
            }
            .padding(.horizontal)
        }
    }
}
