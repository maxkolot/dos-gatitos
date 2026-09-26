#!/usr/bin/env python3
"""The game's own music, synthesized from scratch (no samples, no third-party tracks → no licensing questions).

  python3 tool/make_music.py OUT_DIR      → casa.mp3 (cozy lo-fi loop), baile.mp3 (cumbia chiptune loop)

Both loop seamlessly: whatever rings past the last bar is folded back onto the beginning.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def note_names(s):
    """'C4 E4 G4' -> midi numbers."""
    base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    out = []
    for tok in s.split():
        n = base[tok[0]]
        rest = tok[1:]
        if rest.startswith('#'):
            n += 1
            rest = rest[1:]
        elif rest.startswith('b'):
            n -= 1
            rest = rest[1:]
        out.append(n + 12 * (int(rest) + 1))
    return out


def env(n, a=0.005, d=1.0, s=0.0, r=0.05):
    """attack/decay-to-sustain envelope of n samples, with a short release at the end."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / max(d, 1e-3)))
    rel = int(r * SR)
    if rel and n > rel:
        e[-rel:] *= np.linspace(1, 0, rel)
    return e


def tone(freq, dur, kind='sine', **kw):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * freq * t
    if kind == 'epiano':  # mellow electric piano: fundamental + soft overtones + slow tremolo
        w = np.sin(ph) + 0.28 * np.sin(2 * ph) * np.exp(-t * 3) + 0.08 * np.sin(3 * ph) * np.exp(-t * 6)
        w *= 1 + 0.06 * np.sin(2 * np.pi * 4.2 * t)
    elif kind == 'tri':
        w = 2 * np.abs(2 * ((freq * t) % 1) - 1) - 1
    elif kind == 'square':
        duty = kw.pop('duty', 0.5)
        w = np.where((freq * t) % 1 < duty, 1.0, -1.0) * 0.6
    else:
        w = np.sin(ph)
    return w * env(n, **kw)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):  # one-pole filter
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def kick(dur=0.35, start=120, end=45):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = end + (start - end) * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def snare(dur=0.22, tone_hz=185):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = noise(dur)
    nz = nz - lowpass(nz, 1200)  # keep the bright part
    return (0.7 * nz * np.exp(-t * 18) + 0.4 * np.sin(2 * np.pi * tone_hz * t) * np.exp(-t * 25))


def hat(dur=0.06):
    nz = noise(dur)
    nz = nz - lowpass(nz, 6000)
    return nz * np.exp(-np.arange(len(nz)) / SR * 70)


class Track:
    def __init__(self, bars, bpm, tail=3.0):
        self.beat = 60 / bpm
        self.length = int(bars * 4 * self.beat * SR)
        self.buf = np.zeros(self.length + int(tail * SR))

    def put(self, sig, at_beat, gain=1.0):
        i = int(at_beat * self.beat * SR)
        j = min(len(self.buf), i + len(sig))
        self.buf[i:j] += sig[: j - i] * gain

    def loop(self):
        out = self.buf[: self.length].copy()
        tail = self.buf[self.length:]
        out[: len(tail)] += tail  # ring-out wraps onto bar 1: seamless loop
        return out


def casa():
    """Cozy lo-fi, 80 bpm, 16 bars."""
    tr = Track(16, 80)
    chords = ['F3 A3 C4 E4', 'E3 G3 B3 D4', 'D3 F3 A3 C4', 'C3 E3 G3 B3']
    bass = ['F2', 'E2', 'D2', 'C2']
    for bar in range(16):
        c = bar // 2 % 4
        notes = note_names(chords[c])
        for k, n in enumerate(notes):  # soft strum
            tr.put(tone(midi(n), 3.2, 'epiano', d=1.4, r=0.3), bar * 4 + 0.02 * k, 0.16)
        if bar % 2 == 1:  # a lighter re-voicing on the second bar
            for k, n in enumerate(notes[1:]):
                tr.put(tone(midi(n + 12), 1.2, 'epiano', d=0.6, r=0.2), bar * 4 + 2.5 + 0.02 * k, 0.07)
        b = note_names(bass[c])[0]
        tr.put(tone(midi(b), 1.4, 'sine', d=0.9, r=0.1), bar * 4, 0.42)
        tr.put(tone(midi(b), 0.9, 'sine', d=0.6, r=0.1), bar * 4 + 2.5, 0.3)
        # drums: kick 1 + a lazy one on the "and" of 3, snare 2 & 4, swung hats
        tr.put(kick(), bar * 4, 0.55)
        tr.put(kick(), bar * 4 + 2.6, 0.35)
        tr.put(snare(), bar * 4 + 1, 0.22)
        tr.put(snare(), bar * 4 + 3, 0.22)
        for e in range(8):
            swing = 0.08 if e % 2 else 0
            tr.put(hat(), bar * 4 + e * 0.5 + swing, 0.07 if e % 2 else 0.1)
    # melody in the second half: C major pentatonic, triangle wave ("pixel" but soft)
    motif = [('E5', 0, 1), ('G5', 1, 0.5), ('A5', 1.5, 1.5), ('G5', 3, 1),
             ('E5', 4, 0.5), ('D5', 4.5, 0.5), ('C5', 5, 2), ('D5', 7, 1),
             ('E5', 8, 1), ('G5', 9, 1), ('C6', 10, 1.5), ('A5', 11.5, 0.5),
             ('G5', 12, 1), ('E5', 13, 1), ('D5', 14, 2)]
    for rep in (8, 12):
        for name, beat, length in motif[: 12 if rep == 8 else len(motif)]:
            n = note_names(name)[0]
            if rep * 4 + beat >= 64:
                continue
            tr.put(tone(midi(n), length * tr.beat * 1.1, 'tri', d=0.5, s=0.35, r=0.12), rep * 4 + beat, 0.09)
    mix = tr.loop()
    mix += noise(len(mix) / SR) * 0.004  # vinyl hiss
    clicks = rng.random(len(mix)) < 0.00003
    mix[clicks] += rng.uniform(-0.25, 0.25, clicks.sum())
    return lowpass(mix, 5200)


