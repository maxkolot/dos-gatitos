#!/usr/bin/env python3
"""The game's sound effects, synthesized from scratch (no samples → no licensing questions).

  python3 tool/make_sfx.py OUT_DIR      → OUT_DIR/<name>.mp3 for every sound below

Needs numpy + scipy + ffmpeg. Loops (sizzle, crackle, night) are made seamless.
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(11)


# ---------------------------------------------------------------- building blocks

def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype='band', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def lp(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, btype='low', fs=SR, output='sos'), x)


def hp(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, btype='high', fs=SR, output='sos'), x)


def reson(x, hz, q=12):
    """A resonant peak (a body that rings: glass, wood, a pan)."""
    b, a = signal.iirpeak(hz, q, fs=SR)
    return signal.lfilter(b, a, x)


def decay(n, tau, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(attack * SR)
    if a:
        e[:a] *= np.linspace(0, 1, a)
    return e


def adsr(n, a=0.01, r=0.05):
    e = np.ones(n)
    ai, ri = int(a * SR), int(r * SR)
    if ai:
        e[:ai] = np.linspace(0, 1, ai)
    if ri and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def sweep(f0, f1, dur, curve='exp'):
    """Phase of a tone gliding from f0 to f1."""
    n = int(dur * SR)
    f = np.geomspace(f0, f1, n) if curve == 'exp' else np.linspace(f0, f1, n)
    return 2 * np.pi * np.cumsum(f) / SR


def partials(freqs, amps, taus, dur, detune=0.0):
    t = t_of(dur)
    x = np.zeros_like(t)
    for f, a, tau in zip(freqs, amps, taus):
        f2 = f * (1 + detune * rng.uniform(-1, 1))
        x += a * np.sin(2 * np.pi * f2 * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    return x * adsr(len(x), 0, 0.04)  # no click where the ringing is cut


def mix(dur, *parts):
    """parts: (signal, at_seconds, gain)."""
    out = np.zeros(int(dur * SR))
    for sig, at, g in parts:
        i = int(at * SR)
        if i >= len(out):
            continue
        n = min(len(sig), len(out) - i)
        out[i:i + n] += g * sig[:n]
    return out


def room(x, size=0.25, wet=0.18, tone=5000):
    """A small warm room: a decaying noise impulse response."""
    n = int(size * 2.5 * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / size)
    ir = lp(ir, tone)
    ir /= np.sqrt(np.sum(ir ** 2))
    tail = np.zeros(len(x) + n)
    conv = signal.fftconvolve(x, ir)
    tail[:len(conv)] = conv[:len(tail)]
    dry = np.concatenate([x, np.zeros(n)])
    return dry + wet * tail


def grains(dur, rate, lo, hi, tau=0.003, amp=(0.2, 1.0), envelope=None):
    """Tiny clicks at random times: crumbs, crackles, sprinkles, fur."""
    n = int(dur * SR)
    x = np.zeros(n)
    count = rng.poisson(rate * dur)
    ln = int(tau * 8 * SR)
    shape = np.exp(-np.arange(ln) / SR / tau)
    for _ in range(count):
        i = rng.integers(0, max(1, n - ln))
        g = rng.uniform(*amp)
        if envelope is not None:
            g *= envelope[i]
        x[i:i + ln] += g * rng.standard_normal(ln) * shape
    return band(x, lo, hi)


def fit(x, peak=0.9):
    m = np.max(np.abs(x))
    return x if m == 0 else x * (peak / m)


def fades(x, a=0.003, r=0.02):
    return x * adsr(len(x), a, r)


def seamless(x, xf=0.4):
    """A loop: the tail crossfades into the head."""
    n = int(xf * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    k = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - k) + head * k, body])


# ---------------------------------------------------------------- UI

def ui_tap():
    d = 0.09
    x = np.sin(sweep(1100, 520, d)) * decay(int(d * SR), 0.018)
    x += 0.3 * band(noise(d), 2500, 6000) * decay(int(d * SR), 0.004)
    return room(x, 0.08, 0.1)


def marimba(freq, dur=0.6):
    return partials([freq, freq * 3.93, freq * 9.2], [1, 0.25, 0.06], [dur / 3, dur / 12, dur / 30], dur)


def ui_open():
    return room(mix(0.8, (marimba(784), 0, 0.8), (marimba(1175), 0.08, 0.8)), 0.3, 0.2)


def ui_close():
    return room(mix(0.8, (marimba(1175), 0, 0.7), (marimba(784), 0.08, 0.7)), 0.3, 0.2)


def glock(freq, dur=1.2):
    return partials([freq, freq * 2.76, freq * 5.4], [1, 0.35, 0.12], [dur / 3, dur / 8, dur / 16], dur)


def sparkle():
    notes = [1568, 1976, 2349, 3136, 3951]
    parts = [(glock(f, 1.0), i * 0.055, 0.5 - i * 0.05) for i, f in enumerate(notes)]
    shimmer = grains(1.4, 50, 5000, 12000, tau=0.002, amp=(0.05, 0.25), envelope=decay(int(1.4 * SR), 0.5))
    return room(mix(1.5, *parts, (shimmer, 0, 0.5)), 0.5, 0.3, 8000)


def wish():
    return room(mix(1.4, (glock(1319, 1.2), 0, 0.7), (glock(1760, 1.2), 0.16, 0.7)), 0.5, 0.3)


def heart_pop():
    d = 0.16
    x = np.sin(sweep(500, 1400, d)) * decay(int(d * SR), 0.03)
    return room(x, 0.15, 0.2)


def voice(base, syllables, seed):
    """Gibberish talk blips (Animal-Crossing style): a few formant-shaped syllables."""
    r = np.random.default_rng(seed)
    parts, at = [], 0.0
    for _ in range(syllables):
        d = r.uniform(0.06, 0.1)
        f = base * r.choice([1, 1.12, 1.26, 0.89, 1.5])
        ph = sweep(f, f * r.uniform(0.85, 1.15), d)
        tone = np.sign(np.sin(ph)) * 0.5 + np.sin(ph)  # hollow squarish, like a toy voice
        vowel = r.choice([700, 1100, 1800, 2400])
        s = reson(tone, vowel, 3) * 0.6 + lp(tone, 1400) * 0.5
        parts.append((s * adsr(len(s), 0.006, 0.025), at, 1))
        at += d + r.uniform(0.015, 0.04)
    return room(lp(mix(at + 0.05, *parts), 5000), 0.1, 0.12)


# ---------------------------------------------------------------- cooking

def egg_dip():
    """The cutlet goes through the beaten egg: a wet squelch and drips."""
    d = 1.0
    squelch = band(noise(0.35), 250, 1400) * decay(int(0.35 * SR), 0.09, 0.03)
    squelch = reson(squelch, 600, 4) * 0.5 + squelch
    drips = []
    for i, at in enumerate([0.45, 0.62, 0.81]):
        dd = 0.07
        drips.append((np.sin(sweep(700 + 150 * i, 1500 + 200 * i, dd)) * decay(int(dd * SR), 0.018), at, 0.35))
    return room(mix(d, (squelch, 0, 1), *drips), 0.12, 0.15)


def breadcrumbs():
    """Pressing the cutlet into breadcrumbs: dry crunchy pats, crumbs rattling."""
    d = 1.4
    parts = []
    for at in [0.0, 0.42, 0.84]:
        pd = 0.36
        env = decay(int(pd * SR), 0.1, 0.015)
        crunch = grains(pd, 900, 1500, 9000, tau=0.0012, amp=(0.2, 1), envelope=env)
        thump = lp(noise(pd), 300) * decay(int(pd * SR), 0.03)
        parts += [(crunch, at, 1), (thump, at, 0.5)]
    trickle = grains(d, 120, 3000, 10000, tau=0.001, amp=(0.05, 0.3), envelope=np.linspace(0.3, 1, int(d * SR)))
    return room(mix(d, *parts, (trickle, 0, 0.4)), 0.12, 0.12)


def sizzle_body(dur, pops=6.0):
    base = hp(noise(dur), 2500) * 0.35 + band(noise(dur), 5000, 12000) * 0.25
    wobble = 0.75 + 0.25 * lp(rng.standard_normal(int(dur * SR)), 3) * 30
    crackle = grains(dur, 260, 2000, 11000, tau=0.0008, amp=(0.1, 0.9))
    oil = grains(dur, pops, 800, 5000, tau=0.006, amp=(0.5, 1.2))
    return base * np.clip(wobble, 0.3, 1.2) + crackle * 1.2 + oil * 1.4


def sizzle():
    return seamless(sizzle_body(4.4), 0.4)


def sizzle_in():
    """The cutlet hits the hot oil: a loud hiss that settles."""
    d = 1.6
    x = sizzle_body(d, 14)
    env = np.minimum(1, np.arange(int(d * SR)) / SR / 0.04) * (0.45 + 0.55 * np.exp(-np.arange(int(d * SR)) / SR / 0.4))
    splash = band(noise(0.2), 400, 3000) * decay(int(0.2 * SR), 0.04)
    return mix(d, (x * env, 0, 1), (splash, 0, 0.6))


def pan_ring(freq=820, dur=0.8):
    return partials([freq, freq * 2.17, freq * 3.6, freq * 5.1], [1, 0.6, 0.35, 0.2], [0.25, 0.15, 0.08, 0.05], dur, 0.01)


def spatula():
    """Metal spatula scraping the pan, then a tap on the edge."""
    d = 0.9
    scrape = band(noise(0.45), 1800, 7000)
    scrape = reson(scrape, 3200, 8) + scrape * 0.4
    scrape *= adsr(len(scrape), 0.05, 0.12) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t_of(0.45)))
    return room(mix(d, (scrape, 0, 0.5), (pan_ring(), 0.5, 0.5)), 0.15, 0.2)


def whoosh(d=0.45, lo=300, hi=2500):
    x = noise(d)
    n = len(x)
    out = np.zeros(n)
    steps = 12
    for i in range(steps):  # a band sweeping up and back
        k = i / (steps - 1)
        f = lo * (hi / lo) ** np.sin(k * np.pi / 2 + 0.2)
        seg = slice(i * n // steps, (i + 1) * n // steps)
        out[seg] = band(x, f * 0.7, f * 1.4)[seg]
    return out * np.sin(np.linspace(0, np.pi, n)) ** 1.5


def flip():
    """The milanesa flies up out of the pan and lands back with a splash of oil."""
    d = 1.3
    land = sizzle_body(0.6, 20) * decay(int(0.6 * SR), 0.2)
    return mix(d, (whoosh(0.5, 400, 3000), 0, 0.7), (pan_ring(760, 0.6), 0.62, 0.35), (land, 0.62, 0.9))


def ceramic(freq=1900, dur=0.7):
    return partials([freq, freq * 2.32, freq * 3.9, freq * 5.6], [1, 0.5, 0.3, 0.15], [0.18, 0.1, 0.05, 0.03], dur, 0.004)


def plate():
    d = 0.8
    thunk = lp(noise(0.12), 400) * decay(int(0.12 * SR), 0.025)
    return room(mix(d, (thunk, 0, 0.8), (ceramic(), 0.004, 0.45), (ceramic(2150), 0.05, 0.2)), 0.2, 0.2)


def sprinkle():
    """Cheese and parsley on top: a light sprinkle."""
    d = 1.1
    env = np.sin(np.linspace(0, np.pi, int(d * SR))) ** 0.7
    return room(grains(d, 700, 4000, 13000, tau=0.0008, amp=(0.05, 0.6), envelope=env), 0.1, 0.1)


def tada():
    notes = [784, 988, 1175, 1568]
    parts = [(marimba(f, 0.9), i * 0.09, 0.6) for i, f in enumerate(notes)]
    parts.append((glock(2349, 1.4), 0.36, 0.45))
    return room(mix(1.7, *parts, (sparkle(), 0.3, 0.35)), 0.4, 0.25)


def kiss():
    """The chef's kiss: a little smack of the lips."""
    d = 0.35
    smack = band(noise(0.03), 800, 5000) * decay(int(0.03 * SR), 0.005)
    pop = np.sin(sweep(900, 1600, 0.05)) * decay(int(0.05 * SR), 0.012)
    return room(mix(d, (smack, 0, 0.7), (pop, 0.012, 0.6)), 0.12, 0.2)


