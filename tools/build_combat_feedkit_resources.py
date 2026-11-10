"""Register unmodified workshop UI sprites. Native scene nodes own scale and layout."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '새-게임-프로젝트/assets/art/combat_feedkit_20261031'
regions = json.loads((OUT / 'regions.json').read_text(encoding='utf-8'))
for name, region in regions.items():
    (OUT / f'{name}.tres').write_text(
        '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
        '[ext_resource type="Texture2D" path="res://assets/art/combat_feedkit_20261031/kit.png" id="atlas"]\n'
        '[resource]\natlas = ExtResource("atlas")\n'
        'region = Rect2(' + ','.join(map(str, region)) + ')\nfilter_clip = true\n', encoding='utf-8')
print('Registered eight regions; source PNG untouched.')
