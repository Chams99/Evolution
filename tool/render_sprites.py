"""Renders the microbe and algae figures used by the microscope view.

    python tool/render_sprites.py

Writes PNGs to assets/sprites/. Cells are drawn in greyscale so the app can tint
them with a family stain; details that keep their own colour (vacuoles,
highlights) go in a separate overlay. Everything is supersampled 4x.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
OUT.mkdir(parents=True, exist_ok=True)

SS = 4
W, H = 192, 128          # one cell frame, front of the cell facing +x
CX, CY = 100, 64
RX, RY = 70, 48
STATES = ["hungry", "fed", "dividing"]


def outline(state, wobble, seed):
    """Polygon for the membrane, with a slight irregular wobble. Dividing cells pinch at the middle."""
    rnd = random.Random(seed)
    phases = [rnd.uniform(0, 2 * math.pi) for _ in range(3)]
    pts = []
    for i in range(240):
        a = i / 240 * 2 * math.pi
        k = 1 + wobble * (math.sin(3 * a + phases[0]) * 0.5 + math.sin(5 * a + phases[1]) * 0.3 + math.sin(7 * a + phases[2]) * 0.2)
        x, y = math.cos(a) * RX * k, math.sin(a) * RY * k
        if state == "dividing":
            pinch = math.exp(-((x / RX) ** 2) / 0.03)
            y *= 1 - 0.38 * pinch
            x *= 1.08
        pts.append(((CX + x) * SS, (CY + y) * SS))
    return pts


def soft_noise(w, h, scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, h // scale), max(2, w // scale)))
    img = Image.fromarray((small * 255).astype("uint8")).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def cell_layers(state, seed):
    w, h = W * SS, H * SS
    pts = outline(state, 0.035, seed)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    mask_np = np.asarray(mask, dtype=np.float32) / 255.0

    # Body shading: bright centre, darker toward the edge, plus granular cytoplasm.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx / SS - CX) / RX) ** 2 + ((yy / SS - CY) / RY) ** 2)
    base = 252 - 38 * np.clip(d, 0, 1) ** 2
    grain = soft_noise(w, h, 6 * SS, seed) - 0.5
    fine = soft_noise(w, h, 2 * SS, seed + 1) - 0.5
    body = base + grain * 26 + fine * 14

    img = Image.fromarray(np.clip(body, 0, 255).astype("uint8"), "L")
    draw = ImageDraw.Draw(img)
    rnd = random.Random(seed)

    # Granules: stored energy.
    count = {"hungry": 14, "fed": 46, "dividing": 54}[state]
    tone = {"hungry": 196, "fed": 168, "dividing": 160}[state]
    for _ in range(count):
        a, r = rnd.uniform(0, 2 * math.pi), math.sqrt(rnd.random()) * 0.78
        gx, gy = CX + math.cos(a) * RX * r, CY + math.sin(a) * RY * r
        gr = rnd.uniform(1.2, 2.6) * SS
        draw.ellipse([gx * SS - gr, gy * SS - gr, gx * SS + gr, gy * SS + gr], fill=tone + rnd.randint(-14, 10))

    # Nucleus (two when dividing), with a darker rim and a nucleolus.
    centres = [(CX - 42, CY), (CX + 42, CY)] if state == "dividing" else [(CX - 8, CY + 2)]
    for nx, ny in centres:
        nrx, nry = (15, 13) if state != "dividing" else (13, 12)
        draw.ellipse([(nx - nrx) * SS, (ny - nry) * SS, (nx + nrx) * SS, (ny + nry) * SS], fill=132, outline=92, width=int(2.2 * SS))
        draw.ellipse([(nx - 4) * SS, (ny - 5) * SS, (nx + 3) * SS, (ny + 2) * SS], fill=82)

    img = img.filter(ImageFilter.GaussianBlur(0.9 * SS))

    # Membrane: dark outer line with a bright refractive rim just inside.
    draw = ImageDraw.Draw(img)
    draw.line(pts + [pts[0]], fill=64, width=int(3.2 * SS), joint="curve")
    inner = [((x - CX * SS) * 0.955 + CX * SS, (y - CY * SS) * 0.94 + CY * SS) for x, y in pts]
    draw.line(inner + [inner[0]], fill=255, width=int(1.4 * SS), joint="curve")
    img = img.filter(ImageFilter.GaussianBlur(0.45 * SS))

    alpha = Image.fromarray((np.clip(mask_np * 0.72, 0, 1) * 255).astype("uint8"))
    rim = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(SS))
    alpha = Image.fromarray(np.maximum(np.asarray(alpha), (np.asarray(rim, dtype=np.float32) * 0.98).astype("uint8")))
    tint = Image.merge("RGBA", (img, img, img, alpha))

    # Overlay: contractile vacuole, food vacuoles with eaten algae, and a glint.
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    vx, vy, vr = CX - 50, CY - 10, 9
    od.ellipse([(vx - vr) * SS, (vy - vr) * SS, (vx + vr) * SS, (vy + vr) * SS], fill=(255, 255, 255, 120), outline=(90, 90, 90, 150), width=int(1.4 * SS))
    od.ellipse([(vx - 4) * SS, (vy - 5) * SS, (vx - 1) * SS, (vy - 2) * SS], fill=(255, 255, 255, 220))
    meals = {"hungry": 1, "fed": 4, "dividing": 5}[state]
    for i in range(meals):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.35, 0.62)
        fx, fy = CX + 10 + math.cos(a) * RX * r * 0.8, CY + math.sin(a) * RY * r
        fr = rnd.uniform(4, 6.5)
        od.ellipse([(fx - fr) * SS, (fy - fr) * SS, (fx + fr) * SS, (fy + fr) * SS], fill=(112, 142, 72, 190), outline=(70, 96, 46, 210), width=int(1.2 * SS))
    glint = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glint).ellipse([(CX + 4) * SS, (CY - 38) * SS, (CX + 46) * SS, (CY - 24) * SS], fill=(255, 255, 255, 95))
    glint = glint.filter(ImageFilter.GaussianBlur(4 * SS))
    overlay = Image.alpha_composite(overlay, glint)
    clip = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    clip.paste(overlay, (0, 0), mask)
    overlay = clip.filter(ImageFilter.GaussianBlur(0.4 * SS))

    return tint, overlay


def ghost(seed):
    w, h = W * SS, H * SS
    pts = outline("hungry", 0.16, seed)
    pts = [((x - CX * SS) * 0.82 + CX * SS, (y - CY * SS) * 0.78 + CY * SS) for x, y in pts]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=(150, 146, 138, 120))
    rnd = random.Random(seed)
    for _ in range(18):
        a, r = rnd.uniform(0, 2 * math.pi), math.sqrt(rnd.random()) * 0.6
        gx, gy = CX + math.cos(a) * RX * r * 0.8, CY + math.sin(a) * RY * r * 0.75
        gr = rnd.uniform(1.2, 2.4) * SS
        d.ellipse([gx * SS - gr, gy * SS - gr, gx * SS + gr, gy * SS + gr], fill=(110, 106, 100, 150))
    img = img.filter(ImageFilter.GaussianBlur(0.8 * SS))
    ImageDraw.Draw(img).line(pts + [pts[0]], fill=(96, 92, 86, 200), width=int(2.2 * SS), joint="curve")
    return img.filter(ImageFilter.GaussianBlur(0.4 * SS))


def alga(kind, seed):
    size = 64
    w = size * SS
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    rnd = random.Random(seed)
    cells = {
        0: [(32, 32, 21)],
        1: [(22, 32, 14.5), (42, 32, 14.5)],
        2: [(22, 22, 10.5), (42, 22, 10.5), (22, 42, 10.5), (42, 42, 10.5)],
    }[kind]
    for cx, cy, r in cells:
        cell = Image.new("RGBA", (w, w), (0, 0, 0, 0))
        yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
        d = np.sqrt((xx / SS - cx) ** 2 + (yy / SS - cy) ** 2) / r
        inside = d <= 1
        light = np.clip(1 - d, 0, 1)
        rgb = np.zeros((w, w, 4), dtype=np.float32)
        rgb[..., 0] = 70 + 40 * light
        rgb[..., 1] = 118 + 52 * light
        rgb[..., 2] = 58 + 26 * light
        rgb[..., 3] = np.where(inside, 235, 0)
        cell = Image.fromarray(rgb.astype("uint8"), "RGBA")
        cd = ImageDraw.Draw(cell)
        # Cup-shaped chloroplast, pyrenoid, rim.
        a0 = rnd.uniform(0, 360)
        cd.chord([(cx - r * 0.82) * SS, (cy - r * 0.82) * SS, (cx + r * 0.82) * SS, (cy + r * 0.82) * SS], a0, a0 + 200, fill=(52, 96, 40, 150))
        pr = r * 0.22
        px, py = cx + r * 0.15, cy - r * 0.1
        cd.ellipse([(px - pr) * SS, (py - pr) * SS, (px + pr) * SS, (py + pr) * SS], fill=(196, 214, 150, 170))
        cd.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], outline=(48, 80, 36, 230), width=int(1.6 * SS))
        gr = r * 0.3
        cd.ellipse([(cx - r * 0.55 - gr) * SS, (cy - r * 0.55 - gr * 0.6) * SS, (cx - r * 0.55 + gr) * SS, (cy - r * 0.55 + gr * 0.6) * SS], fill=(255, 255, 255, 90))
        img = Image.alpha_composite(img, cell.filter(ImageFilter.GaussianBlur(0.5 * SS)))
    return img


def sheet(frames, fw, fh, factor):
    """Lays frames side by side at a given scale. Downsampling from the 4x
    master with Lanczos keeps outlines clean at small sizes."""
    w, h = round(fw * factor), round(fh * factor)
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        out.paste(frame.resize((w, h), Image.LANCZOS), (i * w, 0))
    return out


# Full size for the field guide and close-ups, then half and quarter size for
# the live view, where cells are only 10 to 30 pixels across.
LEVELS = {"": 1.0, "@half": 0.5, "@quarter": 0.25}
cells = [cell_layers(state, seed=11 + i) for i, state in enumerate(STATES)]
ghost_master = ghost(5)
algae_master = [alga(k, seed=40 + k) for k in range(3)]
for suffix, factor in LEVELS.items():
    sheet([t for t, _ in cells], W, H, factor).save(OUT / f"cell_tint{suffix}.png", optimize=True)
    sheet([o for _, o in cells], W, H, factor).save(OUT / f"cell_overlay{suffix}.png", optimize=True)
    sheet([ghost_master], W, H, factor).save(OUT / f"cell_ghost{suffix}.png", optimize=True)
    sheet(algae_master, 64, 64, factor).save(OUT / f"algae{suffix}.png", optimize=True)
print("wrote", sorted(p.name for p in OUT.iterdir()))
