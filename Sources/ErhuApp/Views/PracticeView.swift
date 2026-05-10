import SwiftUI

/// Score follower states for visual feedback
enum FollowerState: Equatable {
    case idle          // Not active
    case listening     // Actively listening for correct pitch (green)
    case waiting       // Awaiting user input after silence (yellow)

    var color: Color {
        switch self {
        case .idle: return .gray
        case .listening: return .green
        case .waiting: return .orange
        }
    }

    var label: String {
        switch self {
        case .idle: return "空闲"
        case .listening: return "监听中"
        case .waiting: return "等待中"
        }
    }
}

struct PracticeView: View {
    @State private var audioEngine = AudioEngine()
    @State private var currentScore: Score?
    @State private var currentNoteIndex = 0
    @State private var judgments: [PitchJudger.Judgment] = []
    @State private var isPlaying = false
    @State private var showScoreLibrary = false
    @State private var showSummary = false
    @State private var followerState: FollowerState = .idle

    /// Track when silence started to detect >500ms of no audio
    @State private var silenceStartTime: Date?
    /// Track how long current note has been matched (>100ms to advance)
    @State private var matchStartTime: Date?

    // MARK: - Loop state
    @State private var loopStartIndex: Int?
    @State private var loopEndIndex: Int?
    @State private var loopCount: Int = 0        // 0 = infinite
    @State private var loopActive: Bool = false
    @State private var loopRemaining: Int = 0    // remaining iterations

    // MARK: - Recording state
    @State private var recordingService = RecordingService()
    @State private var showRecordings = false
    @State private var recordingStartTime: Date?

    // MARK: - Metronome state
    @State private var tempo: Double = 80
    @State private var metronomeEnabled = false
    @State private var currentBeat = 0

    // MARK: - Check-in toast
    @State private var showCheckInToast = false

    private let metronome = Metronome()

