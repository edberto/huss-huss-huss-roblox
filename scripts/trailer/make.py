# Huss Huss Huss trailer: cut the Studio captures, add titles, score with our own samples.
import math, os, random, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont

os.chdir(os.environ.get('TRAILER_DIR', '.trailer'))
AUD = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'audio')
W, H, VH = 1920, 1080, 745  # frame, picture height (2.58:1 letterbox)
TOP = (H - VH) // 2
FPS = 30
BEAT = 0.5  # 120 bpm
LUCKY = 'fonts/LuckiestGuy.ttf'
FRED = 'fonts/Fredoka600.ttf'
random.seed(7)

# (source, in-point, duration, overlays)  overlays: (png, start, end, fade)
SCENES = [
    ('shot1', 0.4, 5.0), ('party', 0.5, 3.5), ('ball', 0.5, 5.5), ('gym', 1.0, 4.5),
    ('burger', 1.0, 4.5), ('shock', 0.4, 4.0), ('dawn2', 0.6, 6.0), ('END', 0, 4.0),
]


def font(path, size):
    return ImageFont.truetype(path, size)


def text_png(name, lines, size=64, y=None, color=(255, 255, 255), stroke=7, path=LUCKY, rotate=0, center=None):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(path, size)
    total = len(lines) * size * 1.1
    y0 = y if y is not None else (H - total) / 2
    for i, line in enumerate(lines):
        d.text((W / 2, y0 + i * size * 1.1 + size / 2), line, font=f, fill=color, anchor='mm',
               stroke_width=stroke, stroke_fill=(10, 5, 25))
    if rotate:
        img = img.rotate(rotate, resample=Image.BICUBIC, center=center)
    img.save(f'ov_{name}.png')
    return f'ov_{name}.png'


def stamp(name, x, y, rot, color):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((x, y), 'HUSS!', font=font(LUCKY, 92), fill=color, anchor='mm', stroke_width=8, stroke_fill=(10, 5, 25))
    img = img.rotate(rot, resample=Image.BICUBIC, center=(x, y))
    img.save(f'ov_{name}.png')
    return f'ov_{name}.png'


def message_card():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 460, TOP + 40, 1460, TOP + 210
    d.rounded_rectangle([x0 + 6, y0 + 8, x1 + 6, y1 + 8], 34, fill=(0, 0, 0, 120))
    d.rounded_rectangle([x0, y0, x1, y1], 34, fill=(242, 238, 220), outline=(0, 0, 0), width=6)
    d.text((W / 2, y0 + 62), 'New message: PARTY AT THE END OF THE STREET', font=font(FRED, 40), fill=(20, 27, 54), anchor='mm')
    d.rounded_rectangle([x0 + 70, y0 + 112, x1 - 70, y0 + 140], 14, fill=(20, 12, 40))
    d.rounded_rectangle([x0 + 70, y0 + 112, x0 + 560, y0 + 140], 14, fill=(255, 46, 147))
    img.save('ov_msg.png')
    return 'ov_msg.png'


def end_card():
    img = Image.new('RGB', (W, H), (16, 10, 36))
    px = img.load()
    for yy in range(0, H, 2):
        for xx in range(0, W, 2):
            dd = min(1, math.hypot(xx - W / 2, yy - H * 0.55) / (W * 0.6))
            c = tuple(int(a * (1 - dd) ** 1.5 + b * (1 - (1 - dd) ** 1.5)) for a, b in zip((150, 40, 140), (16, 10, 36)))
            for oy in (0, 1):
                for ox in (0, 1):
                    if xx + ox < W and yy + oy < H:
                        px[xx + ox, yy + oy] = c
    d = ImageDraw.Draw(img)
    d.text((W / 2, 400), 'HUSS HUSS HUSS', font=font(LUCKY, 170), fill=(255, 215, 90), anchor='mm', stroke_width=12, stroke_fill=(10, 5, 25))
    d.text((W / 2, 560), 'WHILE THEY PARTY', font=font(LUCKY, 96), fill=(255, 255, 255), anchor='mm', stroke_width=9, stroke_fill=(10, 5, 25))
    d.rounded_rectangle([660, 690, 1260, 800], 40, fill=(255, 107, 26), outline=(0, 0, 0), width=7)
    d.text((W / 2, 750), 'PLAY NOW ON ROBLOX', font=font(LUCKY, 52), fill=(255, 255, 255), anchor='mm', stroke_width=5, stroke_fill=(10, 5, 25))
    img.save('endcard.png')