# ---------------------------------------------------------------- wine

def cork_pop():
    d = 0.5
    pop = np.sin(sweep(420, 140, 0.09)) * decay(int(0.09 * SR), 0.03)
    click = band(noise(0.01), 1000, 6000) * decay(int(0.01 * SR), 0.002)
    air = band(noise(0.25), 500, 3000) * decay(int(0.25 * SR), 0.05)
    return room(mix(d, (click, 0, 0.6), (pop, 0.004, 1), (air, 0.01, 0.2)), 0.2, 0.2)


def pour():
    """Wine into a glass: a stream and glugs, the pitch rising as the glass fills."""
    d = 2.2
    n = int(d * SR)
    k = np.linspace(0, 1, n)
    stream = band(noise(d), 350, 2200)
    stream = reson(stream, 800, 3) * 0.6 + stream * 0.3
    stream *= adsr(n, 0.15, 0.3)
    glugs = []
    at = 0.12
    while at < d - 0.35:
        gd = rng.uniform(0.05, 0.09)
        f = 380 + 700 * (at / d) + rng.uniform(-60, 60)
        glugs.append((np.sin(sweep(f, f * 1.9, gd)) * decay(int(gd * SR), 0.02), at, rng.uniform(0.25, 0.5)))
        at += rng.uniform(0.07, 0.16)
    return room(mix(d, (stream * (0.4 + 0.3 * k), 0, 0.35), *glugs), 0.2, 0.2)


