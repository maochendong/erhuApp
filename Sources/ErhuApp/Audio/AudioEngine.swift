import AVFoundation
import Accelerate
import Observation

/// Manages microphone input and audio processing
@Observable
final class AudioEngine {
    let engine = AVAudioEngine()
    var isListening = false
    var currentFrequency: Double = 0
    var currentNote: Int = 0
    var currentOctave: Int = 0
    var amplitude: Float = 0

    private let fftSize = 4096
    private let sampleRate: Double = 44100

    func start() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
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
            return
        }

        if let freq = detectPitch(samples) {
            currentFrequency = freq
            let (note, octave) = frequencyToNote(freq)
            currentNote = note
            currentOctave = octave
        }
    }

    /// Autocorrelation-based pitch detection
    private func detectPitch(_ samples: [Float]) -> Double? {
        let count = samples.count
        var correlation = [Float](repeating: 0, count: count)

        vDSP_conv(samples, 1, samples, 1, &correlation, 1, vDSP_Length(count), vDSP_Length(count))

        let minLag = Int(sampleRate / 2000)
        let maxLag = Int(sampleRate / 65)

        guard maxLag < count else { return nil }

        var maxVal: Float = 0
        var maxIdx = minLag

        for i in minLag..<maxLag {
            if correlation[i] > maxVal {
                maxVal = correlation[i]
                maxIdx = i
            }
        }

        guard maxVal > 0.1 else { return nil }

        if maxIdx > 0 && maxIdx < count - 1 {
            let a = correlation[maxIdx - 1]
            let b = correlation[maxIdx]
            let c = correlation[maxIdx + 1]
            let delta = (a - c) / (2 * (a - 2 * b + c))
            return sampleRate / (Double(maxIdx) + Double(delta))
        }

        return sampleRate / Double(maxIdx)
    }

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
