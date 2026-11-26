# Builds the 512x512 store icons in assets/icons/ (VIP pass + 5 developer products). Everything
# stays inside the circle Roblox crops pass icons to. Run: python3 scripts/icons.py
import glob, math, os
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageFilter

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


def game_icon():
    """Experience icon: sigma-faced trainer, unbothered while a partier blasts a horn in his ear. 512x512 square."""
    import random
    random.seed(7)
    B = 2 * S  # draw at 2x, downscale for smooth edges
    BLK, TAN, TAN_D = (0, 0, 0), (255, 204, 110), (245, 200, 165)
    # radial party glow behind the trainer
    img = Image.new('RGB', (B, B))
    px = img.load()
    for y in range(0, B, 2):
        for x in range(0, B, 2):
            t = min(1, math.hypot(x - 420, y - 640) / 780) ** 0.9
            c = tuple(int(a * (1 - t) + b * t) for a, b in zip((255, 90, 200), (50, 15, 110)))
            px[x, y] = px[x + 1, y] = px[x, y + 1] = px[x + 1, y + 1] = c
    img = img.convert('RGBA')
    fx = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx)
    for ang, col in [(-50, (0, 220, 255)), (-22, (255, 60, 220)), (10, (255, 230, 40)), (38, (0, 220, 255)), (62, (255, 60, 220))]:
        r = math.radians(ang)
        ox, oy, n = 420, 1150, 30
        tx, ty = ox + math.sin(r) * 1400, oy - math.cos(r) * 1400
        nx, ny = math.cos(r) * n, math.sin(r) * n
        fd.polygon([(ox - nx, oy - ny), (ox + nx, oy + ny), (tx + nx * 3, ty + ny * 3), (tx - nx * 3, ty - ny * 3)], fill=col + (95,))
    img.alpha_composite(fx.filter(ImageFilter.GaussianBlur(6)))
    sp = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    for k in range(40):
        a = k * math.tau / 40 + random.uniform(-0.04, 0.04)
        w = random.uniform(0.012, 0.03)
        cx, cy = 330, 640
        sd.polygon([(cx + math.cos(a) * 330, cy + math.sin(a) * 330), (cx + math.cos(a - w) * 1500, cy + math.sin(a - w) * 1500),
                    (cx + math.cos(a + w) * 1500, cy + math.sin(a + w) * 1500)], fill=(255, 255, 255, 120))
    img.alpha_composite(sp)
    d = ImageDraw.Draw(img)
    for cx, cy in [(60, 470), (130, 330), (980, 250), (900, 120), (70, 720), (990, 980), (640, 300), (30, 150)]:
        col = random.choice([(0, 220, 255), (255, 230, 40), (120, 255, 140), (255, 255, 255)])
        sz, a = random.randint(18, 30), random.uniform(0, math.pi)
        pts = [(cx + sz * math.cos(a + k * math.pi / 2), cy + sz * math.sin(a + k * math.pi / 2)) for k in range(4)]
        d.polygon(pts, fill=col, outline=BLK, width=4)

    # partier (behind): bigger, tongue-out grin, jaunty hat, glow stick with halo
    halo = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    ImageDraw.Draw(halo).line([(975, 560), (1000, 250)], fill=(60, 255, 120, 200), width=70)
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    d.line([(975, 560), (1000, 250)], fill=BLK, width=46)
    d.line([(975, 560), (1000, 250)], fill=(60, 255, 120), width=28)
    d.rounded_rectangle([690, 400, 990, 700], 44, fill=TAN_D, outline=BLK, width=14)
    d.polygon([(720, 420), (760, 210), (900, 395)], fill=PINK, outline=BLK, width=12)
    d.ellipse([735, 185, 785, 235], fill=(255, 230, 40), outline=BLK, width=8)
    d.rounded_rectangle([720, 480, 830, 545], 20, fill=BLK)
    d.rounded_rectangle([850, 480, 960, 545], 20, fill=BLK)
    d.line([(735, 495), (770, 495)], fill=(120, 120, 160), width=8)
    d.chord([740, 580, 950, 680], 0, 180, fill=(255, 255, 255), outline=BLK, width=12)


    # trainer head on its own layer, tilted, bleeding off the bottom
    H = 760
    head = Image.new('RGBA', (H + 200, H + 200), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head)
    o = 100
    hd.rounded_rectangle([o, o, o + H, o + H], 110, fill=TAN, outline=BLK, width=18)
    hd.rectangle([o + 9, o + 90, o + H - 9, o + 200], fill=(230, 40, 60))
    hd.line([(o + 9, o + 90), (o + H - 9, o + 90)], fill=BLK, width=12)
    hd.line([(o + 9, o + 200), (o + H - 9, o + 200)], fill=BLK, width=12)
    hd.polygon([(o + H - 20, o + 120), (o + H + 90, o + 60), (o + H + 70, o + 170)], fill=(230, 40, 60), outline=BLK, width=10)
    # sigma face: low flat brows, heavy-lidded narrow eyes glancing aside, chiselled cheekbones and jaw, flat mouth
    shadow = Image.new('RGBA', head.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    SH = (150, 80, 30, 150)
    sd.polygon([(o + 30, o + 520), (o + 230, o + 600), (o + 200, o + 730), (o + 60, o + 700)], fill=SH)  # cheek hollows
    sd.polygon([(o + H - 30, o + 520), (o + H - 230, o + 600), (o + H - 200, o + 730), (o + H - 60, o + 700)], fill=SH)
    sd.polygon([(o + 60, o + 700), (o + 250, o + 760), (o + H - 250, o + 760), (o + H - 60, o + 700),
                (o + H - 40, o + H - 20), (o + 40, o + H - 20)], fill=SH)  # jaw shadow under a hard jawline
    sd.polygon([(o + 380, o + 420), (o + 400, o + 600), (o + 360, o + 610)], fill=SH)  # nose side
    clip = Image.new('L', head.size, 0)
    ImageDraw.Draw(clip).rounded_rectangle([o + 9, o + 9, o + H - 9, o + H - 9], 100, fill=255)
    shadow.putalpha(ImageChops.darker(shadow.getchannel('A'), clip))
    head.alpha_composite(shadow)
    hd = ImageDraw.Draw(head)
    hd.line([(o + 60, o + 700), (o + 250, o + 765), (o + H - 250, o + 765), (o + H - 60, o + 700)], fill=BLK, width=12)
    hd.line([(o + 90, o + 300), (o + 330, o + 320), (o + 345, o + 345)], fill=BLK, width=40)
    hd.line([(o + H - 90, o + 300), (o + H - 330, o + 320), (o + H - 345, o + 345)], fill=BLK, width=40)
    for ex0 in (o + 105, o + 425):
        hd.chord([ex0, o + 330, ex0 + 230, o + 470], 0, 180, fill=(255, 255, 255), outline=BLK, width=12)
        hd.line([(ex0 - 5, o + 400), (ex0 + 235, o + 395)], fill=BLK, width=22)  # heavy upper lid
        hd.chord([ex0 + 140, o + 375, ex0 + 210, o + 445], 0, 180, fill=BLK)  # pupil glancing to his left
    hd.line([(o + 375, o + 600), (o + 410, o + 600)], fill=BLK, width=10)  # nose base
    hd.line([(o + 300, o + 665), (o + 470, o + 660)], fill=BLK, width=14)  # flat, unbothered mouth
    head = head.rotate(-3, resample=Image.BICUBIC, expand=True)
    head = head.resize((int(head.width * 0.74), int(head.height * 0.74)), Image.LANCZOS)
    img.alpha_composite(head, (-20, 290))
    d = ImageDraw.Draw(img)

    # partier's party horn blasting in his ear (he doesn't flinch)
    horn = [(830, 640), (615, 690), (650, 815)]
    d.polygon(horn, fill=(255, 230, 40))
    d.line([(735, 668), (755, 735)], fill=PINK, width=18)
    d.line([(680, 680), (705, 770)], fill=(0, 220, 255), width=18)
    d.polygon(horn, outline=BLK, width=12)

    # HUSS!: yellow, black outline, pink drop shadow, tilted
    t = Image.new('RGBA', (B, 360), (0, 0, 0, 0))
    td = ImageDraw.Draw(t)
    f = ImageFont.truetype(FONT, 280)
    td.text((B / 2 - 60 + 16, 185 + 16), 'HUSS!', font=f, fill=(255, 60, 170), anchor='mm', stroke_width=26, stroke_fill=(255, 60, 170))
    td.text((B / 2 - 60, 185), 'HUSS!', font=f, fill=(255, 230, 40), anchor='mm', stroke_width=26, stroke_fill=BLK)
    img.alpha_composite(t.rotate(7, resample=Image.BICUBIC), (0, 0))
    img.resize((S, S), Image.LANCZOS).convert('RGB').save('assets/icon.png')

def ticket(w, h, angle, fill, label, label_size):
    """A tilted ticket with notched ends and a label."""
    tile = Image.new('RGBA', (int(w) + 40, int(h) + 40), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    x0, y0, x1, y1 = 20, 20, 20 + w, 20 + h
    td.rounded_rectangle([x0 + 6, y0 + 8, x1 + 6, y1 + 8], 18, fill=INK)
    td.rounded_rectangle([x0, y0, x1, y1], 18, fill=fill, outline=INK, width=7)
    for nx in (x0, x1):
        td.ellipse([nx - 18, (y0 + y1) / 2 - 18, nx + 18, (y0 + y1) / 2 + 18], fill=(0, 0, 0, 0), outline=INK, width=7)
    td.line([(x0 + w * 0.28, y0 + 14), (x0 + w * 0.28, y1 - 14)], fill=INK, width=4)
    td.text(((x0 + w * 0.28 + x1) / 2, (y0 + y1) / 2), label, font=ImageFont.truetype(FONT, label_size), fill=INK, anchor='mm')
    return tile.rotate(angle, resample=Image.BICUBIC, expand=True)


def party_animal():
    img = background()
    back = ticket(250, 120, 18, CYAN, 'PARTY', 56)
    front = ticket(280, 130, -10, YELLOW, 'PARTY', 64)
    img.alpha_composite(back, (int(S * 0.5 - back.width / 2 + 40), int(S * 0.52 - back.height / 2 - 30)))
    img.alpha_composite(front, (int(S * 0.5 - front.width / 2 - 20), int(S * 0.6 - front.height / 2 + 20)))
    d = ImageDraw.Draw(img)
    text(d, (S / 2, S * 0.21), 'PARTY ANIMAL', 60, PINK, 9)
    text(d, (S / 2, S * 0.9), 'SKIP PRACTICE', 46)
    save(img, 'party_animal')



if __name__ == '__main__':
    vip()
    game_icon()
    huss_boost()
    huss_pack('huss_500', '500', [1, 2])
    huss_pack('huss_1750', '1,750', [2, 3, 2])
    huss_pack('huss_5000', '5,000', [3, 5, 3])
    second_wind()
    throw_party()
    party_animal()

    # Contact sheet with the circular crop, for review.
    names = ['vip_pass', 'huss_500', 'huss_1750', 'huss_5000', 'second_wind', 'throw_party', 'huss_boost', 'party_animal']
    sheet = Image.new('RGB', (4 * 260, 2 * 260), (240, 240, 240))
    mask = Image.new('L', (250, 250), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 250, 250], fill=255)
    for i, n in enumerate(names):
        icon = Image.open(f'{OUT}/{n}.png').resize((250, 250), Image.LANCZOS)
        sheet.paste(icon, (5 + (i % 4) * 260, 5 + (i // 4) * 260), mask)
    sheet.save('/tmp/icon_sheet.png')
    print('ok')