def clink():
    """Two wine glasses touching: bright rings that beat against each other."""
    d = 2.2
    a = partials([1340, 3610, 6780, 10300], [1, 0.45, 0.2, 0.08], [0.9, 0.35, 0.15, 0.06], d)
    b = partials([1395, 3720, 6950, 10500], [0.9, 0.4, 0.18, 0.07], [0.8, 0.3, 0.13, 0.05], d)
    tick = hp(noise(0.006), 3000) * decay(int(0.006 * SR), 0.001)
    return room(mix(d, (tick, 0, 0.6), (a, 0, 0.5), (b, 0.004, 0.5)), 0.6, 0.35, 9000)


def sip():
    d = 0.6
    x = band(noise(0.35), 1200, 5000)
    x *= np.sin(np.linspace(0, np.pi, len(x))) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t_of(0.35)))
    gulp = np.sin(sweep(260, 160, 0.09)) * decay(int(0.09 * SR), 0.03)
    return room(mix(d, (x, 0, 0.35), (gulp, 0.42, 0.5)), 0.12, 0.15)


# ---------------------------------------------------------------- the record

def sleeve():
    d = 0.7
    x = band(noise(0.55), 900, 6000)
    x *= np.sin(np.linspace(0, np.pi, len(x))) ** 1.2
    return room(mix(d, (x, 0, 0.5)), 0.12, 0.12)


