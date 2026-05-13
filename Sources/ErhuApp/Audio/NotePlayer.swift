import AVFoundation

/// Generates and plays erhu-like tones for note preview and audition.
final class NotePlayer {
    private var audioPlayer: AVAudioPlayer?

    private let sampleRate: Double = 44100

    /// Erhu harmonic structure: strong odd harmonics, weak even harmonics.
    /// (harmonic ratio, relative amplitude)
    private let harmonics: [(ratio: Double, amplitude: Double)] = [
        (1, 1.0),   // fundamental
        (2, 0.06),  // 2nd harmonic (very weak)
        (3, 0.65),  // 3rd harmonic (strong — characteristic of erhu)
        (4, 0.04),  // 4th (very weak)
        (5, 0.40),  // 5th (strong)
        (6, 0.02),  // 6th
        (7, 0.20),  // 7th (moderate)
        (9, 0.10),  // 9th
    ]

    func play(note: Note, duration: TimeInterval = 0.6) {
        guard note.degree > 0 else { return }
        stop()
        let data = generateErhuNote(frequency: note.frequency, duration: duration)
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
        } catch {
            print("NotePlayer failed: \(error)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Erhu Tone Synthesis

    private func generateErhuNote(frequency: Double, duration: TimeInterval) -> Data {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        // Pre-compute harmonic normalization factor
        let normFactor: Double = 1.0 / harmonics.map(\.amplitude).reduce(0, +)

        // Formant filter: band-pass around 2700 Hz for erhu's "nasal" quality
        let formantFreq: Double = 2700.0
        let formantQ: Double = 2.0
        var b0 = 0.0, b1 = 0.0, b2 = 0.0, a0 = 0.0, a1 = 0.0, a2 = 0.0
        computeBPF(Fc: formantFreq, Q: formantQ, sampleRate: sampleRate,
                   b0: &b0, b1: &b1, b2: &b2, a0: &a0, a1: &a1, a2: &a2)

        var x1 = 0.0, x2 = 0.0  // input delay line for formant filter
        var y1 = 0.0, y2 = 0.0  // output delay line for formant filter

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate

            // --- Envelope ---
            // Erhu-like ADSR: 80ms attack, slight decay, moderate sustain, 120ms release
            let attackTime: Double = 0.08
            let decayTime: Double = 0.06
            let releaseTime: Double = 0.12

            var env: Double
            if t < attackTime {
                env = t / attackTime  // 0→1 attack
            } else if t < attackTime + decayTime {
                let dt = (t - attackTime) / decayTime
                env = 1.0 - (1.0 - 0.85) * dt  // decay to 0.85
            } else if t > duration - releaseTime {
                let rt = (t - (duration - releaseTime)) / releaseTime
                env = 0.85 * (1.0 - rt)  // release to 0
            } else {
                env = 0.85  // sustain
            }

            // --- Vibrato: 5-6 Hz, small depth, typical of erhu performance ---
            let vibDepth: Double = 0.004  // ±0.4% frequency modulation
            let vibRate: Double = 5.5
            // Vibrato ramps in over first 0.2s
            let vibAmount = vibDepth * min(t / 0.2, 1.0)
            let vib = 1.0 + vibAmount * sin(2.0 * .pi * vibRate * t - 0.5)

            // --- Additive synthesis ---
            var raw: Double = 0
            for (ratio, amp) in harmonics {
                let freq = frequency * Double(ratio) * vib
                // Small random phase per harmonic for warmth
                let phase = frequency <= 200 ? 0.0 : 0.0
                raw += amp * sin(2.0 * .pi * freq * t + phase)
            }
            raw *= normFactor

            // --- Bow noise (attack grain) ---
            // Short burst of noise at note onset, decays quickly
            let bowAttackLen: Double = 0.03
            let bowNoise: Double
            if t < bowAttackLen {
                bowNoise = 0.06 * (1.0 - t / bowAttackLen)
                // Since we're in a loop, we need deterministic noise for reproducibility
                // Use a simple hash-like noise based on sample index
                let n = Double((i * 123456) & 0x7FFFFF) / Double(0x7FFFFF) * 2.0 - 1.0
                raw += bowNoise * n
            }

            // --- Apply formant filter (nasal resonance) ---
            let x0 = raw
            let y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0

            let filtered = y0

            // Apply final envelope and gain
            samples[i] = Float(filtered * env * 0.45)
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

    /// Compute biquad band-pass filter coefficients (direct form I)
    private func computeBPF(Fc: Double, Q: Double, sampleRate: Double,
                          b0: inout Double, b1: inout Double, b2: inout Double,
                          a0: inout Double, a1: inout Double, a2: inout Double) {
        let w0 = 2.0 * .pi * Fc / sampleRate
        let alpha = sin(w0) / (2.0 * Q)
        let cos_w0 = cos(w0)

        let norm = 1.0 / (1.0 + alpha)

        b0 = alpha * norm
        b1 = 0.0
        b2 = -alpha * norm
        a0 = 1.0
        a1 = (-2.0 * cos_w0) * norm
        a2 = (1.0 - alpha) * norm
    }

    // MARK: - WAV Encoding

    private func wavData(from samples: [Float], sampleRate: Double) -> Data {
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let sampleCount = samples.count

        var data = Data()
        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        let fileSize = UInt32(36 + sampleCount * 2)
        data.append(contentsOf: withUnsafeBytes(of: fileSize) { Data($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        let fmtSize: UInt32 = 16
        data.append(contentsOf: withUnsafeBytes(of: fmtSize) { Data($0) })
        let audioFormat: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: audioFormat) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: channels) { Data($0) })
        let sr = UInt32(sampleRate)
        data.append(contentsOf: withUnsafeBytes(of: sr) { Data($0) })
        let byteRate = UInt32(sampleRate * Double(channels) * Double(bitsPerSample) / 8)
        data.append(contentsOf: withUnsafeBytes(of: byteRate) { Data($0) })
        let blockAlign = UInt16(channels * bitsPerSample / 2)
        data.append(contentsOf: withUnsafeBytes(of: blockAlign) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample) { Data($0) })

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        let dataSize = UInt32(sampleCount * 2)
        data.append(contentsOf: withUnsafeBytes(of: dataSize) { Data($0) })

        for sample in samples {
            var intSample = Int16(clamping: Int(sample * Float(Int16.max)))
            data.append(contentsOf: withUnsafeBytes(of: &intSample) { Data($0) })
        }

        return data
    }
}
