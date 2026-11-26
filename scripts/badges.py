# Builds the 512x512 badge icons in assets/badges/ (same night-sky style as the store icons).
# Roblox crops badge icons to a circle, so the art and label stay inside it.
# Run: python3 scripts/badges.py   (also writes .trailer/badges_sheet.png to preview them)
import math, os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from icons import CYAN, GOLD, GOLD_DARK, INK, PINK, S, VIOLET, YELLOW, background, basketball, text  # noqa: E402

OUT = 'assets/badges'


def label(d, s, size=54):
    text(d, (S / 2, 392), s, size, stroke=8)


def station(img, name):
    art = Image.open(f'assets/ui/station_{name}.png').convert('RGBA').resize((250, 250), Image.LANCZOS)
    img.alpha_composite(art, (131, 92))


def make(name, draw):
    img = background()
    draw(img, ImageDraw.Draw(img))
    os.makedirs(OUT, exist_ok=True)
    img.convert('RGB').save(f'{OUT}/{name}.png')
    return img


def welcome(img, d):
    basketball(d, S / 2, 215, 110)
    label(d, 'WELCOME!')


def first_dawn(img, d):
    cx, cy = S / 2, 290
    for i in range(9):
        a = math.radians(180 + i * 22.5)
        d.line([(cx + math.cos(a) * 125, cy + math.sin(a) * 125), (cx + math.cos(a) * 175, cy + math.sin(a) * 175)], fill=YELLOW, width=16)
    d.pieslice([cx - 115, cy - 115, cx + 115, cy + 115], 180, 360, fill=(255, 170, 40), outline=INK, width=8)
    d.rectangle([90, cy, S - 90, cy + 14], fill=INK)
    label(d, 'FIRST DAWN')


def combo(img, d):
    text(d, (S / 2, 215), 'x50', 190, fill=GOLD, stroke=12)
    label(d, 'COMBO!')


def gave_in(img, d):
    cx, cy, r = S / 2, 205, 105  # disco ball
    d.line([(cx, 40), (cx, cy - r)], fill=INK, width=8)
    d.ellipse([cx - r - 7, cy - r - 7, cx + r + 7, cy + r + 7], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(190, 200, 230))
    for k in range(-4, 5):
        y = cy + k * r / 5
        w = math.sqrt(max(0, r * r - (y - cy) ** 2))
        d.line([(cx - w, y), (cx + w, y)], fill=(110, 110, 150), width=4)
        x = cx + k * r / 5
        h = math.sqrt(max(0, r * r - (x - cx) ** 2))
        d.line([(x, cy - h), (x, cy + h)], fill=(110, 110, 150), width=4)
    for (x, y, c) in [(cx - 50, cy - 50, PINK), (cx + 30, cy - 20, CYAN), (cx - 10, cy + 40, YELLOW)]:
        d.rectangle([x, y, x + 20, y + 20], fill=c)
    label(d, "CAN'T RESIST", 50)


def _unused_speaker(img, d):
    x0, y0, w, h = S / 2 - 85, 85, 170, 240  # speaker
    d.rounded_rectangle([x0 - 7, y0 - 7, x0 + w + 7, y0 + h + 7], 26, fill=INK)
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], 20, fill=VIOLET)
    for cy, r in [(y0 + 62, 38), (y0 + 160, 60)]:
        d.ellipse([S / 2 - r - 6, cy - r - 6, S / 2 + r + 6, cy + r + 6], fill=INK)
        d.ellipse([S / 2 - r, cy - r, S / 2 + r, cy + r], fill=PINK)
        d.ellipse([S / 2 - r * 0.35, cy - r * 0.35, S / 2 + r * 0.35, cy + r * 0.35], fill=INK)
    for side in (-1, 1):
        for k in (1, 2):
            rr = 120 + k * 30
            box = [S / 2 - rr, 205 - rr, S / 2 + rr, 205 + rr]
            d.arc(box, -25 if side > 0 else 155, 25 if side > 0 else 205, fill=CYAN, width=10)
    label(d, 'LIFE OF THE PARTY', 44)


def level_badge(station_name, level, title):
    def draw(img, d):
        station(img, station_name)
        col = GOLD if level >= 100 else (255, 255, 255)
        text(d, (S / 2 + 118, 118), f'LV {level}', 58, fill=col, stroke=8)
        label(d, title, 50 if len(title) < 14 else 42)
    return draw


def rank(title, stars):
    def draw(img, d):
        cx, cy = S / 2, 205
        pts = []
        for i in range(10):  # a big star
            a = math.radians(-90 + i * 36)
            r = 130 if i % 2 == 0 else 58
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        d.polygon(pts, fill=GOLD, outline=INK, width=10)
        text(d, (cx, cy + 12), str(stars), 80, fill=GOLD_DARK, stroke=0)
        label(d, title)
    return draw