def vinyl_set():
    d = 0.5
    thud = lp(noise(0.1), 500) * decay(int(0.1 * SR), 0.02)
    click = band(noise(0.01), 1500, 5000) * decay(int(0.01 * SR), 0.002)
    return room(mix(d, (thud, 0, 0.8), (click, 0.03, 0.4)), 0.15, 0.2)


def crackle_body(dur):
    c = grains(dur, 45, 1000, 9000, tau=0.0007, amp=(0.2, 1))
    fine = grains(dur, 400, 3000, 12000, tau=0.0004, amp=(0.02, 0.15))
    hiss = band(noise(dur), 3000, 10000) * 0.03
    rumble = lp(noise(dur), 90) * 0.4
    return c + fine + hiss + rumble


def needle():
    d = 1.0
    drop = lp(noise(0.08), 700) * decay(int(0.08 * SR), 0.015)
    return mix(d, (drop, 0, 0.9), (crackle_body(1.0) * adsr(int(SR), 0.02, 0.3), 0.02, 0.6))


def crackle():
    return seamless(crackle_body(4.4), 0.4)


def snap():
    d = 0.35
    x = band(noise(0.02), 1500, 7000) * decay(int(0.02 * SR), 0.003)
    x = reson(x, 2400, 5) + x
    return room(mix(d, (x, 0, 1)), 0.25, 0.3)


# ---------------------------------------------------------------- hug, cushions, dinner

def rustle(dur, lo=600, hi=5000, rate=500, seed_env=None):
    """Cloth (or fur) moving: grains over a soft swish, in gentle waves."""
    n = int(dur * SR)
    env = np.clip(lp(rng.standard_normal(n), 6) * 40 + 0.6, 0.05, 1.5)
    if seed_env is not None:
        env *= seed_env
    swish = band(noise(dur), lo, hi) * 0.25 * env
    g = grains(dur, rate, lo * 1.5, hi * 1.6, tau=0.0015, amp=(0.1, 0.6), envelope=env)
    return swish + g


def hug():
    d = 1.4
    body = rustle(1.2, 400, 3500, 420) * adsr(int(1.2 * SR), 0.1, 0.4)
    squeeze = lp(noise(0.3), 250) * np.sin(np.linspace(0, np.pi, int(0.3 * SR)))
    return room(mix(d, (body, 0, 0.6), (squeeze, 0.25, 0.8)), 0.15, 0.15)


