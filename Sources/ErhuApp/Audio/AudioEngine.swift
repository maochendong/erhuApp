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

    /// YIN threshold parameter (default 0.15, lower = more sensitive)
    var yinThreshold: Double = 0.15
    /// Minimum detected frequency (C3 ≈ 130.81 Hz)
    let minFrequency: Double = 65.0
    /// Maximum detected frequency (C7 ≈ 2093 Hz)
    let maxFrequency: Double = 2093.0

    private let sampleRate: Double = 44100
    /// Buffer size for analysis (≈23ms at 44.1kHz, allows detection down to ~65Hz)
    private let bufferSize = 2048

    /// Portamento smoothing: require pitch stability for 80ms before registering
    private var pitchHistory: [Double] = []
    private let pitchHistoryMaxSize = 4  // ~80ms at ~50Hz buffer rate (23ms * 4 ≈ 92ms)
    private let stabilityCentsThreshold: Double = 50.0

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
        pitchHistory.removeAll()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
        amplitude = rms

        guard rms > 0.01 else {
            currentFrequency = 0
            currentNote = 0
            pitchHistory.removeAll()
            return
        }

        if let rawFreq = detectPitchYIN(samples) {
            if let freq = smoothAndValidatePitch(rawFreq), freq > 0 {
                currentFrequency = freq
                let (note, octave) = frequencyToNote(freq)
                currentNote = note
                currentOctave = octave
            }
        }
    }

    // MARK: - YIN Algorithm

    /// YIN pitch detection (de Cheveigné & Kawahara, 2002)
    /// Returns fundamental frequency in Hz, or nil if no clear pitch detected
    private func detectPitchYIN(_ samples: [Float]) -> Double? {
        let count = samples.count
        let maxLag = min(count, Int(sampleRate / minFrequency))
        let minLag = max(1, Int(sampleRate / maxFrequency))

        guard maxLag > minLag else { return nil }

        // Step 1: Difference function d(tau)
        var diff = [Double](repeating: 0, count: maxLag)

        // Use Accelerate for performance
        var squaredSum: Float = 0
        vDSP_svesq(samples, 1, &squaredSum, vDSP_Length(count))
        diff[0] = Double(squaredSum) * 2.0

        for tau in 1..<maxLag {
            // d(tau) = sum_{j=0}^{N-1-tau} (x[j] - x[j+tau])^2
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

        // Step 3: Absolute threshold search
        // Find first tau where CMND drops below threshold
        var bestTau: Int? = nil
        for tau in minLag..<maxLag {
            if cmnd[tau] < yinThreshold {
                bestTau = tau
                break
            }
        }

        // If no point below threshold, find global minimum in range
        if bestTau == nil {
            var minVal = Double.infinity
            for tau in minLag..<maxLag {
                if cmnd[tau] < minVal {
                    minVal = cmnd[tau]
                    bestTau = tau
                }
            }
        }

        guard let tau = bestTau, tau > 0 else { return nil }

        // Step 4: Parabolic interpolation for sub-sample accuracy
        let interpolatedTau = parabolicInterpolation(cmnd: cmnd, tau: tau)

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
    /// Only registers a pitch when it has been stable within 50 cents for >80ms
    private func smoothAndValidatePitch(_ freq: Double) -> Double? {
        pitchHistory.append(freq)
        if pitchHistory.count > pitchHistoryMaxSize {
            pitchHistory.removeFirst()
        }

        guard pitchHistory.count >= 3 else { return nil }

        // Check if all recent pitches are within ±50 cents of each other
        let meanFreq = pitchHistory.reduce(0, +) / Double(pitchHistory.count)
        let allStable = pitchHistory.allSatisfy { pitch in
            let cents = 1200 * log2(pitch / meanFreq)
            return abs(cents) < stabilityCentsThreshold
        }

        return allStable ? meanFreq : nil
    }

    // MARK: - Frequency to Note

    /// Convert frequency to jianpu note degree and octave
    private func frequencyToNote(_ freq: Double) -> (degree: Int, octave: Int) {
        guard freq > 0 else { return (0, 0) }

        let midi = 12 * log2(freq / 440.0) + 69
        let roundedMidi = Int(round(midi))

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

        return (degree, octave)
    }
}
