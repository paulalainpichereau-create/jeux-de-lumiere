"""Régénère toutes les icônes (site, Android, App Store, Play Store) à partir du même dessin :
trois faisceaux de projecteurs qui partent du bas. Lancer depuis la racine du dépôt : python3 outils/icones.py
(il faut Pillow : pip install pillow)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

def icon(size, bg=(7, 6, 14)):
    S = size * 4
    base = Image.new("RGB", (S, S), bg)
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    beams = [(-24, (61, 230, 255)), (0, (255, 77, 148)), (24, (180, 110, 255))]
    ox, oy, L = S / 2, S * 0.86, S * 0.85
    for ang, colr in beams:
        a, half = math.radians(ang), math.radians(7)
        p1 = (ox + math.sin(a - half) * L, oy - math.cos(a - half) * L)
        p2 = (ox + math.sin(a + half) * L, oy - math.cos(a + half) * L)
        d.polygon([(ox, oy), p1, p2], fill=tuple(int(c * 0.75) for c in colr))
    img = ImageChops.add(base, glow.filter(ImageFilter.GaussianBlur(S * 0.02)))
    r = S * 0.05
    ImageDraw.Draw(img).ellipse([ox - r, oy - r, ox + r, oy + r], fill=(255, 235, 245))
    return img.resize((size, size), Image.LANCZOS)

# site (PWA)
for s in (180, 192, 512):
    icon(s).save(f"icon-{s}.png")
# Android
res = "android/app/src/main/res"
for name, sz in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    os.makedirs(f"{res}/mipmap-{name}", exist_ok=True)
    im = icon(sz)
    im.save(f"{res}/mipmap-{name}/ic_launcher.png")
    mask = Image.new("L", (sz * 4, sz * 4), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, sz * 4 - 1, sz * 4 - 1], fill=255)
    rnd = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
    rnd.paste(im, (0, 0), mask.resize((sz, sz), Image.LANCZOS))
    rnd.save(f"{res}/mipmap-{name}/ic_launcher_round.png")
# iPhone (App Store) and store images
icon(1024).save("ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
os.makedirs("stores/images", exist_ok=True)
icon(512).save("stores/images/icone-512.png")
icon(1024).save("stores/images/icone-1024.png")
print("Icônes régénérées.")
