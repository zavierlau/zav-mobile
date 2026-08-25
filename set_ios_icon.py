#!/usr/bin/env python3
"""Generate all iOS app-icon sizes from the reference image into Assets.xcassets."""
from PIL import Image, ImageDraw
import os

SRC = "/tmp/appicon-ref.jpg"
APPSET = "/home/zav/zav_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"

img = Image.open(SRC).convert("RGBA")
w, h = img.size
side = min(w, h)
left = (w - side) // 2
top = int((h - side) * 0.45); top = max(0, min(top, h - side))
sq = img.crop((left, top, left + side, top + side))

# sizes (pixel dimensions our filename/scale call for)
sizes = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

LANCZOS = getattr(Image, "LANCZOS", None) or getattr(Image, "Resampling", Image).LANCZOS
for fname, px in sizes.items():
    out = sq if sq.width == px else sq.resize((px, px), LANCZOS)
    out.convert("RGB").save(os.path.join(APPSET, fname))
print(f"Generated {len(sizes)} iOS icons.")