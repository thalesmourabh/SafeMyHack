#!/usr/bin/env python3
"""SafeMyHack Icon Generator - roda direto no Mac"""
from PIL import Image, ImageDraw

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size
    margin = int(s * 0.06)
    corner = int(s * 0.22)
    draw.rounded_rectangle([margin, margin, s - margin, s - margin], radius=corner, fill=(20, 25, 45, 255))
    inner_margin = margin + int(s * 0.02)
    draw.rounded_rectangle(
        [inner_margin, inner_margin, s - inner_margin, s - inner_margin],
        radius=corner - int(s * 0.02),
        outline=(60, 130, 255, 80), width=max(1, int(s * 0.005)))
    cx, cy = s // 2, s // 2
    shield_w, shield_h = int(s * 0.50), int(s * 0.58)
    shield_top = cy - int(shield_h * 0.45)
    shield_points = [
        (cx, shield_top),
        (cx + shield_w // 2, shield_top + int(shield_h * 0.15)),
        (cx + shield_w // 2, shield_top + int(shield_h * 0.55)),
        (cx, shield_top + shield_h),
        (cx - shield_w // 2, shield_top + int(shield_h * 0.55)),
        (cx - shield_w // 2, shield_top + int(shield_h * 0.15)),
    ]
    draw.polygon(shield_points, fill=(30, 100, 220, 200), outline=(100, 180, 255, 255))
    inner_points = [(cx + (px - cx) * 0.82, shield_top + (py - shield_top) * 0.82 + int(shield_h * 0.05)) for px, py in shield_points]
    draw.polygon(inner_points, fill=(40, 120, 240, 150))
    wifi_cx, wifi_cy = cx, cy - int(s * 0.02)
    for arc_r in [int(s * 0.10), int(s * 0.18), int(s * 0.26)]:
        draw.arc([wifi_cx - arc_r, wifi_cy - arc_r, wifi_cx + arc_r, wifi_cy + arc_r],
                 start=220, end=320, fill=(255, 255, 255, 220), width=max(2, int(s * 0.025)))
    dot_r = max(2, int(s * 0.025))
    draw.ellipse([wifi_cx - dot_r, wifi_cy + int(s * 0.02) - dot_r,
                  wifi_cx + dot_r, wifi_cy + int(s * 0.02) + dot_r], fill=(255, 255, 255, 240))
    wr_cx, wr_cy = cx + int(s * 0.10), cy + int(s * 0.14)
    wr_r = max(2, int(s * 0.04))
    draw.ellipse([wr_cx - wr_r, wr_cy - wr_r, wr_cx + wr_r, wr_cy + wr_r],
                 outline=(255, 200, 50, 255), width=max(1, int(s * 0.015)))
    draw.line([wr_cx + wr_r, wr_cy + wr_r, wr_cx + int(s * 0.07), wr_cy + int(s * 0.07)],
              fill=(255, 200, 50, 255), width=max(1, int(s * 0.015)))
    return img

sizes = {
    'icon_16x16.png': 16, 'icon_16x16@2x.png': 32,
    'icon_32x32.png': 32, 'icon_32x32@2x.png': 64,
    'icon_128x128.png': 128, 'icon_128x128@2x.png': 256,
    'icon_256x256.png': 256, 'icon_256x256@2x.png': 512,
    'icon_512x512.png': 512, 'icon_512x512@2x.png': 1024,
}

import os, sys
dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Resources', 'AppIcon.iconset')
os.makedirs(dest, exist_ok=True)

for fname, sz in sizes.items():
    icon = create_icon(sz)
    icon.save(os.path.join(dest, fname))
    print(f'✓ {fname} ({sz}x{sz})')

print(f'\n✅ Todos os ícones gerados em {dest}')
