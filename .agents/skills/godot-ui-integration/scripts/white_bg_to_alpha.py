#!/usr/bin/env python3
"""Remove edge-connected white backgrounds from UI cutout images."""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


def flattened_pixels(image: Image.Image) -> list[int]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def is_whiteish(pixel: tuple[int, int, int, int], threshold: int, spread: int) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    return min(red, green, blue) >= threshold and (max(red, green, blue) - min(red, green, blue)) <= spread


def connected_background_mask(image: Image.Image, threshold: int, spread: int) -> Image.Image:
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def enqueue_if_bg(x: int, y: int) -> None:
        idx = index(x, y)
        if visited[idx]:
            return
        if is_whiteish(pixels[x, y], threshold, spread):
            visited[idx] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue_if_bg(x, 0)
        enqueue_if_bg(x, height - 1)
    for y in range(height):
        enqueue_if_bg(0, y)
        enqueue_if_bg(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue_if_bg(x - 1, y)
        if x + 1 < width:
            enqueue_if_bg(x + 1, y)
        if y > 0:
            enqueue_if_bg(x, y - 1)
        if y + 1 < height:
            enqueue_if_bg(x, y + 1)

    mask = Image.new("L", (width, height), 0)
    mask.putdata([255 if value else 0 for value in visited])
    return mask


def remove_white_bg(source: Path, out: Path, threshold: int, spread: int, soft_edge: float, force: bool) -> None:
    if out.exists() and not force:
        raise FileExistsError(f"Output exists: {out}. Use --force to overwrite.")

    image = Image.open(source).convert("RGBA")
    bg_mask = connected_background_mask(image, threshold, spread)
    if soft_edge > 0:
        bg_mask = bg_mask.filter(ImageFilter.GaussianBlur(radius=soft_edge))

    red, green, blue, alpha = image.split()
    new_alpha = Image.new("L", image.size, 0)
    source_alpha = flattened_pixels(alpha)
    background = flattened_pixels(bg_mask)
    new_alpha.putdata([
        max(0, min(255, int(src * (255 - bg) / 255)))
        for src, bg in zip(source_alpha, background)
    ])

    result = Image.merge("RGBA", (red, green, blue, new_alpha))
    out.parent.mkdir(parents=True, exist_ok=True)
    result.save(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Source image with a white background")
    parser.add_argument("--out", required=True, type=Path, help="Output transparent PNG")
    parser.add_argument("--threshold", type=int, default=245, help="Minimum RGB channel value treated as white background")
    parser.add_argument("--spread", type=int, default=24, help="Maximum RGB channel spread treated as neutral white background")
    parser.add_argument("--soft-edge", type=float, default=1.2, help="Gaussian blur radius for alpha feathering")
    parser.add_argument("--force", action="store_true", help="Overwrite the output file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.input.exists():
        print(f"Missing input file: {args.input}", file=sys.stderr)
        return 1
    try:
        remove_white_bg(args.input, args.out, args.threshold, args.spread, args.soft_edge, args.force)
    except Exception as exc:  # pragma: no cover - CLI guard
        print(f"Failed: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
