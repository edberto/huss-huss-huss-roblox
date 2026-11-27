# Launch Night event thumbnail (1920x1080): the store thumbnail, softened and darkened, with
# fireworks and the event title. Run: python3 scripts/event_thumb.py [out.png]
import glob, math, random, sys
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1920, 1080
F = glob.glob('/usr/share/fonts/**/Anton*.ttf', recursive=True)[0]
INK = (16, 14, 40)

base = Image.open('assets/thumbnail.png').convert('RGB').resize((W, H))
base = ImageEnhance.Color(ImageEnhance.Brightness(base.filter(ImageFilter.GaussianBlur(40))).enhance(0.55)).enhance(1.4)
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
random.seed(5)
for cx, cy, r, col in [(330, 230, 170, (255, 90, 200)), (1600, 210, 190, (80, 220, 255)),
                       (1500, 820, 150, (255, 205, 60)), (380, 860, 140, (120, 255, 170))]:
    for k in range(18):  # a firework burst: rays with a dot at the end
        a = 2 * math.pi * k / 18 + random.random() * 0.1
        x1, y1 = cx + math.cos(a) * r * 0.35, cy + math.sin(a) * r * 0.35
        x2, y2 = cx + math.cos(a) * r, cy + math.sin(a) * r
        g.line([(x1, y1), (x2, y2)], fill=col + (230,), width=7)
        g.ellipse([x2 - 9, y2 - 9, x2 + 9, y2 + 9], fill=col + (255,))
glow = glow.filter(ImageFilter.GaussianBlur(1.2))
out = Image.alpha_composite(base.convert('RGBA'), glow)
d = ImageDraw.Draw(out)


def text(xy, s, size, fill, stroke=12):
    d.text(xy, s, font=ImageFont.truetype(F, size), fill=fill, anchor='mm', stroke_width=stroke, stroke_fill=INK)


text((W / 2, 250), 'HUSS HUSS HUSS', 120, (255, 255, 255), 10)
text((W / 2, 520), 'LAUNCH NIGHT', 270, (255, 214, 60), 18)
# date ribbon
d.rounded_rectangle([W / 2 - 330, 720, W / 2 + 330, 850], 40, fill=(255, 90, 200), outline=INK, width=10)
text((W / 2, 785), '5 DECEMBER', 92, (255, 255, 255), 8)
out.convert('RGB').save(sys.argv[1] if len(sys.argv) > 1 else 'assets/event_launch.png')