COLORS = [(255, 215, 90), (255, 255, 255), (61, 255, 176)]


def stamps_for(scene, beats):
    out = []
    for i, t in enumerate(beats):
        x = W / 2 + random.uniform(-330, 330)
        y = TOP + VH * 0.3 + random.uniform(-80, 60)
        png = stamp(f'{scene}_{i}', x, y, random.uniform(-14, 14), random.choice(COLORS))
        out.append((png, t, t + 0.45, 0.06))
    return out


def build_overlays():
    ov = {s[0]: [] for s in SCENES}
    cap_y = H - TOP + 40
    ov['shot1'].append((text_png('cap1', ['IN THIS TOWN, EVERYBODY GOES OUT PARTYING...'], 58, y=cap_y - 30), 0.6, 5.0, 0.4))
    ov['party'].append((text_png('cap1b', ['IN THIS TOWN, EVERYBODY GOES OUT PARTYING...'], 58, y=cap_y - 30), 0, 3.5, 0))
    ov['ball'].append((text_png('cap2', ['...EXCEPT ME.'], 72, y=cap_y - 36, color=(255, 215, 90)), 0.0, 2.4, 0.2))
    ov['ball'] += stamps_for('ball', [2.5, 3.0, 3.5])
    ov['gym'] += stamps_for('gym', [0.5, 1.0, 1.5, 2.5, 3.0, 3.5])
    ov['burger'] += stamps_for('burger', [0.5, 1.0, 1.5, 2.5, 3.0, 3.5])
    ov['shock'].append((message_card(), 1.1, 4.0, 0.15))
    ov['shock'].append((text_png('cap3', ['SAY NO. KEEP HUSSING.'], 60, y=cap_y - 30), 1.6, 4.0, 0.25))
    ov['dawn2'].append((text_png('cap4', ['LAST UNTIL DAWN.'], 72, y=cap_y - 36, color=(255, 215, 90)), 0.8, 6.0, 0.3))
    return ov


