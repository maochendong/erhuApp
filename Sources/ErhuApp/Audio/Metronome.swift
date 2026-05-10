import AVFoundation
import Combine

/// Generates metronome click sounds and provides beat timing.
final class Metronome {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var beatCount = 0

    var onBeat: ((_ beat: Int, _ isDownbeat: Bool) -> Void)?

    var isPlaying: Bool { timer != nil }

    func setTempo(_ bpm: Int) {
        stop()
        let interval = 60.0 / Double(bpm)
        beatCount = 0
        let clickData = generateClickData()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let beat = self.beatCount % 4
            self.beatCount += 1
            self.playClick(data: clickData)
            self.onBeat?(beat, beat == 0)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func generateClickData() -> Data {
        let sampleRate: Double = 44100
        let frequency: Double = 1000
        let duration: Double = 0.03
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 120)
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.5)
        }

        // Write as WAV
        var data = Data()
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        let fileSize = UInt32(36 + sampleCount * 2)
        data.append(contentsOf: withUnsafeBytes(of: fileSize) { Data($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let fmtSize: UInt32 = 16
        data.append(contentsOf: withUnsafeBytes(of: fmtSize) { Data($0) })
        let audioFormat: UInt16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: audioFormat) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: channels) { Data($0) })
        let sr = UInt32(sampleRate)
        data.append(contentsOf: withUnsafeBytes(of: sr) { Data($0) })
        let byteRate = UInt32(sampleRate * Double(channels) * Double(bitsPerSample) / 8)
        data.append(contentsOf: withUnsafeBytes(of: byteRate) { Data($0) })
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        data.append(contentsOf: withUnsafeBytes(of: blockAlign) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample) { Data($0) })

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        let dataSize = UInt32(sampleCount * 2)
        data.append(contentsOf: withUnsafeBytes(of: dataSize) { Data($0) })

        // PCM samples as Int16
        for sample in samples {
            var intSample = Int16(clamping: Int(sample * Float(Int16.max)))
            data.append(contentsOf: withUnsafeBytes(of: &intSample) { Data($0) })
        }

        return data
    }

    private func playClick(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 0.8
            audioPlayer?.play()
        } catch {
            // Silently fail — metronome click is non-critical
        }
    }
}
