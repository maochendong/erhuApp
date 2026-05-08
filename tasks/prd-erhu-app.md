# PRD: 二胡识谱 (Erhu Score Trainer) - Remaining Work

## Introduction

二胡识谱 is an iOS SwiftUI app that helps erhu learners practice score reading and pitch accuracy. Phase 1 (project scaffolding, data models, basic UI, audio engine prototype, built-in scores) is complete. This PRD covers all remaining work to make the app production-ready, organized into phases.

## Phase 1: Core Functionality (MVP)

The app must be buildable, and the core practice loop must work: select a score → play with erhu → see real-time pitch feedback → review accuracy.

## Phase 2: Enhanced Features

Advanced practice tools, user progress tracking, and content expansion.

## Phase 3: Polish & Platform

iPad adaptation, onboarding, and production readiness.

---

## Phase 1 User Stories

### US-001: Xcode project configuration
**Description:** As a developer, I want a proper Xcode project setup so the app can be built and run on iOS Simulator.

**Acceptance Criteria:**
- [ ] Create .xcodeproj or configure Package.swift for proper iOS building
- [ ] All Swift source files compile without errors
- [ ] Info.plist correctly configured (microphone permission, display name, etc.)
- [ ] App launches on iOS 18+ Simulator
- [ ] Audio permission prompt appears on first launch

### US-002: YIN pitch detection algorithm
**Description:** As a user, I want accurate pitch detection so the app correctly recognizes notes I play on erhu.

**Acceptance Criteria:**
- [ ] Replace autocorrelation with YIN algorithm in AudioEngine
- [ ] YIN threshold parameter configurable (default 0.15)
- [ ] Detect fundamental frequency range C3-C7 (65Hz-2093Hz)
- [ ] Note detection latency under 100ms
- [ ] Accurate within ±20 cents for sustained notes
- [ ] Handle erhu's portamento (滑音) gracefully - no false triggers during slides
- [ ] Typecheck passes

### US-003: Real-time score follower
**Description:** As a user, I want the score display to follow my playing in real time so I know where I am in the piece.

**Acceptance Criteria:**
- [ ] Current note highlights in real time as user plays
- [ ] Score follower advances note-by-note when correct pitch is detected
- [ ] Follower pauses when no audio input detected (user stops playing)
- [ ] Follower skips rest notes automatically (no need to play them)
- [ ] Visual indicator shows when follower is "listening" vs "waiting"
- [ ] Typecheck passes

### US-004: Real-time audio visual feedback
**Description:** As a user, I want immediate visual feedback on pitch accuracy so I can correct my intonation while playing.

**Acceptance Criteria:**
- [ ] Each note judged immediately: green (correct), red (wrong), orange (close but off)
- [ ] Arrow indicators: ↑ for sharp, ↓ for flat
- [ ] Cents deviation display (e.g., "+23¢")
- [ ] Frequency display (e.g., "440.0 Hz")
- [ ] Note name display in jianpu format
- [ ] Smooth color transitions (not jarring)
- [ ] Typecheck passes

### US-005: Performance summary
**Description:** As a user, I want to see my performance summary after finishing a practice session.

**Acceptance Criteria:**
- [ ] Summary screen shows: total notes, correct count, accuracy percentage
- [ ] Breakdown by note degree (which notes were most/least accurate)
- [ ] Option to retry or choose another score
- [ ] Typecheck passes

---

## Phase 2 User Stories

### US-006: Jianpu text parser
**Description:** As a user, I want to import scores from plain text jianpu notation.

**Acceptance Criteria:**
- [ ] Parse jianpu text format: numbers 1-7, 0 for rest, dots for octaves, spaces as separators
- [ ] Support duration markers (e.g., "5-" for half note, "5_" for double)
- [ ] Support bar lines ("|") to separate measures
- [ ] Produce valid Score object from parsed text
- [ ] Show parse errors with line numbers
- [ ] Typecheck passes

### US-007: Score editor UI
**Description:** As a user, I want to create and edit scores directly in the app.

**Acceptance Criteria:**
- [ ] Text input field for jianpu notation
- [ ] Preview of parsed score
- [ ] Save custom score to local library
- [ ] Edit existing scores
- [ ] Delete custom scores
- [ ] Typecheck passes

### US-008: A/B loop practice
**Description:** As a user, I want to loop a specific section of a score so I can practice difficult passages.

**Acceptance Criteria:**
- [ ] Long-press on score to set loop start (A) and end (B) markers
- [ ] Loop playback repeats section A-B
- [ ] Visual highlight shows loop region
- [ ] Option to play loop N times then continue
- [ ] Typecheck passes

### US-009: Tempo control and metronome
**Description:** As a user, I want to control practice tempo and use a metronome.