def baile():
    """Cumbia-flavoured chiptune, 112 bpm, 8 bars — Sebastián's dance track."""
    tr = Track(8, 112, tail=1.5)
    chords = ['A3 C4 E4', 'F3 A3 C4', 'C4 E4 G4', 'G3 B3 D4']
    bass = ['A2', 'F2', 'C3', 'G2']
    for bar in range(8):
        c = bar % 4
        notes = note_names(chords[c])
        b = note_names(bass[c])[0]
        # cumbia bass: 1 and 3 with a pickup
        tr.put(tone(midi(b), 0.35, 'square', duty=0.5, d=0.25, r=0.05), bar * 4, 0.2)
        tr.put(tone(midi(b + 7), 0.3, 'square', duty=0.5, d=0.2, r=0.05), bar * 4 + 2, 0.18)
        tr.put(tone(midi(b), 0.2, 'square', duty=0.5, d=0.15, r=0.03), bar * 4 + 3.5, 0.14)
        # chip arpeggio in 8ths
        arp = notes + [notes[1] + 12, notes[2] + 12, notes[1] + 12, notes[0] + 12, notes[2]]
        for e in range(8):
            tr.put(tone(midi(arp[e % len(arp)] + 12), 0.2, 'square', duty=0.25, d=0.12, r=0.03), bar * 4 + e * 0.5, 0.05)
        # percussion: kick 1 & 3, rim/snare on the upbeats, güiro "ch-ch-chk"
        tr.put(kick(0.25, 140, 55), bar * 4, 0.5)
        tr.put(kick(0.25, 140, 55), bar * 4 + 2, 0.5)
        for up in (1, 3):
            tr.put(snare(0.12, 320), bar * 4 + up, 0.2)
        for e in range(8):
            g = noise(0.09 if e % 2 == 0 else 0.05)
            g = (g - lowpass(g, 3000)) * np.linspace(1, 0.2, len(g))
            tr.put(g, bar * 4 + e * 0.5, 0.08 if e % 2 == 0 else 0.05)
    melody = [('E5', 0, 1), ('A5', 1, 1), ('G5', 2, 0.5), ('E5', 2.5, 1.5),
              ('C5', 4, 1), ('F5', 5, 1), ('E5', 6, 0.5), ('C5', 6.5, 1.5),
              ('E5', 8, 0.5), ('G5', 8.5, 0.5), ('C6', 9, 1), ('B5', 10, 0.5), ('G5', 10.5, 1.5),
              ('D5', 12, 1), ('G5', 13, 1), ('F#5', 14, 0.5), ('D5', 14.5, 1.5)]
    for rep in (0, 16):
        for name, beat, length in melody:
            n = note_names(name)[0]
            tr.put(tone(midi(n), length * tr.beat, 'square', duty=0.5, d=0.4, s=0.4, r=0.05), rep + beat, 0.06)
    return lowpass(tr.loop(), 7000)


def write(path, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    wav = path[:-4] + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libmp3lame', '-b:a', '96k', path], check=True)
    os.remove(wav)
    print(path, round(len(x) / SR, 1), 's', os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/audio'
    os.makedirs(out, exist_ok=True)
    write(os.path.join(out, 'casa.mp3'), casa())
    write(os.path.join(out, 'baile.mp3'), baile())
