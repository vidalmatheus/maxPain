#!/usr/bin/env python3
"""Builds the street's textures from ambientCG materials (CC0).

Usage: tools/prepare_textures.py <source dir>

The source dir must contain these ambientCG downloads (1K-JPG), unzipped
into folders named after them: Asphalt026C, Concrete044D, Facade018A,
Facade020A, Facade009, Snow010A (https://ambientcg.com/a/<name>).

Besides resizing, it:
- draws the joints between the concrete slabs of the sidewalk,
- lights some of the facades' windows at night: an emission map where a
  random quarter of the windows glow warm (or the blue of a TV), with the
  window colors warmed up to match and the dark windows darkened.

Requires Pillow and NumPy.
"""

import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__))
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures" / "street"
OUT.mkdir(parents=True, exist_ok=True)

# Window colors: mostly warm lamps, a few cold TVs and fluorescent tubes.
LIGHTS = [(255, 196, 120)] * 6 + [(255, 170, 90)] * 3 + [(140, 170, 255), (220, 235, 255)]


def source(name: str, kind: str) -> Image.Image:
    return Image.open(SRC / name / f"{name}_1K-JPG_{kind}.jpg").convert("RGB")


def save(image: Image.Image, name: str, size: int) -> None:
    image.resize((size, size), Image.LANCZOS).save(OUT / name, quality=88)
    print(name)


def sidewalk() -> None:
    # The texture covers 3 x 3 m: four 1.5 m slabs with joints between them.
    image = source("Concrete044D", "Color")
    draw = ImageDraw.Draw(image)
    w, h = image.size
    for x in (0, w // 2):
        draw.rectangle([x - 3, 0, x + 3, h], fill=(70, 68, 66))
    for y in (0, h // 2):
        draw.rectangle([0, y - 3, w, y + 3], fill=(70, 68, 66))
    save(image, "sidewalk_color.jpg", 512)


def facade(name: str, out: str, seed: int, windows: int = 6, half_size: int = 61) -> None:
    """The facades have a regular grid of windows x windows per tile, with
    window centers at multiples of the period (wrapping around the edges)."""
    color = np.asarray(source(name, "Color")).astype(np.float32)
    size = color.shape[0]
    r, g, b = color[..., 0], color[..., 1], color[..., 2]
    glass = (b >= r - 2) & (np.abs(r - g) < 12)
    emission = np.zeros_like(color)
    rng = random.Random(seed)
    period = size / windows
    yy, xx = np.mgrid[0:size, 0:size]
    # Unlit windows are dark glass at night.
    color[glass] *= 0.55
    for row in range(windows):
        for column in range(windows):
            if rng.random() > 0.27:
                continue
            light = np.array(rng.choice(LIGHTS), np.float32)
            brightness = rng.uniform(0.55, 1.0)
            dx = (xx - column * period + size / 2) % size - size / 2
            dy = (yy - row * period + size / 2) % size - size / 2
            window = (np.abs(dx) < half_size) & (np.abs(dy) < half_size) & glass
            # Curtains and blinds (the lighter glass) glow the most.
            shade = (color[window].mean(axis=1, keepdims=True) / 140.0).clip(0, 1) * 0.6 + 0.4
            emission[window] = light * brightness * shade
            color[window] = color[window] * 0.35 + light * brightness * shade * 0.65
    save(Image.fromarray(color.clip(0, 255).astype(np.uint8)), f"{out}_color.jpg", 1024)
    save(Image.fromarray(emission.clip(0, 255).astype(np.uint8)), f"{out}_emission.jpg", 512)
    save(source(name, "NormalGL"), f"{out}_normal.jpg", 512)


def main() -> None:
    save(source("Asphalt026C", "Color"), "asphalt_color.jpg", 1024)
    save(source("Asphalt026C", "NormalGL"), "asphalt_normal.jpg", 512)
    sidewalk()
    save(source("Concrete044D", "NormalGL"), "sidewalk_normal.jpg", 512)
    facade("Facade018A", "facade_a", seed=18)
    facade("Facade020A", "facade_b", seed=20)
    # Distant office towers: dark glass, with the source's own lit offices.
    save(source("Facade009", "Color"), "tower_color.jpg", 512)
    save(source("Facade009", "Emission"), "tower_emission.jpg", 512)
    save(source("Snow010A", "Color"), "snow_color.jpg", 512)
    save(source("Snow010A", "NormalGL"), "snow_normal.jpg", 512)


main()
