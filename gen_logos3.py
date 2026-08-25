#!/usr/bin/env python3
"""5 metallic grey 3D app icons (reference: grey metal logo on dark+light)."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, os

OUT = "/home/zav/zav_mobile/logo3"
os.makedirs(OUT, exist_ok=True)
S = 512

def radial_grad_bg(size, top, bottom):
    img = Image.new("RGB",(size,size))
    px = img.load()
    cx,cy = size/2, size*0.45
    maxd = size*0.8
    for y in range(size):
        for x in range(size):
            d = math.hypot(x-cx,y-cy)/maxd
            t = min(1.0,d)
            px[x,y] = tuple(int(top[i]+(bottom[i]-top[i])*t) for i in range(3))
    return img

def metal_sphere(size, center, radius, light_col=(255,255,255), dark_col=(60,60,70), band=0.6):
    img = Image.new("RGBA",size,(0,0,0,0))
    px = img.load()
    cx,cy = center
    r = radius
    lx,ly = cx-r*0.5, cy-r*0.5
    for y in range(max(0,int(cy-r)),min(size[1],int(cy+r+1))):
        for x in range(max(0,int(cx-r)),min(size[0],int(cx+r+1))):
            dx,dy = x-cx, y-cy
            if dx*dx+dy*dy <= r*r:
                nz = math.sqrt(max(0,1-(dx*dx+dy*dy)/(r*r)))
                lv = (lx-cx,ly-cy,r)
                llen = math.sqrt(lv[0]**2+lv[1]**2+lv[2]**2)
                ndl = max(0,(dx/r*lv[0]+dy/r*lv[1]+nz*lv[2])/llen)
                # metal bands
                yndl = max(0, -dy/r*0.6 + nz*0.8)
                t = 0.25 + 0.75*ndl
                # slight cyan/grey tint
                col = (
                    int(40+(light_col[0]-40)*t),
                    int(48+(light_col[1]-48)*t),
                    int(58+(light_col[2]-58)*t)
                )
                px[x,y] = tuple(max(0,min(255,c)) for c in col)
    # specular highlight
    hl = Image.new("RGBA",size,(0,0,0,0))
    hp = hl.load()
    hx,hy = cx-r*0.4, cy-r*0.5
    for y in range(size[1]):
        for x in range(size[0]):
            dd = math.hypot(x-hx,y-hy)
            if dd < r*0.38:
                hp[x,y] = (255,255,255,int(200*(1-dd/(r*0.38))))
    gl = hl.filter(ImageFilter.GaussianBlur(16))
    img.alpha_composite(gl)
    # rim light bottom
    rim = Image.new("RGBA",size,(0,0,0,0))
    rp = rim.load()
    for y in range(size[1]):
        for x in range(size[0]):
            dx,dy = x-cx,y-cy
            d = math.hypot(dx,dy)
            if r-4 < d < r:
                nn = math.hypot(dx,dy) and (dy/d) if d else 0
                if dy>0:
                    rp[x,y]=(190,200,220,int(120*max(0,dy/r)))
    rim = rim.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(rim)
    return img

def metal_letter(d,text,font,cx,cy,colors,sw):
    """letter with metallic vertical gradient fill + dark outline + drop shadow."""
    bbox = d.textbbox((0,0),text,font=font)
    w,h = bbox[2]-bbox[0],bbox[3]-bbox[1]
    x = cx-w/2-bbox[0]
    y = cy-h/2-bbox[1]
    d.text((x+3,y+4),text,font=font,fill=(0,0,0,180))  # shadow
    d.text((x,y),text,font=font,fill=colors[1],stroke_width=sw,stroke_fill=(0,0,0))
    # gradient overlay approximation with bands
    d.text((x,y),text,font=font,fill=colors[0],stroke_width=sw,stroke_fill=(20,20,25))
    return x,y,w,h

def rounded_icon(img,radius=96):
    mask = Image.new("L",img.size,0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0)+img.size,radius=radius,fill=255)
    out = Image.new("RGBA",img.size,(0,0,0,0))
    out.paste(img.convert("RGBA"),(0,0),mask)
    return out

def shadow_plate(img, cx, cy, rx, ry, alpha=110):
    sh = Image.new("RGBA",img.size,(0,0,0,0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse([cx-rx,cy-ry,cx+rx,cy+ry],fill=(0,0,0,alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(20))
    img.alpha_composite(sh)
    return img

f_zav = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",118)
f_d   = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",300)
f_sm  = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",90)

G_LIGHT=(235,235,245); G_DARK=(55,58,70)

# 1: 金屬銀球 + ZAV 灰鋼字
i1 = radial_grad_bg(S,(18,18,24),(6,7,10)).convert("RGBA")
i1 = shadow_plate(i1, S/2, S-100, 200, 55)
sphere = metal_sphere((S,S),(S/2,S/2-70),170)
i1.alpha_composite(sphere)
d1 = ImageDraw.Draw(i1)
metal_letter(d1,"ZAV",f_zav,S/2,S/2+120,[(225,228,238),(70,73,86)],3)
i1 = rounded_icon(i1); i1.save(f"{OUT}/1-metal-sphere.png")

# 2: 大 D 金屬環 + ZAV 細字
i2 = radial_grad_bg(S,(16,16,22),(6,7,10)).convert("RGBA")
i2 = shadow_plate(i2,S/2,S-90,220,50)
d2 = ImageDraw.Draw(i2)
# D ring metallic
for i in range(12,0,-6):
    d2.ellipse([S/2-155-i,S/2-155-i,S/2+155+i,S/2+155+i],outline=(40,42,52),width=4)
d2.ellipse([S/2-160,S/2-160,S/2+160,S/2+160],outline=(210,214,225),width=34)
d2.ellipse([S/2-105,S/2-105,S/2+105,S/2+105],fill=(12,12,16),outline=(120,124,136),width=8)
# vertical D bar
d2.rectangle([S/2+95,S/2-150,S/2+145,S/2+150],fill=(210,214,225))
# small ZAV below
metal_letter(d2,"ZAV",f_sm,S/2,S/2+205,[(205,209,220),(60,63,76)],3)
i2 = rounded_icon(i2); i2.save(f"{OUT}/2-metald.png")

# 3: 蟹形鋼板 ZAV 立體
i3 = radial_grad_bg(S,(15,15,21),(6,7,9)).convert("RGBA")
d3 = ImageDraw.Draw(i3)
# hexagon metal plate
pts=[(S/2,80),(S/2+195,S/2-40),(S/2+195,S/2+130),(S/2,S/2+250),(S/2-195,S/2+130),(S/2-195,S/2-40)]
for off in (12,6):
    dark=[(p[0]+off,p[1]+off) for p in pts]
    d3.polygon(dark,fill=int(30)+off, outline=None)
d3.polygon(pts,fill=(50,54,66),outline=(180,185,198),width=6)
metal_letter(d3,"Z",f_zav,S/2-40,S/2,[(225,228,238),(60,63,76)],3)
metal_letter(d3,"D",f_d,S/2+150,S/2,[(225,228,238),(60,63,76)],3)
i3 = rounded_icon(i3); i3.save(f"{OUT}/3-hex.png")

# 4: 銀 Z 線條立體
i4 = radial_grad_bg(S,(16,16,22),(5,6,9)).convert("RGBA")
i4 = shadow_plate(i4,S/2,S-90,200,45)
d4 = ImageDraw.Draw(i4)
# extruded Z layers
zig=[(140,150),(372,150),(160,340),(360,340)]
for o in (0,7,14,21):
    oc = int(60+o*2)
    zz=[(px+o,py+o) for px,py in zig]
    d4.line(zz,fill=(oc,oc+2,oc+6),width=26,joint="curve")
d4.line(zig,fill=(228,231,240),width=24,joint="curve")
# D dot
d4.ellipse([S/2+60,S/2+200,S/2+130,S/2+270],fill=(200,205,218),outline=(40,42,52),width=6)
i4 = rounded_icon(i4); i4.save(f"{OUT}/4-zline.png")

# 5: 星球/星環立體 + ZAV
i5 = radial_grad_bg(S,(20,20,28),(6,7,11)).convert("RGBA")
i5 = shadow_plate(i5,S/2,S-100,210,55)
center=(S/2,S/2-40)
sphere5 = metal_sphere((S,S),center,170)
i5.alpha_composite(sphere5)
# metallic ring around
d5 = ImageDraw.Draw(i5)
ell=[center[0]-245,center[1]-70,center[0]+245,center[1]+70]
for off,w,col in ((14,12,(60,64,76)),(0,10,(215,219,230))):
    d5.ellipse(ell,outline=col,width=w)
metal_letter(d5,"ZAV",f_zav,S/2,S/2+160,[(225,228,238),(60,63,76)],3)
i5 = rounded_icon(i5); i5.save(f"{OUT}/5-saturn.png")

for f in sorted(os.listdir(OUT)):
    print(f,os.path.getsize(f"{OUT}/{f}"))
print("done")