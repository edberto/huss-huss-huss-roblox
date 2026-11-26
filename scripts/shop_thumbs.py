# Builds the 256x256 shop thumbnails in assets/shop/ (one per cosmetic, same night-sky style as
# the store icons). Square: the shop shows them in a square tile. Run: python3 scripts/shop_thumbs.py
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from icons import FONT, INK, S, background  # noqa: E402

OUT = 'assets/shop'
T = 256


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def canvas():
    return background()  # 512, scaled down on save


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.convert('RGB').resize((T, T), Image.LANCZOS).save(f'{OUT}/{name}.png')


def glow(img, draw_fn, radius=14):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius)))
    img.alpha_composite(layer)


def ball(d, cx, cy, r, color):
    seam = tuple(max(0, c // 4) for c in color)
    hi = tuple(min(255, c + 90) for c in color)
    d.ellipse([cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    w = max(5, int(r / 11))
    d.line([(cx - r, cy), (cx + r, cy)], fill=seam, width=w)
    d.line([(cx, cy - r), (cx, cy + r)], fill=seam, width=w)
    d.arc([cx - r * 1.55, cy - r, cx - r * 0.35, cy + r], -62, 62, fill=seam, width=w)
    d.arc([cx + r * 0.35, cy - r, cx + r * 1.55, cy + r], 118, 242, fill=seam, width=w)
    d.ellipse([cx - r * 0.6, cy - r * 0.75, cx - r * 0.25, cy - r * 0.45], fill=hi)


def trail(name, a, b):
    """A ball streaking across, leaving a ribbon that fades from colour b (tail) to a (head)."""
    img = canvas()
    a, b = hexrgb(a), hexrgb(b)
    pts = [(40 + t * 300, 380 - math.sin(t * math.pi * 0.9) * 170 - t * 60) for t in [i / 80 for i in range(81)]]

    def ribbon(d):
        for i, (x, y) in enumerate(pts):
            t = i / (len(pts) - 1)
            col = tuple(int(b[k] * (1 - t) + a[k] * t) for k in range(3))
            r = 14 + 44 * t
            d.ellipse([x - r, y - r, x + r, y + r], fill=col + (int(80 + 175 * t),))

    glow(img, ribbon, 18)
    d = ImageDraw.Draw(img)
    hx, hy = pts[-1]
    ball(d, hx + 20, hy - 10, 70, (240, 110, 30))
    save(img, name)


def title(name, text):
    """The overhead tag on a dark plate, in its own green."""
    img = canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 170, 472, 342], 36, fill=(20, 10, 40), outline=INK, width=10)
    d.rounded_rectangle([52, 182, 460, 330], 28, outline=(61, 255, 176), width=5)
    words = text.upper().split()
    lines = [text.upper()] if len(text) <= 9 else [' '.join(words[: len(words) // 2 or 1]), ' '.join(words[len(words) // 2 or 1:])]
    size = 108 if len(lines) == 1 else 70
    for i, line in enumerate(lines):
        y = 256 + (i - (len(lines) - 1) / 2) * (size * 1.0)
        d.text((256, y), line, font=ImageFont.truetype(FONT, size), fill=(61, 255, 176), anchor='mm',
               stroke_width=6, stroke_fill=INK)
    save(img, name)


def ball_skin(name, color, shine):
    img = canvas()
    col = hexrgb(color)
    glow(img, lambda d: d.ellipse([110, 110, 402, 402], fill=col + (200,)), 30 if shine else 10)
    ball(ImageDraw.Draw(img), 256, 256, 130, col)
    save(img, name)


# Dancer poses: angles in degrees (0 = straight down, positive = toward the dancer's left/our right)
# for upper arm, forearm, thigh and shin on each side, plus a body lean.
POSES = {
    'dance_groove': dict(lean=-8, la=(-120, -170), ra=(60, 20), ll=(-20, 0), rl=(25, 10)),
    'dance_shuffle': dict(lean=5, la=(-70, -30), ra=(70, 30), ll=(-35, 10), rl=(40, -40)),
    'dance_bounce': dict(lean=0, la=(-120, -60), ra=(120, 60), ll=(-30, 25), rl=(30, -25)),
    'dance_cheer': dict(lean=0, la=(-150, -160), ra=(150, 160), ll=(-18, 0), rl=(18, 0)),
    'dance_hype': dict(lean=-6, la=(-90, -170), ra=(140, 170), ll=(-35, 0), rl=(30, 45)),
    'dance_floss': dict(lean=-10, la=(55, 75), ra=(35, 85), ll=(-12, 0), rl=(12, 0)),
    'dance_robot': dict(lean=0, la=(-90, 0), ra=(90, 180), ll=(-10, 0), rl=(10, 0)),
    'dance_celebrate': dict(lean=-4, la=(-150, -170), ra=(120, 170), ll=(-60, 40), rl=(20, -10)),
}


def dancer(name, color):
    img = canvas()
    col = hexrgb(color)
    # Spotlight cone and floor pool in the dance's colour.
    glow(img, lambda d: (d.polygon([(256, 0), (120, 450), (392, 450)], fill=col + (60,)),
                         d.ellipse([110, 420, 402, 480], fill=col + (170,))), 16)
    p = POSES[name]
    d = ImageDraw.Draw(img)
    hip, lean = (256, 320), math.radians(p['lean'])
    neck = (hip[0] + math.sin(lean) * 125, hip[1] - math.cos(lean) * 125)

    def limb(start, a1, a2, l1, l2):
        r1, r2 = math.radians(a1), math.radians(a2)
        mid = (start[0] + math.sin(r1) * l1, start[1] + math.cos(r1) * l1)
        end = (mid[0] + math.sin(r2) * l2, mid[1] + math.cos(r2) * l2)
        return [start, mid, end]

    shoulder = (neck[0] + math.sin(lean) * -10, neck[1] + 12)
    parts = [[hip, neck],
             limb(shoulder, *p['la'], 72, 66), limb(shoulder, *p['ra'], 72, 66),
             limb(hip, *p['ll'], 70, 66), limb(hip, *p['rl'], 70, 66)]
    for width, fill in [(40, INK), (24, (255, 255, 255))]:
        for part in parts:
            d.line(part, fill=fill, width=width, joint='curve')
            for x, y in (part[0], part[-1]):
                d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=fill)
    head = (neck[0] + math.sin(lean) * 52, neck[1] - 52)
    d.ellipse([head[0] - 44, head[1] - 44, head[0] + 44, head[1] + 44], fill=(255, 255, 255), outline=INK, width=8)
    save(img, name)


def party_animal():
    img = Image.open('assets/icons/party_animal.png').convert('RGBA')
    save(img, 'perk_party_animal')


if __name__ == '__main__':
    for n, a, b in [('trail_mint', '3DFFB0', '3DFFB0'), ('trail_fire', 'FF6B1A', 'FFB547'),
                    ('trail_ice', '85B7EB', 'F2EEDC'), ('trail_party', 'FF2E93', '8A3CFF'),
                    ('trail_gold', 'FAC775', 'FFB547'), ('trail_streak', '3DFFB0', 'FF2E93')]:
        trail(n, a, b)
    for n, t in [('title_hooper', 'Hooper'), ('title_gymrat', 'Gym Rat'), ('title_burgerboss', 'Burger Boss'),
                 ('title_neverpartied', 'Never Partied'), ('title_legend', 'Huss Legend')]:
        title(n, t)
    ball_skin('ball_glow', 'FF6B1A', True)
    ball_skin('ball_party', 'FF2E93', True)
    ball_skin('ball_gold', 'FAC775', True)
    for n, c in [('dance_groove', '8A3CFF'), ('dance_shuffle', '50C3FF'), ('dance_bounce', '5AD278'),
                 ('dance_cheer', 'FFD246'), ('dance_hype', 'FF6B1A'), ('dance_floss', 'FF2E93'),
                 ('dance_robot', '85B7EB'), ('dance_celebrate', 'FAC775')]:
        dancer(n, c)
    party_animal()
    names = sorted(f[:-4] for f in os.listdir(OUT))
    sheet = Image.new('RGB', (6 * 170, math.ceil(len(names) / 6) * 170), (240, 240, 240))
    for i, n in enumerate(names):
        sheet.paste(Image.open(f'{OUT}/{n}.png').resize((160, 160)), (5 + (i % 6) * 170, 5 + (i // 6) * 170))
    sheet.save('/tmp/shop_sheet.png')
    print(len(names), 'thumbs')