**Acceptance Criteria:**
- [ ] Tempo slider (40-200 BPM) adjustable before/during practice
- [ ] Metronome click track plays at current tempo
- [ ] Metronome visual flash on beat 1
- [ ] Typecheck passes

### US-010: Practice recording
**Description:** As a user, I want to record my practice session audio.

**Acceptance Criteria:**
- [ ] Start/stop recording button in practice view
- [ ] Audio saved to app documents directory
- [ ] Recording metadata: date, score, duration
- [ ] Typecheck passes

### US-011: Playback comparison
**Description:** As a user, I want to play back my recording alongside the score.

**Acceptance Criteria:**
- [ ] Recording list view sorted by date
- [ ] Playback with synchronized score highlighting
- [ ] Previous judgment data shown during playback
- [ ] Delete recordings
- [ ] Typecheck passes

### US-012: Core Data persistence
**Description:** As a developer, I want practice records persisted so users can track progress over time.

**Acceptance Criteria:**
- [ ] Core Data model for PracticeRecord: date, scoreId, accuracy, duration
- [ ] NoteDetail entity: noteIndex, degree, wasCorrect, centsOff
- [ ] Save practice session results automatically
- [ ] Migrate from in-memory to Core Data
- [ ] Typecheck passes

### US-013: Progress charts
**Description:** As a user, I want to see my accuracy trends over time.

**Acceptance Criteria:**
- [ ] Chart showing accuracy % per session (last 7/30/all)
- [ ] Chart showing accuracy by note degree
- [ ] Streak counter (consecutive practice days)
- [ ] Swift Charts framework usage for native look
- [ ] Typecheck passes

### US-014: Daily practice check-in
**Description:** As a user, I want daily practice reminders and streak tracking.

**Acceptance Criteria:**
- [ ] Local notification for daily practice reminder
- [ ] Check-in button on first open each day
- [ ] Calendar view showing practice days
- [ ] Typecheck passes

### US-015: Extended score library
**Description:** As a user, I want more erhu pieces to practice organized by difficulty.

**Acceptance Criteria:**
- [ ] Add scores: 二泉映月, 良宵, 空山鸟语, 光明行, 江河水, 月夜
- [ ] Difficulty filter (入门/初级/中级/高级)
- [ ] Search by title and composer
- [ ] Favorites/bookmark system
- [ ] Typecheck passes

---

## Phase 3 User Stories

### US-016: iPad and landscape layout
**Description:** As a user, I want to use the app on iPad and in landscape orientation.

**Acceptance Criteria:**
- [ ] Adaptive layout: compact (iPhone portrait) vs regular (iPad/landscape)
- [ ] Score view shows 2 measures side-by-side on iPad
- [ ] All views properly laid out in landscape
- [ ] Typecheck passes

### US-017: Onboarding flow
**Description:** As a new user, I want a guided introduction to the app's features.

**Acceptance Criteria:**
- [ ] 3-5 screen onboarding on first launch
- [ ] Explains: how to read jianpu, how to practice, how to read feedback
- [ ] "Skip" button available
- [ ] Only shows once (UserDefaults flag)
- [ ] Typecheck passes

---

## Functional Requirements (Summary)

- FR-1: YIN algorithm for pitch detection (replaces autocorrelation)
- FR-2: Real-time score following with highlight sync
- FR-3: Real-time pitch accuracy feedback (green/red/orange + cents)
- FR-4: Jianpu text import and parsing
- FR-5: A/B loop practice with repeat count
- FR-6: Metronome sync to score tempo
- FR-7: Practice session audio recording and storage
- FR-8: Playback review with synchronized score
- FR-9: Core Data persistence for practice records
- FR-10: Progress charts with Swift Charts
- FR-11: Daily streak and notification reminders
- FR-12: Extended score library (12+ pieces)
- FR-13: iPad and landscape adaptive layout
- FR-14: Onboarding tutorial flow

## Non-Goals

- No cloud sync or user accounts (Phase 1-3)
- No AI-powered teaching assistant
- No musicXML import (jianpu text only)
- No sheet music rendering (MIDI export)
- No social/community features
- No Android version

## Technical Considerations

- Swift 6+, iOS 18+ minimum deployment target
- AudioKit not used (custom YIN implementation with AVFAudio + Accelerate)
- Swift Charts for progress visualization
- Core Data for persistence (not CloudKit initially)
- Package.swift based project, open via Xcode
- YIN algorithm: implement in pure Swift with Accelerate FFT

## Success Metrics

- Pitch detection accuracy: ≥95% for sustained notes on erhu
- Score follower latency: ≤200ms from note onset to advance
- App launches without crashes on iPhone 15+ (iOS 18+)
- User can complete a full practice session (select score → play → see results)

## Open Questions

- Should recordings be stored as audio files or just pitch data?
- What YIN threshold works best for erhu's timbre? Needs empirical testing.
- Should we support Apple Pencil for score annotation on iPad?

