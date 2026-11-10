"""Bake the approved G body grid and front hands from registered combat poses."""

from collections import deque
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ART, = (path.parent for path in REPO.glob("*/assets/art/combat_outfit_blocks_20261107"))
SOURCE = ART / "combat_outfit_blocks_20261107"
OUTPUT = ART / "combat_outfit_grid_20261108"
REPORTS = REPO / "docs/qa/reports"
OUTFITS = ("work", "carrier", "scout", "heatworker", "hoist", "recovery", "expedition")
FAMILIES = ("pistol", "long")
ACTIONS = ("idle", "aim", "recoil", "reload_open", "reload_seat", "cooling")
SIZE = (83, 56)
SIDES = ((0, -1), (0, 1), (-1, 0), (1, 0))

# A logical body tile spans two pixels in the reference combat viewport.
# The weapon is still drawn on its own 768 x 512 surface.
REFERENCE_EXTENT = np.array([165, 110])
ACTOR_EXTENT = np.array([768, 512])
GRID_ORIGIN = np.array([-1, -1])
ACTOR_FOOT = np.array([240, 480])
PALETTE = """
181e20 282b2c 293640 384750 4a5758 3f3930 585044 716552 817163 9a8068
b49a7c 624033 8f4836 aa6144 875c38 b1824b d8a665 f2bb77 f0deb3 f8edd6
"""
MATERIALS = {
    "work": "293b56 344f76 4a6383 6b8197",
    "carrier": "",
    "scout": "39474c 52615e 7c806d b5ad8b",
    "heatworker": "2d4165 3f557b 556d92 b28d5e",
    "hoist": "27384e 3d5173 596c8a bbb6a8 d2cbc1",
    "recovery": "344342 485b56 5e6a5d 9a9a76",
    "expedition": "5a513c 706344 93816a a99a7a c4ad79 d4bb81",
}


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def rgb(hex_value):
    return list(bytes.fromhex(hex_value))


def to_source(screen, pose):
    scale = pose["scale"]
    offset = ACTOR_FOOT - np.array(pose["foot"]) * scale
    return (screen * ACTOR_EXTENT / REFERENCE_EXTENT - offset) / scale


def bake_pose(image, pose):
    x, y, width, height = pose["source"]
    source = image[y:y + height, x:x + width]
    yy, xx = np.mgrid[:SIZE[1], :SIZE[0]]
    corner = np.stack((xx, yy), axis=-1) * 2 + GRID_ORIGIN
    offsets = np.array([(dx, dy) for dy in (0.33, 1.0, 1.67) for dx in (0.33, 1.0, 1.67)])
    local = to_source(corner[:, :, None] + offsets, pose)
    ix, iy = np.floor(local).astype(int).transpose(3, 0, 1, 2)
    inside = (ix >= 0) & (iy >= 0) & (ix < width) & (iy < height)
    samples = source[iy.clip(0, height - 1), ix.clip(0, width - 1)]
    votes_mask = inside & (samples[:, :, :, 3] >= 128)
    palette = np.array([rgb(code) for code in (PALETTE + MATERIALS[pose["outfit"]]).split()])
    delta = samples[:, :, :, None, :3].astype(np.int32) - palette
    closest = ((delta ** 2) * [3, 4, 2]).sum(axis=-1).argmin(axis=-1)
    votes = np.stack([((closest == index) & votes_mask).sum(axis=2) for index in range(len(palette))], axis=-1)
    first = votes.argmax(axis=-1)
    center = closest[:, :, 4]
    use_center = votes_mask[:, :, 4] & (
        np.take_along_axis(votes, center[:, :, None], axis=-1)[:, :, 0] == votes.max(axis=-1))
    chosen = np.where(use_center, center, first)

    body = np.zeros((*yy.shape, 4), dtype=np.uint8)
    opaque = votes_mask.sum(axis=2) >= 5
    body[opaque, :3] = palette[chosen[opaque]]
    body[opaque, 3] = 255
    foreground = np.zeros_like(opaque)
    mx, my = local[:, :, 4].transpose(2, 0, 1)
    for hx, hy, hw, hh in pose["front_hands"]:
        foreground |= (mx >= hx) & (my >= hy) & (mx < hx + hw) & (my < hy + hh)
    soften_exterior(body, foreground)
    hands = np.where(foreground[:, :, None], body, 0).astype(np.uint8)
    return body, hands


