"""Read-only alpha analysis; register unchanged generated PNGs for Godot."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / '새-게임-프로젝트/assets/art/noble_enemies_20261025'
# Reuse the reviewed connected-component/monotone-outline measurement only.
# Executing its registration output section would overwrite the garden registry.
source = (ROOT / 'tools/measure_garden_leaders.py').read_text(encoding='utf-8')
measurement = source.split('\nspecies =', 1)[0]
measurement = measurement.replace('def measure(path, height):', 'def measure(path, height, count=3):')
measurement = measurement.replace('reverse=True)[:3]', 'reverse=True)[:count]')
namespace = {'__file__': str(ROOT / 'tools/measure_garden_leaders.py')}
exec(compile(measurement, 'shared_alpha_measurement', 'exec'), namespace)
measure = namespace['measure']
registry = {}
for species, filename, height in [
    ('shield_noble', 'shield_noble_v2.png', 110),
    ('double_door_servant', 'double_door_servant_v2.png', 108),
    ('chief_servant', 'chief_servant_v2.png', 128),
    ('cupronickel_marquis', 'cupronickel_marquis_v1.png', 142),
]:
    registry[species] = measure(ASSETS/filename, height)
workers = measure(ASSETS/'house_workers_v1.png', 100, 2)
for species, index, height in [('house_effigy',0,100), ('house_pressure',1,108)]:
    pose = workers['poses'][index]
    pose['scale'] = height / pose['source'][3]
    registry[species] = {'height':height, 'poses':[pose]}
(ASSETS/'registration.json').write_text(json.dumps({'species':registry},indent=2)+'\n',encoding='utf-8')
template = (ROOT/'새-게임-프로젝트/redesign/garden_art.gd').read_text(encoding='utf-8')
tail = template[template.index('\nstatic func data()'):]
paths = sorted({pose['file'] for data in registry.values() for pose in data['poses']})
gd = 'extends RefCounted\n## Measured alpha polygons; generated source pixels remain unchanged.\n'
gd += 'const REGISTRATION := '+json.dumps(registry,separators=(',',':'))+'\nconst TEXTURES := {\n'
gd += ''.join('\t'+json.dumps(path)+':preload('+json.dumps(path)+'),\n' for path in paths)
gd += '}\n'+tail
(ROOT/'새-게임-프로젝트/redesign/noble_art.gd').write_text(gd,encoding='utf-8')
hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ASSETS.glob('*.png')}
(ASSETS/'hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
for species, data in registry.items():
    print(species, [(p['source'],p['feet'],round(p['scale'],4)) for p in data['poses']])
