#!/usr/bin/env python3
"""Convert reference image into Android app icons (all mipmap sizes) + web icons."""
from PIL import Image, ImageDraw, ImageChops
LANCZOS = getattr(Image, "LANCZOS", None) or getattr(Image, "Resampling", Image).LANCZOS
import os

SRC = "/tmp/appicon-ref.jpg"
BASE = "/home/zav/zav_mobile"

# Android standard launcher icon sizes per density
sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
# web
web_sizes = {"Icon-192.png": 192, "Icon-512.png": 512, "Icon-maskable-192.png": 192, "Icon-maskable-512.png": 512}

img = Image.open(SRC).convert("RGBA")
w, h = img.size

# Center-crop to square
side = min(w, h)
left = (w - side) // 2
top = int((h - side) * 0.45)  # bias slightly up toward likely focal point
top = max(0, min(top, h - side))
sq = img.crop((left, top, left + side, top + side))

# Round the icon corners slightly for a clean app-icon look (optional). 
def rounded(img, radius_ratio=0.16):
    r = int(img.width * radius_ratio)
    mask = Image.new("L", (img.width, img.height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width, img.height), radius=r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out

icon = rounded(sq)

count = 0
# Android
for dirname, px in sizes.items():
    target_dir = os.path.join(BASE, "android", "app", "src", "main", "res", dirname)
    os.makedirs(target_dir, exist_ok=True)
    out = icon if icon.width == px else icon.resize((px, px), LANCZOS)
    out.convert("RGB").save(os.path.join(target_dir, "ic_launcher.png"))
    count += 1

# Web
for fname, px in web_sizes.items():
    out = icon if icon.width == px else icon.resize((px, px), LANCZOS)
    out.convert("RGB").save(os.path.join(BASE, "web", "icons", fname))
    count += 1

print(f"Generated {count} icons from {img.size} → {side}x{side}.")
print("Android mipmaps + web icons updated.")