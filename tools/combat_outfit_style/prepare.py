"""Bake material groups into the 7 combat outfit atlases with pinned PixelOE."""

from collections import defaultdict
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ART, = (p.parent for p in REPO.glob("*/assets/art/outfits_unified_20261025"))
SOURCE = ART / "outfits_unified_20261025"
OUTPUT = ART / "combat_outfit_blocks_20261107"
sys.path.insert(0, str(REPO / "tools"))
from outfit_material_blocks import carrier_aim_reference, keep_material_edges, pixel_oe


def fill_rect(mask, rect, padding=0):
    x, y, width, height = rect
    mask[max(0, y - padding):y + height + padding,
         max(0, x - padding):x + width + padding] = True


def selective_blocks(cell, pose):
    _, top, _, height = pose["bounds"]
    opacity = cell[:, :, 3]
    y, x = np.ogrid[:cell.shape[0], :cell.shape[1]]
    depth = (y - top) / height

    # Measure the head in each registered pose. Hold the forward portion and
    # leave the hands on their measured contours, including the overlap edge.
    head_start, head_end = top + round(height * 0.04), top + round(height * 0.16)
    _, head_x = np.nonzero(opacity[head_start:head_end] >= 128)
    left, right = np.quantile(head_x, [0.04, 0.96])
    face = (depth < 0.26) & (x >= left + (right - left) * 0.63)
    protected = face.copy()
    for hand in pose["hands"]:
        fill_rect(protected, hand, padding=round(height * 0.012))

    helmet = depth < 0.22
    back = (depth >= 0.17) & (depth < 0.50) & (x <= (left + right) / 2)
    clothing = (depth >= 0.48) & (depth < 0.88)
    chosen = (helmet | back | clothing) & ~protected

    # Preserve the size of the material groups relative to the actor's height
    # across 512 px action cells and the larger 887 px idle sheets.
    grid = round(cell.shape[0] * 35 / height)
    rgb = cell[:, :, :3]
    grouped = keep_material_edges(rgb, pixel_oe(cell, grid=grid, colors=32))
    result = np.where(chosen[:, :, None], grouped, rgb)
    assert np.array_equal(result[protected], rgb[protected])
    return result


def bake_atlas(asset, poses):
    source = ART / "hero_contours_20261025" / asset if asset == "work_pistol.png" else SOURCE / asset
    original = np.array(Image.open(source).convert("RGBA"))
    result = original.copy()
    occupied = np.zeros(original.shape[:2], dtype=bool)
    for pose in poses:
        x, y, width, height = pose["source"]
        assert width == height and x + width <= original.shape[1] and y + height <= original.shape[0], pose
        region = np.s_[y:y + height, x:x + width]
        assert not occupied[region].any(), pose
        occupied[region] = True
        cell = original[region]
        approved = asset == "carrier_long.png" and pose["action"] == "aim"
        colors = carrier_aim_reference(cell, protect_edges=True) if approved else selective_blocks(cell, pose)
        np.copyto(result[region][:, :, :3], colors, where=(cell[:, :, 3] > 0)[:, :, None])
        assert np.any(result[region] != cell), pose

    assert np.array_equal(result[:, :, 3], original[:, :, 3]), asset
    assert np.array_equal(result[~occupied], original[~occupied]), asset
    target = OUTPUT / asset
    Image.fromarray(result).save(target)
    return {
        "source": source.relative_to(ART).as_posix(),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output": target.name,
        "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "pose_count": len(poses),
    }


def main():
    by_asset = defaultdict(list)
    for pose in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")):
        by_asset[pose["asset"]].append(pose)
    assert len(by_asset) == 21 and sum(map(len, by_asset.values())) == 77
    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = [bake_atlas(asset, poses) for asset, poses in by_asset.items()]
    manifest = {
        "tool": "Pinned PixelOE 1.0.1 CPU, contrast, 32 colors, no outline expansion",
        "reference": "Carrier E / long aim from hero_style_2026-11-07",
        "treatment": "Pose-specific material groups on helmet, rear gear and trousers. Contrasting original material edges are protected. RGB only; original alpha and hand contacts.",
        "outputs": outputs,
    }
    (OUTPUT / "provenance.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"OUTFIT STYLE COMPLETE atlases={len(outputs)} poses={sum(map(len, by_asset.values()))}")


if __name__ == "__main__":
    main()
