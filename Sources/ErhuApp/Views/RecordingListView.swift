import SwiftUI
import AVFoundation

struct RecordingListView: View {
    @State private var recordings: [RecordingService.RecordingInfo] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingFileName: String?
    @State private var showDeleteConfirmation: RecordingService.RecordingInfo?
    @State private var playbackRecording: RecordingService.RecordingInfo?

    let onDelete: ((RecordingService.RecordingInfo?) -> Void)?

    var body: some View {
        List {
            if recordings.isEmpty {
                ContentUnavailableView(
                    "还没有录音记录",
                    systemImage: "waveform",
                    description: Text("开始练习时会自动录音")
                )
            } else {
                ForEach(recordings) { recording in
                    NavigationLink {
                        if let score = findScore(title: recording.scoreTitle) {
                            PlaybackView(recording: recording, score: score)
                        } else {
                            scoreNotFoundView(recording)
                        }
                    } label: {
                        RecordingRow(recording: recording)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = recording
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("练习录音")
        .onAppear {
            recordings = RecordingService.loadRecordings()
        }
        .confirmationDialog(
            "删除录音？",
            isPresented: .init(get: { showDeleteConfirmation != nil },
                              set: { if !$0 { showDeleteConfirmation = nil } }),
            presenting: showDeleteConfirmation
        ) { recording in
            Button("删除", role: .destructive) {
                RecordingService.deleteRecording(recording)
                recordings = RecordingService.loadRecordings()
                onDelete?(recording)
            }
            Button("取消", role: .cancel) { }
        } message: { recording in
            Text("将删除「\(recording.scoreTitle)」的录音")
        }
    }

    private func findScore(title: String) -> Score? {
        ScoreService.shared.allScores.first { $0.title == title }
    }

    private func scoreNotFoundView(_ recording: RecordingService.RecordingInfo) -> some View {
        HStack {
            RecordingRow(recording: recording)
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .onTapGesture {
                    playAudioOnly(recording)
                }
        }
    }

    private func playAudioOnly(_ recording: RecordingService.RecordingInfo) {
        audioPlayer?.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.play()
            playingFileName = recording.fileName
        } catch {
            print("Playback failed: \(error)")
        }
    }
}

struct RecordingRow: View {
    let recording: RecordingService.RecordingInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.scoreTitle)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text(recording.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if recording.totalCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(recording.accuracy * 100))%")
                        .font(.headline)
                        .foregroundStyle(accuracyColor(recording.accuracy))
                    Text("\(recording.correctCount)/\(recording.totalCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.6 { return .orange }
        return .red
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }
}
