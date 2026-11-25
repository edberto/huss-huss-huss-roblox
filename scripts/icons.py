# Builds the 512x512 store icons in assets/icons/ (VIP pass + 5 developer products). Everything
# stays inside the circle Roblox crops pass icons to. Run: python3 scripts/icons.py
import glob, math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 512
FONT = glob.glob('/usr/share/fonts/**/Anton*.ttf', recursive=True)[0]
GOLD, GOLD_DARK, INK = (255, 205, 60), (110, 60, 10), (24, 8, 40)
PINK, CYAN, YELLOW, VIOLET = (255, 70, 200), (80, 220, 255), (255, 220, 60), (150, 90, 255)
OUT = 'assets/icons'


def background():
    """Night sky with the party's pink glow and fanned beams."""
    img = Image.new('RGB', (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            d = min(1, math.hypot(x - S / 2, y - S * 0.62) / (S * 0.62))
            a, b = PINK, (34, 14, 70)
            px[x, y] = tuple(int(a[i] * (1 - d) ** 1.6 + b[i] * (1 - (1 - d) ** 1.6)) for i in range(3))
    beams = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beams)
    for ang, col in [(-38, CYAN), (-12, YELLOW), (14, VIOLET), (40, CYAN)]:
        r = math.radians(ang)
        ox, oy = S / 2, S * 0.78
        tx, ty = ox + math.sin(r) * 600, oy - math.cos(r) * 600
        nx, ny = math.cos(r) * 14, math.sin(r) * 14
        bd.polygon([(ox - nx, oy - ny), (ox + nx, oy + ny), (tx + nx * 3, ty + ny * 3), (tx - nx * 3, ty - ny * 3)], fill=col + (70,))
    return Image.alpha_composite(img.convert('RGBA'), beams.filter(ImageFilter.GaussianBlur(4)))


def text(d, xy, s, size, fill=(255, 255, 255), stroke=7):
    d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill, anchor='mm', stroke_width=stroke, stroke_fill=INK)


def basketball(d, cx, cy, r):
    seam = (40, 20, 20)
    d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=(30, 12, 40))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 110, 30))
    w = max(4, int(r / 12))
    d.line([(cx - r, cy), (cx + r, cy)], fill=seam, width=w)
    d.line([(cx, cy - r), (cx, cy + r)], fill=seam, width=w)
    d.arc([cx - r * 1.55, cy - r, cx - r * 0.35, cy + r], -62, 62, fill=seam, width=w)
    d.arc([cx + r * 0.35, cy - r, cx + r * 1.55, cy + r], 118, 242, fill=seam, width=w)
    d.ellipse([cx - r * 0.6, cy - r * 0.75, cx - r * 0.25, cy - r * 0.45], fill=(255, 170, 100))


def coin(d, cx, cy, r):
    """A gold 'H' coin, seen slightly from above."""
    d.ellipse([cx - r - 5, cy - r * 0.62 - 5 + 10, cx + r + 5, cy + r * 0.62 + 5 + 10], fill=INK)
    d.ellipse([cx - r, cy - r * 0.62 + 10, cx + r, cy + r * 0.62 + 10], fill=GOLD_DARK)
    d.ellipse([cx - r, cy - r * 0.62, cx + r, cy + r * 0.62], fill=GOLD, outline=GOLD_DARK, width=4)
    d.ellipse([cx - r * 0.72, cy - r * 0.44, cx + r * 0.72, cy + r * 0.44], outline=(235, 170, 40), width=4)
    d.text((cx, cy), 'H', font=ImageFont.truetype(FONT, int(r * 0.75)), fill=GOLD_DARK, anchor='mm')


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.convert('RGB').save(f'{OUT}/{name}.png')


def vip():
    img = background()
    d = ImageDraw.Draw(img)
    cx, cy, r = S / 2, S * 0.675, 86
    basketball(d, cx, cy, r)
    base_y, top_y, w = cy - r + 8, cy - r - 58, 112
    crown = [(cx - w / 2, base_y), (cx - w / 2, top_y + 22), (cx - w / 4, top_y + 48), (cx, top_y),
             (cx + w / 4, top_y + 48), (cx + w / 2, top_y + 22), (cx + w / 2, base_y)]
    d.polygon(crown, fill=GOLD, outline=GOLD_DARK, width=6)
    for jx, jy, col in [(cx - w / 2, top_y + 22, CYAN), (cx, top_y, PINK), (cx + w / 2, top_y + 22, CYAN)]:
        d.ellipse([jx - 11, jy - 11, jx + 11, jy + 11], fill=col, outline=GOLD_DARK, width=4)
    text(d, (S / 2, S * 0.235), 'VIP', 124, GOLD, 11)
    text(d, (S / 2, S * 0.9), 'x2 HUSS', 50)
    save(img, 'vip_pass')


def huss_pack(name, amount, stacks):
    """Coin piles that grow with the pack size; `stacks` is coins per pile, left to right."""
    img = background()
    d = ImageDraw.Draw(img)
    r = 58
    spacing = 118
    x0 = S / 2 - spacing * (len(stacks) - 1) / 2
    base = S * 0.66
    for i, count in enumerate(stacks):
        for k in range(count):
            coin(d, x0 + i * spacing, base - k * 24, r)
    text(d, (S / 2, S * 0.22), amount, 112, GOLD, 10)
    text(d, (S / 2, S * 0.88), 'HUSS', 56)
    save(img, name)


