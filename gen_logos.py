#!/usr/bin/env python3
"""Generate 5 ZAV Mobile app-icon concepts (cyber/sci-fi neon on dark)."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, os

OUT = "/home/zav/zav_mobile/logo_concepts"
os.makedirs(OUT, exist_ok=True)
S = 512

def radial_grad(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = size/2, size*0.42
    maxd = size*1.1
    for y in range(size):
        for x in range(size):
            d = math.hypot(x-cx, y-cy)/maxd
            t = min(1.0, d)
            px[x,y] = tuple(int(top[i]+(bottom[i]-top[i])*t) for i in range(3))
    return img

def neon_glow(draw_img, shape_fn, blur=8, passes=3):
    """draw shape onto a temp, blur, add under base."""
    out = draw_img.convert("RGBA")
    for p in range(passes, 0, -1):
        layer = Image.new("RGBA", out.size, (0,0,0,0))
        d = ImageDraw.Draw(layer)
        shape_fn(d, (p*blur)//passes, p)
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
        out.alpha_composite(layer)
    return out

def rounded_icon(base_img, radius=96):
    mask = Image.new("L", base_img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0)+base_img.size, radius=radius, fill=255)
    out = Image.new("RGBA", base_img.size, (0,0,0,0))
    out.paste(base_img, (0,0), mask)
    return out

def pill_text(d, xy, text, font, fill, glow=None):
    x,y = xy

# Font
try:
    font_big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 120)
    font_mid = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
    font_sm  = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 40)
except:
    font_big = font_mid = font_sm = ImageFont.load_default()

C = {
 "cyan":(0,229,255), "purple":(124,108,240), "pink":(184,92,255),
 "green":(110,231,160), "bg_dark":(5,7,13), "bg_mid":(13,21,32),
}

# ── Concept 1: 光球 Orb（紫青 core + 光環）──
img1 = radial_grad(S, (8,10,20), (2,3,8))
d1 = ImageDraw.Draw(img1)
cx,cy,r = S/2, S/2, 150
# outer ring glow
for i in range(60,0,-1):
    a = i/60
    d1.ellipse([cx-r-2*i,cy-r-2*i,cx+r+2*i,cy+r+2*i], outline=tuple(int(C['cyan'][j]*(a)+0) for j in range(3)) if False else (0,229,255), width=1)

def ring(d, off, p):
    d.ellipse([cx-r+off,cy-r+off,cx+r-off,cy+r-off], outline=C['cyan'], width=(4+p))
    d.ellipse([cx-(r-46)+off,cy-(r-46)+off,cx+(r-46)-off,cy+(r-46)-off], outline=C['purple'], width=(4+p))
img1 = neon_glow(img1, ring, blur=10)
img1 = rounded_icon(img1)
img1.save(f"{OUT}/1-orb.png")

# ── Concept 2: Z 字霓虹 ──
img2 = radial_grad(S, (13,21,32), (5,7,13))
d2 = ImageDraw.Draw(img2)

def zshape(d, off, p):
    pts = [(150,170-off),(362,170-off),(170,342+off),(350,342+off)]
    d.line(pts, fill=C['purple'], width=(10+p*2), joint="curve")
    d.line([(150,170-off),(350,170-off)], fill=C['cyan'], width=(6+p))
img2 = neon_glow(img2, zshape, blur=8)
d2b = ImageDraw.Draw(img2)
d2b.line([(150,170),(362,170),(170,342),(350,342)], fill=C['pink'], width=14, joint="curve")
img2 = rounded_icon(img2)
img2.save(f"{OUT}/2-zlogo.png")

# ── Concept 3: 棋盤節點網絡（G-Brain 式）──
img3 = radial_grad(S, (5,7,13), (2,3,8))
d3 = ImageDraw.Draw(img3)
# network lines
for ang in range(0,360,45):
    a = math.radians(ang)
    x1,y1 = S/2+math.cos(a)*330, S/2+math.sin(a)*330
    x2,y2 = S/2-math.cos(a)*330, S/2-math.sin(a)*330
    d3.line([x1,y1,x2,y2], fill=(60,60,90), width=2)
# nodes on rings
for radius in (120,190,260):
    for ang in range(0,360,30):
        a = math.radians(ang)
        x,y = S/2+math.cos(a)*radius, S/2+math.sin(a)*radius
        col = C['cyan'] if (ang//60)%2==0 else C['purple']
        d3.ellipse([x-8,y-8,x+8,y+8], fill=col)
# central core glowing
d3.ellipse([S/2-70,S/2-70,S/2+70,S/2+70], outline=C['cyan'], width=6)
img3 = neon_glow(img3, lambda d,o,p: d.ellipse([S/2-40-o,S/2-40-o,S/2+40+o,S/2+40+o], outline=C['purple'], width=5), blur=12)
img3 = rounded_icon(img3)
img3.save(f"{OUT}/3-network.png")

# ── Concept 4: 菱形科技盾/指揮中心 ──
img4 = radial_grad(S, (16,10,40), (5,7,13))
d4 = ImageDraw.Draw(img4)

def diamond(d, off, p):
    pts = [(S/2,80),(S/2+170, S/2),(S/2, S-80),(S/2-170, S/2)]
    d.polygon(pts, outline=C['cyan'], width=8)
    pts2 = [(S/2,80+40),(S/2+130,S/2),(S/2,S-120),(S/2-130,S/2)]
    d.polygon(pts2, outline=C['pink'], width=4)
img4 = neon_glow(img4, diamond, blur=9)
d4b = ImageDraw.Draw(img4)
d4b.polygon([(S/2,80),(S/2+170,S/2),(S/2,S-80),(S/2-170,S/2)], outline=C['cyan'], width=8)
img4 = rounded_icon(img4)
img4.save(f"{OUT}/4-diamond.png")

# ── Concept 5: 斜向速度線 + 光點 ──
img5 = radial_grad(S, (8,10,20), (3,4,10))
d5 = ImageDraw.Draw(img5)
for i in range(12):
    x = 40 + i*40
    d5.line([x, 520, x+260, 300-i*18], fill=(70,50,140), width=3)
# moving bright dot
d5.ellipse([S/2-60,S/2-60,S/2+60,S/2+60], outline=C['cyan'], width=8)
d5.ellipse([S/2-18,S/2-18,S/2+18,S/2+18], fill=C['green'])
img5 = neon_glow(img5, lambda d,o,p: d.ellipse([S/2-50+o,S/2-50+o,S/2+50-o,S/2+50-o], outline=C['purple'], width=5), blur=10)
img5 = rounded_icon(img5)
img5.save(f"{OUT}/5-motion.png")

for f in sorted(os.listdir(OUT)):
    print(f, os.path.getsize(f"{OUT}/{f}"))
print("done")