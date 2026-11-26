# Vertical 15 s cut (1080x1920), every cut and voice on the 120 bpm grid.
import os, random, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont

os.chdir(os.environ.get('TRAILER_DIR', '.trailer'))
from make import load, SR, LUCKY, FRED  # reuse sample loader and fonts

W, H, FPS, BEAT = 1080, 1920, 30, 0.5
random.seed(11)

HIT = {  # source time of hit k (sync flash + 0.5 s grid)
    'v2_hook': lambda k: 0.98 + 0.5 * k,
    'v2_gym': lambda k: 1.031 + 0.5 * k,
    'v2_burger': lambda k: 1.001 + 0.5 * k,
    'v2_ui': lambda k: 1.0 + 0.5 * k,
}

# (timeline start, duration, source, source start, mode, cx) mode: crop = 9:16 crop centred at cx (0..1); fit = whole frame over blur
CUTS = [
    (0.0, 2.0, 'v2_hook', HIT['v2_hook'](1), 'crop', 0.5),
    (2.0, 1.0, 'party', 1.2, 'crop', 0.55),
    (3.0, 1.0, 'v2_hook', HIT['v2_hook'](6), 'crop', 0.5),
    (4.0, 0.5, 'v2_gym', HIT['v2_gym'](1), 'crop', 0.5),
    (4.5, 0.5, 'v2_burger', HIT['v2_burger'](3), 'crop', 0.5),
    (5.0, 0.5, 'v2_hook', HIT['v2_hook'](3), 'crop', 0.5),
    (5.5, 0.5, 'v2_gym', HIT['v2_gym'](4), 'crop', 0.5),
    (6.0, 0.5, 'v2_burger', HIT['v2_burger'](5), 'crop', 0.5),
    (6.5, 0.5, 'v2_hook', HIT['v2_hook'](8), 'crop', 0.5),
    (7.0, 0.5, 'v2_gym', HIT['v2_gym'](8), 'crop', 0.5),
    (7.5, 0.5, 'v2_burger', HIT['v2_burger'](10), 'crop', 0.5),
    (8.0, 2.0, 'v2_ui', HIT['v2_ui'](1), 'fit', 0.5),
    (10.0, 2.5, 'shock', 0.9, 'crop', 0.47),
    (12.5, 1.0, 'dawn2', 1.0, 'crop', 0.5),
    (13.5, 1.5, 'END', 0, 'end', 0.5),
]
TOTAL = 15.0
SKILL_AT = {1.5, 5.5, 6.0, 6.5, 7.0, 7.5, 9.5}  # timeline beats where a skill move lands


def font(p, s):
    return ImageFont.truetype(p, s)


def text_layer(name, lines, size, y, color=(255, 255, 255), rot=0, stroke=10):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, line in enumerate(lines):
        d.text((W / 2, y + i * size * 1.08), line, font=font(LUCKY, size), fill=color, anchor='mm',
               stroke_width=stroke, stroke_fill=(10, 5, 25))
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, center=(W / 2, y))
    img.save(f'v_{name}.png')
    return f'v_{name}.png'


def stamp(name, rot, color, y):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = W / 2 + random.uniform(-200, 200)
    d.text((x, y), 'HUSS!', font=font(LUCKY, 150), fill=color, anchor='mm', stroke_width=12, stroke_fill=(10, 5, 25))
    img = img.rotate(rot, resample=Image.BICUBIC, center=(x, y))
    img.save(f'v_{name}.png')
    return f'v_{name}.png'


def message_card():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 70, 330, 1010, 560
    d.rounded_rectangle([x0 + 8, y0 + 10, x1 + 8, y1 + 10], 40, fill=(0, 0, 0, 120))
    d.rounded_rectangle([x0, y0, x1, y1], 40, fill=(242, 238, 220), outline=(0, 0, 0), width=8)
    d.text((W / 2, y0 + 60), 'New message:', font=font(FRED, 46), fill=(20, 27, 54), anchor='mm')
    d.text((W / 2, y0 + 118), 'PARTY AT THE END OF THE STREET', font=font(FRED, 46), fill=(20, 27, 54), anchor='mm')
    d.rounded_rectangle([x0 + 60, y0 + 168, x1 - 60, y0 + 198], 15, fill=(20, 12, 40))
    d.rounded_rectangle([x0 + 60, y0 + 168, x0 + 520, y0 + 198], 15, fill=(255, 46, 147))
    img.save('v_msg.png')
    return 'v_msg.png'


