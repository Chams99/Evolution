"""Renders the app icon, every platform's icon set and the launch images.

    python tool/render_icons.py            # write everything
    python tool/render_icons.py --preview  # write a contact sheet to build/icon_preview.png

The icon is the microscope view itself: one stained microbe and a few algae on
the ivory slide, seen through the eyepiece. It reuses the cell and algae
drawings from render_sprites.py, so the icon matches the live view. Sizes of
48 px and under get a simplified drawing with heavier lines.
"""
import io
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from render_sprites import CX, CY, RX, SS, alga, cell_layers

ROOT = Path(__file__).resolve().parent.parent

# From lib/app/theme.dart and lib/app/microbes.dart.
INK = (9, 8, 14)
SURFACE = (18, 15, 20)
RAISED = (27, 22, 27)
CREAM = (245, 236, 224)
SLIDE_BRIGHT = (244, 240, 231)
SLIDE_EDGE = (217, 208, 193)
SLIDE_DEBRIS = (110, 100, 87)
SLIDE_INK = (45, 36, 33)
EYESPOT = (210, 80, 48)
ALGAE = (94, 144, 77)
ALGAE_RIM = (59, 97, 45)
STAIN = (59, 125, 177)  # the blue family stain

MASTER = 2048


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def radial(size, stops, centre=(0.5, 0.5)):
    """RGB array with colour stops along the distance from centre (0 at centre, 1 at the edge of the square's inscribed circle)."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    d = np.sqrt((xx - centre[0]) ** 2 + (yy - centre[1]) ** 2) / 0.5
    out = np.zeros((size, size, 3), np.float32)
    positions = [p for p, _ in stops]
    for c in range(3):
        out[..., c] = np.interp(d, positions, [col[c] for _, col in stops])
    return out


def disc_mask(size, radius, feather=1.5):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    d = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2)
    return np.clip((radius - d) / feather + 0.5, 0, 1)


def to_image(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(rgb, "RGB").convert("RGBA")
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def tinted_cell(color):
    """The 'fed' cell from the sprite renderer, tinted the way the app tints it."""
    tint, overlay = cell_layers("fed", seed=12)
    arr = np.asarray(tint, np.float32)
    shade = lerp(color, (255, 255, 255), 0.18)
    for c in range(3):
        arr[..., c] = arr[..., c] * shade[c] / 255
    body = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return Image.alpha_composite(body, overlay)


def paste_cell(canvas, centre, half_length, heading, color, speed=0.9, sense=120):
    """Draws a microbe like paintMicrobeFigures in field_view.dart: flagellum, body, eyespot."""
    radius = half_length / 1.25
    direction = (math.cos(heading), math.sin(heading))
    side = (-direction[1], direction[0])
    draw = ImageDraw.Draw(canvas)

    base = (centre[0] - direction[0] * half_length * 0.96, centre[1] - direction[1] * half_length * 0.96)
    length = radius * (1.0 + speed * 1.35)
    points = [base]
    for i in range(1, 61):
        t = i / 60
        wave = math.sin(t * 2.6 * math.pi - 1.1) * radius * 0.3 * t
        points.append((base[0] - direction[0] * length * t + side[0] * wave, base[1] - direction[1] * length * t + side[1] * wave))
    tail = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tail)
    width = radius * 0.1
    tail_color = lerp(color, SLIDE_INK, 0.5)
    for i in range(len(points) - 1):
        w = max(1, round(width * (1 - 0.45 * i / len(points))))
        td.line([points[i], points[i + 1]], fill=tail_color + (200,), width=w)
        td.ellipse([points[i + 1][0] - w / 2, points[i + 1][1] - w / 2, points[i + 1][0] + w / 2, points[i + 1][1] + w / 2], fill=tail_color + (200,))
    canvas.alpha_composite(tail.filter(ImageFilter.GaussianBlur(width * 0.12)))

    body = tinted_cell(color)
    scale = half_length / (RX * SS)
    body = body.resize((round(body.width * scale), round(body.height * scale)), Image.LANCZOS)
    pivot = (CX * SS * scale, CY * SS * scale)
    # Rotate about the cell centre: pad so the pivot sits in the middle, then rotate.
    pad = Image.new("RGBA", (body.width * 2, body.height * 2), (0, 0, 0, 0))
    pad.paste(body, (round(body.width - pivot[0]), round(body.height - pivot[1])))
    pad = pad.rotate(-math.degrees(heading), resample=Image.BICUBIC)
    canvas.alpha_composite(pad, (round(centre[0] - pad.width / 2), round(centre[1] - pad.height / 2)))

    eye = (centre[0] + direction[0] * radius * 0.88 - side[0] * radius * 0.18, centre[1] + direction[1] * radius * 0.88 - side[1] * radius * 0.18)
    er = radius * (0.1 + sense / 180 * 0.26)
    draw = ImageDraw.Draw(canvas)
    draw.ellipse([eye[0] - er, eye[1] - er, eye[0] + er, eye[1] + er], fill=EYESPOT + (235,))


def paste_alga(canvas, centre, radius, kind, seed):
    img = alga(kind, seed)
    single = {0: 21, 1: 14.5, 2: 10.5}[kind]
    scale = radius / (single * SS)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(img, (round(centre[0] - img.width / 2), round(centre[1] - img.height / 2)))


def lens(size):
    """The field of view: ivory slide with vignette, debris, algae and one microbe, inside a dark eyepiece ring.
    Transparent outside the ring."""
    ring_outer = size * 0.5
    ring_inner = size * 0.455
    field = radial(size, [(0, SLIDE_BRIGHT), (0.55, lerp(SLIDE_BRIGHT, SLIDE_EDGE, 0.55)), (0.86, SLIDE_EDGE), (1.0, SLIDE_DEBRIS)], centre=(0.46, 0.44))
    canvas = to_image(field, disc_mask(size, ring_inner + 2))

    rnd = np.random.default_rng(7)
    specks = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(specks)
    for _ in range(26):
        a, r = rnd.uniform(0, 2 * math.pi), math.sqrt(rnd.uniform(0.05, 0.85)) * ring_inner
        x, y = size / 2 + math.cos(a) * r, size / 2 + math.sin(a) * r
        s = size * rnd.uniform(0.004, 0.011)
        sd.ellipse([x - s, y - s, x + s, y + s], fill=SLIDE_DEBRIS + (int(rnd.uniform(40, 90)),))
    canvas.alpha_composite(specks.filter(ImageFilter.GaussianBlur(size * 0.002)))

    paste_alga(canvas, (size * 0.30, size * 0.33), size * 0.047, 0, 40)
    paste_alga(canvas, (size * 0.70, size * 0.74), size * 0.034, 1, 41)
    paste_alga(canvas, (size * 0.255, size * 0.70), size * 0.027, 2, 42)
    paste_cell(canvas, (size * 0.575, size * 0.44), size * 0.205, math.radians(-30), STAIN, speed=0.55, sense=55)

    # Keep everything inside the field, then add the eyepiece ring.
    clip = disc_mask(size, ring_inner)
    arr = np.asarray(canvas, np.float32)
    arr[..., 3] *= clip
    canvas = Image.fromarray(arr.astype(np.uint8), "RGBA")

    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    d = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2)
    ring_alpha = disc_mask(size, ring_outer) * (1 - disc_mask(size, ring_inner))
    # A soft bevel: lighter toward the top-left, darker bottom-right.
    light = ((size / 2 - xx) + (size / 2 - yy)) / size
    ring_rgb = np.zeros((size, size, 3), np.float32)
    for c in range(3):
        ring_rgb[..., c] = RAISED[c] + light * 34
    ring = to_image(ring_rgb, ring_alpha)
    canvas = Image.alpha_composite(canvas, ring)
    lines = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    w = max(1, round(size * 0.004))
    for r, alpha in [(ring_inner, 90), (ring_outer - w, 46)]:
        ld.ellipse([size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r], outline=CREAM + (alpha,), width=w)
    # A thin shadow the ring casts onto the slide.
    shade = (1 - np.clip((ring_inner - d) / (size * 0.03), 0, 1)) * disc_mask(size, ring_inner)
    canvas = Image.alpha_composite(canvas, to_image(np.zeros((size, size, 3)), shade * 0.35))
    return Image.alpha_composite(canvas, lines)


def small_lens(size):
    """A flat, bold version for 16 to 48 px: slide, ring, one cell with its eyespot and tail, one alga."""
    k = 8
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, s - 1, s - 1], fill=RAISED + (255,))
    inner = s * 0.43
    c = s / 2
    d.ellipse([c - inner, c - inner, c + inner, c + inner], fill=SLIDE_EDGE + (255,))
    bright = inner * 0.8
    d.ellipse([c - bright - s * 0.03, c - bright - s * 0.04, c + bright - s * 0.03, c + bright - s * 0.04], fill=SLIDE_BRIGHT + (255,))
    img = img.filter(ImageFilter.GaussianBlur(s * 0.03))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, s - 1, s - 1], outline=RAISED + (255,), width=round(s * 0.07))
    # Tail.
    ang = math.radians(-32)
    dx, dy = math.cos(ang), math.sin(ang)
    cx, cy = s * 0.54, s * 0.47
    hl = s * 0.24
    # Body as a rotated ellipse.
    body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse([c - hl, c - hl * 0.68, c + hl, c + hl * 0.68], fill=lerp(STAIN, (255, 255, 255), 0.12) + (255,), outline=lerp(STAIN, SLIDE_INK, 0.55) + (255,), width=round(s * 0.035))
    body = body.rotate(-math.degrees(ang), resample=Image.BICUBIC, center=(c, c))
    img.alpha_composite(body, (round(cx - c), round(cy - c)))
    d = ImageDraw.Draw(img)
    er = s * 0.055
    ex, ey = cx + dx * hl * 0.62 + dy * hl * 0.12, cy + dy * hl * 0.62 - dx * hl * 0.12
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=EYESPOT + (255,))
    ar = s * 0.06
    ax, ay = s * 0.33, s * 0.69
    d.ellipse([ax - ar, ay - ar, ax + ar, ay + ar], fill=ALGAE + (255,), outline=ALGAE_RIM + (255,), width=round(s * 0.015))
    return img.resize((size, size), Image.LANCZOS)


def on_background(size, lens_fraction, master):
    """The lens centred on the dark ground, full bleed."""
    ground = to_image(radial(size, [(0, lerp(SURFACE, RAISED, 0.4)), (1.0, INK), (1.5, INK)], centre=(0.5, 0.45)))
    lens_size = round(size * lens_fraction)
    ground.alpha_composite(master.resize((lens_size, lens_size), Image.LANCZOS), ((size - lens_size) // 2, (size - lens_size) // 2))
    return ground


def round_badge(size, master, small=None):
    """Lens on a dark disc, transparent around it (Windows, legacy Android, PWA)."""
    if size <= 48 and small is not None:
        return small(size)
    disc = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=INK + (255,))
    disc = disc.resize((size, size), Image.LANCZOS)
    inner = round(size * 0.9)
    disc.alpha_composite(master.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    return disc


def macos_icon(size, master):
    """macOS style: a rounded square on the 1024 grid (824 body, 100 margin) with a soft shadow."""
    k = 1024
    canvas = Image.new("RGBA", (k, k), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (k, k), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([100, 112, 924, 936], radius=185, fill=(0, 0, 0, 120))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    body = on_background(824, 0.84, master)
    mask = Image.new("L", (824, 824), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 823, 823], radius=185, fill=255)
    canvas.paste(body, (100, 100), mask)
    rim = Image.new("RGBA", (k, k), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle([100, 100, 923, 923], radius=185, outline=CREAM + (34,), width=3)
    canvas.alpha_composite(rim)
    if size <= 32:
        canvas = Image.new("RGBA", (k, k), (0, 0, 0, 0))
        canvas.paste(on_background(824, 1, Image.new("RGBA", (8, 8))), (100, 100), mask)
        lens_small = small_lens(round(size * 0.74))
        out = canvas.resize((size, size), Image.LANCZOS)
        out.alpha_composite(lens_small, ((size - lens_small.width) // 2, (size - lens_small.height) // 2))
        return out
    return canvas.resize((size, size), Image.LANCZOS)


def monochrome(size):
    """Android 13 themed icon: a single-colour silhouette inside the adaptive safe zone."""
    k = 4
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    r = s * 0.30
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=round(s * 0.035))
    ang = math.radians(-30)
    hl = s * 0.15
    body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse([c - hl, c - hl * 0.64, c + hl, c + hl * 0.64], fill=(255, 255, 255, 255))
    nr = hl * 0.3
    bd.ellipse([c - hl * 0.15 - nr, c - nr, c - hl * 0.15 + nr, c + nr], fill=(0, 0, 0, 0))
    er = hl * 0.15
    bd.ellipse([c + hl * 0.62 - er, c - hl * 0.2 - er, c + hl * 0.62 + er, c - hl * 0.2 + er], fill=(0, 0, 0, 0))
    body = body.rotate(-math.degrees(ang), resample=Image.BICUBIC, center=(c, c))
    img.alpha_composite(body, (round(s * 0.02), round(-s * 0.02)))
    d = ImageDraw.Draw(img)
    for ax, ay, ar in [(-0.16, 0.13, 0.034), (0.12, 0.17, 0.026), (-0.14, -0.15, 0.022)]:
        d.ellipse([c + s * (ax - ar), c + s * (ay - ar), c + s * (ax + ar), c + s * (ay + ar)], fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def write_ico(path, images):
    """ICO with PNG-compressed entries, one hand-picked image per size."""
    blobs = []
    for im in images:
        buf = io.BytesIO()
        im.save(buf, "PNG", optimize=True)
        blobs.append((im.width, buf.getvalue()))
    header = struct.pack("<HHH", 0, 1, len(blobs))
    offset = 6 + 16 * len(blobs)
    entries, data = b"", b""
    for w, blob in blobs:
        entries += struct.pack("<BBBBHHII", w % 256, w % 256, 0, 0, 1, 32, len(blob), offset + len(data))
        data += blob
    path.write_bytes(header + entries + data)


def save(img, path, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(path, optimize=True)


def main(preview=False):
    master = lens(MASTER)
    full = on_background(1024, 0.8, master)

    if preview:
        sheet = Image.new("RGB", (1400, 760), (70, 70, 70))
        sheet.paste(full.resize((512, 512), Image.LANCZOS), (10, 10))
        x = 540
        for sz in (180, 96, 48, 32, 16):
            img = full.resize((sz, sz), Image.LANCZOS) if sz > 48 else on_background(sz, 1, Image.new("RGBA", (4, 4)))
            if sz <= 48:
                img.alpha_composite(small_lens(round(sz * 0.86)), (round(sz * 0.07), round(sz * 0.07)))
            sheet.paste(img.convert("RGB"), (x, 10))
            sheet.paste(img.convert("RGB").resize((sz * 3, sz * 3), Image.NEAREST) if sz <= 48 else img.convert("RGB"), (x, 220))
            x += sz + 14
        sheet.paste(round_badge(256, master).convert("RGB"), (10, 530 - 10))
        sheet.paste(macos_icon(220, master).convert("RGB"), (280, 530))
        mono = monochrome(220)
        bg = Image.new("RGBA", (220, 220), (60, 90, 70, 255))
        bg.alpha_composite(mono)
        sheet.paste(bg.convert("RGB"), (520, 530))
        fg = on_background(220, 0.62, master)
        m = Image.new("L", (220, 220), 0)
        ImageDraw.Draw(m).ellipse([0, 0, 219, 219], fill=255)
        sheet.paste(fg.convert("RGB"), (760, 530), m)
        out = ROOT / "build" / "icon_preview.png"
        out.parent.mkdir(exist_ok=True)
        sheet.save(out)
        print("wrote", out)
        return

    def small_or_full(size, lens_fraction=0.8):
        if size > 48:
            return on_background(size, lens_fraction, master)
        img = on_background(size, 1, Image.new("RGBA", (4, 4)))
        lens_small = small_lens(round(size * 0.86))
        img.alpha_composite(lens_small, ((size - lens_small.width) // 2, (size - lens_small.height) // 2))
        return img

    save(full, ROOT / "assets/icon/icon.png")

    # Android: adaptive icon (108 dp layers, content inside the 66 dp safe circle),
    # a themed monochrome layer, round legacy icons and the pre-12 splash image.
    res = ROOT / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, f in densities.items():
        layer = round(108 * f)
        fg = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
        lens_size = round(layer * 0.62)
        fg.alpha_composite(master.resize((lens_size, lens_size), Image.LANCZOS), ((layer - lens_size) // 2, (layer - lens_size) // 2))
        save(fg, res / f"drawable-{name}/ic_launcher_foreground.png")
        save(monochrome(layer), res / f"drawable-{name}/ic_launcher_monochrome.png")
        save(round_badge(round(48 * f), master, small_lens), res / f"mipmap-{name}/launcher_icon.png")
        splash = round(132 * f)
        save(master.resize((splash, splash), Image.LANCZOS), res / f"drawable-{name}/launch_lens.png")

    # iOS: full-bleed squares without alpha; the system rounds the corners.
    ios = ROOT / "ios/Runner/Assets.xcassets"
    contents = json.loads((ios / "AppIcon.appiconset/Contents.json").read_text())
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        px = round(points * int(entry["scale"][0]))
        save(small_or_full(px), ios / "AppIcon.appiconset" / entry["filename"], rgb=True)
    for scale in (1, 2, 3):
        name = "LaunchImage.png" if scale == 1 else f"LaunchImage@{scale}x.png"
        save(master.resize((132 * scale, 132 * scale), Image.LANCZOS), ios / "LaunchImage.imageset" / name)

    # macOS.
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(macos_icon(size, master), mac / f"app_icon_{size}.png")

    # Windows: one image per size, the bold drawing for the small ones.
    write_ico(ROOT / "windows/runner/resources/app_icon.ico", [round_badge(s, master, small_lens) for s in (16, 20, 24, 32, 40, 48, 64, 256)])

    # Web: favicons, touch icon, install icons (maskable ones keep the lens inside the 80% safe circle).
    web = ROOT / "web"
    write_ico(web / "favicon.ico", [small_lens(s) for s in (16, 32, 48)])
    save(small_lens(32), web / "favicon.png")
    save(on_background(180, 0.8, master), web / "icons/apple-touch-icon.png", rgb=True)
    for size in (192, 512):
        save(round_badge(size, master), web / f"icons/Icon-{size}.png")
        save(on_background(size, 0.72, master), web / f"icons/Icon-maskable-{size}.png")
    print("icons written")


if __name__ == "__main__":
    main(preview="--preview" in sys.argv)
