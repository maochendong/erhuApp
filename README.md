#  Erhu Trainer

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-18.0+-000000?logo=apple)](https://developer.apple.com/ios)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

**An intelligent erhu practice companion — real-time pitch detection, jianpu sheet music, and CD-quality sample playback.**

> Built for learners who want precise intonation feedback without a teacher looking over their shoulder.

---

## Overview

盼盼学二胡 bridges traditional Chinese instrument practice with modern audio DSP. The app listens to the player through the microphone, runs a YIN pitch-detection algorithm in real time, and compares each note against the sheet music to give instant cent-accuracy feedback. A built-in preview engine plays each score using **43 CD-quality single-note erhu samples** extracted from a professional recording, so learners hear authentic timbre before they play.

---

## Features

### 🎵 Jianpu Rendering
Canvas-based numbered musical notation (简谱) with octave dots, bar lines, and articulations — rendered entirely in SwiftUI without a third-party dependency.

### 🎯 Real-Time Pitch Detection
- **YIN algorithm** (de Cheveigné & Kawahara, 2002) with sub-sample parabolic interpolation
- Octave-error correction tuned for erhu harmonic profiles
- Portamento (滑音) smoothing — 40 ms stability gate prevents false triggers during slides
- Configurable detection range: D3 (146 Hz) – A6 (1760 Hz) covering the full erhu register

### 🔊 Sample-Based Preview
- **43 WAV samples** extracted offline from a 466 MB CD-quality recording — one per semitone from C4 to Bb5
- Per-note round-robin selection with 30 ms fade envelopes for natural transitions
- Nearest-match pitch shifting (< 100 cents) for notes outside the sampled range
- Dedicated high-quality playback of *赛马* (Horse Racing) full recording

### 📊 Intonation Grading
- Cent-level deviation display (±0–30 cents = in tune)
- Per-session accuracy tracking with average cent error
- Visual feedback — correct notes glow green, miscues flash red, real-time cursor follows the player

### 📚 Built-in Score Library
Classic erhu pieces including 赛马, 二泉映月, 良宵, and more, each with tempo metadata and full jianpu notation data.

---

## Architecture

```
ErhuApp/
├── Audio/
│   ├── AudioEngine.swift       # YIN pitch detection + AVAudioEngine tap
│   ├── ErhuSamplePlayer.swift  # Sample library loader & WAV playback
│   ├── NotePlayer.swift        # Additive synthesis fallback
│   └── Metronome.swift         # Tempo-reference clicks
├── Models/                     # Note, Score, Lesson data model
├── Services/
│   ├── PitchJudger.swift       # Frequency-to-note comparison & grading
│   ├── ScoreService.swift      # Score library CRUD
│   ├── RecordingService.swift  # Session persistence + Core Data
│   └── JianpuParser.swift      # Plain-text jianpu → score model
├── Views/                      # SwiftUI screens (13 screens)
└── Resources/
    ├── Notes/                  # 43 single-note WAV samples
    └── 赛马 recording.mp3
```

### DSP Pipeline

```
Mic → [FFT RMS gate] → [YIN autocorrelation] → [Parabolic interpolation]
  → [Portamento smooth] → [Frequency → note/octave/cents]
  → PitchJudger.compare(targetNote) → Judgment { isCorrect, centsOff }
```

---

## Getting Started

### Prerequisites
- Xcode 16.0+
- iOS 18.0+ simulator or device

### Build & Run

```bash
git clone https://github.com/maochendong/erhuApp.git
cd erhuApp
xcodebuild -scheme ErhuApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or open `ErhuApp.xcodeproj` in Xcode and press **⌘R**.

---

## Technical Highlights

| Component | Technique | Why |
|-----------|-----------|-----|
| Pitch detection | YIN + parabolic interpolation | Sub-cent accuracy with O(n) complexity |
| Octave correction | Multi-candidate CMND dip scoring | Erhu's strong 2nd harmonic confuses naive YIN |
| Portamento handling | 40 cent stability gate over 80 ms window | Natural 滑音 without fragmenting detection |
| Audio preview | Per-note sample + AVAudioUnitTimePitch | Authentic timbre vs. additive synthesis |
| Sample extraction | RMS segmentation → autocorrelation → pitch labeling | 43 clean samples from 46 min of raw audio |
| Sheet rendering | Canvas-based bar layout engine | Full control over jianpu conventions |

---

## Sample Extraction Pipeline

The companion script at `scripts/extract_erhu_samples.py` processes a 466 MB, 46‑minute CD recording into individual note WAVs:

1. **RMS segmentation** — slides a 2048-sample window, detects onset/offset boundaries
2. **Pitch detection** — autocorrelation on each segment → label by nearest semitone
3. **Quality filter** — rejects segments with unstable pitch or excessive noise
4. **Truncation & fade** — 0.5 s steady-state with 3 ms crossfade, saved as 16‑bit 44.1 kHz mono WAV
5. **Deduplication** — 2 best SNR samples per pitch class — 43 total from ~340 candidate segments

---

## License

MIT

---

*Built with Swift 6, SwiftUI, and Accelerate framework.*