def end_card():
    yy, xx = np.mgrid[0:H, 0:W]
    dd = np.clip(np.hypot(xx - W / 2, yy - H * 0.5) / (H * 0.6), 0, 1) ** 1.2
    a, b = np.array([150, 40, 140]), np.array([16, 10, 36])
    rgb = (a * (1 - dd)[..., None] + b * dd[..., None]).astype(np.uint8)
    img = Image.fromarray(rgb)
    d = ImageDraw.Draw(img)
    for i, word in enumerate(['HUSS', 'HUSS', 'HUSS']):
        d.text((W / 2, 640 + i * 175), word, font=font(LUCKY, 210), fill=(255, 215, 90), anchor='mm', stroke_width=14, stroke_fill=(10, 5, 25))
    d.text((W / 2, 1190), 'WHILE THEY PARTY', font=font(LUCKY, 96), fill=(255, 255, 255), anchor='mm', stroke_width=9, stroke_fill=(10, 5, 25))
    d.rounded_rectangle([170, 1320, 910, 1450], 50, fill=(255, 107, 26), outline=(0, 0, 0), width=8)
    d.text((W / 2, 1388), 'PLAY NOW ON ROBLOX', font=font(LUCKY, 62), fill=(255, 255, 255), anchor='mm', stroke_width=6, stroke_fill=(10, 5, 25))
    img.save('v_end.png')


COLORS = [(255, 215, 90), (255, 255, 255), (61, 255, 176)]


def overlays():
    ov = {i: [] for i in range(len(CUTS))}
    top = 360
    ov[0].append((text_layer('t1', ['IN THIS TOWN,', 'EVERYBODY GOES', 'OUT PARTYING...'], 96, top - 90), 0.0, 2.0))
    ov[1].append((text_layer('t1b', ['IN THIS TOWN,', 'EVERYBODY GOES', 'OUT PARTYING...'], 96, top - 90), 0.0, 1.0))
    ov[2].append((text_layer('t2', ['...EXCEPT ME.'], 130, top, (255, 215, 90), rot=-3), 0.0, 1.0))
    # HUSS! on every cut of the montage and on each hit of the hook.
    k = 0
    for i, (t0, dur, src, *_rest) in enumerate(CUTS):
        if src.startswith('v2_') and src != 'v2_ui':
            beats = [b * BEAT for b in range(int(dur / BEAT))]
            for b in beats:
                if i == 0 and b < 2.0 or i >= 3:
                    png = stamp(f's{k}', random.uniform(-14, 14), random.choice(COLORS), random.uniform(1230, 1420))
                    ov[i].append((png, b, b + 0.4))
                    k += 1
    ov[11].append((text_layer('t3', ['TAP TO THE BEAT'], 110, top, (61, 255, 176)), 0.0, 2.0))
    ov[12].append((message_card(), 0.2, 2.5))
    ov[12].append((text_layer('t4', ["DON'T GIVE IN."], 120, 1500, (255, 255, 255), rot=2), 1.0, 2.5))
    ov[13].append((text_layer('t5', ['LAST UNTIL', 'DAWN.'], 130, top - 40, (255, 215, 90)), 0.0, 1.0))
    return ov


