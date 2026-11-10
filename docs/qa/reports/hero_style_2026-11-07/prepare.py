"""Build comparison-only textures using the pinned PixelOE Python environment."""

from pathlib import Path
import sys

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO / "tools"))
from outfit_material_blocks import carrier_aim_reference, pixel_oe


def soften_values(rgb):
    color = rgb.astype(np.float32)
    peak = color.max(axis=2, keepdims=True)
    dark = np.clip((61 - peak) / 41, 0, 1)
    warmth = np.clip((color[:, :, :1] - color[:, :, 2:] - 23) / 72, 0, 1)
    shadow_target = np.array([39, 44, 49])
    warm_target = np.array([130, 108, 90])
    return np.rint(color + (shadow_target - color) * dark * 0.85
                   + (warm_target - color) * warmth * 0.38).astype(np.uint8)


def group_colors(rgb, alpha):
    # Keep source colors and the original silhouette. For centers outside the
    # body, use the nearest opaque pixel from the same group.
    result = rgb.copy()
    step = 8
    for y in range(0, rgb.shape[0], step):
        for x in range(0, rgb.shape[1], step):
            opaque = np.argwhere(alpha[y:y + step, x:x + step] >= 128)
            if opaque.size:
                center = opaque[np.argmin(((opaque - (step - 1) / 2) ** 2).sum(axis=1))]
                result[y:y + step, x:x + step] = rgb[y + center[0], x + center[1]]
    return result


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    asset, = REPO.glob("*/assets/art/outfits_unified_20261025/carrier_long.png")
    atlas = np.array(Image.open(asset).convert("RGBA"))
    aim = atlas[:512, 512:1024]
    rgb, alpha = aim[:, :, :3], aim[:, :, 3]
    variants = {
        "b": soften_values(rgb),
        "c": group_colors(rgb, alpha),
        "d": pixel_oe(aim),
        "e": carrier_aim_reference(aim),
    }
    for key, colors in variants.items():
        result = atlas.copy()
        cell = result[:512, 512:1024, :3]
        np.copyto(cell, colors, where=(alpha > 0)[:, :, None])
        assert np.array_equal(result[:, :, 3], atlas[:, :, 3]), key
        assert np.any(cell[alpha >= 128] != rgb[alpha >= 128]), key
        Image.fromarray(result).save(out / f"body_{key}.png")


if __name__ == "__main__":
    main()
