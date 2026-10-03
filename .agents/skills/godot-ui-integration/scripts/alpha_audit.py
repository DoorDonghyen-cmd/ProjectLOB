#!/usr/bin/env python3
"""Audit alpha quality for transparent PNG UI assets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image


def flattened_pixels(image: Image.Image) -> list[int]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def audit_image(path: Path) -> dict:
    with Image.open(path) as image:
        original_mode = image.mode
        width, height = image.size
        has_alpha = "A" in image.getbands()
        rgba = image.convert("RGBA")

    alpha = rgba.getchannel("A")
    pixels = flattened_pixels(alpha)
    total = width * height
    transparent = sum(1 for value in pixels if value == 0)
    partial = sum(1 for value in pixels if 0 < value < 255)
    opaque = sum(1 for value in pixels if value == 255)
    nonzero = total - transparent
    bbox = alpha.getbbox()

    corners = {
        "top_left": alpha.getpixel((0, 0)),
        "top_right": alpha.getpixel((width - 1, 0)),
        "bottom_left": alpha.getpixel((0, height - 1)),
        "bottom_right": alpha.getpixel((width - 1, height - 1)),
    }

    return {
        "path": str(path),
        "mode": original_mode,
        "size": [width, height],
        "has_alpha": has_alpha,
        "corner_alpha": corners,
        "transparent_pixels": transparent,
        "partial_alpha_pixels": partial,
        "opaque_pixels": opaque,
        "nonzero_alpha_pixels": nonzero,
        "nonzero_alpha_coverage": round(nonzero / total, 6) if total else 0,
        "nonzero_alpha_bbox": list(bbox) if bbox else None,
    }


def format_report(result: dict) -> str:
    corners = ", ".join(f"{key}={value}" for key, value in result["corner_alpha"].items())
    return (
        f"{result['path']}\n"
        f"  mode={result['mode']} size={result['size'][0]}x{result['size'][1]} "
        f"has_alpha={result['has_alpha']}\n"
        f"  corners: {corners}\n"
        f"  pixels: transparent={result['transparent_pixels']} "
        f"partial={result['partial_alpha_pixels']} opaque={result['opaque_pixels']} "
        f"coverage={result['nonzero_alpha_coverage']}\n"
        f"  bbox={result['nonzero_alpha_bbox']}"
    )


def strict_failures(result: dict, max_corner_alpha: int, min_coverage: float) -> list[str]:
    failures: list[str] = []
    if result["mode"] != "RGBA":
        failures.append("image mode is not RGBA")
    if not result["has_alpha"]:
        failures.append("image has no alpha channel")
    if result["nonzero_alpha_coverage"] < min_coverage:
        failures.append("non-transparent coverage is too low")
    bad_corners = {
        key: value
        for key, value in result["corner_alpha"].items()
        if value > max_corner_alpha
    }
    if bad_corners:
        failures.append(f"corner alpha exceeds {max_corner_alpha}: {bad_corners}")
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path, help="PNG files to audit")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    parser.add_argument("--strict", action="store_true", help="Fail on non-RGBA, missing alpha, opaque corners, or empty subject")
    parser.add_argument("--max-corner-alpha", type=int, default=0, help="Allowed alpha value at image corners in strict mode")
    parser.add_argument("--min-coverage", type=float, default=0.0001, help="Minimum non-transparent coverage in strict mode")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    results = []
    failed = False

    for path in args.images:
        if not path.exists():
            print(f"Missing file: {path}", file=sys.stderr)
            failed = True
            continue
        try:
            result = audit_image(path)
        except Exception as exc:  # pragma: no cover - CLI guard
            print(f"Failed to audit {path}: {exc}", file=sys.stderr)
            failed = True
            continue
        results.append(result)
        if args.strict:
            failures = strict_failures(result, args.max_corner_alpha, args.min_coverage)
            if failures:
                result["strict_failures"] = failures
                failed = True

    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        for result in results:
            print(format_report(result))
            for failure in result.get("strict_failures", []):
                print(f"  STRICT FAIL: {failure}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