def heartbeat():
    d = 2.4
    parts = []
    for i in range(3):
        at = i * 0.78
        for off, g in [(0, 1), (0.2, 0.7)]:
            bd = 0.16
            parts.append((np.sin(sweep(70, 45, bd)) * decay(int(bd * SR), 0.05, 0.008), at + off, g))
    return lp(mix(d, *parts), 300)


def cushion_poof():
    d = 0.9
    thump = lp(noise(0.25), 220) * decay(int(0.25 * SR), 0.06, 0.01)
    air = band(noise(0.6), 400, 3000) * decay(int(0.6 * SR), 0.18, 0.02)
    return room(mix(d, (thump, 0, 1), (air, 0.02, 0.25), (rustle(0.5, 500, 3000, 200), 0.05, 0.25)), 0.15, 0.12)


def fork():
    d = 0.5
    x = partials([3150, 5400, 7900], [1, 0.5, 0.2], [0.06, 0.04, 0.02], d, 0.01)
    return room(mix(d, (ceramic(2300, 0.4), 0, 0.35), (x, 0.002, 0.35)), 0.15, 0.15)


def bite():
    """A bite of crispy milanesa: crunch, then a couple of soft chews."""
    d = 1.0
    crunch = grains(0.18, 1600, 1200, 8000, tau=0.001, amp=(0.2, 1), envelope=decay(int(0.18 * SR), 0.06))
    chews = []
    for i, at in enumerate([0.32, 0.55, 0.78]):
        cd = 0.12
        chews.append((lp(noise(cd), 600) * np.sin(np.linspace(0, np.pi, int(cd * SR))), at, 0.35 - i * 0.08))
        chews.append((grains(cd, 400, 1500, 6000, tau=0.0008, amp=(0.05, 0.3)), at, 0.4 - i * 0.1))
    return room(mix(d, (crunch, 0, 1), *chews), 0.1, 0.1)


def nom():
    """«Mmm!» — a warm hum that goes up: tasty."""
    d = 0.7
    ph = sweep(230, 330, 0.55)
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    x = lp(x, 900) * adsr(len(x), 0.05, 0.2)
    return room(mix(d, (x, 0, 0.8)), 0.15, 0.15)


# ---------------------------------------------------------------- bedtime

def table_drag():
    d = 1.3
    n = int(1.1 * SR)
    x = band(noise(1.1), 150, 1200)
    stick = (np.sin(2 * np.pi * 14 * t_of(1.1)) > 0.2).astype(float)  # wood legs stutter on the tiles
    stick = lp(stick, 60)
    x = reson(x, 380, 6) * 0.6 + x * 0.5
    return room(mix(d, (x * (0.4 + 0.6 * stick) * adsr(n, 0.08, 0.25), 0, 0.7)), 0.25, 0.2)


def creak(dur=0.6, f0=260, f1=180):
    """A metal spring / hinge creak: a buzzy tone with jitter."""
    n = int(dur * SR)
    jitter = 1 + 0.08 * lp(rng.standard_normal(n), 30) * 20
    f = np.geomspace(f0, f1, n) * jitter
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = signal.sawtooth(ph) * (0.5 + 0.5 * (np.sin(ph * 0.5) > 0.6))
    return band(x, 400, 3500) * adsr(n, 0.05, 0.15)


def sofa_bed():
    d = 1.8
    clack = band(noise(0.04), 800, 5000) * decay(int(0.04 * SR), 0.008)
    thump = lp(noise(0.3), 180) * decay(int(0.3 * SR), 0.07)
    return room(mix(d, (creak(0.7), 0, 0.35), (clack, 0.72, 0.6), (creak(0.35, 320, 240), 0.8, 0.25), (thump, 1.1, 1), (clack, 1.12, 0.3)), 0.3, 0.2)


def boing(dur=0.6, f0=180, f1=110):
    t = t_of(dur)
    ph = sweep(f0, f1, dur) + 2.5 * np.sin(2 * np.pi * 9 * t)
    return np.sin(ph) * decay(len(t), 0.18)


def bed_jump():
    d = 1.5
    thump = lp(noise(0.35), 200) * decay(int(0.35 * SR), 0.08, 0.005)
    return room(mix(d, (whoosh(0.35, 500, 2500), 0, 0.35), (thump, 0.33, 1), (boing(), 0.34, 0.35),
                    (creak(0.4, 300, 230), 0.4, 0.15), (rustle(0.5, 500, 3000, 250), 0.35, 0.25)), 0.25, 0.2)


