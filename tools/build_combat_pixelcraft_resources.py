"""Register unmodified generated sprites; pixel scaling belongs to Godot nodes."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '새-게임-프로젝트/assets/art/combat_pixelcraft_20261031'
REGIONS = {
    'tray': [28, 289, 447, 144], 'active': [498, 234, 250, 200],
    'fire': [787, 288, 398, 143], 'cool': [1213, 284, 296, 151],
    'reload': [35, 660, 368, 133], 'heat': [437, 695, 315, 72],
    'header': [779, 675, 333, 109], 'modal': [1140, 616, 372, 202],
}
for name, region in REGIONS.items():
    (OUT / f'{name}.tres').write_text(
        '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
        '[ext_resource type="Texture2D" path="res://assets/art/combat_pixelcraft_20261031/kit.png" id="atlas"]\n'
        '[resource]\natlas = ExtResource("atlas")\n'
        'region = Rect2(' + ','.join(map(str, region)) + ')\nfilter_clip = true\n', encoding='utf-8')
(OUT / 'regions.json').write_text(json.dumps(REGIONS, indent=2) + '\n', encoding='utf-8')
print('Registered eight atlas regions; original PNG untouched.')