def render_scene(i, scene, ov):
    src, start, dur = scene
    out = f'scene{i}.mp4'
    tmp = f'scene{i}.tmp.mp4'
    cmd = ['ffmpeg', '-v', 'error', '-y']
    if src == 'END':
        cmd += ['-framerate', str(FPS), '-i', 'endcard.png']
        vf = f'[0:v]format=yuv420p,loop=-1:1,trim=duration={dur},setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.4[v0]'
    else:
        cmd += ['-ss', str(start), '-t', str(dur), '-i', f'{src}.mp4']
        vf = (f'[0:v]fps={FPS},scale={W}:{VH}:flags=lanczos,eq=contrast=1.06:saturation=1.15,'
              f'pad={W}:{H}:0:{TOP}:black,setsar=1')
        if i == 0:
            vf += ',fade=t=in:st=0:d=0.6'
        vf += '[v0]'
    last = 'v0'
    for k, (png, a, b, fade) in enumerate(ov.get(src, [])):
        cmd += ['-loop', '1', '-framerate', str(FPS), '-t', str(dur), '-i', png]
        idx = k + 1
        f = f'[{idx}:v]format=rgba'
        if fade:
            f += f',fade=t=in:st={a}:d={fade}:alpha=1'
        f += f'[o{k}];[{last}][o{k}]overlay=0:0:enable=\'between(t,{a},{b})\'[v{k + 1}]'
        vf += ';' + f
        last = f'v{k + 1}'
    cmd += ['-filter_complex', vf, '-map', f'[{last}]', '-t', str(dur), '-r', str(FPS),
            '-c:v', 'libx264', '-crf', '18', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-an', tmp]
    subprocess.run(cmd, check=True)
    os.replace(tmp, out)
    return out


# ---------------- audio ----------------
SR = 44100


def load(name):
    w = wave.open(f'{AUD}/{name}.wav')
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768
    if ch == 2:
        a = a.reshape(-1, 2).mean(1)
    if sr != SR:
        a = np.interp(np.linspace(0, len(a) - 1, int(len(a) * SR / sr)), np.arange(len(a)), a)
    return a


def build_audio(total):
    S = {n: load(n) for n in ['beat_kick', 'beat_hat', 'beat_bass', 'beat_stab', 'firework', 'ahh-almost-almost'] + [f'huss{i}' for i in range(1, 7)]}
    mix = np.zeros(int((total + 3) * SR))

    def put(name, t, gain=1.0, pitch=1.0):
        a = S[name]
        if pitch != 1.0:
            a = np.interp(np.arange(0, len(a) - 1, pitch), np.arange(len(a)), a)
        i = int(t * SR)
        mix[i:i + len(a)] += a[:len(mix) - i] * gain

    starts = np.cumsum([0] + [s[2] for s in SCENES])
    sc = {s[0]: starts[i] for i, s in enumerate(SCENES)}

    def groove(a, b, kick=1.0, hat=0.5, bass=0.0, stab=0.0):
        t = a
        n = 0
        while t < b - 0.01:
            put('beat_kick', t, kick)
            put('beat_hat', t + BEAT / 2, hat)
            if bass and n % 2 == 0:
                put('beat_bass', t, bass, pitch=[1, 1, 0.84, 0.89][(n // 2) % 4])
            if stab and n % 4 == 3:
                put('beat_stab', t + BEAT / 2, stab)
            t += BEAT
            n += 1

    # Party intro: full groove, swelling in.
    groove(sc['shot1'] + 1.0, sc['ball'], kick=0.8, hat=0.4, bass=0.7, stab=0.5)
    # "...except me": hard stop, then the practice beat with the huss rhythm.
    groove(sc['ball'] + 1.0, sc['shock'], kick=1.0, hat=0.45, bass=0.4)
    t = sc['ball'] + 2.5
    k = 0
    while t < sc['shock'] - 0.2:
        beat_in_bar = k % 4
        take = 1 if (k // 4) % 2 == 0 else 4
        if beat_in_bar < 3:
            put(f'huss{take + beat_in_bar}', t, 0.9)
        else:
            for j in range(3):
                put(f'huss{(4 if take == 1 else 1) + j}', t + j * 0.16, 0.9)
        t += BEAT
        k += 1
    # The temptation: the beat drops out, a stab on the message, the party thumps faintly.
    put('beat_stab', sc['shock'] + 1.1, 0.9, pitch=0.8)
    for j in range(8):
        put('beat_kick', sc['shock'] + 1.6 + j * BEAT * 0.5, 0.25, pitch=0.9)
    # Dawn: fireworks and the full groove back.
    put('firework', sc['dawn2'] + 0.3, 0.9)
    put('firework', sc['dawn2'] + 1.4, 0.7)
    groove(sc['dawn2'], sc['END'], kick=1.0, hat=0.5, bass=0.8, stab=0.6)
    # End card: the full phrase, then a last hit.
    for j in range(3):
        put(f'huss{j + 1}', sc['END'] + 0.3 + j * 0.2, 1.0)
    put('beat_kick', sc['END'] + 1.0, 1.0)
    put('beat_stab', sc['END'] + 1.0, 0.7)
    mix = mix[:int(total * SR)]
    fade = int(0.8 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)
    mix = np.tanh(mix * 1.1) * 0.9
    pcm = (mix * 32767).astype(np.int16)
    with wave.open('score.wav', 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == '__main__':
    import sys
    end_card()
    ov = build_overlays()
    only = sys.argv[1:]
    files = []
    for i, s in enumerate(SCENES):
        f = f'scene{i}.mp4'
        if not only or str(i) in only or not os.path.exists(f):
            render_scene(i, s, ov)
        files.append(f)
    with open('list.txt', 'w') as fh:
        fh.writelines(f"file '{f}'\n" for f in files)
    total = sum(s[2] for s in SCENES)
    build_audio(total)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', 'video.mp4'], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', 'video.mp4', '-i', 'score.wav', '-map', '0:v', '-map', '1:a',
                    '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', 'huss_trailer.tmp.mp4'], check=True)
    os.replace('huss_trailer.tmp.mp4', 'huss_trailer.mp4')
    print('total', total)
