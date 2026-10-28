"""Composes the link-preview card (web/social.png, 1200x630) from a screenshot
of the live view and the bundled fonts.

    python tool/render_social.py docs/screenshot.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"
W, H, SS = 1200, 630, 2

INK = (9, 8, 14)
CREAM = (245, 236, 224)
MUTED = (184, 173, 164)
GOLD = (201, 164, 83)
TERRA = (211, 123, 89)

shot = Image.open(sys.argv[1] if len(sys.argv) > 1 else ROOT / "docs" / "screenshot.png").convert("RGB")
card = Image.new("RGB", (W * SS, H * SS), INK)
draw = ImageDraw.Draw(card)

# The lens: a circle cut from the middle of the live view, with a dark rim.
lens_d = 520 * SS
cx, cy = 870 * SS, 315 * SS
# A clear patch of slide: below the overlay chips, above the tool dock, left of the field guide.
view = shot.crop((90, 160, 90 + 420, 160 + 420)).resize((lens_d, lens_d), Image.LANCZOS)
mask = Image.new("L", (lens_d, lens_d), 0)
ImageDraw.Draw(mask).ellipse([0, 0, lens_d - 1, lens_d - 1], fill=255)
vignette = Image.new("L", (lens_d, lens_d), 0)
ImageDraw.Draw(vignette).ellipse([lens_d * 0.08, lens_d * 0.08, lens_d * 0.92, lens_d * 0.92], fill=255)
vignette = vignette.filter(ImageFilter.GaussianBlur(40 * SS))
view = Image.composite(view, Image.new("RGB", view.size, (110, 100, 87)), vignette)
card.paste(view, (cx - lens_d // 2, cy - lens_d // 2), mask)
for i, (pad, color, width) in enumerate([(0, (60, 52, 50), 3), (14, (24, 20, 26), 14), (28, (60, 52, 50), 2)]):
    r = lens_d // 2 + pad * SS
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=width * SS)

def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size * SS)

x = 72 * SS
draw.text((x, 150 * SS), "LIVE · POND WATER · ×400", font=font("SpaceMono-Bold.ttf", 18), fill=TERRA)
draw.text((x, 186 * SS), "Evolution", font=font("SpaceGrotesk-SemiBold.ttf", 88), fill=CREAM)
body = font("DMSans-Regular.ttf", 27)
for i, line in enumerate(["Watch natural selection happen", "under a microscope. Microbes hunt", "algae, divide, mutate and adapt."]):
    draw.text((x, (312 + i * 40) * SS), line, font=body, fill=MUTED)
draw.rounded_rectangle([x, 462 * SS, x + 250 * SS, 516 * SS], radius=8 * SS, fill=GOLD)
draw.text((x + 26 * SS, 474 * SS), "Run the experiment", font=font("DMSans-SemiBold.ttf", 22), fill=(18, 15, 20))

card.resize((W, H), Image.LANCZOS).save(ROOT / "web" / "social.png", optimize=True)
print("wrote web/social.png")
