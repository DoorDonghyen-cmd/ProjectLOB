"""Shared PixelOE processing for the outfit study and the production bake."""

import cv2
import numpy as np
from PIL import Image
from pixeloe.legacy.pixelize import pixelize

from art_pixel_pilot import pad_transparent_rgb


def pixel_oe(rgba, grid=72, colors=48):
    cv2.setNumThreads(1)
    cv2.setRNGSeed(0)
    padded = cv2.cvtColor(pad_transparent_rgb(rgba), cv2.COLOR_RGB2BGR)
    result = pixelize(padded, mode="contrast", target_size=[grid, grid], patch_size=4,
                      thickness=0, colors=colors, contrast=1.0, saturation=1.0,
                      no_upscale=True)
    small = Image.fromarray(cv2.cvtColor(result, cv2.COLOR_BGR2RGB))
    return np.asarray(small.resize((rgba.shape[1], rgba.shape[0]), Image.Resampling.NEAREST))


def keep_material_edges(original, grouped):
    """Keep a block's color from replacing a contrasting adjacent material."""
    delta = np.abs(original.astype(np.int16) - grouped)
    matches_material = delta.max(axis=2) <= 36
    return np.where(matches_material[:, :, None], grouped, original)


def carrier_aim_reference(rgba, protect_edges=False):
    """Reproduce the E study or its edge-protected production variant."""
    rgb = rgba[:, :, :3]
    coarse = pixel_oe(rgba, grid=40, colors=32).copy()
    if protect_edges:
        coarse = keep_material_edges(rgb, coarse)
    y, x = np.ogrid[:512, :512]
    helmet = y < 128
    shoulder_pack = (x < 250) & (y >= 111) & (y < 257)
    pants = (y >= 250) & (y < 432)
    face_lamp = (x >= 281) & (y >= 49) & (y < 147)
    trigger_hand = (x >= 247) & (x < 286) & (y >= 171) & (y < 215)
    support_hand = (x >= 334) & (y >= 140) & (y < 181)
    protected = face_lamp | trigger_hand | support_hand

    # Keep one readable thigh-pocket flap and fold the other light flecks
    # into the fabric. The main block grid is shared with the PixelOE pass.
    row = ((y + 0.5) * 40 / 512).astype(int)
    col = ((x + 0.5) * 40 / 512).astype(int)
    leg_patch = (col >= 11) & (col <= 16) & (row >= 20) & (row <= 27)
    patch_glints = leg_patch & (coarse[:, :, 1] >= 132)
    if protect_edges:
        patch_glints &= rgb[:, :, 1] >= 115
    flap = (col >= 13) & (col <= 15) & (row == 23)
    coarse[patch_glints & ~flap] = [126, 108, 95]
    coarse[patch_glints & flap] = [160, 142, 125]

    selected = (helmet | shoulder_pack | pants) & ~protected
    result = np.where(selected[:, :, None], coarse, rgb)
    assert np.array_equal(result[protected], rgb[protected])
    return result
