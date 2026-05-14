import AVFoundation

/// Sample-based erhu note player using per-note CD-quality samples.
///
/// Loads individual WAV files from the Notes/ bundle subdirectory (e.g. C4.wav,
/// D4.wav), each recorded at a known pitch. Plays back by selecting the
/// nearest-matching note sample with minimal pitch shift, yielding drastically
/// better timbre than the old approach of pitch-shifting two generic samples
/// across the full note range.
///
/// Falls back to pitch-shifting the nearest available sample when an exact
/// match is not in the library. If no samples are available at all, the
/// failable initializer returns nil and the caller (PracticeView) falls back
/// to NotePlayer (additive synthesis).
final class ErhuSamplePlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pitchUnit = AVAudioUnitTimePitch()

    /// Samples keyed by note name (e.g. "C4", "D#5"). Each key holds 1-2
    /// WAV buffers for slight variety on repeated notes.
    private var library: [String: [AVAudioPCMBuffer]] = [:]
    /// Sorted note names by frequency, for nearest-match lookup.
    private var sortedNoteNames: [String] = []

    /// Round-robin index per note so we cycle through samples predictably.
    private var sampleIndex: [String: Int] = [:]

    private var saimaPlayer: AVAudioPlayer?

    private let volume: Float = 0.5

    // MARK: - Initialization

    init?() {
        loadNoteSamples()
        guard !library.isEmpty else {
            print("ErhuSamplePlayer: no note samples loaded")
            return nil
        }

        sortedNoteNames = library.keys.sorted { freq($0) < freq($1) }

        pitchUnit.overlap = 8.0

        engine.attach(playerNode)
        engine.attach(pitchUnit)
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        engine.connect(playerNode, to: pitchUnit, format: monoFormat)
        engine.connect(pitchUnit, to: engine.mainMixerNode, format: monoFormat)

        do {
            try engine.start()
        } catch {
            print("ErhuSamplePlayer: failed to start audio engine — \(error)")
            return nil
        }

        loadSaima()
    }

    deinit {
        engine.stop()
    }

    // MARK: - Sample Loading

    private func loadNoteSamples() {
        let bundle = Bundle.main

        guard let urls = bundle.urls(forResourcesWithExtension: "wav",
                                     subdirectory: nil),
              !urls.isEmpty
        else {
            print("ErhuSamplePlayer: no WAV files found in bundle")
            return
        }

        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            let noteName = parseNoteName(from: name)
            guard !noteName.isEmpty else {
                print("ErhuSamplePlayer: skipping \(name).wav — unrecognised note name")
                continue
            }

            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length))
            else { continue }

            try? file.read(into: buffer)
            buffer.frameLength = AVAudioFrameCount(file.length)

            print("ErhuSamplePlayer: loaded \(name).wav → \(noteName) "
                  + "(\(file.length) frames)")
            library[noteName, default: []].append(buffer)
        }

        let sampleCount = library.values.reduce(0) { $0 + $1.count }
        print("ErhuSamplePlayer: \(library.keys.count) notes, \(sampleCount) total samples")
    }

    /// Parse a note name from a filename like "C4", "C#5", "D4_2", "Eb5_1".
    /// Returns empty string if the filename doesn't match a known pattern.
    private func parseNoteName(from filename: String) -> String {
        let validNotes = ["C#", "D#", "F#", "G#", "A#", "C", "D", "E", "F", "G", "A", "B",
                          "Db", "Eb", "Gb", "Ab", "Bb"]

        for note in validNotes {
            guard filename.hasPrefix(note) else { continue }
            let rest = filename.dropFirst(note.count)
            guard let octaveChar = rest.first, let _ = Int(String(octaveChar)) else { continue }
            return note + String(octaveChar)
        }
        return ""
    }

    private func loadSaima() {
        let name = "二胡独奏《赛马》_耳聆网_[声音ID：35714]"
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            saimaPlayer = player
            print("ErhuSamplePlayer: loaded 赛马 recording (\(player.duration)s)")
        } catch {
            print("ErhuSamplePlayer: failed to load 赛马 MP3 — \(error.localizedDescription)")
        }
    }

    // MARK: - Frequency / Note Helpers

    /// Equal-temperament frequency for a note name like "C4" or "F#5".
    private func freq(_ noteName: String) -> Float {
        let noteMap: [String: Int] = [
            "C": -9, "C#": -8, "Db": -8,
            "D": -7, "D#": -6, "Eb": -6,
            "E": -5, "F": -4, "F#": -3, "Gb": -3,
            "G": -2, "G#": -1, "Ab": -1,
            "A": 0, "A#": 1, "Bb": 1,
            "B": 2,
        ]
        guard noteName.count >= 2 else { return 440 }
        let octaveChar = noteName.last!
        guard let octave = Int(String(octaveChar)) else { return 440 }
        var base = noteName
        base.removeLast()
        guard let semitoneOffset = noteMap[base] else { return 440 }
        let semitonesFromA4 = semitoneOffset + (octave - 4) * 12
        return 440.0 * pow(2.0, Float(semitonesFromA4) / 12.0)
    }

    /// MIDI-based note name for a frequency (uses flats to match file names).
    private func noteName(for frequency: Float) -> String {
        let names = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        let midi = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        let rounded = Int(round(midi))
        let octave = max(0, rounded / 12 - 1)
        let idx = ((rounded % 12) + 12) % 12
        return "\(names[idx])\(octave)"
    }

    /// Nearest available note name by frequency.
    private func nearestNote(to frequency: Float) -> String {
        guard !sortedNoteNames.isEmpty else { return "A4" }
        var best = sortedNoteNames[0]
        var bestDiff: Float = .infinity
        for name in sortedNoteNames {
            let diff = abs(freq(name) - frequency)
            if diff < bestDiff {
                bestDiff = diff
                best = name
            }
        }
        return best
    }

    // MARK: - Public API

    /// Play a single note. The caller is responsible for timing between notes.
    func play(note: Note, duration: TimeInterval = 0.6) {
        let targetFreq = Float(note.frequency)
        guard targetFreq > 0, !library.isEmpty else { return }

        // Resolve source: exact match → no pitch shift; nearest → small shift
        let name = noteName(for: targetFreq)
        let sourceNote: String
        let cents: Float

        if library[name] != nil && !library[name, default: []].isEmpty {
            sourceNote = name
            cents = 0
        } else {
            sourceNote = nearestNote(to: targetFreq)
            let sourceFreq = freq(sourceNote)
            cents = 1200 * log2(targetFreq / sourceFreq)
        }

        guard let buffers = library[sourceNote], !buffers.isEmpty else { return }

        // Round-robin sample selection
        let idx = sampleIndex[sourceNote] ?? 0
        let sourceBuf = buffers[idx % buffers.count]
        sampleIndex[sourceNote] = idx + 1

        stop()

        pitchUnit.pitch = cents
        pitchUnit.overlap = 8.0

        let sampleRate = Float(sourceBuf.format.sampleRate)
        let iTargetFrames = Int(sampleRate * Float(duration))
        let sourceFrames = Int(sourceBuf.frameLength)
        let framesToUse = min(iTargetFrames, sourceFrames)
        guard framesToUse > 0 else { return }

        let fadeSec: Float = 0.03
        let fadeLen = Int(min(sampleRate * fadeSec, Float(framesToUse) / 3))
        let attackLen = Int(min(sampleRate * 0.005, Float(framesToUse) / 4))

        // Only allocate a new buffer if we need a different size; otherwise use source
        let needsCopy = framesToUse < sourceFrames
        let playBuf: AVAudioPCMBuffer

        if needsCopy {
            guard let buf = AVAudioPCMBuffer(pcmFormat: sourceBuf.format,
                                             frameCapacity: AVAudioFrameCount(framesToUse))
            else { return }
            buf.frameLength = AVAudioFrameCount(framesToUse)
            let src = sourceBuf.floatChannelData![0]
            let dst = buf.floatChannelData![0]
            for i in 0..<framesToUse { dst[i] = src[i] }
            playBuf = buf
        } else {
            playBuf = sourceBuf
        }

        // Apply envelope: 5ms attack, sustain, 30ms release
        let data = playBuf.floatChannelData![0]
        for i in 0..<attackLen {
            data[i] *= Float(i) / Float(attackLen)      // linear attack
        }
        for i in 0..<fadeLen {
            let pos = Float(framesToUse - 1 - i) / Float(fadeLen)
            data[framesToUse - 1 - i] *= min(pos, 1.0)  // linear release
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
