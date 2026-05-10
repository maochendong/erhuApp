import AVFoundation

/// Manages audio recording of practice sessions.
final class RecordingService {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    struct RecordingInfo: Codable, Identifiable {
        let id: UUID
        let date: Date
        let scoreTitle: String
        let duration: TimeInterval
        let fileName: String
        let judgments: [PitchJudger.Judgment]
        var correctCount: Int { judgments.filter(\.isCorrect).count }
        var totalCount: Int { judgments.count }
        var accuracy: Double { totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0 }

        var fileURL: URL {
            recordingsDir.appendingPathComponent(fileName)
        }
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    private static var recordingsDir: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var metadataURL: URL {
        recordingsDir.appendingPathComponent("recordings.json")
    }

    /// Start recording for a given score title
    func startRecording(scoreTitle: String) {
        stopRecording(scoreTitle: scoreTitle)

        let fileName = "\(UUID().uuidString).m4a"
        let url = Self.recordingsDir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordingURL = url
        } catch {
            print("Recording failed: \(error)")
        }
    }

    /// Stop recording and save metadata
    func stopRecording(scoreTitle: String, judgments: [PitchJudger.Judgment] = []) -> RecordingInfo? {
        guard let recorder = recorder, recorder.isRecording else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil

        guard let url = recordingURL else { return nil }

        let info = RecordingInfo(
            id: UUID(),
            date: Date(),
            scoreTitle: scoreTitle,
            duration: duration,
            fileName: url.lastPathComponent,
            judgments: judgments
        )

        var allRecordings = Self.loadRecordings()
        allRecordings.append(info)
        Self.saveRecordings(allRecordings)

        return info
    }

    func stop() {
        recorder?.stop()
        recorder = nil
    }

    // MARK: - Persistence

    static func loadRecordings() -> [RecordingInfo] {
        guard let data = try? Data(contentsOf: metadataURL),
              let list = try? JSONDecoder().decode([RecordingInfo].self, from: data) else {
            return []
        }
        return list.sorted { $0.date > $1.date }
    }

    static func saveRecordings(_ recordings: [RecordingInfo]) {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    static func deleteRecording(_ info: RecordingInfo) {
        try? FileManager.default.removeItem(at: info.fileURL)
        var all = loadRecordings()
        all.removeAll { $0.id == info.id }
        saveRecordings(all)
    }
}