def soften_exterior(body, foreground):
    opaque = body[:, :, 3] != 0
    height, width = opaque.shape
    air = {(0, 0)}
    pending = deque(air)
    while pending:
        y, x = pending.popleft()
        for dy, dx in SIDES:
            row, col = y + dy, x + dx
            if 0 <= row < height and 0 <= col < width and not opaque[row, col] and (row, col) not in air:
                air.add((row, col))
                pending.append((row, col))
    original = body.copy()
    boot_edge = np.where(opaque)[0].max() - 1
    dark = (body[:, :, :3].max(axis=2) <= 45) & opaque & ~foreground
    for y, x in zip(*np.where(dark)):
        if y >= boot_edge or not any((y + dy, x + dx) in air for dy, dx in SIDES):
            continue
        neighbors = original[max(0, y - 1):y + 2, max(0, x - 1):x + 2, :3].reshape(-1, 3)
        red, _, blue = (int(channel) for channel in neighbors[neighbors.max(axis=1).argmax()])
        tone = "303539"
        if red - blue > 19:
            tone = "3c3630"
        elif blue - red > 11:
            tone = "303a42"
        body[y, x, :3] = rgb(tone)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    assert len(rows) == 77
    assert {pose["outfit"] for pose in rows} == set(OUTFITS)
    body_ref = REPORTS / "hero_contour_2026-11-08/g_body_cells.png"
    hand_ref = REPORTS / "hero_grid_2026-11-08/f_hand_cells.png"
    width, height = SIZE
    sheet = np.zeros((height * len(OUTFITS) * len(FAMILIES), width * len(ACTIONS) * 2, 4), dtype=np.uint8)
    assets = {}
    for pose in rows:
        key = (pose["outfit"], pose["family"], pose["action"])
        if pose["asset"] not in assets:
            assets[pose["asset"]] = rgba(SOURCE / pose["asset"])
        if key == ("carrier", "long", "aim"):
            body, hands = rgba(body_ref), rgba(hand_ref)
        else:
            body, hands = bake_pose(assets[pose["asset"]], pose)
        y = height * (OUTFITS.index(key[0]) * len(FAMILIES) + FAMILIES.index(key[1]))
        x = width * ACTIONS.index(key[2])
        assert body.shape == hands.shape == (height, width, 4), key
        opaque = body[:, :, 3] > 0
        fingers = hands[:, :, 3] > 0
        assert 500 < opaque.sum() < 1600 and fingers.any(), key
        assert np.array_equal(hands[fingers], body[fingers]), key
        assert not (opaque[:, 0].any() or opaque[:, -1].any() or opaque[0].any() or opaque[-1].any()), key
        sheet[y:y + height, x:x + width] = body
        x += width * len(ACTIONS)
        sheet[y:y + height, x:x + width] = hands
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "combat_outfits.png"
    Image.fromarray(sheet).save(target, optimize=True)
    provenance = {
        "approved_reference": str(body_ref.relative_to(REPO)),
        "reference_sha256": digest(body_ref),
        "reference_hand_sha256": digest(hand_ref),
        "source_sha256": {name: digest(SOURCE / name) for name in sorted(assets)},
        "grid_cell_extent": SIZE,
        "registered_poses": len(rows),
        "body_and_foreground_hand_layers": True,
        "output_sha256": digest(target),
    }
    (OUTPUT / "provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print(f"G OUTFIT GRID COMPLETE poses={len(rows)} atlas={sheet.shape[1]}x{sheet.shape[0]}")


if __name__ == "__main__":
    main()