def blanket():
    d = 1.8
    env = np.sin(np.linspace(0, np.pi, int(1.6 * SR))) ** 0.8
    return room(mix(d, (rustle(1.6, 350, 3500, 520, env), 0, 0.7)), 0.2, 0.15)


def lamp_click():
    d = 0.3
    a = band(noise(0.008), 2000, 8000) * decay(int(0.008 * SR), 0.0015)
    b = reson(a, 3100, 10) + a
    return room(mix(d, (b, 0, 1), (a, 0.045, 0.4)), 0.2, 0.2)


def night():
    """Night in Gràcia: crickets far away, a warm hum of the city."""
    d = 8.4
    x = np.zeros(int(d * SR))
    for f, period, off in [(4300, 1.1, 0.0), (4700, 1.45, 0.4), (3900, 1.9, 0.9)]:
        at = off
        while at < d - 0.5:
            for k in range(3):  # a chirp: three tiny pulses
                cd = 0.03
                p = np.sin(2 * np.pi * f * t_of(cd)) * np.sin(np.linspace(0, np.pi, int(cd * SR)))
                i = int((at + k * 0.045) * SR)
                x[i:i + len(p)] += p * 0.25
            at += period * rng.uniform(0.85, 1.15)
    city = lp(noise(d), 180) * 0.35 + band(noise(d), 200, 700) * 0.04
    return seamless(room(x, 0.6, 0.5, 7000)[:int(d * SR)] + city, 0.5)


def birds():
    d = 3.2
    parts = []
    at = 0.1
    while at < d - 0.4:
        for k in range(rng.integers(2, 5)):
            cd = rng.uniform(0.05, 0.1)
            f = rng.uniform(2800, 4200)
            ph = sweep(f, f * rng.uniform(1.2, 1.6), cd) + 3 * np.sin(2 * np.pi * 40 * t_of(cd))
            parts.append((np.sin(ph) * np.sin(np.linspace(0, np.pi, int(cd * SR))), at + k * (cd + 0.03), rng.uniform(0.2, 0.45)))
        at += rng.uniform(0.35, 0.7)
    return room(mix(d, *parts), 0.8, 0.45, 8000)


# ---------------------------------------------------------------- rooftop chicken hunt

def leap():
    return mix(0.45, (whoosh(0.35, 700, 4000), 0, 0.8))


def scamper():
    """Four quick paws on the terrace tiles."""
    d = 0.4
    parts = []
    for i in range(4):
        pd = 0.03
        parts.append((band(noise(pd), 600, 3000) * decay(int(pd * SR), 0.006), i * 0.07, 0.6 - i * 0.08))
    return room(mix(d, *parts), 0.08, 0.1)


def land():
    d = 0.35
    return room(mix(d, (lp(noise(0.12), 400) * decay(int(0.12 * SR), 0.03), 0, 1)), 0.1, 0.1)


