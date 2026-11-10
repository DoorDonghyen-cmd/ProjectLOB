"""Small, reproducible PixelOE comparison; never replaces source art.

Run with the pinned .tools/pixeloe/venv Python. PixelOE changes RGB only.
Keep source canvas/alpha exactly so registered hands and feet cannot move.
This is a pilot, not a blanket recipe for transparent animation sheets.
"""
from pathlib import Path
import hashlib
import json
import cv2
import numpy as np
from PIL import Image
from pixeloe.legacy.pixelize import pixelize

REPO = Path(__file__).resolve().parents[1]
ART = REPO / "새-게임-프로젝트/assets/art"
OUTPUT = ART / "style_pilot_20261106"
SOURCES = {
    "rivet": ART / "rivet_twohand_20261106/rivet_carbine_v1.png",
    "hero": ART / "outfits_unified_20261025/work_long.png",
    "hero_idle": ART / "outfits_unified_20261025/work_idle.png",
    "background": ART / "tower_sample_20261003/residential_tower.png",
}
RECIPES = {
    "quiet": {"widths": {"rivet": 96, "hero": 288, "hero_idle": 332, "background": 418}, "colors": 40, "thickness": 0},
    "coarse": {"widths": {"rivet": 64, "hero": 192, "hero_idle": 222, "background": 334}, "colors": 24, "thickness": 1},
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pad_transparent_rgb(rgba):
    rgb = rgba[:, :, :3].copy()
    opaque = rgba[:, :, 3] >= 128
    if opaque.all():
        return rgb
    if not opaque.any():
        raise ValueError("Empty source")
    # Nearest opaque colour fills invisible pixels before RGB-only processing;
    # black transparent padding must not bleed into the silhouette or palette.
    _, labels = cv2.distanceTransformWithLabels((~opaque).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    lookup = np.zeros((int(labels.max()) + 1, 3), dtype=np.uint8)
    lookup[labels[opaque]] = rgb[opaque]
    rgb[~opaque] = lookup[labels[~opaque]]
    return rgb


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cv2.setNumThreads(1)
    rows = []
    for name, source in SOURCES.items():
        image = Image.open(source).convert("RGBA")
        rgba = np.asarray(image)
        padded = pad_transparent_rgb(rgba)
        for variant, recipe in RECIPES.items():
            width = recipe["widths"][name]
            height = round(width * image.height / image.width)
            cv2.setRNGSeed(0)
            result = pixelize(cv2.cvtColor(padded, cv2.COLOR_RGB2BGR), mode="contrast", target_size=[width, height], patch_size=4, thickness=recipe["thickness"], colors=recipe["colors"], contrast=1.0, saturation=1.0, no_upscale=True)
            output = Image.fromarray(cv2.cvtColor(result, cv2.COLOR_BGR2RGB)).resize(image.size, Image.Resampling.NEAREST).convert("RGBA")
            output.putalpha(image.getchannel("A"))
            path = OUTPUT / f"{name}_{variant}.png"
            output.save(path)
            restored = np.asarray(Image.open(path).convert("RGBA"))
            assert restored.shape == rgba.shape and np.array_equal(restored[:, :, 3], rgba[:, :, 3]), name
            rows.append({"asset": name, "variant": variant, "source": str(source.relative_to(REPO)), "output": str(path.relative_to(REPO)), "source_sha256": digest(source.read_bytes()), "output_sha256": digest(path.read_bytes()), "source_size": image.size, "logical_size": [width, height], "colors": recipe["colors"], "thickness": recipe["thickness"], "alpha_unchanged": True, "alpha_sha256": digest(rgba[:, :, 3].tobytes())})
            print(f"PIXEL PILOT {name}/{variant}: {width}x{height}, alpha unchanged", flush=True)
    (OUTPUT / "provenance.json").write_text(json.dumps({"tool": "PixelOE 1.0.1, pinned legacy CPU backend", "opencv_seed": 0, "rgb_preparation": "nearest opaque edge padding", "alpha_policy": "original alpha and canvas preserved, no resampled collision/contact geometry", "status": "comparison only; not production references", "outputs": rows}, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
