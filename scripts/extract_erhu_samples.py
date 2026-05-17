#!/usr/bin/env python3
"""
Two-pass note extraction from CDImage.wav.

Phase 1 - RMS segmentation (fast, no pitch detection per window):
  Slide through file, find loud/quiet transitions, build segment list.

Phase 2 - Pitch detection + extraction:
  For each segment >280ms, extract audio, run autocorrelation ONCE to
  determine pitch, name, and save as a clean mono WAV sample.

Total autocorrelation calls: ~200-300 instead of 30,000.
"""

import wave
import struct
import math
import os
import sys
from collections import defaultdict

SAMPLE_RATE = 44100
WINDOW_SIZE = 2048
HOP_SIZE = 2048          # ~46ms hops
RMS_THRESHOLD = 0.02
MIN_SEGMENT_WINDOWS = 6  # ~280ms minimum segment
SILENCE_GAP_WINDOWS = 4  # ~184ms silence to end a segment
SAMPLE_SECS = 0.5
FADE_MS = 3

NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
ALL_NOTES = {}
for octave in range(2, 7):
    for i, name in enumerate(NOTE_NAMES):
        st = i - 9 + (octave - 4) * 12
        ALL_NOTES[f"{name}{octave}"] = 440.0 * (2.0 ** (st / 12.0))


def freq_to_note(freq):
    if freq <= 0:
        return None
    best_n, best_c = None, 999.0
    for n, f in ALL_NOTES.items():
        if f < 80:
            continue
        c = abs(1200.0 * math.log2(freq / f))
        if c < best_c:
            best_c = c
            best_n = n
    return best_n