def render(i, cut, ov):
    t0, dur, src, ss, mode, cx = cut
    out, tmp = f'v{i}.mp4', f'v{i}.tmp.mp4'
    cmd = ['ffmpeg', '-v', 'error', '-y']
    if mode == 'end':
        cmd += ['-framerate', str(FPS), '-i', 'v_end.png']
        vf = (f'[0:v]format=yuv420p,loop=-1:1,trim=duration={dur},setpts=PTS-STARTPTS,'
              f'scale=iw*(1.25-0.25*min(t/0.25\\,1)):-1:eval=frame,crop={W}:{H},fade=t=in:st=0:d=0.15[v0]')
    else:
        cmd += ['-ss', f'{ss:.3f}', '-t', f'{dur + 0.1:.3f}', '-i', f'{src}.mp4']
        if mode == 'crop':
            # 405x720 window around the subject, scaled up; a slow punch-in over the cut.
            cw = 405
            vf = (f'[0:v]fps={FPS},crop={cw}:720:max(0\\,min(iw-{cw}\\,iw*{cx}-{cw}/2)):0,'
                  f'scale={W}:{H}:flags=lanczos,unsharp=5:5:0.6,eq=contrast=1.07:saturation=1.2[v0]')
        else:
            vf = (f'[0:v]fps={FPS},split[a][b];[a]scale=-2:{H},crop={W}:{H},boxblur=30:3,eq=brightness=-0.15[bg];'
                  f'[b]scale={W}:-2:flags=lanczos,eq=contrast=1.05:saturation=1.15[fg];[bg][fg]overlay=0:(H-h)/2[v0]')
    last = 'v0'
    for k, (png, a, b) in enumerate(ov.get(i, [])):
        cmd += ['-loop', '1', '-framerate', str(FPS), '-t', f'{dur}', '-i', png]
        vf += (f';[{k + 1}:v]format=rgba[o{k}];[{last}][o{k}]overlay=0:0:enable=\'between(t,{a},{b})\'[v{k + 1}]')
        last = f'v{k + 1}'
    cmd += ['-filter_complex', vf, '-map', f'[{last}]', '-t', f'{dur}', '-r', str(FPS),
            '-c:v', 'libx264', '-crf', '18', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-an', tmp]
    subprocess.run(cmd, check=True)
    os.replace(tmp, out)
    return out


def audio():
    S = {n: load(n) for n in ['beat_kick', 'beat_hat', 'beat_bass', 'beat_stab', 'firework'] + [f'huss{i}' for i in range(1, 7)]}
    mix = np.zeros(int((TOTAL + 1) * SR))

    def put(name, t, gain=1.0, pitch=1.0):
        a = S[name]
        if pitch != 1.0:
            a = np.interp(np.arange(0, len(a) - 1, pitch), np.arange(len(a)), a)
        i = int(t * SR)
        mix[i:i + len(a)] += a[:max(0, len(mix) - i)] * gain

    def groove(a, b, kick=1.0, hat=0.5, bass=0.0, stab=0.0):
        t, n = a, 0
        while t < b - 0.01:
            put('beat_kick', t, kick)
            put('beat_hat', t + BEAT / 2, hat)
            if bass and n % 2 == 0:
                put('beat_bass', t, bass, pitch=[1, 1, 0.84, 0.89][(n // 2) % 4])
            if stab and n % 4 == 3:
                put('beat_stab', t + BEAT / 2, stab)
            t, n = t + BEAT, n + 1

    groove(0, 2.0, 1.0, 0.45, 0.4)
    groove(2.0, 3.0, 0.9, 0.5, 0.9, 0.7)          # party
    groove(3.0, 10.0, 1.0, 0.5, 0.6)
    take = 0

    def huss_single(t, g=0.95):
        nonlocal take
        put(f'huss{take % 6 + 1}', t, g)
        take += 1

    def phrase(t):
        for j in range(3):
            put(f'huss{j + 1}', t + j * 0.16, 1.0)

    for b in range(int(10.0 / BEAT)):
        t = b * BEAT
        if 2.0 <= t < 3.0:
            continue
        if t in SKILL_AT:
            phrase(t)
            put('beat_stab', t, 0.5)
        else:
            huss_single(t)
    # Temptation: beat out, muffled party thump, stab when the message lands.
    put('beat_stab', 10.2, 1.0, pitch=0.8)
    for j in range(10):
        put('beat_kick', 10.5 + j * 0.2, 0.18 + j * 0.03, pitch=0.85)
    # Dawn drop.
    put('firework', 12.5, 0.9)
    groove(12.5, 13.5, 1.0, 0.5, 0.9, 0.7)
    phrase(13.5)
    put('beat_kick', 14.0, 1.0)
    put('beat_stab', 14.0, 0.8)
    mix = mix[:int(TOTAL * SR)]
    f = int(0.5 * SR)
    mix[-f:] *= np.linspace(1, 0, f)
    mix = np.tanh(mix * 1.15) * 0.92
    with wave.open('v_score.wav', 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


if __name__ == '__main__':
    import sys
    end_card()
    ov = overlays()
    only = sys.argv[1:]
    files = []
    for i, c in enumerate(CUTS):
        if not only or str(i) in only or not os.path.exists(f'v{i}.mp4'):
            render(i, c, ov)
        files.append(f'v{i}.mp4')
    open('vlist.txt', 'w').writelines(f"file '{f}'\n" for f in files)
    audio()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', 'vlist.txt', '-c', 'copy', 'v_video.mp4'], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', 'v_video.mp4', '-i', 'v_score.wav', '-map', '0:v', '-map', '1:a',
                    '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', 'huss_vertical.tmp.mp4'], check=True)
    os.replace('huss_vertical.tmp.mp4', 'huss_vertical_15s.mp4')
    print('ok')
