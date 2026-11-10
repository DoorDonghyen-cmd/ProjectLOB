"""Measure transparent indoor atlases and author Godot profiles; never edit PNGs."""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = next(p.parent for p in ROOT.glob('*/project.godot'))
ART = PROJECT / 'assets/art/service_cohesion_20261025'
OUTFITS = ['work', 'carrier', 'scout', 'heatworker', 'hoist', 'recovery', 'expedition']

def pose_splits(rgba):
    """Find clear atlas gutters; an extended hand can cross a nominal third."""
    width = rgba.shape[1]
    occupied = (rgba[:, :, 3] > 200).any(axis=0)
    cuts = [0]
    for boundary in [width / 3, width * 2 / 3]:
        start, end = round(boundary - width / 12), round(boundary + width / 12)
        runs = []
        left = None
        for x in range(start, end + 1):
            clear = x < end and not occupied[x]
            if clear and left is None:
                left = x
            elif not clear and left is not None:
                runs.append((left, x))
                left = None
        assert runs, 'No transparent gap between poses'
        left, right = max(runs, key=lambda span: span[1] - span[0])
        assert right - left >= 18, 'Poses overlap or gutter is too narrow'
        cuts.append((left + right) // 2)
    return cuts + [width]

result = {}
for path in sorted(ART.glob('*.png')):
    if path.stem not in OUTFITS:
        continue
    rgba = np.asarray(Image.open(path).convert('RGBA'))
    height, width = rgba.shape[:2]
    splits = pose_splits(rgba)
    result[path.stem] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'size': [width, height], 'splits': splits, 'poses': {}}
    for index, place in enumerate(['shop', 'supply', 'workshop']):
        left, right = splits[index:index + 2]
        mask = rgba[:, left:right, 3] > 200
        yy, xx = np.where(mask)
        assert len(xx) and xx.min() > 8 and xx.max() < right - left - 8, (path, place, 'missing alpha gutter')
        bounds = [int(xx.min() + left) - 2, int(yy.min()) - 2, int(xx.max() - xx.min()) + 5, int(yy.max() - yy.min()) + 5]
        bottom = mask.copy()
        bottom[:int(yy.max()) - 12] = False
        fy, fx = np.where(bottom)
        foot_x = (float(fx.min() + fx.max() + 1) / 2 + left - bounds[0]) / bounds[2]
        foot_y = (float(yy.max() + 1) - bounds[1]) / bounds[3]
        text = f'''[gd_resource type="Resource" load_steps=3 format=3]
[ext_resource type="Script" path="res://redesign/service_actor_profile.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/service_cohesion_20261025/{path.name}" id="2"]
[resource]
script = ExtResource("1")
texture = ExtResource("2")
source_rect = Rect2({', '.join(map(str, bounds))})
foot_in_source = Vector2({foot_x:.6f}, {foot_y:.6f})
'''
        (PROJECT / f'redesign/service_actor_{place}_{path.stem}_cohesive.tres').write_text(text, encoding='utf-8')
        result[path.stem]['poses'][place] = {'source': bounds, 'foot': [foot_x, foot_y]}
(ART / 'registration.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
assert set(result) == set(OUTFITS), 'All seven outfits are required before switching the catalog'
catalog = PROJECT / 'redesign/service_actor_catalog.gd'
catalog.write_text(catalog.read_text(encoding='utf-8').replace('_unified.tres', '_cohesive.tres'), encoding='utf-8')
print(json.dumps({k: v['poses'] for k, v in result.items()}))
