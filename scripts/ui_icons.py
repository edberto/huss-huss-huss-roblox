# Side-button icons (white glyphs, dark outline, transparent) in assets/ui/. Run: python3 scripts/ui_icons.py
import os
from PIL import Image, ImageDraw

S, INK, W = 256, (24, 8, 40, 255), (255, 255, 255, 255)
os.makedirs('assets/ui', exist_ok=True)


def icon(name, draw):
    img = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))
    draw(ImageDraw.Draw(img), S, S)
    img.resize((S, S), Image.LANCZOS).save(f'assets/ui/{name}.png')


def stroke_line(d, pts, w, fill=W):
    d.line(pts, fill=INK, width=w + 28, joint='curve')
    d.line(pts, fill=fill, width=w, joint='curve')


def cart(d, cx, cy):
    pts = [(cx - 190, cy - 130), (cx - 120, cy - 130), (cx - 60, cy + 70), (cx + 150, cy + 70), (cx + 200, cy - 70), (cx - 95, cy - 70)]
    stroke_line(d, pts, 44)
    for wx in (cx - 40, cx + 130):
        d.ellipse([wx - 50, cy + 110, wx + 50, cy + 210], fill=W, outline=INK, width=16)


def calendar(d, cx, cy):
    d.rounded_rectangle([cx - 190, cy - 160, cx + 190, cy + 200], 40, fill=W, outline=INK, width=18)
    d.rounded_rectangle([cx - 180, cy - 150, cx + 180, cy - 50], 30, fill=(255, 70, 90, 255))
    d.line([(cx - 180, cy - 50), (cx + 180, cy - 50)], fill=INK, width=14)
    for rx in (cx - 100, cx + 100):
        d.rounded_rectangle([rx - 22, cy - 210, rx + 22, cy - 110], 14, fill=W, outline=INK, width=12)
    stroke_line(d, [(cx - 95, cy + 70), (cx - 20, cy + 140), (cx + 110, cy - 5)], 40, (40, 180, 90, 255))


def gift(d, cx, cy):
    d.rectangle([cx - 170, cy - 30, cx + 170, cy + 200], fill=W, outline=INK, width=18)
    d.rectangle([cx - 200, cy - 110, cx + 200, cy - 20], fill=W, outline=INK, width=18)
    d.rectangle([cx - 35, cy - 110, cx + 35, cy + 200], fill=(255, 220, 60, 255), outline=INK, width=14)
    for sx in (-1, 1):
        d.ellipse([cx + sx * 95 - 85, cy - 220, cx + sx * 95 + 85, cy - 110], outline=INK, width=44)
        d.ellipse([cx + sx * 95 - 72, cy - 207, cx + sx * 95 + 72, cy - 123], outline=W, width=20)


def metronome(d, cx, cy):
    d.polygon([(cx - 170, cy + 200), (cx - 80, cy - 200), (cx + 80, cy - 200), (cx + 170, cy + 200)], fill=W, outline=INK, width=18)
    d.rectangle([cx - 150, cy + 110, cx + 150, cy + 130], fill=INK)
    d.line([(cx, cy + 120), (cx + 120, cy - 170)], fill=INK, width=34)
    d.ellipse([cx + 25, cy - 75, cx + 105, cy + 5], fill=(255, 200, 40, 255), outline=INK, width=14)


for name, fn in (('shop', cart), ('daily', calendar), ('gifts', gift), ('timing', metronome)):
    icon(name, fn)
print('ok')


# Practice picker art (512, transparent): basketball, dumbbell, burger.
def station(name, draw):
    img = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    draw(ImageDraw.Draw(img), 512, 512)
    img.resize((512, 512), Image.LANCZOS).save(f'assets/ui/station_{name}.png')


def basketball(d, cx, cy):
    r, w, seam = 380, 26, INK
    d.ellipse([cx - r - 30, cy - r - 30, cx + r + 30, cy + r + 30], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(245, 120, 35, 255))
    d.ellipse([cx - r * 0.85, cy - r * 0.9, cx + r * 0.6, cy + r * 0.5], fill=(255, 145, 60, 255))
    d.line([(cx - r, cy), (cx + r, cy)], fill=seam, width=w)
    d.line([(cx, cy - r), (cx, cy + r)], fill=seam, width=w)
    d.arc([cx - r * 1.55, cy - r, cx - r * 0.35, cy + r], -62, 62, fill=seam, width=w)
    d.arc([cx + r * 0.35, cy - r, cx + r * 1.55, cy + r], 118, 242, fill=seam, width=w)
    d.ellipse([cx - r * 0.62, cy - r * 0.72, cx - r * 0.3, cy - r * 0.45], fill=(255, 205, 150, 255))


def dumbbell(d, cx, cy):
    d.rounded_rectangle([cx - 420, cy - 45, cx + 420, cy + 45], 30, fill=(205, 210, 225, 255), outline=INK, width=26)
    d.rectangle([cx - 400, cy - 30, cx + 400, cy - 12], fill=(240, 244, 255, 255))
    for sx in (-1, 1):
        for k, (w, h) in enumerate(((110, 440), (100, 330))):
            x = cx + sx * (230 + k * 115)
            d.rounded_rectangle([x - w / 2, cy - h / 2, x + w / 2, cy + h / 2], 34, fill=(70, 72, 100, 255), outline=INK, width=26)
            d.rounded_rectangle([x - w / 2 + 24, cy - h / 2 + 30, x - w / 2 + 46, cy + h / 2 - 30], 10, fill=(120, 124, 160, 255))


def burger(d, cx, cy):
    def layer(box, fill, rad):
        d.rounded_rectangle(box, rad, fill=fill, outline=INK, width=24)
    d.chord([cx - 400, cy - 400, cx + 400, cy + 40], 180, 360, fill=(240, 170, 70, 255), outline=INK, width=26)
    for k in range(6):
        sx = cx - 230 + k * 92
        d.ellipse([sx, cy - 280 + (k % 2) * 40, sx + 34, cy - 256 + (k % 2) * 40], fill=(255, 240, 200, 255))
    layer([cx - 420, cy - 200, cx + 420, cy - 120], (90, 195, 70, 255), 40)
    layer([cx - 400, cy - 120, cx + 400, cy - 10], (130, 65, 35, 255), 50)
    d.polygon([(cx - 400, cy - 10), (cx + 400, cy - 10), (cx + 300, cy + 60), (cx + 150, cy + 20), (cx - 50, cy + 70), (cx - 330, cy + 40)], fill=(255, 210, 60, 255), outline=INK)
    layer([cx - 390, cy + 30, cx + 390, cy + 170], (235, 160, 60, 255), 70)


for name, fn in (('basketball', basketball), ('gym', dumbbell), ('burgers', burger)):
    station(name, fn)
print('stations ok')
