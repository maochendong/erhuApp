import AVFoundation
import Accelerate
import Observation

/// Manages microphone input and audio processing with YIN pitch detection
@Observable
final class AudioEngine {
    let engine = AVAudioEngine()
    var isListening = false
    var currentFrequency: Double = 0
    var currentNote: Int = 0
    var currentOctave: Int = 0
    var amplitude: Float = 0
    /// Cent deviation from the nearest standard note (negative = flat, positive = sharp)
    var currentCentsOffset: Double = 0

    /// YIN threshold parameter (default 0.15, lower = more sensitive)
    var yinThreshold: Double = 0.12
    /// Minimum detected frequency (C3 ≈ 130.81 Hz, but erhu low string ≈ D4)
    let minFrequency: Double = 130.0
    /// Maximum detected frequency (erhu high range up to ~A6)
    let maxFrequency: Double = 2000.0

    private let sampleRate: Double = 44100
    /// Buffer size for analysis (~46ms at 44.1kHz)
    private let bufferSize = 2048

    /// Portamento smoothing: require pitch stability before registering
    private var pitchHistory: [Double] = []
    private let pitchHistoryMaxSize = 4
    private let stabilityCentsThreshold: Double = 40.0

    func start() {
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("AudioSession setup failed: \(error)")
        }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        // Fallback to standard format if input format is invalid (e.g. on simulator)
        let format: AVAudioFormat
        if inputFormat.sampleRate == 0 {
            format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        } else {
            format = inputFormat
        }