    let judger = PitchJudger()
    let silenceThresholdMs: Double = 500
    let matchThresholdMs: Double = 100
    let amplitudeThreshold: Float = 0.02
    let centsToleranceForAdvance: Double = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let score = currentScore {
                    // Score follower state indicator
                    HStack {
                        Circle()
                            .fill(followerState.color)
                            .frame(width: 10, height: 10)
                        Text(followerState.label)
                            .font(.caption)
                            .foregroundStyle(followerState.color)
                        Spacer()
                        Text("音符 \(currentNoteIndex + 1) / \(score.allNotes.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    ScoreView(
                        score: score,
                        currentNoteIndex: currentNoteIndex,
                        judgments: judgments,
                        loopStartIndex: loopStartIndex,
                        loopEndIndex: loopEndIndex,
                        onLongPressNote: { idx in handleLongPressNote(idx, score: score) }
                    )
                    .padding(.top, 4)

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

                    // Loop controls
                    if isPlaying || loopStartIndex != nil || loopEndIndex != nil {
                        VStack(spacing: 4) {
                            if let start = loopStartIndex, let end = loopEndIndex, loopActive {
                                HStack {
                                    Text("循环 \(start+1)-\(end+1)")
                                        .font(.caption)
                                    Stepper(value: $loopCount, in: 0...10) {
                                        Text(loopCount == 0 ? "无限" : "\(loopCount) 次")
                                            .font(.caption)
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: 80)

                                    Button("取消循环") {
                                        clearLoop()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }
                            } else if let start = loopStartIndex {
                                Text("起点 A: 第\(start+1)音 — 长按设置终点 B")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("长按音符设置循环起点 A")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    // Metronome controls
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "metronome")
                                .foregroundStyle(metronomeEnabled ? Color.accentColor : Color.secondary)
                            Text("♩ = \(Int(tempo))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()

                            Button(metronomeEnabled ? "关闭节拍器" : "节拍器") {
                                metronomeEnabled.toggle()
                                if metronomeEnabled {
                                    metronome.onBeat = { beat, isDownbeat in
                                        DispatchQueue.main.async {
                                            currentBeat = beat
                                        }
                                    }
                                    metronome.setTempo(Int(tempo))
                                } else {
                                    metronome.stop()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(metronomeEnabled ? Color.accentColor : Color.secondary)
                        }

                        Slider(value: $tempo, in: 40...200, step: 5) { editing in
                            if !editing, metronomeEnabled {
                                metronome.setTempo(Int(tempo))
                            }
                        }
                        .padding(.horizontal)

                        // Beat indicator: 4 dots
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { beat in
                                Circle()
                                    .fill(metronomeEnabled && beat == currentBeat
                                          ? (beat == 0 ? Color.accentColor : Color.orange)
                                          : Color.gray.opacity(0.3))
                                    .frame(width: beat == currentBeat && metronomeEnabled ? 12 : 8,
                                           height: beat == currentBeat && metronomeEnabled ? 12 : 8)
                                    .animation(.easeInOut(duration: 0.1), value: currentBeat)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

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
                                HStack {
                                    if recordingService.isRecording {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                    }
                                    Label(isPlaying ? "停止" : "开始演奏",
                                          systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                }
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
                ToolbarItem(placement: .topBarLeading) {
                    if currentScore != nil {
                        Button {
                            showRecordings = true
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
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
            .sheet(isPresented: $showRecordings) {
                NavigationStack {
                    RecordingListView { deleted in
                        if let deleted = deleted {
                            RecordingService.deleteRecording(deleted)
                        }
                    }
                    .navigationTitle("练习录音")
                }
            }
            .sheet(isPresented: $showSummary) {
                if let score = currentScore, !judgments.isEmpty {
                    let result = PitchJudger.PerformanceResult(score: score, judgments: judgments)
                    PerformanceSummaryView(
                        result: result,
                        onRetry: { resetPerformance(); showSummary = false },
                        onChoose: { resetPerformance(); currentScore = nil; showSummary = false }
                    )
                    .onAppear {
                        PersistenceController.shared.savePracticeResult(
                            scoreTitle: score.title,
                            accuracy: result.accuracy,
                            duration: recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0,
                            totalNotes: result.totalCount,
                            correctNotes: result.correctCount,
                            judgments: judgments
                        )
                        NotificationManager.shared.recordPracticeDate()
                    }
                }
            }
            .overlay(alignment: .top) {
                if showCheckInToast {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundStyle(.orange)
                        Text("今日打卡成功")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showCheckInToast = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startNewScore(_ score: Score) {
        currentScore = score
        currentNoteIndex = 0
        judgments = []
        isPlaying = false
        followerState = .idle
        silenceStartTime = nil
        matchStartTime = nil
        audioEngine.stop()
        showScoreLibrary = false
        showSummary = false
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            let firstToday = NotificationManager.shared.isFirstPracticeToday
            if firstToday {
                showCheckInToast = true
            }
            recordingStartTime = Date()
            recordingService.startRecording(scoreTitle: currentScore?.title ?? "")
            audioEngine.start()
            startScoreFollowing()
            if metronomeEnabled {
                metronome.onBeat = { beat, isDownbeat in
                    DispatchQueue.main.async {
                        currentBeat = beat
                    }
                }
                metronome.setTempo(Int(tempo))
            }
        } else {
            let info = recordingService.stopRecording(scoreTitle: currentScore?.title ?? "", judgments: judgments)
            audioEngine.stop()
            metronome.stop()
            followerState = .idle
            silenceStartTime = nil
            matchStartTime = nil
        }
    }

    private func resetPerformance() {
        currentNoteIndex = 0
        judgments = []
        isPlaying = false
        followerState = .idle
        silenceStartTime = nil
        matchStartTime = nil
        clearLoop()
        metronome.stop()
        audioEngine.stop()
    }

    // MARK: - Loop Actions

    private func handleLongPressNote(_ idx: Int, score: Score) {
        guard !isPlaying else { return }
        if loopStartIndex == nil {
            loopStartIndex = idx
            loopEndIndex = nil
            loopActive = false
        } else if loopStartIndex != nil, loopEndIndex == nil, idx != loopStartIndex {
            let start = min(loopStartIndex!, idx)
            let end = max(loopStartIndex!, idx)
            loopStartIndex = start
            loopEndIndex = end
            loopActive = true
            loopCount = 0  // infinite by default
            loopRemaining = 0
        } else {
            // Both set, reset and start fresh
            loopStartIndex = idx
            loopEndIndex = nil
            loopActive = false
        }
    }

    private func clearLoop() {
        loopStartIndex = nil
        loopEndIndex = nil
        loopActive = false
        loopCount = 0
        loopRemaining = 0
    }

    // MARK: - Score Following

    private func startScoreFollowing() {
        guard let score = currentScore else { return }
        followerState = .listening

        Task {
            while isPlaying && currentNoteIndex < score.allNotes.count {
                try? await Task.sleep(nanoseconds: 30_000_000) // ~33fps (~30ms)

                await MainActor.run {
                    updateFollower(score: score)
                }
            }

            await MainActor.run {
                isPlaying = false
                audioEngine.stop()
                followerState = .idle
                // Show summary when reaching end of score
                if let score = currentScore, currentNoteIndex >= score.allNotes.count {
                    showSummary = true
                }
            }
        }
    }

    /// Core follower logic: advance note-by-note when correct pitch held >100ms,
    /// pause on silence >500ms, skip rests automatically
    private func updateFollower(score: Score) {
        guard isPlaying, currentNoteIndex < score.allNotes.count else { return }

        let targetNote = score.allNotes[currentNoteIndex]

        // Skip rest notes automatically
        if targetNote.isRest {
            // Rest: append "correct" placeholder and advance immediately
            let ts = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
            let restJudgment = PitchJudger.Judgment(
                note: targetNote,
                playedDegree: 0,
                playedOctave: 0,
                isCorrect: true,
                centsOff: 0,
                timestamp: ts
            )
            judgments.append(restJudgment)
            advanceWithLoop(score: score)
            silenceStartTime = nil
            matchStartTime = nil
            return
        }

        // Check amplitude for silence detection
        let isSilent = audioEngine.amplitude < amplitudeThreshold

        if isSilent {
            // Track silence duration
            if silenceStartTime == nil {
                silenceStartTime = Date()
            }
            let silenceMs = Date().timeIntervalSince(silenceStartTime!) * 1000

            if silenceMs > silenceThresholdMs {
                followerState = .waiting
            }
            matchStartTime = nil
            return
        } else {
            silenceStartTime = nil
        }

        // Evaluate pitch match
        let judgment = judger.judge(
            playedFrequency: audioEngine.currentFrequency,
            targetNote: targetNote
        )

        let isInTune = abs(judgment.centsOff) <= centsToleranceForAdvance
        let isCorrectDegree = judgment.playedDegree == targetNote.degree
        let isMatch = isCorrectDegree && isInTune

        if isMatch {
            followerState = .listening
            if matchStartTime == nil {
                matchStartTime = Date()
            }
            let matchMs = Date().timeIntervalSince(matchStartTime!) * 1000

            if matchMs >= matchThresholdMs {
                // Advance after holding correct pitch for >100ms
                let ts = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
                let judgmentWithTimestamp = PitchJudger.Judgment(
                    note: judgment.note,
                    playedDegree: judgment.playedDegree,
                    playedOctave: judgment.playedOctave,
                    isCorrect: judgment.isCorrect,
                    centsOff: judgment.centsOff,
                    timestamp: ts
                )
                judgments.append(judgmentWithTimestamp)
                advanceWithLoop(score: score)
                matchStartTime = nil
            }
        } else {
            followerState = .listening // Still listening, just not matched yet
            matchStartTime = nil
        }
    }

    /// Advance the score follower, jumping back to loop start if active
    private func advanceWithLoop(score: Score) {
        currentNoteIndex += 1

        guard let start = loopStartIndex, let end = loopEndIndex, loopActive,
              currentNoteIndex > end else { return }

        if loopRemaining > 0 {
            loopRemaining -= 1
            if loopRemaining == 0 {
                loopActive = false
                return
            }
        }
        // loopCount == 0 means infinite; remaining > 0 means finite
        currentNoteIndex = start
    }
}

#Preview {
    PracticeView()
}
