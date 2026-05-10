import SwiftUI
import AVFoundation

struct PlaybackView: View {
    let recording: RecordingService.RecordingInfo
    let score: Score

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentJudgmentIndex = 0
    @State private var playbackRate: Float = 1.0
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var syncTimer: Timer?

    private var noteIndex: Int {
        min(currentJudgmentIndex, score.allNotes.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreView(
                score: score,
                currentNoteIndex: noteIndex,
                judgments: Array(recording.judgments.prefix(currentJudgmentIndex + 1))
            )
            .padding(.top, 4)

            Spacer()

            // Current judgment detail
            if currentJudgmentIndex < recording.judgments.count {
                let j = recording.judgments[currentJudgmentIndex]
                HStack(spacing: 20) {
                    VStack {
                        Text("目标")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(j.note.displayText)
                            .font(.system(size: 28, weight: .bold))
                    }
                    VStack {
                        Text("偏差")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%+.0f¢", j.centsOff))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(centsColor(j.centsOff))
                    }
                    VStack {
                        Text("结果")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: j.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(j.isCorrect ? .green : .red)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .shadow(radius: 1)
                )
                .padding(.horizontal)
            }

            // Seek bar
            VStack(spacing: 4) {
                Slider(value: $currentTime, in: 0...max(duration, 0.01)) { editing in
                    if editing {
                        audioPlayer?.pause()
                    } else {
                        let seekTime = TimeInterval(currentTime) / Double(playbackRate)
                        audioPlayer?.currentTime = seekTime
                        let adjustedTime = currentTime
                        currentJudgmentIndex = findJudgmentIndex(at: adjustedTime)
                        if isPlaying {
                            audioPlayer?.play()
                        }
                    }
                }
                .disabled(duration <= 0)
                .padding(.horizontal)

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)

            // Playback controls
            HStack(spacing: 20) {
                Picker("速度", selection: $playbackRate) {
                    Text("0.5x").tag(Float(0.5))
                    Text("1x").tag(Float(1.0))
                    Text("1.5x").tag(Float(1.5))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .onChange(of: playbackRate) { _, newRate in
                    audioPlayer?.rate = newRate
                }

                Spacer()

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(recording.scoreTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupAudio()
        }
        .onDisappear {
            syncTimer?.invalidate()
            audioPlayer?.stop()
        }
    }

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Playback setup failed: \(error)")
        }
    }

    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            audioPlayer?.play()
            startSync()
        } else {
            audioPlayer?.pause()
            syncTimer?.invalidate()
        }
    }

    private func startSync() {
        syncTimer?.invalidate()

        let judgments = recording.judgments
        guard !judgments.isEmpty else { return }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let player = audioPlayer else { return }
            let effectiveTime = player.currentTime * Double(playbackRate)
            currentTime = effectiveTime

            currentJudgmentIndex = findJudgmentIndex(at: effectiveTime)

            if !player.isPlaying, effectiveTime >= duration - 0.5 {
                isPlaying = false
                syncTimer?.invalidate()
                currentJudgmentIndex = judgments.count - 1
            }
        }
    }

    private func findJudgmentIndex(at time: TimeInterval) -> Int {
        let judgments = recording.judgments
        var idx = 0
        for j in judgments {
            if j.timestamp <= time { idx += 1 }
            else { break }
        }
        return max(0, idx - 1)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func centsColor(_ cents: Double) -> Color {
        if abs(cents) <= 50 { return .green }
        if abs(cents) <= 100 { return .orange }
        return .red
    }
}
