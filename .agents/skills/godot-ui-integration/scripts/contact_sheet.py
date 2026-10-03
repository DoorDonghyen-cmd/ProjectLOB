#!/usr/bin/env python3
"""Create a contact sheet for reviewing UI asset candidates."""

from __future__ import annotations

import argparse
import glob
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def expand_inputs(patterns: list[str]) -> list[Path]:
    paths: list[Path] = []
    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            paths.extend(Path(match) for match in matches)
        else:
            paths.append(Path(pattern))
    return [path for path in paths if path.exists()]


def checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, "white")
    draw = ImageDraw.Draw(image)
    colors = ("#f3f4f6", "#d1d5db")
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            color = colors[((x // tile) + (y // tile)) % 2]
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=color)
    return image


def fit_image(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(max_size, Image.Resampling.LANCZOS)
    return copy


def draw_truncated_label(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], max_width: int, font: ImageFont.ImageFont) -> None:
    if draw.textlength(text, font=font) <= max_width:
        draw.text(xy, text, fill="#111827", font=font)
        return
    ellipsis = "..."
    trimmed = text
    while trimmed and draw.textlength(trimmed + ellipsis, font=font) > max_width:
        trimmed = trimmed[:-1]
    draw.text(xy, trimmed + ellipsis, fill="#111827", font=font)


def create_contact_sheet(paths: list[Path], out: Path, columns: int, thumb_size: int, padding: int, labels: bool) -> None:
    if not paths:
        raise ValueError("No existing input images were found.")

    font = ImageFont.load_default()
    label_height = 22 if labels else 0
    cell_width = thumb_size + padding * 2
    cell_height = thumb_size + padding * 2 + label_height
    rows = math.ceil(len(paths) / columns)
    sheet = Image.new("RGB", (cell_width * columns, cell_height * rows), "#ffffff")
    draw = ImageDraw.Draw(sheet)

    for idx, path in enumerate(paths):
        col = idx % columns
        row = idx // columns
        left = col * cell_width
        top = row * cell_height
        cell_bg = checkerboard((cell_width, cell_height - label_height))
        sheet.paste(cell_bg, (left, top))

        with Image.open(path) as image:
            preview = fit_image(image.convert("RGBA"), (thumb_size, thumb_size))
        px = left + padding + (thumb_size - preview.width) // 2
        py = top + padding + (thumb_size - preview.height) // 2
        sheet.paste(preview, (px, py), preview)

        draw.rectangle((left, top, left + cell_width - 1, top + cell_height - 1), outline="#9ca3af")
        if labels:
            label_y = top + cell_height - label_height + 5
            draw_truncated_label(draw, path.name, (left + padding, label_y), cell_width - padding * 2, font)

    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", help="Input image paths or glob patterns")
    parser.add_argument("--out", required=True, type=Path, help="Output contact sheet image")
    parser.add_argument("--columns", type=int, default=4, help="Number of columns")
    parser.add_argument("--thumb-size", type=int, default=180, help="Maximum thumbnail size in pixels")
    parser.add_argument("--padding", type=int, default=14, help="Padding inside each cell")
    parser.add_argument("--no-labels", action="store_true", help="Hide filename labels")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paths = expand_inputs(args.images)
    try:
        create_contact_sheet(paths, args.out, args.columns, args.thumb_size, args.padding, not args.no_labels)
    except Exception as exc:  # pragma: no cover - CLI guard
        print(f"Failed: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
