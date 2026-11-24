import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter
D='/tmp/claude-tool-results/71c6616f-0a7c-57cd-8cf7-4feeb9716fa9/'
left=Image.open(D+'mcp-remote-devices-blob-1795505496423-xuvswr-60a2d1d5.jpg').convert('RGB')
right=Image.open(D+'mcp-remote-devices-blob-1795505498149-rxongl-1ff69aca.jpg').convert('RGB')
W,H=1920,1080
def half(img, x0, x1):
    c=img.crop((x0,0,x1,img.height))
    return c.resize((int(c.width*H/c.height),H), Image.LANCZOS)
L=half(left,560,1300)
R=half(right,560,1300)
# cool the trainer side, push the party side
blue=Image.new('RGB',L.size,(30,60,160))
L=Image.blend(ImageEnhance.Brightness(L).enhance(0.85),blue,0.2)
R=ImageEnhance.Color(R).enhance(1.25)
out=Image.new('RGB',(W,H))
out.paste(R.crop((R.width//2-W//2+300,0,R.width//2-W//2+300+W,H)) if R.width>=W else R.resize((W,H)),(0,0))
out.paste(R.crop(((R.width-1060)//2,0,(R.width-1060)//2+1060,H)),(860,0))
mask=Image.new('L',(W,H),0)
md=ImageDraw.Draw(mask); md.polygon([(0,0),(1060,0),(860,H),(0,H)],fill=255)
out.paste(L.crop((max(0,(L.width-1060)//2),0,max(0,(L.width-1060)//2)+1060,H)),(0,0),mask.crop((0,0,1060,H)))
d=ImageDraw.Draw(out)
d.line([(1060,0),(860,H)],fill=(255,255,255),width=14)
F='/usr/share/fonts/truetype/anton/Anton-Regular.ttf'
import glob; F=(glob.glob('/usr/share/fonts/**/Anton*.ttf',recursive=True) or [F])[0]
def text(xy,s,size,fill,anchor='mm',stroke=10):
    d.text(xy,s,font=ImageFont.truetype(F,size),fill=fill,anchor=anchor,stroke_width=stroke,stroke_fill=(16,14,40))
text((W//2,130),'HUSS HUSS HUSS',190,(255,255,255),stroke=14)
text((250,H-110),'YOU',120,(120,220,255))
text((1460,H-110),'THEY PARTY',120,(255,120,230))
out.save(sys.argv[1] if len(sys.argv) > 1 else 'thumbnail.png')
print(out.size)