def cluck_one(f0, dur, gain=1.0):
    """One «bok»: a buzzy voice with a hen's formants."""
    n = int(dur * SR)
    f = np.geomspace(f0 * 1.15, f0 * 0.8, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = signal.sawtooth(ph, 0.3)
    v = reson(src, 900, 5) + reson(src, 1900, 7) * 0.6 + reson(src, 3200, 9) * 0.3
    return v * adsr(n, 0.008, dur * 0.4) * gain


def cluck():
    d = 0.8
    return room(mix(d, (cluck_one(420, 0.08), 0, 0.7), (cluck_one(400, 0.07), 0.16, 0.6), (cluck_one(460, 0.1), 0.3, 0.8)), 0.15, 0.12)


def squawk():
    """Caught! «BAWK!» + a puff of feathers."""
    d = 1.0
    n = int(0.28 * SR)
    f = 560 + 260 * np.sin(np.linspace(0, np.pi, n))
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = signal.sawtooth(ph, 0.3)
    v = (reson(src, 1100, 4) + reson(src, 2300, 6) * 0.7 + reson(src, 3500, 8) * 0.3) * adsr(n, 0.01, 0.1)
    feathers = rustle(0.5, 1500, 7000, 700) * decay(int(0.5 * SR), 0.18)
    pop = np.sin(sweep(300, 900, 0.07)) * decay(int(0.07 * SR), 0.02)
    return room(mix(d, (pop, 0, 0.6), (cluck_one(480, 0.06), 0.02, 0.5), (v, 0.1, 0.9), (feathers, 0.05, 0.5)), 0.2, 0.15)


def coin():
    return room(mix(0.9, (glock(1976, 0.6), 0, 0.6), (glock(2637, 0.9), 0.07, 0.7), (sparkle() * 0.4, 0.05, 1)), 0.3, 0.2)


def whistle():
    """Round over: a referee's whistle, friendly."""
    d = 0.9
    t = t_of(0.7)
    ph = 2 * np.pi * 2350 * t + 25 * np.sin(2 * np.pi * 28 * t)
    x = np.sin(ph) * adsr(len(t), 0.02, 0.1) + 0.2 * band(noise(0.7), 2000, 5000) * adsr(len(t), 0.02, 0.1)
    return room(mix(d, (x, 0, 0.6)), 0.3, 0.25)


def fanfare():
    notes = [(784, 0), (784, 0.12), (784, 0.24), (1047, 0.4), (1319, 0.62), (1568, 0.84)]
    parts = [(marimba(f, 0.8 if i < 5 else 1.4), at, 0.6) for i, (f, at) in enumerate(notes)]
    return room(mix(2.4, *parts, (sparkle(), 0.84, 0.5)), 0.4, 0.3)


# ---------------------------------------------------------------- Sr. Fer

def furby(notes, seed, speed=1.0):
    """Furby-ish babble: a toy voice with a fast vibrato and a squeaky formant."""
    r = np.random.default_rng(seed)
    parts, at = [], 0.0
    for f, d in notes:
        d /= speed
        t = t_of(d)
        vib = 1 + 0.035 * np.sin(2 * np.pi * r.uniform(9, 13) * t)
        ph = 2 * np.pi * np.cumsum(np.geomspace(f, f * r.uniform(1.05, 1.25), len(t)) * vib) / SR
        src = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        s = reson(src, 2600, 4) * 0.4 + src * 0.6
        parts.append((s * adsr(len(s), 0.012, d * 0.35), at, 1))
        at += d + 0.035
    return room(mix(at + 0.1, *parts), 0.12, 0.15)


def fer_chirp_1():
    return furby([(620, 0.13), (700, 0.2)], 1)  # «me-me!»


def fer_chirp_2():
    return furby([(560, 0.11), (820, 0.09), (700, 0.22)], 2)  # «kah may-may»


def fer_chirp_3():
    return furby([(760, 0.16), (600, 0.24)], 3)  # «u-nye?»


def fer_happy():
    """Giggle: a quick bouncy trill going up."""
    notes = [(640 + 55 * i, 0.07) for i in range(7)]
    return mix(1.2, (furby(notes, 4), 0, 1), (sparkle(), 0.35, 0.25))


def fer_call():
    """Someone whistles for him: «fiu-fiuuu»."""
    d = 1.1
    a = np.sin(sweep(1300, 1900, 0.18)) * adsr(int(0.18 * SR), 0.02, 0.05)
    b = np.sin(sweep(1900, 1250, 0.4)) * adsr(int(0.4 * SR), 0.02, 0.12)
    air = band(noise(0.6), 1200, 3000) * 0.05
    return room(mix(d, (a, 0, 0.55), (b, 0.26, 0.55), (air, 0, 1)), 0.4, 0.3)


def fer_rustle():
    """His fluffy fur rustling as he waddles."""
    d = 0.45
    env = np.sin(np.linspace(0, np.pi, int(0.4 * SR)))
    fur = rustle(0.4, 1200, 7000, 900, env)
    return room(mix(d, (fur, 0, 0.7), (lp(noise(0.05), 300) * decay(int(0.05 * SR), 0.01), 0.18, 0.4)), 0.1, 0.1)


def fer_shake():
    """A fluffy shake-off: brrrr of fur, fast wobble."""
    d = 0.9
    n = int(0.75 * SR)
    wob = 0.5 + 0.5 * np.sin(2 * np.pi * 16 * t_of(0.75))
    fur = rustle(0.75, 1000, 7000, 1400) * wob * adsr(n, 0.05, 0.2)
    return room(mix(d, (fur, 0, 0.8)), 0.12, 0.1)


def fer_snore():
    """Sleepy in-breath and a tiny whistle out."""
    d = 2.2
    inhale = band(noise(0.9), 300, 1500) * np.sin(np.linspace(0, np.pi, int(0.9 * SR))) ** 2
    t = t_of(0.8)
    whistle_out = np.sin(sweep(1150, 820, 0.8)) * np.sin(np.linspace(0, np.pi, len(t))) ** 2
    return room(mix(d, (inhale, 0, 0.35), (whistle_out, 1.05, 0.22), (band(noise(0.8), 800, 2500) * np.sin(np.linspace(0, np.pi, len(t))) ** 2, 1.05, 0.1)), 0.3, 0.2)


def fer_step():
    d = 0.12
    return mix(d, (band(noise(0.04), 500, 2500) * decay(int(0.04 * SR), 0.008), 0, 0.5), (rustle(0.1, 1500, 7000, 600), 0, 0.3))


# ---------------------------------------------------------------- output

SOUNDS = {
    'ui_tap': (ui_tap, 0.7), 'ui_open': (ui_open, 0.7), 'ui_close': (ui_close, 0.7),
    'sparkle': (sparkle, 0.6), 'wish': (wish, 0.65), 'heart_pop': (heart_pop, 0.6),
    'voice_seb_1': (lambda: voice(190, 4, 21), 0.55), 'voice_seb_2': (lambda: voice(175, 5, 22), 0.55),
    'voice_max_1': (lambda: voice(265, 4, 31), 0.55), 'voice_max_2': (lambda: voice(285, 5, 32), 0.55),
    'egg_dip': (egg_dip, 0.8), 'breadcrumbs': (breadcrumbs, 0.85), 'sizzle_in': (sizzle_in, 0.8),
    'sizzle': (sizzle, 0.6), 'spatula': (spatula, 0.7), 'flip': (flip, 0.8), 'plate': (plate, 0.8),
    'sprinkle': (sprinkle, 0.6), 'tada': (tada, 0.7), 'kiss': (kiss, 0.7),
    'cork_pop': (cork_pop, 0.85), 'pour': (pour, 0.75), 'clink': (clink, 0.8), 'sip': (sip, 0.6),
    'sleeve': (sleeve, 0.6), 'vinyl_set': (vinyl_set, 0.7), 'needle': (needle, 0.7), 'crackle': (crackle, 0.5),
    'snap': (snap, 0.8), 'whoosh': (lambda: whoosh(0.5, 300, 2200), 0.6), 'hug': (hug, 0.7),
    'heartbeat': (heartbeat, 0.85), 'cushion_poof': (cushion_poof, 0.8), 'fork': (fork, 0.6),
    'bite': (bite, 0.8), 'nom': (nom, 0.6),
    'table_drag': (table_drag, 0.7), 'sofa_bed': (sofa_bed, 0.8), 'bed_jump': (bed_jump, 0.85),
    'blanket': (blanket, 0.7), 'lamp_click': (lamp_click, 0.8), 'night': (night, 0.5), 'birds': (birds, 0.6),
    'leap': (leap, 0.7), 'scamper': (scamper, 0.6), 'land': (land, 0.7), 'cluck': (cluck, 0.6),
    'squawk': (squawk, 0.85), 'coin': (coin, 0.75), 'whistle': (whistle, 0.6), 'fanfare': (fanfare, 0.75),
    'fer_chirp_1': (fer_chirp_1, 0.7), 'fer_chirp_2': (fer_chirp_2, 0.7), 'fer_chirp_3': (fer_chirp_3, 0.7),
    'fer_happy': (fer_happy, 0.75), 'fer_call': (fer_call, 0.7), 'fer_rustle': (fer_rustle, 0.6),
    'fer_shake': (fer_shake, 0.7), 'fer_snore': (fer_snore, 0.6), 'fer_step': (fer_step, 0.5),
}
LOOPS = {'sizzle', 'crackle', 'night'}


def write(path, x):
    wav = path[:-4] + '.wav'
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libmp3lame', '-b:a', '80k', path], check=True)
    os.remove(wav)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/sfx'
    only = set(sys.argv[2:])
    os.makedirs(out, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        if only and name not in only:
            continue
        x = make()
        x = x - np.mean(x)
        x = fit(x, peak) if name in LOOPS else fades(fit(x, peak), 0.001, 0.03)
        write(os.path.join(out, f'{name}.mp3'), x)
        print(f'{name:14s} {len(x) / SR:5.2f}s')


if __name__ == '__main__':
    main()
