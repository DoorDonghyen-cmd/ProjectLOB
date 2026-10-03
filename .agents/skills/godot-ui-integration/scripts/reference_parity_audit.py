#!/usr/bin/env python3
"""Create side-by-side, overlay, and difference views for UI parity review."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps, ImageStat


def flatten(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    background = Image.new("RGBA", rgba.size, "#000000")
    return Image.alpha_composite(background, rgba).convert("RGB")


def add_label(image: Image.Image, label: str, label_height: int = 30) -> Image.Image:
    canvas = Image.new("RGB", (image.width, image.height + label_height), "#111318")
    canvas.paste(image, (0, label_height))
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 8), label, fill="#f1eee4", font=ImageFont.load_default())
    return canvas


def create_audit(
    reference_path: Path,
    runtime_path: Path,
    out_path: Path,
    panel_width: int,
    opacity: float,
    allow_aspect_mismatch: bool,
) -> dict[str, float | int]:
    with Image.open(reference_path) as source:
        reference = flatten(source)
    with Image.open(runtime_path) as source:
        runtime = flatten(source)

    reference_ratio = reference.width / reference.height
    runtime_ratio = runtime.width / runtime.height
    aspect_delta = abs(reference_ratio - runtime_ratio) / reference_ratio
    if aspect_delta > 0.005 and not allow_aspect_mismatch:
        raise ValueError(
            f"Aspect ratios differ by {aspect_delta:.2%}: "
            f"reference={reference.width}x{reference.height}, runtime={runtime.width}x{runtime.height}. "
            "Capture a matching aspect ratio or pass --allow-aspect-mismatch."
        )

    panel_width = max(320, panel_width)
    panel_height = max(180, round(panel_width / reference_ratio))
    target_size = (panel_width, panel_height)
    reference = reference.resize(target_size, Image.Resampling.LANCZOS)
    if allow_aspect_mismatch and aspect_delta > 0.005:
        runtime = ImageOps.pad(runtime, target_size, method=Image.Resampling.LANCZOS, color="#000000")
    else:
        runtime = runtime.resize(target_size, Image.Resampling.LANCZOS)

    overlay = Image.blend(reference, runtime, opacity)
    difference = ImageChops.difference(reference, runtime)
    difference_view = ImageOps.autocontrast(difference)
    stat = ImageStat.Stat(difference)
    mean_absolute_error = sum(stat.mean) / (len(stat.mean) * 255.0)
    rms = math.sqrt(sum(value * value for value in stat.rms) / len(stat.rms)) / 255.0

    panels = [
        add_label(reference, "APPROVED REFERENCE"),
        add_label(runtime, "RUNTIME CAPTURE"),
        add_label(overlay, f"OVERLAY ({opacity:.0%} runtime)"),
        add_label(difference_view, "AMPLIFIED DIFFERENCE"),
    ]
    gap = 16
    sheet = Image.new(
        "RGB",
        (panels[0].width * 2 + gap, panels[0].height * 2 + gap),
        "#08090b",
    )
    sheet.paste(panels[0], (0, 0))
    sheet.paste(panels[1], (panels[0].width + gap, 0))
    sheet.paste(panels[2], (0, panels[0].height + gap))
    sheet.paste(panels[3], (panels[0].width + gap, panels[0].height + gap))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)

    return {
        "reference_width": reference.width,
        "reference_height": reference.height,
        "aspect_delta": aspect_delta,
        "mean_absolute_error": mean_absolute_error,
        "rms_difference": rms,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path, help="Approved design image")
    parser.add_argument("--runtime", required=True, type=Path, help="Runtime screenshot")
    parser.add_argument("--out", required=True, type=Path, help="Output audit image")
    parser.add_argument("--panel-width", type=int, default=960, help="Width of each comparison panel")
    parser.add_argument("--opacity", type=float, default=0.5, help="Runtime opacity in the overlay")
    parser.add_argument(
        "--allow-aspect-mismatch",
        action="store_true",
        help="Letterbox a mismatched runtime capture instead of failing",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not 0.0 <= args.opacity <= 1.0:
        print("--opacity must be between 0 and 1", file=sys.stderr)
        return 2
    try:
        metrics = create_audit(
            args.reference,
            args.runtime,
            args.out,
            args.panel_width,
            args.opacity,
            args.allow_aspect_mismatch,
        )
    except Exception as exc:
        print(f"Failed: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {args.out}")
    print(
        "Diagnostics: aspect_delta={aspect_delta:.4%}, "
        "mean_absolute_error={mean_absolute_error:.4f}, "
        "rms_difference={rms_difference:.4f}".format(**metrics)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
