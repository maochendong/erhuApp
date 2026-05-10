import SwiftUI

struct PerformanceSummaryView: View {
    let result: PitchJudger.PerformanceResult
    let onRetry: () -> Void
    let onChoose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("练习完成！")
                            .font(.largeTitle.weight(.bold))

                        Text("\(result.score.title)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Overall accuracy ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        Circle()
                            .trim(from: 0, to: result.accuracy)
                            .stroke(
                                accuracyColor,
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: result.accuracy)

                        VStack {
                            Text("\(Int(result.accuracy * 100))%")
                                .font(.system(size: 48, weight: .bold))
                            Text("准确率")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 200, height: 200)

                    // Summary stats
                    HStack(spacing: 32) {
                        StatBadge(
                            value: "\(result.totalCount)",
                            label: "总音符",
                            color: .blue
                        )
                        StatBadge(
                            value: "\(result.correctCount)",
                            label: "正确",
                            color: .green
                        )
                        StatBadge(
                            value: "\(result.totalCount - result.correctCount)",
                            label: "错误",
                            color: .red
                        )
                    }

                    // Breakdown by note degree
                    VStack(alignment: .leading, spacing: 12) {
                        Text("音符准确率")
                            .font(.headline)
                            .padding(.horizontal)

                        let degreeStats = computeDegreeStats()
                        ForEach(degreeStats, id: \.degree) { stat in
                            HStack {
                                Text(noteName(for: stat.degree))
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(width: 40, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(stat.accuracy > 0.7 ? Color.green : (stat.accuracy > 0.4 ? Color.orange : Color.red))
                                            .frame(width: geo.size.width * CGFloat(stat.accuracy))
                                    }
                                }
                                .frame(height: 24)

                                Text("\(Int(stat.accuracy * 100))% (\(stat.correct)/\(stat.total))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: onRetry) {
                            Label("再练一次", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: onChoose) {
                            Label("选择其他曲目", systemImage: "music.note.list")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("练习总结")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Helpers

    private var accuracyColor: Color {
        if result.accuracy >= 0.8 { return .green }
        if result.accuracy >= 0.5 { return .orange }
        return .red
    }

    private func noteName(for degree: Int) -> String {
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

    private struct DegreeStat: Identifiable {
        var id: Int { degree }
        let degree: Int
        let total: Int
        let correct: Int
        var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    }

    private func computeDegreeStats() -> [DegreeStat] {
        var stats: [Int: (total: Int, correct: Int)] = [:]
        for j in result.judgments {
            let d = j.note.degree
            if d == 0 { continue }
            var entry = stats[d] ?? (0, 0)
            entry.total += 1
            if j.isCorrect { entry.correct += 1 }
            stats[d] = entry
        }
        return stats.sorted { $0.key < $1.key }
            .map { DegreeStat(degree: $0.key, total: $0.value.total, correct: $0.value.correct) }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
}

#Preview {
    PerformanceSummaryView(
        result: PitchJudger.PerformanceResult(
            score: ScoreService.shared.scores[0],
            judgments: [
                PitchJudger.Judgment(note: Note(degree: 1), playedDegree: 1, playedOctave: 0, isCorrect: true, centsOff: 10, timestamp: 0),
                PitchJudger.Judgment(note: Note(degree: 2), playedDegree: 2, playedOctave: 0, isCorrect: true, centsOff: 5, timestamp: 1),
                PitchJudger.Judgment(note: Note(degree: 3), playedDegree: 3, playedOctave: 0, isCorrect: false, centsOff: 80, timestamp: 2),
            ]
        ),
        onRetry: {},
        onChoose: {}
    )
}