def drag_in(count, title):
    def draw(img, d):
        # a hand pulling: an arrow curving into the party, with the count
        d.arc([110, 90, 400, 330], 200, 340, fill=PINK, width=26)
        d.polygon([(395, 175), (430, 250), (350, 235)], fill=PINK)
        text(d, (S / 2, 245), str(count), 120 if count < 100 else 100, fill=CYAN, stroke=10)
        label(d, title, 50 if len(title) < 14 else 42)
    return draw


def hype(points, title):
    def draw(img, d):
        for i, col in enumerate([PINK, CYAN, YELLOW]):
            x = 150 + i * 106
            d.ellipse([x - 52, 110 - i % 2 * 25, x + 52, 230 - i % 2 * 25], fill=col, outline=INK, width=8)
            d.line([(x, 230 - i % 2 * 25), (x + 10, 300)], fill=INK, width=5)
        text(d, (S / 2, 300), f'{points:,}', 76, fill=GOLD, stroke=9)
        label(d, title)
    return draw


def party_starter(img, d):
    text(d, (S / 2, 200), 'PARTY!', 130, fill=PINK, stroke=12)
    label(d, 'PARTY STARTER', 48)


def full_house(img, d):
    for i in range(5):  # a row of houses, all lit pink
        x = 76 + i * 72
        d.rectangle([x, 190, x + 60, 270], fill=PINK, outline=INK, width=6)
        d.polygon([(x - 6, 192), (x + 30, 150), (x + 66, 192)], fill=VIOLET, outline=INK, width=6)
        d.rectangle([x + 20, 215, x + 40, 240], fill=YELLOW)
    for (x, y, c) in [(130, 100, CYAN), (256, 80, YELLOW), (380, 105, PINK)]:
        for k in range(8):
            a = math.radians(k * 45)
            d.line([(x, y), (x + math.cos(a) * 34, y + math.sin(a) * 34)], fill=c, width=7)
    label(d, 'FULL HOUSE')


STATIONS = [
    ('basketball', 'Basketball', ['ROOKIE BALLER', 'BALLER', 'HOOPER', 'ALL-STAR', 'MVP', 'HALL OF FAME', 'GOAT BALLER']),
    ('gym', 'Gym', ['ROOKIE LIFTER', 'GYM RAT', 'IRON PUMPER', 'POWERLIFTER', 'BEAST MODE', 'TITAN', 'GYM LEGEND']),
    ('burgers', 'Burgers', ['LINE COOK', 'SHORT-ORDER', 'GRILL MASTER', 'HEAD CHEF', 'EXEC CHEF', 'IRON CHEF', 'MASTER CHEF']),
]
LEVELS = [5, 10, 25, 50, 100, 150, 200]

BADGES = [
    ('welcome', welcome),
    ('first_dawn', first_dawn),
    ('party_starter', party_starter),
    ('life_of_party', drag_in(1, 'LIFE OF THE PARTY')),
    ('cant_resist', gave_in),
    ('combo_50', combo),
    ('bad_influence', drag_in(10, 'BAD INFLUENCE')),
    ('peer_pressure', drag_in(50, 'PEER PRESSURE')),
    ('party_legend', drag_in(250, 'PARTY LEGEND')),
    ('hype_crew', hype(1000, 'HYPE CREW')),
    ('hype_machine', hype(10000, 'HYPE MACHINE')),
    ('full_house', full_house),
    ('rank_grinder', rank('GRINDER', 1)),
    ('rank_locked_in', rank('LOCKED IN', 2)),
    ('rank_pro', rank('PRO', 3)),
    ('rank_legend', rank('LEGEND', 4)),
    ('rank_goat', rank('GOAT', 5)),
] + [
    (f'{key}_{lv}', level_badge(art, lv, title))
    for art, key, titles in STATIONS
    for lv, title in zip(LEVELS, titles)
]

if __name__ == '__main__':
    imgs = [make(name, draw) for name, draw in BADGES]
    cols = 7
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * 270 + 10, rows * 270 + 10), (20, 14, 30))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S, S], fill=255)
    for i, img in enumerate(imgs):
        round_ = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        round_.paste(img, (0, 0), mask)
        sheet.paste(round_.resize((260, 260), Image.LANCZOS), (10 + (i % cols) * 270, 10 + (i // cols) * 270), round_.resize((260, 260), Image.LANCZOS))
    os.makedirs('.trailer', exist_ok=True)
    sheet.save('.trailer/badges_sheet.png')
