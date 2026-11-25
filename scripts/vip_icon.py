# Builds assets/vip_pass.png (512x512): VIP game-pass icon, all content inside the circle Roblox
# crops pass icons to. Run: python3 scripts/vip_icon.py
import glob, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 512
FONT = glob.glob('/usr/share/fonts/**/Anton*.ttf', recursive=True)[0]
img = Image.new('RGB', (S, S))
px = img.load()
# Night sky: hot pink centre fading to deep purple (the party glow).
for y in range(S):
    for x in range(S):
        d = min(1, math.hypot(x - S / 2, y - S * 0.62) / (S * 0.62))
        a, b = (255, 70, 200), (34, 14, 70)
        px[x, y] = tuple(int(a[i] * (1 - d) ** 1.6 + b[i] * (1 - (1 - d) ** 1.6)) for i in range(3))

# Party beams fanning up behind everything.
beams = Image.new('RGBA', (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(beams)
for ang, col in [(-38, (80, 220, 255)), (-12, (255, 220, 60)), (14, (150, 90, 255)), (40, (80, 220, 255))]:
    r = math.radians(ang)
    ox, oy = S / 2, S * 0.78
    tx, ty = ox + math.sin(r) * 600, oy - math.cos(r) * 600
    nx, ny = math.cos(r) * 14, math.sin(r) * 14
    bd.polygon([(ox - nx, oy - ny), (ox + nx, oy + ny), (tx + nx * 3, ty + ny * 3), (tx - nx * 3, ty - ny * 3)], fill=col + (70,))
img = Image.alpha_composite(img.convert('RGBA'), beams.filter(ImageFilter.GaussianBlur(4)))

d = ImageDraw.Draw(img)
# Basketball.
cx, cy, r = S / 2, S * 0.675, 86
d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=(30, 12, 40))
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 110, 30))
seam = (40, 20, 20)
d.line([(cx - r, cy), (cx + r, cy)], fill=seam, width=7)
d.line([(cx, cy - r), (cx, cy + r)], fill=seam, width=7)
d.arc([cx - r * 1.55, cy - r, cx - r * 0.35, cy + r], -62, 62, fill=seam, width=7)
d.arc([cx + r * 0.35, cy - r, cx + r * 1.55, cy + r], 118, 242, fill=seam, width=7)
d.ellipse([cx - r * 0.6, cy - r * 0.75, cx - r * 0.25, cy - r * 0.45], fill=(255, 170, 100))

# Gold crown sitting on the ball.
gold, dark = (255, 205, 60), (110, 60, 10)
base_y, top_y, w = cy - r + 8, cy - r - 58, 112
crown = [(cx - w / 2, base_y), (cx - w / 2, top_y + 22), (cx - w / 4, top_y + 48), (cx, top_y),
         (cx + w / 4, top_y + 48), (cx + w / 2, top_y + 22), (cx + w / 2, base_y)]
d.polygon(crown, fill=gold, outline=dark, width=6)
for jx, jy, col in [(cx - w / 2, top_y + 22, (80, 220, 255)), (cx, top_y, (255, 70, 200)), (cx + w / 2, top_y + 22, (80, 220, 255))]:
    d.ellipse([jx - 11, jy - 11, jx + 11, jy + 11], fill=col, outline=dark, width=4)

# Text.
def text(xy, s, size, fill, stroke):
    d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill, anchor='mm', stroke_width=stroke, stroke_fill=(24, 8, 40))
text((S / 2, S * 0.235), 'VIP', 124, gold, 11)
text((S / 2, S * 0.9), 'x2 HUSS', 50, (255, 255, 255), 7)

img.convert('RGB').save('assets/vip_pass.png')
# Preview with the circular crop players see.
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).ellipse([0, 0, S, S], fill=255)
prev = Image.new('RGB', (S, S), (245, 245, 245))
prev.paste(img.convert('RGB'), (0, 0), mask)
prev.save('/tmp/vip_preview.png')
print('ok')
