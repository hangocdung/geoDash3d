"""Packs the Codex-generated source images (art_source/textures/*.png, not committed) into the channel-packed
detail textures the neon shaders sample once per pixel:

  assets/textures/track_detail.png    R = road plates, G = circuit traces (glow mask), B = side panels,
                                      A = hex plates (raised blocks)
  assets/textures/scenery_detail.png  R = lit windows (glow mask), G = pillar ribs, B = facade structure

Every source is made seamless first: the tile is cropped to the repeat period that best matches its own start
(so regular grids line up), then a narrow cross-fade hides what is left of the seam. Grayscale, 512 px.
Sources come from Codex image generation: bash tools/textures/generate_sources.sh (prompts inside).
Usage: python tools/textures/build_textures.py   Related: src/presentation/shaders/neon_track.gdshader
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SOURCE_DIR = os.path.join(ROOT, "art_source", "textures")
OUT_DIR = os.path.join(ROOT, "assets", "textures")
SIZE = 512
# Search the repeat period within this fraction of the image, comparing this many leading pixels.
MIN_PERIOD_FRACTION = 0.6
MATCH_PIXELS = 12
BLEND_PIXELS = 40


def load_gray(name):
    image = Image.open(os.path.join(SOURCE_DIR, name + ".png")).convert("L")
    return np.asarray(image).astype(np.float64) / 255.0


def best_period(gray, axis):
    """Period along `axis` whose following pixels best repeat the image's first pixels."""
    data = gray if axis == 1 else gray.T
    length = data.shape[1]
    head = data[:, :MATCH_PIXELS]
    best, best_error = length, None
    for period in range(int(length * MIN_PERIOD_FRACTION), length - MATCH_PIXELS):
        error = np.abs(data[:, period:period + MATCH_PIXELS] - head).mean()
        if best_error is None or error < best_error:
            best, best_error = period, error
    return best


def seamless_axis(gray, axis):
    """Crops to the best period, then cross-fades the start into the pixels just past the crop."""
    data = gray if axis == 1 else gray.T
    period = best_period(gray, axis)
    blend = min(BLEND_PIXELS, data.shape[1] - period)
    tile = data[:, :period].copy()
    if blend > 0:
        weight = np.linspace(0.0, 1.0, blend)[None, :]
        # The first columns fade from the continuation of the last column (data[period + i]) to themselves.
        tile[:, :blend] = data[:, period:period + blend] * (1.0 - weight) + data[:, :blend] * weight
    return tile if axis == 1 else tile.T


def seamless(gray):
    return seamless_axis(seamless_axis(gray, 1), 0)


def resized(gray):
    image = Image.fromarray(np.clip(gray * 255.0, 0, 255).astype(np.uint8), "L")
    return np.asarray(image.resize((SIZE, SIZE), Image.LANCZOS)).astype(np.float64) / 255.0


def normalized(gray, low=1.0, high=99.0):
    """Stretches the 1st..99th percentile to 0..1 so every channel uses the full range."""
    lo, hi = np.percentile(gray, low), np.percentile(gray, high)
    return np.clip((gray - lo) / max(hi - lo, 1e-6), 0.0, 1.0)


def mask(gray, threshold, softness=0.08):
    return np.clip((gray - threshold) / softness, 0.0, 1.0)


def thickened(gray, size):
    """Widens thin bright lines so they survive mipmapping on the road (seen at a grazing angle)."""
    image = Image.fromarray(np.clip(gray * 255.0, 0, 255).astype(np.uint8), "L")
    image = image.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.GaussianBlur(1.0))
    return np.asarray(image).astype(np.float64) / 255.0


def channel(name):
    return resized(seamless(load_gray(name)))


def save(path, channels):
    stacked = np.stack([np.clip(c * 255.0 + 0.5, 0, 255).astype(np.uint8) for c in channels], axis=-1)
    Image.fromarray(stacked, "RGBA" if len(channels) == 4 else "RGB").save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    road = normalized(channel("track_panel"))
    traces = thickened(mask(normalized(channel("circuit")), 0.45), 5)
    sides = normalized(channel("side_panel"))
    hexes = normalized(channel("hex_plate"))
    save(os.path.join(OUT_DIR, "track_detail.png"), [road, traces, sides, hexes])
    facade = normalized(channel("tower_facade"))
    windows = mask(facade, 0.75)
    ribs = normalized(channel("pillar_ribs"))
    save(os.path.join(OUT_DIR, "scenery_detail.png"), [windows, ribs, facade])


if __name__ == "__main__":
    main()
