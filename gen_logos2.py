#!/usr/bin/env python3
"""3D-feel ZAV logo with sphere + letters + D mark."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, os

OUT = "/home/zav/zav_mobile/logo2"
os.makedirs(OUT, exist_ok=True)
S = 512

def radial_grad(size, top, bottom):
    img = Image.new("RGB", (size,size))
    px = img.load()
    cx,cy = size/2, size*0.5
    maxd = size*0.9
    for y in range(size):
        for x in range(size):
            d = math.hypot(x-cx,y-cy)/maxd
            t = min(1.0, d)
            px[x,y] = tuple(int(top[i]+(bottom[i]-top[i])*t) for i in range(3))
    return img

def sphere(size, light_col, dark_col, center, radius, gloss=0.8):
    """Draw a glossy 3D sphere with highlight + shadow."""
    img = Image.new("RGBA", size, (0,0,0,0))
    px = img.load()
    cx,cy = center
    r = radius
    # light source top-left
    lx,ly = cx - r*0.45, cy - r*0.5
    for y in range(max(0,int(cy-r)), min(size[1],int(cy+r+1))):
        for x in range(max(0,int(cx-r)), min(size[0],int(cx+r+1))):
            dx,dy = x-cx, y-cy
            if dx*dx+dy*dy <= r*r:
                nx,ny,nz = dx/r, dy/r, math.sqrt(max(0,1-(dx*dx+dy*dy)/(r*r)))
                # N·L for diffuse
                l = (lx-cx, ly-cy, r*gloss)
                llen = math.sqrt(l[0]**2+l[1]**2+l[2]**2)
                ndl = max(0,(nx*l[0]+ny*l[1]+nz*l[2])/llen)
                # fog toward dark
                t = 0.3+0.85*ndl
                px[x,y] = tuple(int(dark_col[i]+(light_col[i]-dark_col[i])*t) for i in range(3))
    # specular highlight
    grad = Image.new("L", size, 0)
    gd = ImageDraw.Draw(grad)
    hl = Image.new("RGBA", size, (0,0,0,0))
    hp = hl.load()
    hx,hy = cx-r*0.42, cy-r*0.5
    for y in range(size[1]):
        for x in range(size[0]):
            dd = math.hypot(x-hx,y-hy)
            if dd < r*0.35:
                hp[x,y] = (255,255,255, int(170*(1-dd/(r*0.35))))
    gl = hl.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(gl)
    # drop shadow below
    sh = Image.new("RGBA", size, (0,0,0,0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse([cx-r*1.2, cy+r*0.7, cx+r*1.2, cy+r*1.3], fill=(0,0,0,90))
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(sh)
    return img

def hammered_letter(d, text, font, cx, cy, fill, outline, shadow):
    """Letter with 3D shadow + outline."""
    bbox = d.textbbox((0,0), text, font=font)
    w,h = bbox[2]-bbox[0], bbox[3]-bbox[1]
    x = cx - w/2 - bbox[0]
    y = cy - h/2 - bbox[1]
    # shadow
    d.text((x+3, y+5), text, font=font, fill=shadow)
    # outline (stroke)
    d.text((x,y), text, font=font, fill=outline, stroke_width=3, stroke_fill=outline)
    # fill
    d.text((x,y), text, font=font, fill=fill)
    return (x,y,w,h)

def rounded_icon(img, radius=96):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0)+img.size, radius=radius, fill=255)
    out = Image.new("RGBA", img.size,(0,0,0,0))
    out.paste(img.convert("RGBA"),(0,0),mask)
    return out

def cyan_grad_text(d, x, y, text, font):
    # cyan->purple fill approximation
    return hammered_letter(d, text, font, x, y,
        fill=(0,229,255), outline=(20,40,80), shadow=(0,0,0))

try:
    f_big  = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 170)
    f_zav  = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 120)
    f_sm   = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 70)
except:
    f_big=f_zav=f_sm=ImageFont.load_default()

# ── Concept A: 立體紫青球體 + ZAV + D 角標 ──
imgA = Image.new("RGBA",(S,S),(0,0,0,0))
from PIL import ImageChops
bgA = radial_grad(S,(10,14,26),(2,3,8)).convert("RGBA")
imgA.alpha_composite(bgA)
sph = sphere((S,S), (160,240,255),(60,20,120), (S/2, S/2-40), 165)
imgA.alpha_composite(sph)
dA = ImageDraw.Draw(imgA)
# ZAV text bottom over sphere
font_zav = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 118)
dx,dy,_,_ = hammered_letter(dA, "ZAV", font_zav, S/2, S/2+60, fill=(0,229,255), outline=(20,50,120), shadow=(0,0,0))
# big D behind top-right
font_d = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 320)
# partial D ring overlaid
dA.ellipse([S/2+120,S/2-180,S/2+340,S/2+40], outline=(184,92,255), width=40)
# inner D hole
# add glossy D overlay
imgA = rounded_icon(imgA)
imgA.save(f"{OUT}/A-orb-zav-d.png")

# ── Concept B: ZAV 巨型字 + D 測邊（金屬）──
imgB = radial_grad(S,(16,22,40),(4,6,12)).convert("RGBA")
dB = ImageDraw.Draw(imgB)
# D big ring center-left, ZAV to the right
dB.ellipse([S/2-190,S/2-175,S/2-40,S/2-25], outline=(0,229,255), width=38)
dB.ellipse([S/2-150,S/2-140,S/2-85,S/2-65], fill=(10,14,26), outline=(0,229,255), width=6)
# ZAV vertical right
hammered_letter(dB,"ZA",font_zav,S/2+150,S/2-40,fill=(184,92,255),outline=(30,30,70),shadow=(0,0,0))
hammered_letter(dB,"V",font_zav,S/2+150,S/2+110,fill=(184,92,255),outline=(30,30,70),shadow=(0,0,0))
imgB = rounded_icon(imgB)
imgB.save(f"{OUT}/B-d-zav.png")

# ── Concept C: 立體 ZAV 3D 擠出字 ──
imgC = radial_grad(S,(8,10,20),(2,3,8)).convert("RGBA")
dC = ImageDraw.Draw(imgC)
# extruded ZAV with multiple depth layers
offs = [(0,0),(4,4),(8,8),(12,12),(16,16)]
colors = [(30,60,110),(80,60,150),(130,70,190),(170,80,220),(0,229,255)[:-1]+(255,)]
# draw depth shadows
for k,(ox,oy) in reversed(list(enumerate(offs))):
    col = (int(20+20*k), int(30+20*k), int(70+30*k))
    hammered_letter(dC,"ZAV",f_zav,S/2-108,S/2-40,fill=col,outline=col,shadow=col)
# top flat bright
hammered_letter(dC,"ZAV",f_zav,S/2-108,S/2-40,fill=(0,229,255),outline=(40,90,180),shadow=(0,0,0))
# small D badge
dC.ellipse([S-160,S-160,S-20,S-20],fill=(10,14,26),outline=(184,92,255),width=6)
hammered_letter(dC,"D",f_sm,S-90,S-90,fill=(184,92,255),outline=(30,30,70),shadow=(0,0,0))
imgC = rounded_icon(imgC)
imgC.save(f"{OUT}/C-zav-3d.png")

for f in sorted(os.listdir(OUT)):
    print(f, os.path.getsize(f"{OUT}/{f}"))
print("done")