def second_wind():
    img = background()
    d = ImageDraw.Draw(img)
    # A full focus bar with a lightning bolt: back in the game.
    bx0, by0, bx1, by1 = S * 0.2, S * 0.53, S * 0.8, S * 0.63
    d.rounded_rectangle([bx0 - 6, by0 - 6, bx1 + 6, by1 + 6], radius=28, fill=INK)
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=24, fill=(60, 60, 80))
    d.rounded_rectangle([bx0, by0, bx0 + (bx1 - bx0) * 0.55, by1], radius=24, fill=(70, 220, 160))
    cx, cy = S / 2, S * 0.43
    bolt = [(cx + 20, cy - 120), (cx - 60, cy + 10), (cx - 5, cy + 10), (cx - 30, cy + 120), (cx + 60, cy - 20), (cx + 5, cy - 20)]
    d.polygon([(x + 5, y + 6) for x, y in bolt], fill=INK)
    d.polygon(bolt, fill=YELLOW, outline=GOLD_DARK, width=6)
    text(d, (S / 2, S * 0.77), 'SECOND', 60)
    text(d, (S / 2, S * 0.875), 'WIND', 54, CYAN)
    save(img, 'second_wind')


def throw_party():
    img = background()
    d = ImageDraw.Draw(img)
    # Party popper bursting confetti.
    cx, cy = S * 0.4, S * 0.66
    cone = [(cx - 100, cy + 90), (cx + 55, cy - 95), (cx + 125, cy - 25)]
    d.polygon([(x + 5, y + 6) for x, y in cone], fill=INK)
    d.polygon(cone, fill=PINK, outline=INK, width=6)
    for t in (0.35, 0.6):
        a = (cone[0][0] + (cone[1][0] - cone[0][0]) * t, cone[0][1] + (cone[1][1] - cone[0][1]) * t)
        b = (cone[0][0] + (cone[2][0] - cone[0][0]) * t, cone[0][1] + (cone[2][1] - cone[0][1]) * t)
        d.line([a, b], fill=YELLOW, width=14)
    import random
    random.seed(7)
    mouth = (cx + 90, cy - 60)
    for _ in range(40):
        ang = random.uniform(-100, 10)
        dist = random.uniform(60, 200)
        x = mouth[0] + math.cos(math.radians(ang)) * dist
        y = mouth[1] + math.sin(math.radians(ang)) * dist
        if math.hypot(x - S / 2, y - S / 2) > 220:
            continue
        col = random.choice([PINK, CYAN, YELLOW, VIOLET, (255, 255, 255)])
        w, h = random.choice([(26, 12), (12, 26), (18, 18)])
        d.rectangle([x - w / 2, y - h / 2, x + w / 2, y + h / 2], fill=col, outline=INK, width=2)
    text(d, (S / 2, S * 0.2), 'PARTY!', 104, PINK, 10)
    text(d, (S / 2, S * 0.9), 'FOR EVERYONE', 46)
    save(img, 'throw_party')


def huss_boost():
    img = background()
    d = ImageDraw.Draw(img)
    # A glowing cyan ring with a big x2, three moons for three nights.
    cx, cy, r = S / 2, S * 0.5, 120
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([cx - r - 18, cy - r - 18, cx + r + 18, cy + r + 18], outline=CYAN + (200,), width=22)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(30, 20, 70), outline=CYAN, width=10)
    text(d, (cx, cy - 4), 'x2', 150, GOLD, 10)
    for i in range(3):
        mx, my = cx - 70 + i * 70, S * 0.79
        d.ellipse([mx - 20, my - 20, mx + 20, my + 20], fill=(255, 245, 210), outline=INK, width=4)
        d.ellipse([mx - 8, my - 26, mx + 28, my + 12], fill=(30, 20, 70))
    text(d, (S / 2, S * 0.15), 'BOOST', 84, CYAN, 9)
    text(d, (S / 2, S * 0.9), '3 NIGHTS', 46)
    save(img, 'huss_boost')


vip()
huss_boost()
huss_pack('huss_500', '500', [1, 2])
huss_pack('huss_1750', '1,750', [2, 3, 2])
huss_pack('huss_5000', '5,000', [3, 5, 3])
second_wind()
throw_party()

# Contact sheet with the circular crop, for review.
names = ['vip_pass', 'huss_500', 'huss_1750', 'huss_5000', 'second_wind', 'throw_party', 'huss_boost']
sheet = Image.new('RGB', (4 * 260, 2 * 260), (240, 240, 240))
mask = Image.new('L', (250, 250), 0)
ImageDraw.Draw(mask).ellipse([0, 0, 250, 250], fill=255)
for i, n in enumerate(names):
    icon = Image.open(f'{OUT}/{n}.png').resize((250, 250), Image.LANCZOS)
    sheet.paste(icon, (5 + (i % 4) * 260, 5 + (i // 4) * 260), mask)
sheet.save('/tmp/icon_sheet.png')
print('ok')
