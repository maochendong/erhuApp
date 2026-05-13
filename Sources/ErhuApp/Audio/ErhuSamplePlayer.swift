import AVFoundation

/// Sample-based erhu note player using real instrument recordings.
///
/// Loads looperman WAV samples, detects their fundamental frequency,
/// and uses AVAudioUnitTimePitch for pitch-shifted playback with
/// realistic erhu timbre. Also supports full-recording playback for
/// scores that have a corresponding audio file (e.g. 赛马).
final class ErhuSamplePlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pitchUnit = AVAudioUnitTimePitch()

    private var sourceSamples: [(frequency: Float, buffer: AVAudioPCMBuffer)] = []
    private var saimaPlayer: AVAudioPlayer?

    private let volume: Float = 0.5

    // MARK: - Initialization

    init?() {
        loadSamples()
        guard !sourceSamples.isEmpty else {
            print("ErhuSamplePlayer: no WAV samples loaded")
            return nil
        }

        pitchUnit.overlap = 8.0

        engine.attach(playerNode)
        engine.attach(pitchUnit)
        engine.connect(playerNode, to: pitchUnit, format: nil)
        engine.connect(pitchUnit, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
        } catch {
            print("ErhuSamplePlayer: failed to start audio engine — \(error)")
            return nil
        }
    }

    deinit {
        engine.stop()
    }

    // MARK: - Sample Loading

    private func loadSamples() {
        let bundle = Bundle.main

        let names = [
            ("二胡 - 60 - 120 Bpm_looperman", "wav"),
            ("二胡1_looperman", "wav"),
        ]

        for (name, ext) in names {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                loadAndDetect(url: url)
            } else {
                print("ErhuSamplePlayer: \(name).\(ext) not found in bundle")
            }
        }

        sourceSamples.sort { $0.frequency < $1.frequency }

        // Load 赛马 MP3 for full-recording playback
        let saimaName = "二胡独奏《赛马》_耳聆网_[声音ID：35714]"
        if let url = bundle.url(forResource: saimaName, withExtension: "mp3") {
            loadSaima(url: url)
        }
    }

    private func loadAndDetect(url: URL) {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length))
        else { return }

        try? file.read(into: buffer)
        buffer.frameLength = AVAudioFrameCount(file.length)

        let sampleRate = Float(file.processingFormat.sampleRate)
        let freq = detectFundamentalFrequency(buffer: buffer, sampleRate: sampleRate)
        print("ErhuSamplePlayer: loaded \(url.lastPathComponent), detected ~\(Int(freq)) Hz")
        sourceSamples.append((freq, buffer))
    }

    private func loadSaima(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            saimaPlayer = player
            print("ErhuSamplePlayer: loaded 赛马 recording (\(player.duration)s)")
        } catch {
            print("ErhuSamplePlayer: failed to load 赛马 MP3 — \(error.localizedDescription)")
        }
    }

    // MARK: - Pitch Detection

    private func detectFundamentalFrequency(buffer: AVAudioPCMBuffer, sampleRate: Float) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 220 }
        let frames = Int(buffer.frameLength)
        let minLag = max(Int(sampleRate / 1200), 4)
        let maxLag = min(Int(sampleRate / 60), frames / 2)
        guard maxLag > minLag else { return 220 }

        let analysisFrames = min(frames, Int(sampleRate * 0.15))
        var bestLag = minLag
        var bestCorr: Float = 0

        for lag in minLag..<maxLag {
            var corr: Float = 0
            var power: Float = 0
            let limit = analysisFrames - lag
            for i in 0..<limit {
                corr += data[i] * data[i + lag]
                power += data[i] * data[i] + data[i + lag] * data[i + lag]
            }
            let norm = power * 0.5
            if norm > Float.ulpOfOne {
                corr /= norm
            }
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        guard bestCorr > 0.12 else { return 220 }
        return sampleRate / Float(bestLag)
    }

    // MARK: - Public API

    /// Play a single note with given duration. Caller handles timing between notes.
    func play(note: Note, duration: TimeInterval = 0.6) {
        let targetFreq = Float(note.frequency)
        guard targetFreq > 0, !sourceSamples.isEmpty else { return }

        stop()

        var bestSample: (frequency: Float, buffer: AVAudioPCMBuffer)?
        var bestDiff: Float = .infinity
        for sample in sourceSamples {
            let diff = abs(sample.frequency - targetFreq)
            if diff < bestDiff {
                bestDiff = diff
                bestSample = sample
            }
        }
        guard let best = bestSample else { return }

        let cents = 1200 * log2(targetFreq / best.frequency)
        pitchUnit.pitch = cents

        let sampleRate = Float(best.buffer.format.sampleRate)
        let neededFrames = AVAudioFrameCount(sampleRate * Float(duration))
        let framesToUse = min(neededFrames, best.buffer.frameLength)
        guard framesToUse > 0,
              let playBuf = AVAudioPCMBuffer(pcmFormat: best.buffer.format, frameCapacity: framesToUse)
        else { return }

        playBuf.frameLength = framesToUse
        let src = best.buffer.floatChannelData![0]
        let dst = playBuf.floatChannelData![0]

        let fadeLen = Int(min(sampleRate * 0.012, Float(framesToUse) / 2))
        let iFrames = Int(framesToUse)
        for i in 0..<iFrames { dst[i] = src[i] }
        for i in 0..<min(fadeLen, iFrames) {
            let env = Float(i) / Float(fadeLen)
            dst[i] *= env
            dst[iFrames - 1 - i] *= env
        }

        playerNode.scheduleBuffer(playBuf, at: nil, options: .interrupts)
        playerNode.volume = volume
        playerNode.play()
    }

    /// Play the full 赛马 recording. Returns true if playback started.
    @discardableResult
    func playSaimaRecording() -> Bool {
        guard let player = saimaPlayer else { return false }
        player.stop()
        player.currentTime = 0
        player.volume = 0.5
        return player.play()
    }

    /// Whether a full recording is available for the given score title.
    func hasFullRecording(for title: String) -> Bool {
        title.contains("赛马") && saimaPlayer != nil
    }

    func stop() {
        playerNode.stop()
        saimaPlayer?.stop()
    }
}
