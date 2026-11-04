"""Compone el icono, las miniaturas con logo y la vitrina de regalos a partir de los renders de Blender.

    python compose.py icon <render_rgba.png> <salida.png>
    python compose.py thumb <render.png> <salida.png> "<subtítulo>"
    python compose.py shelf <render.png> <salida.png> <catalog.json>
"""

import json
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/inter/Inter-Black.otf",
    "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf",
    "/usr/share/fonts/opentype/inter/Inter-Bold.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def font(size):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        draw.line([(0, y), (w, y)], fill=color)
    return img


def radial_glow(size, center, radius, color, strength=1.0):
    w, h = size
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    steps = 40
    for i in range(steps, 0, -1):
        r = radius * i / steps
        alpha = int(255 * strength * (1 - i / steps) ** 1.6)
        draw.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (alpha,))
    return glow.filter(ImageFilter.GaussianBlur(radius * 0.08))


def snowflakes(img, count, seed, max_size):
    rnd = random.Random(seed)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    w, h = img.size
    for _ in range(count):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.uniform(1, max_size)
        a = int(rnd.uniform(90, 230))
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, a))
    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    return Image.alpha_composite(img, layer)


def outlined_text(img, text, center, size, fill_top, fill_bottom, stroke, stroke_color=(20, 10, 30), shadow=True):
    f = font(size)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=f, stroke_width=stroke)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = center[0] - tw / 2 - bbox[0]
    y = center[1] - th / 2 - bbox[1]
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((x + size * 0.05, y + size * 0.08), text, font=f, fill=(0, 0, 0, 170), stroke_width=stroke, stroke_fill=(0, 0, 0, 170))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.04)))
    draw.text((x, y), text, font=f, fill=stroke_color, stroke_width=stroke, stroke_fill=stroke_color)
    # relleno con degradado
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=f, fill=255)
    top_y = int(y + bbox[1])
    fill = gradient_band(img.size, top_y, th, fill_top, fill_bottom)
    img.paste(fill, (0, 0), mask)


def gradient_band(size, top_y, height, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = min(1, max(0, (y - top_y) / max(1, height)))
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        draw.line([(0, y), (w, y)], fill=color)
    return img


def make_icon(render_path, out_path):
    size = 1024
    img = gradient((size, size), (34, 18, 72), (150, 14, 40))
    img = Image.alpha_composite(img, radial_glow((size, size), (size / 2, size * 0.58), size * 0.5, (255, 200, 90), 0.85))
    img = snowflakes(img, 160, 7, 5)
    presents = Image.open(render_path).convert("RGBA")
    presents = presents.resize((int(size * 0.98), int(size * 0.98)), Image.LANCZOS)
    img.alpha_composite(presents, (int(size * 0.01), int(size * 0.13)))
    outlined_text(img, "DON'T STEAL", (size / 2, size * 0.13), 150, (255, 255, 255), (255, 214, 90), 14)
    outlined_text(img, "THE PRESENT", (size / 2, size * 0.88), 140, (255, 255, 255), (255, 120, 120), 14)
    img = img.resize((512, 512), Image.LANCZOS)
    img.convert("RGB").save(out_path)


def make_thumb(render_path, out_path, subtitle):
    img = Image.open(render_path).convert("RGBA")
    w, h = img.size
    # viñeta suave
    vignette = Image.new("L", img.size, 0)
    vd = ImageDraw.Draw(vignette)
    for i in range(60):
        a = int(150 * (i / 60) ** 2)
        inset = int(i * w / 120)
        vd.rectangle([inset, inset, w - inset, h - inset], outline=255 - a)
    dark = Image.new("RGBA", img.size, (0, 0, 20, 255))
    img = Image.composite(img, dark, vignette.filter(ImageFilter.GaussianBlur(40)))
    band = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(band).rectangle([0, 0, w, int(h * 0.27)], fill=(10, 8, 30, 120))
    img = Image.alpha_composite(img, band.filter(ImageFilter.GaussianBlur(30)))
    outlined_text(img, "DON'T STEAL THE PRESENT", (w / 2, h * 0.11), int(h * 0.105), (255, 255, 255), (255, 210, 80), int(h * 0.011))
    if subtitle:
        outlined_text(img, subtitle, (w / 2, h * 0.215), int(h * 0.045), (200, 255, 200), (110, 230, 140), int(h * 0.006))
    img.convert("RGB").save(out_path)


def make_shelf(render_path, out_path, catalog_path):
    img = Image.open(render_path).convert("RGBA")
    w, h = img.size
    with open(catalog_path) as f:
        catalog = json.load(f)
    bg = gradient(img.size, (18, 26, 64), (6, 8, 26))
    bg = snowflakes(bg, 220, 3, 3)
    img = Image.alpha_composite(bg, img)
    ppu = catalog["pixelsPerStud"]
    x0, y0 = catalog["originX"], catalog["originY"]
    draw = ImageDraw.Draw(img)
    name_font = font(int(ppu * 0.78))
    rarity_font = font(int(ppu * 0.62))
    for entry in catalog["items"]:
        px = (entry["x"] - x0) * ppu
        py = (y0 - entry["y"]) * ppu
        color = tuple(int(c * 255) for c in entry["color"])
        for text, fnt, fill, dy in ((entry["name"], name_font, (255, 255, 255), 0), (entry["rarity"], rarity_font, color, ppu * 0.95)):
            bbox = draw.textbbox((0, 0), text, font=fnt, stroke_width=3)
            draw.text((px - (bbox[2] - bbox[0]) / 2, py + dy), text, font=fnt, fill=fill, stroke_width=3, stroke_fill=(10, 10, 20))
    outlined_text(img, "28 REGALOS · 7 RAREZAS", (w / 2, ppu * 1.4), int(ppu * 1.7), (255, 255, 255), (255, 214, 90), 8)
    img.convert("RGB").save(out_path)


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "icon":
        make_icon(sys.argv[2], sys.argv[3])
    elif mode == "thumb":
        make_thumb(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
    elif mode == "shelf":
        make_shelf(sys.argv[2], sys.argv[3], sys.argv[4])
    print("ok", sys.argv[3])
