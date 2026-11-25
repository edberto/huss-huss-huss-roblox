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