def detect_pitch(samples):
    n = len(samples)
    min_lag = max(int(SAMPLE_RATE / 1200), 4)
    max_lag = min(int(SAMPLE_RATE / 60), n // 2)
    if max_lag <= min_lag:
        return 0.0
    best_lag, best_corr = 0, 0.0
    for lag in range(min_lag, max_lag):
        corr = 0.0
        power = 0.0
        limit = n - lag
        for i in range(limit):
            s = samples[i]
            sl = samples[i + lag]
            corr += s * sl
            power += s * s + sl * sl
        norm = power * 0.5
        if norm > 1e-10:
            corr /= norm
        if corr > best_corr:
            best_corr = corr
            best_lag = lag
    if best_corr < 0.15:
        return 0.0
    return SAMPLE_RATE / best_lag


def rms(samples):
    if not samples:
        return 0.0
    return math.sqrt(sum(s * s for s in samples) / len(samples))


def stereo_to_mono(raw):
    count = len(raw) // 4
    out = [0.0] * count
    for i in range(count):
        off = i * 4
        l = struct.unpack_from('<h', raw, off)[0]
        r = struct.unpack_from('<h', raw, off + 2)[0]
        out[i] = (l + r) / 65536.0
    return out


def extract_audio(wf, start_frame, num_frames):
    """Read frames from WAV and return mono float samples."""
    wf.setpos(start_frame)
    raw = wf.readframes(min(num_frames, wf.getnframes() - start_frame))
    return stereo_to_mono(raw)


def write_wav(path, samples, rate):
    data_size = len(samples) * 2
    with open(path, 'wb') as f:
        f.write(b'RIFF')
        f.write(struct.pack('<I', 36 + data_size))
        f.write(b'WAVE')
        f.write(b'fmt ')
        f.write(struct.pack('<IHHIIHH', 16, 1, 1, rate, rate * 2, 2, 16))
        f.write(b'data')
        f.write(struct.pack('<I', data_size))
        for s in samples:
            f.write(struct.pack('<h', max(-32768, min(32767, int(s * 32767)))))


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    input_path = os.path.join(base, "Sources", "ErhuApp", "Resources", "CDImage.wav")
    output_dir = os.path.join(base, "Sources", "ErhuApp", "Resources", "Notes")
    os.makedirs(output_dir, exist_ok=True)

    print(f"CDImage.wav: {os.path.getsize(input_path) / 1024 / 1024:.0f} MB", flush=True)
    print(f"Output: {output_dir}", flush=True)

    # ── Phase 1: Fast RMS segmentation ──
    print("Phase 1: RMS segmentation...", flush=True)
    wf = wave.open(input_path, 'rb')
    total_frames = wf.getnframes()
    total_windows = total_frames // HOP_SIZE

    is_active = False
    seg_start_frame = 0
    silence_counter = 0
    segments = []  # [(start_frame, end_frame)]

    frame = 0
    wc = 0
    while frame < total_frames:
        want = min(WINDOW_SIZE, total_frames - frame)
        raw = wf.readframes(want)
        if not raw:
            break
        wc += 1
        if wc % 10000 == 0:
            pct = min(wc * 100 // total_windows, 100)
            print(f"  Phase 1: {pct}% ({wc}/{total_windows})", flush=True)

        samples = stereo_to_mono(raw)
        rm = rms(samples)

        if rm > RMS_THRESHOLD:
            if not is_active:
                is_active = True
                seg_start_frame = frame
                silence_counter = 0
            else:
                silence_counter = max(0, silence_counter - 1)
        else:
            if is_active:
                silence_counter += 1
                if silence_counter >= SILENCE_GAP_WINDOWS:
                    seg_end = frame - silence_counter * HOP_SIZE
                    if seg_end - seg_start_frame >= MIN_SEGMENT_WINDOWS * HOP_SIZE:
                        segments.append((seg_start_frame, seg_end))
                    is_active = False
                    silence_counter = 0

        frame += want

    # Handle segment at end of file
    if is_active and frame - seg_start_frame >= MIN_SEGMENT_WINDOWS * HOP_SIZE:
        segments.append((seg_start_frame, frame))

    wf.close()
    print(f"Phase 1 done: {len(segments)} segments found", flush=True)

    # ── Phase 2: Pitch detection + extraction ──
    print(f"\nPhase 2: Pitch detection & extraction...", flush=True)
    wf = wave.open(input_path, 'rb')
    candidates = defaultdict(list)

    for sidx, (start_f, end_f) in enumerate(segments):
        if sidx % 20 == 0:
            print(f"  Phase 2: {sidx}/{len(segments)}", flush=True)

        mid_f = (start_f + end_f) // 2
        # Extract audio from middle portion for pitch detection
        analysis_frames = int(SAMPLE_RATE * 0.15)
        samples = extract_audio(wf, mid_f, analysis_frames)
        if not samples:
            continue

        pitch = detect_pitch(samples)
        if pitch < 80:
            continue

        note_name = freq_to_note(pitch)
        if not note_name:
            continue

        # Skip notes outside erhu range (C4 - C6)
        try:
            octave = int(note_name[-1])
            if octave < 4 or octave > 5:
                continue
        except ValueError:
            continue

        # Extract clean sample from middle of segment
        seg_len = end_f - start_f
        extract_frames = min(int(SAMPLE_RATE * SAMPLE_SECS), seg_len)
        take_start = start_f + (seg_len - extract_frames) // 2
        extract = extract_audio(wf, take_start, extract_frames)

        # Compute RMS and estimate pitch stability
        seg_rms = rms(extract)

        # Pitch verification: detect pitch on extracted sample too
        ver_pitch = detect_pitch(extract[:min(len(extract), int(SAMPLE_RATE * 0.2))])
        if ver_pitch > 0:
            pitch_dev = abs(1200 * math.log2(ver_pitch / pitch))
            if pitch_dev > 50:  # unstable pitch → skip (likely ornament)
                continue

        candidates[note_name].append({
            'samples': extract,
            'rms': seg_rms,
            'duration': len(extract) / SAMPLE_RATE,
            'pitch': pitch,
        })

    wf.close()

    print(f"\nDetected {sum(len(v) for v in candidates.values())} across "
          f"{len(candidates)} notes", flush=True)
    detected = sorted(candidates.keys())
    print(f"Notes: {', '.join(detected)}", flush=True)

    # ── Phase 3: Save best 2 per note ──
    print(f"\nPhase 3: Saving samples...", flush=True)
    saved = 0
    for note_name in sorted(candidates.keys()):
        segs = candidates[note_name]
        segs.sort(key=lambda s: s['rms'], reverse=True)

        for idx, seg in enumerate(segs[:2]):
            if len(seg['samples']) < SAMPLE_RATE * 0.15:
                continue

            # Apply fade
            samples_out = seg['samples'][:]
            fade_n = int(FADE_MS * SAMPLE_RATE / 1000)
            for i in range(min(fade_n, len(samples_out))):
                e = i / fade_n
                samples_out[i] *= e
                samples_out[-(i + 1)] *= e

            suffix = f"_{idx + 1}" if idx > 0 else ""
            out_name = f"{note_name}{suffix}.wav"
            write_wav(os.path.join(output_dir, out_name), samples_out, SAMPLE_RATE)
            print(f"  {out_name}: {seg['duration']:.2f}s RMS={seg['rms']:.3f}", flush=True)
            saved += 1

    print(f"\nDone! {saved} samples → {output_dir}", flush=True)
    print(f"Bundle size: ~{saved * 44} KB", flush=True)


if __name__ == "__main__":
    main()
