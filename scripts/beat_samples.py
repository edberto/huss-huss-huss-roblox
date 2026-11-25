# Synthesizes the training-beat samples in assets/audio/ (our own sounds, no library clips).
# Run: python3 scripts/beat_samples.py
import wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1)


def save(name, x):
    x = x / np.max(np.abs(x)) * 0.89  # about -1 dBFS
    with wave.open(f'assets/audio/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


# Closed hi-hat: bright noise burst, 60 ms.
tt = t(0.06)
noise = rng.uniform(-1, 1, tt.size)
save('beat_hat', (noise - lowpass(noise, 0.35)) * np.exp(-tt * 70))

# Bass: C2 (65.41 Hz) square-ish saw, filtered, 0.3 s pluck. Pitched in game with PlaybackSpeed.
tt = t(0.3)
f = 65.41
saw = 2 * ((tt * f) % 1) - 1
sub = np.sin(2 * np.pi * f * tt)
bass = lowpass(0.6 * saw + 0.8 * sub, 0.08) * np.minimum(1, tt * 400) * np.exp(-tt * 7)
save('beat_bass', bass)

# Stab: C minor chord (C4 Eb4 G4), two detuned saws each, 0.35 s.
tt = t(0.35)
stab = np.zeros_like(tt)
for f in (261.63, 311.13, 392.0):
    for det in (0.995, 1.005):
        stab += 2 * ((tt * f * det) % 1) - 1
stab = lowpass(stab, 0.25) * np.minimum(1, tt * 300) * np.exp(-tt * 9)
save('beat_stab', stab)
print('ok')

# Firework: a low boom, then a shower of crackles, 1.6 s.
tt = t(1.6)
boom = np.sin(2 * np.pi * np.cumsum(40 + 90 * np.exp(-tt * 18)) / SR) * np.exp(-tt * 6)
noise = rng.uniform(-1, 1, tt.size)
body = lowpass(noise, 0.15) * np.exp(-tt * 9) * 0.8
crackle = np.zeros_like(tt)
for _ in range(70):
    start = int(SR * rng.uniform(0.25, 1.3))
    n = int(SR * 0.012)
    crackle[start:start + n] += rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / (n / 4)) * rng.uniform(0.3, 1)
save('firework', boom + body + crackle * np.exp(-(tt - 0.25).clip(0) * 2.5) * 0.7)
print('firework ok')

# Kick: punchy sine drop (150 -> 50 Hz) with a click and soft clipping, so it still cuts
# through on phone speakers that can't play the low end. 0.35 s.
tt = t(0.35)
body = np.sin(2 * np.pi * np.cumsum(50 + 100 * np.exp(-tt * 30)) / SR) * np.exp(-tt * 9)
click = rng.uniform(-1, 1, tt.size) * np.exp(-tt * 400) * 0.6
save('beat_kick', np.tanh(2.5 * (body + click)))
print('ok')
