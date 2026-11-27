# Game page gallery / ad thumbnails (1920x1080) from Studio captures in .trailer/shots/
# (gym.jpg, tempt.jpg, party.jpg, dusk.jpg; 1868x829 viewport). Crops 16:9, scales up, adds the
# title. Writes assets/gallery/*.png. Run: python3 scripts/gallery.py
import glob, os, random
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1920, 1080
F = glob.glob('/usr/share/fonts/**/Anton*.ttf', recursive=True)[0]
INK = (16, 14, 40)
SRC, OUT = '.trailer/shots', 'assets/gallery'


def shot(name, x0):
    img = Image.open(f'{SRC}/{name}.jpg').convert('RGB')
    w = round(img.height * 16 / 9)
    img = img.crop((x0, 0, x0 + w, img.height)).resize((W, H), Image.LANCZOS)
    return img.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))


def title(img, lines, y, size=150, colors=((255, 214, 60),), x=W / 2, anchor='mm', rot=0):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    font = ImageFont.truetype(F, size)
    for i, line in enumerate(lines):
        d.text((x, y + i * size * 1.02), line, font=font, fill=colors[i % len(colors)], anchor=anchor,
               stroke_width=max(8, size // 14), stroke_fill=INK)
    if rot:
        layer = layer.rotate(rot, center=(x, y), resample=Image.BICUBIC)
    return Image.alpha_composite(img.convert('RGBA'), layer)


def pop(img, xy, size, rot, color):
    # A "HUSS!" pop like the in-game ones (those are drawn over the world, which Studio captures miss).
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, 'HUSS!', font=ImageFont.truetype(F, size), fill=color, anchor='mm',
                               stroke_width=size // 12, stroke_fill=INK)
    return Image.alpha_composite(img, layer.rotate(rot, center=xy, resample=Image.BICUBIC))


os.makedirs(OUT, exist_ok=True)

# 1. Keep the beat: Gym, with HUSS! pops around the lifter.
img = shot('gym', 394)  # keeps the HUSS button and most of the beat track
img = title(img, ['KEEP THE BEAT'], 120, 170)
for xy, size, rot, col in [((400, 560), 96, 12, (255, 255, 255)), ((1340, 420), 110, -10, (255, 214, 60)),
                          ((1290, 640), 80, 8, (120, 255, 190))]:
    img = pop(img, xy, size, rot, col)
img.convert('RGB').save(f'{OUT}/1_keep_the_beat.png')

# 2. Don't give in: the party invite popping up mid-practice.
img = shot('tempt', 394)  # keeps the HUSS button
img = title(img, ["DON'T", 'GIVE IN'], 560, 170, ((255, 255, 255), (255, 90, 200)), x=330)
img.convert('RGB').save(f'{OUT}/2_dont_give_in.png')

# 3. ...or join the party.
img = shot('party', 197)
shade = Image.new('L', (W, H), 0)  # darken the top, where the cut-off sign letters sit
ImageDraw.Draw(shade).rectangle([0, 0, W, 90], fill=255)
shade = shade.filter(ImageFilter.GaussianBlur(40))
img = Image.composite(Image.new('RGB', (W, H), INK), img, shade)
img = title(img, ['...OR JOIN', 'THE PARTY'], 120, 150, ((255, 255, 255), (255, 214, 60)))
img.convert('RGB').save(f'{OUT}/3_join_the_party.png')

# 4. Pick your practice: the Dusk station cards (the UI says it).
img = shot('dusk', 197)
img.convert('RGB').save(f'{OUT}/4_pick_your_practice.png')

# Contact sheet for review.
files = sorted(glob.glob(f'{OUT}/*.png'))
sheet = Image.new('RGB', (2 * 960 + 30, 2 * 540 + 30), (20, 14, 30))
for i, f in enumerate(files):
    sheet.paste(Image.open(f).resize((960, 540)), (10 + (i % 2) * 970, 10 + (i // 2) * 550))
sheet.save('.trailer/gallery_sheet.png')
