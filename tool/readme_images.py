"""Builds the README images from the PNGs the screen-render test writes.

1. Render the screens inside the real macOS app (no network, no key):

       flutter test integration_test/voice_ui_preview_test.dart -d macos

   It prints `PREVIEW <path>` for every PNG it writes.

2. Collect them into docs/ and build the banner and social preview:

       uv run --with pillow python tool/readme_images.py <folder-with-the-PNGs>

Outputs (all committed): docs/screenshots/*.png, docs/banner.png and
docs/social-preview.png (1280x640, upload it under the repository's
Settings -> Social preview).
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
FONT = ROOT / "assets" / "fonts" / "Inter.ttf"

# README name <- the preview test's file name.
SCREENS = {
    "home": "ui_02_home_previous.png",
    "chat": "ui_14_chat_markdown.png",
    "voice-listening": "ui_08_voice_full_sentence.png",
    "voice-thinking": "ui_09_voice_thinking.png",
    "voice-speaking": "ui_10_voice_speaking.png",
    "settings": "ui_15_settings.png",
    "licences": "ui_16_licences.png",
}

SILVER = (238, 238, 234)
SOFT = (184, 184, 180)
DIM = (138, 138, 134)


def inter(size: int, weight: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT), size)
    try:
        axes = font.get_variation_axes()
        values = []
        for axis in axes:
            name = axis["name"]
            name = name.decode() if isinstance(name, bytes) else name
            if name.lower().startswith("weight"):
                values.append(max(axis["minimum"], min(axis["maximum"], weight)))
            elif name.lower().startswith("optical"):
                values.append(axis["maximum"] if size >= 32 else axis["default"])
            else:
                values.append(axis["default"])
        font.set_variation_by_axes(values)
    except Exception:  # a static font, or FreeType without variation support
        pass
    return font


def rounded(image: Image.Image, radius: int) -> Image.Image:
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius, fill=255
    )
    image.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    return image


def phone(shot: Image.Image, width: int) -> Image.Image:
    """The screenshot with rounded corners and a thin bezel line."""
    height = round(shot.height * width / shot.width)
    shot = shot.convert("RGB").resize((width, height), Image.LANCZOS)
    radius = round(width * 0.115)
    body = rounded(shot, radius)
    frame = Image.new("RGBA", (width + 6, height + 6), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (0, 0, frame.width - 1, frame.height - 1),
        radius + 3,
        fill=(34, 34, 33, 255),
        outline=(70, 70, 68, 255),
        width=2,
    )
    frame.alpha_composite(body, (3, 3))
    return frame


def glow(size: tuple[int, int], center: tuple[float, float], radius: int, alpha: int):
    """A soft monochrome radial glow, like the app's voice backdrop."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    spot = Image.radial_gradient("L").resize((radius * 2, radius * 2), Image.BICUBIC)
    # radial_gradient reaches 255 only in the corners, so rescale it to hit 255 at
    # the edge midpoints; the glow then fades to nothing inside its square.
    spot = spot.point(lambda v: round(alpha * (1 - min(1.0, v * 1.42 / 255)) ** 2))
    tint = Image.new("RGBA", spot.size, SOFT + (0,))
    tint.putalpha(spot)
    layer.alpha_composite(
        tint, (round(center[0] - radius), round(center[1] - radius))
    )
    return layer


# (screen, centre x as a fraction of the width, top as a fraction of the height, scale)
WIDE = [("home", 0.955, 0.19, 1.0), ("chat", 0.575, 0.19, 1.0), ("voice-speaking", 0.765, 0.09, 1.1)]
SQUARE_ISH = [("chat", 0.675, 0.19, 0.92), ("voice-speaking", 0.885, 0.09, 1.0)]


def banner(
    shots: dict[str, Image.Image],
    size: tuple[int, int],
    layout: list[tuple[str, float, float, float]],
) -> Image.Image:
    width, height = size
    canvas = Image.new("RGBA", size, (0, 0, 0, 255))
    canvas.alpha_composite(glow(size, (width * 0.72, height * 1.05), int(width * 0.38), 120))
    canvas.alpha_composite(glow(size, (width * 0.05, -height * 0.1), int(width * 0.25), 40))

    draw = ImageDraw.Draw(canvas)
    left = round(width * 0.07)
    title_size = round(height * 0.22)
    draw.text((left, height * 0.2), "Cryonis", font=inter(title_size, 700), fill=SILVER)
    draw.text(
        (left, height * 0.2 + title_size * 1.28),
        "A voice-first AI assistant.",
        font=inter(round(height * 0.068), 500),
        fill=SOFT,
    )
    draw.text(
        (left, height * 0.2 + title_size * 1.28 + height * 0.1),
        "Chat or talk to Cryo, in English and Hindi.",
        font=inter(round(height * 0.052), 400),
        fill=DIM,
    )
    chips = ["Flutter", "Ollama Cloud", "LiveKit"]
    chip_font = inter(round(height * 0.04), 500)
    x = left
    y = height * 0.2 + title_size * 1.28 + height * 0.235
    pad = round(height * 0.025)
    for chip in chips:
        text_w = draw.textlength(chip, font=chip_font)
        box = (x, y, x + text_w + pad * 2, y + chip_font.size + pad * 1.2)
        draw.rounded_rectangle(box, radius=pad, fill=(29, 29, 28), outline=(60, 60, 58))
        draw.text((x + pad, y + pad * 0.55), chip, font=chip_font, fill=SOFT)
        x = box[2] + pad * 0.8

    # Phones bleeding off the bottom edge, drawn in list order (the last is in front).
    phone_w = round(height * 0.44)
    for name, cx, top, scale in layout:
        img = phone(shots[name], round(phone_w * scale))
        canvas.alpha_composite(img, (round(width * cx - img.width / 2), round(height * top)))
    return canvas.convert("RGB")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    shots_dir = DOCS / "screenshots"
    shots_dir.mkdir(parents=True, exist_ok=True)

    shots: dict[str, Image.Image] = {}
    for name, original in SCREENS.items():
        path = source / original
        if not path.exists():
            sys.exit(f"missing {path}; run the preview test first")
        image = Image.open(path).convert("RGB")
        image.save(shots_dir / f"{name}.png", optimize=True)
        shots[name] = image
        print("wrote", shots_dir / f"{name}.png", image.size)

    banner(shots, (1600, 640), WIDE).save(DOCS / "banner.png", optimize=True)
    banner(shots, (1280, 640), SQUARE_ISH).save(DOCS / "social-preview.png", optimize=True)
    print("wrote", DOCS / "banner.png", "and", DOCS / "social-preview.png")


if __name__ == "__main__":
    main()
