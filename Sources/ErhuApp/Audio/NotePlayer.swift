import AVFoundation

/// Generates and plays sine wave tones for note preview and audition.
final class NotePlayer {
    private var audioPlayer: AVAudioPlayer?

    func play(note: Note, duration: TimeInterval = 0.6) {
        guard note.degree > 0 else { return }
        stop()
        let data = generateNoteData(frequency: note.frequency, duration: duration)
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

    private func generateNoteData(frequency: Double, duration: TimeInterval) -> Data {
        let sampleRate: Double = 44100
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            // Sine wave with soft attack/release envelope
            let attack = min(t / 0.02, 1.0)
            let release = min((duration - t) / 0.04, 1.0)
            let envelope = min(attack, release)
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.4)
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

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