        // Ensure output node is properly connected
        if engine.outputNode.inputFormat(forBus: 0).sampleRate == 0 {
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        }

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            isListening = true
        } catch {
            print("AudioEngine failed to start: \(error)")
            isListening = false
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        currentFrequency = 0
        currentNote = 0
        currentCentsOffset = 0
        pitchHistory.removeAll()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // RMS amplitude
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))
        amplitude = rms

        // Noise gate: require minimum amplitude
        guard rms > 0.012 else {
            currentFrequency = 0
            currentNote = 0
            currentCentsOffset = 0
            pitchHistory.removeAll()
            return
        }

        if let rawFreq = detectPitchYIN(samples) {
            if let freq = smoothAndValidatePitch(rawFreq), freq > 0 {
                currentFrequency = freq
                let (note, octave, centsOff) = frequencyToNote(freq)
                currentNote = note
                currentOctave = octave
                currentCentsOffset = centsOff
            }
        }
    }

    // MARK: - YIN Algorithm

    /// YIN pitch detection with octave error correction for erhu.
    /// Returns fundamental frequency in Hz, or nil if no clear pitch detected.
    private func detectPitchYIN(_ samples: [Float]) -> Double? {
        let count = samples.count
        let maxLag = min(count, Int(sampleRate / minFrequency))
        let minLag = max(1, Int(sampleRate / maxFrequency))

        guard maxLag > minLag else { return nil }

        // Step 1: Difference function d(tau)
        var diff = [Double](repeating: 0, count: maxLag)

        var squaredSum: Float = 0
        vDSP_svesq(samples, 1, &squaredSum, vDSP_Length(count))
        diff[0] = Double(squaredSum) * 2.0

        for tau in 1..<maxLag {
            var sum: Float = 0
            let len = count - tau
            vDSP_distancesq(samples, 1, Array(samples[tau..<count]), 1, &sum, vDSP_Length(len))
            diff[tau] = Double(sum)
        }

        // Step 2: Cumulative mean normalized difference function
        var cmnd = [Double](repeating: 0, count: maxLag)
        cmnd[0] = 1.0
        var runningSum: Double = 0
        for tau in 1..<maxLag {
            runningSum += diff[tau]
            cmnd[tau] = diff[tau] * Double(tau) / runningSum
        }

        // Step 3: Absolute threshold search — find all candidate dips, not just the first
        var candidates: [(tau: Int, value: Double)] = []
        var inDip = false
        for tau in minLag..<maxLag {
            if cmnd[tau] < yinThreshold && !inDip {
                inDip = true
                candidates.append((tau, cmnd[tau]))
            } else if cmnd[tau] >= yinThreshold {
                inDip = false
            }
        }

        // If no point below threshold, find global minimum
        if candidates.isEmpty {
            var minVal = Double.infinity
            var bestTau = minLag
            for tau in minLag..<maxLag {
                if cmnd[tau] < minVal {
                    minVal = cmnd[tau]
                    bestTau = tau
                }
            }
            candidates.append((bestTau, minVal))
        }

        // Step 4: Choose the best candidate with octave correction.
        // The first YIN dip is often the correct fundamental, but strong
        // erhu harmonics can pull it to a sub-octave. We compare candidates
        // and prefer the one that gives a frequency in a plausible range
        // for the expected instrument range.
        var bestCandidate = candidates[0]
        var bestScore = Double.infinity

        for candidate in candidates {
            guard candidate.tau > 0 else { continue }

            // Interpolate for sub-sample accuracy
            let interpolatedTau = parabolicInterpolation(cmnd: cmnd, tau: candidate.tau)
            let freq = sampleRate / interpolatedTau
            guard freq >= minFrequency && freq <= maxFrequency else { continue }

            // Score: prefer lower CMND value and penalize candidates that
            // appear to be octave errors (freq × 2 has a dip too)
            let score = candidate.value

            // Check if double frequency also has a dip (good sign it's the fundamental)
            let halfTau = candidate.tau / 2
            var octaveConfidence: Double = 1.0
            if halfTau >= minLag {
                octaveConfidence = cmnd[halfTau] / cmnd[candidate.tau]
            }

            // Prefer candidates where the octave also dips (strong fundamental)
            let adjustedScore = score * (0.5 + 0.5 / max(octaveConfidence, 0.1))

            if adjustedScore < bestScore {
                bestScore = adjustedScore
                bestCandidate = candidate
            }
        }

        guard bestCandidate.tau > 0 else { return nil }

        let interpolatedTau = parabolicInterpolation(cmnd: cmnd, tau: bestCandidate.tau)
        let frequency = sampleRate / interpolatedTau
        guard frequency >= minFrequency && frequency <= maxFrequency else { return nil }

        return frequency
    }

    /// Parabolic interpolation around the best tau for sub-sample accuracy
    private func parabolicInterpolation(cmnd: [Double], tau: Int) -> Double {
        guard tau > 0 && tau < cmnd.count - 1 else { return Double(tau) }

        let alpha = cmnd[tau - 1]
        let beta = cmnd[tau]
        let gamma = cmnd[tau + 1]

        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else { return Double(tau) }

        let p = 0.5 * (alpha - gamma) / denominator
        return Double(tau) + p
    }

    // MARK: - Portamento Handling

    /// Smooth pitch detection to avoid false triggers during erhu portamento (滑音)
    /// Only registers a pitch when it has been stable within 40 cents for >80ms
    private func smoothAndValidatePitch(_ freq: Double) -> Double? {
        pitchHistory.append(freq)
        if pitchHistory.count > pitchHistoryMaxSize {
            pitchHistory.removeFirst()
        }

        guard pitchHistory.count >= 3 else { return nil }

        // Check stability
        let meanFreq = pitchHistory.reduce(0, +) / Double(pitchHistory.count)
        let allStable = pitchHistory.allSatisfy { pitch in
            let cents = 1200 * log2(pitch / meanFreq)
            return abs(cents) < stabilityCentsThreshold
        }

        return allStable ? meanFreq : nil
    }

    // MARK: - Frequency to Note

    /// Convert frequency to jianpu note degree, octave, and cent offset.
    private func frequencyToNote(_ freq: Double) -> (degree: Int, octave: Int, centsOff: Double) {
        guard freq > 0 else { return (0, 0, 0) }

        let midi = 12 * log2(freq / 440.0) + 69
        let roundedMidi = Int(round(midi))

        // Cent offset from the nearest equal-temperament note
        let nearestFreq = 440.0 * pow(2.0, (Double(roundedMidi) - 69.0) / 12.0)
        let centsOff = 1200 * log2(freq / nearestFreq)

        let noteInOctave = ((roundedMidi - 12) % 12 + 12) % 12
        let octave = (roundedMidi - 12) / 12 - 1

        let degree: Int
        switch noteInOctave {
        case 0:  degree = 1
        case 2:  degree = 2
        case 4:  degree = 3
        case 5:  degree = 4
        case 7:  degree = 5
        case 9:  degree = 6
        case 11: degree = 7
        default: degree = 0
        }

        return (degree, octave, centsOff)
    }
}
