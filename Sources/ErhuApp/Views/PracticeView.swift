import SwiftUI

struct PracticeView: View {
    @State private var audioEngine = AudioEngine()
    @State private var currentScore: Score?
    @State private var currentNoteIndex = 0
    @State private var judgments: [PitchJudger.Judgment] = []
    @State private var isPlaying = false
    @State private var showScoreLibrary = false

    let judger = PitchJudger()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let score = currentScore {
                    ScoreView(
                        score: score,
                        currentNoteIndex: currentNoteIndex,
                        judgments: judgments
                    )
                    .padding(.top, 8)

                    if !judgments.isEmpty {
                        let result = PitchJudger.PerformanceResult(
                            score: score,
                            judgments: judgments
                        )
                        HStack {
                            Text("正确: \(result.correctCount)/\(result.totalCount)")
                            Text("准确率: \(Int(result.accuracy * 100))%")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 4)
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        if audioEngine.isListening {
                            HStack(spacing: 20) {
                                VStack {
                                    Text("检测")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(Note(
                                        degree: audioEngine.currentNote,
                                        octave: audioEngine.currentOctave
                                    ).displayText)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundStyle(audioEngine.currentNote > 0 ? .green : .secondary)
                                }

                                VStack {
                                    Text("频率")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f Hz", audioEngine.currentFrequency))
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(audioEngine.currentFrequency > 0 ? .blue : .secondary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background)
                                    .shadow(radius: 2)
                            )
                            .padding(.horizontal)
                        }

                        HStack(spacing: 20) {
                            Button {
                                togglePlay()
                            } label: {
                                Label(isPlaying ? "停止" : "开始演奏",
                                      systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(currentScore != nil ? Color.accentColor : Color.gray)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(currentScore == nil)

                            Button("重置") {
                                resetPerformance()
                            }
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.secondary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                } else {
                    ContentUnavailableView(
                        "选择一首曲子",
                        systemImage: "music.note",
                        description: Text("从曲库中选择一首曲子开始练习")
                    )
                }
            }
            .navigationTitle("练习")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentScore != nil {
                        Button("选择曲目") {
                            showScoreLibrary = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showScoreLibrary) {
                NavigationStack {
                    ScoreLibraryView { score in
                        startNewScore(score)
                    }
                    .navigationTitle("选择曲目")
                }
            }
        }
    }

    private func startNewScore(_ score: Score) {
        currentScore = score
        currentNoteIndex = 0
        judgments = []
        isPlaying = false
        audioEngine.stop()
        showScoreLibrary = false
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            audioEngine.start()
            startScoreFollowing()
        } else {
            audioEngine.stop()
        }
    }

    private func resetPerformance() {
        currentNoteIndex = 0
        judgments = []
        isPlaying = false
        audioEngine.stop()
    }

    private func startScoreFollowing() {
        guard let score = currentScore else { return }

        Task {
            while isPlaying && currentNoteIndex < score.allNotes.count {
                let targetNote = score.allNotes[currentNoteIndex]

                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    let judgment = judger.judge(
                        playedFrequency: audioEngine.currentFrequency,
                        targetNote: targetNote
                    )
                    judgments.append(judgment)

                    if audioEngine.amplitude > 0.02 {
                        currentNoteIndex += 1
                    }
                }
            }

            await MainActor.run {
                isPlaying = false
                audioEngine.stop()
            }
        }
    }
}

#Preview {
    PracticeView()
}
