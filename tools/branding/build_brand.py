"""Build the BeatGlide brand assets in assets/brand/ from the Codex sources (art_source/brand, not committed) and the
company logo: boot splash, title logo with alpha, project/store icons and Android launcher icons.
Usage: python tools/branding/build_brand.py [--logo logo_a] [--icon icon_a] [--company D:/sntgames/docs/logo.webp]
Related: tools/branding/generate_sources.sh, project.godot (boot_splash, config/icon), export_presets.cfg (launcher_icons)
"""
import argparse
from pathlib import Path

import numpy
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "art_source" / "brand"
OUT = ROOT / "assets" / "brand"
SPLASH_SIZE = 1600          # square canvas: "Keep" stretch shows the logo at the same size in landscape and portrait
SPLASH_LOGO_WIDTH = 0.55    # company logo width as a fraction of the splash canvas
ADAPTIVE_SIZE = 432


def crop_to_content(image: Image.Image, threshold: int = 12, margin: float = 0.03) -> Image.Image:
    """Trim the transparent / black border around a bright-on-dark image, keeping a margin for the glow."""
    luminance = image.convert("RGBA").split()[3] if image.mode == "RGBA" else image.convert("L")
    box = luminance.point(lambda v: 255 if v > threshold else 0).getbbox()
    if box is None:
        raise SystemExit("image has no visible content")
    pad = round(max(box[2] - box[0], box[3] - box[1]) * margin)
    return image.crop((max(0, box[0] - pad), max(0, box[1] - pad),
                       min(image.width, box[2] + pad), min(image.height, box[3] + pad)))


def build_splash(company: Path) -> None:
    logo = crop_to_content(Image.open(company).convert("RGBA"))
    width = int(SPLASH_SIZE * SPLASH_LOGO_WIDTH)
    logo = logo.resize((width, round(logo.height * width / logo.width)), Image.LANCZOS)
    canvas = Image.new("RGBA", (SPLASH_SIZE, SPLASH_SIZE), (0, 0, 0, 255))
    canvas.alpha_composite(logo, ((SPLASH_SIZE - logo.width) // 2, (SPLASH_SIZE - logo.height) // 2))
    canvas.convert("RGB").save(OUT / "splash.png", optimize=True)


def black_to_alpha(image: Image.Image) -> Image.Image:
    """Neon art on pure black -> straight-alpha RGBA (alpha = brightest channel, colour un-premultiplied)."""
    rgb = numpy.asarray(image.convert("RGB"), dtype=numpy.float32)
    peak = rgb.max(axis=2, keepdims=True)
    alpha = numpy.clip((peak - 10.0) / 235.0, 0.0, 1.0)
    colour = numpy.where(peak > 0, rgb * 255.0 / numpy.maximum(peak, 1.0), 0.0)
    out = numpy.concatenate([colour, alpha * 255.0], axis=2)
    return Image.fromarray(numpy.round(out).astype(numpy.uint8), "RGBA")


def build_logo(source: Path) -> None:
    logo = crop_to_content(black_to_alpha(Image.open(source)))
    logo.thumbnail((1400, 800), Image.LANCZOS)
    logo.save(OUT / "logo.png", optimize=True)


def square_center(image: Image.Image) -> Image.Image:
    side = min(image.size)
    left, top = (image.width - side) // 2, (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).convert("RGB")


def build_icons(source: Path) -> None:
    icon = square_center(Image.open(source))
    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon_512.png", optimize=True)
    icon.resize((256, 256), Image.LANCZOS).save(OUT / "icon.png", optimize=True)
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "icon_192.png", optimize=True)
    # Adaptive: the full-bleed art is the background layer (launcher masks show its centre, where the cube sits);
    # the foreground layer stays empty so the art is not drawn twice.
    icon.resize((ADAPTIVE_SIZE, ADAPTIVE_SIZE), Image.LANCZOS).save(OUT / "icon_adaptive_bg.png", optimize=True)
    Image.new("RGBA", (ADAPTIVE_SIZE, ADAPTIVE_SIZE), (0, 0, 0, 0)).save(OUT / "icon_adaptive_fg.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--logo", default="logo_a")
    parser.add_argument("--icon", default="icon_a")
    parser.add_argument("--company", default="D:/sntgames/docs/logo.webp")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    build_splash(Path(args.company))
    build_logo(SOURCES / f"{args.logo}.png")
    build_icons(SOURCES / f"{args.icon}.png")
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
