"""Measure original PNGs without modifying pixels; emit export-safe Godot data."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / '새-게임-프로젝트'
ASSETS = PROJECT / 'assets/art/central_leaders_20261026'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

references = [PROJECT / 'assets/art' / item for item in [
    'central_guard_alt_20261025/guard_heavy_b.png',
    'central_guard_alt_20261025/guard_shield_b.png',
    'hero_contours_20261025/work_pistol.png',
    'central_ascent_20261024/upper_v1.png']]
reference_records = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)} for p in references]
data = {}
for item in json.loads((PROJECT / 'assets/art/central_guard_alt_20261025/registration.json').read_text(encoding='utf-8'))['items']:
    data[item['id']] = {key: item[key] for key in ['source', 'feet', 'height']}
    data[item['id']]['file'] = 'res://assets/art/central_guard_alt_20261025/' + item['file'].split('/')[-1]

records = []
for species, filename, height, generated in [
    ('guard_captain', 'captain_v1.png', 148, 'exec-24d42b99-c93c-46f7-bf6d-a661e73cec9c.png'),
    ('tower_ruler', 'ruler_v1.png', 148, 'exec-c2870767-8759-49f1-8821-cde69dd7057a.png')]:
    path = ASSETS / filename
    im = Image.open(path)
    assert im.mode == 'RGBA'
    alpha = im.getchannel('A')
    mask = alpha.point(lambda a: 255 if a >= 128 else 0)
    x0, y0, x1, y1 = mask.getbbox()
    strip = mask.crop((x0, y1 - max(1, round((y1-y0)*0.04)), x1, y1)).getbbox()
    feet = [x0 + (strip[0]+strip[2])/2, y1]
    assert x0 > 0 and y0 > 0 and x1 < im.width and y1 < im.height
    data[species] = {'file': 'res://' + path.relative_to(PROJECT).as_posix(), 'height': height, 'source': [x0, y0, x1-x0, y1-y0], 'feet': feet}
    records.append({'species': species, 'output': filename, 'sha256': sha(path), 'generated_source': generated,
                    'tool': 'built-in image_gen', 'transparent_background': True,
                    'prompt': (ASSETS / (filename.split('_')[0] + '_prompt.txt')).read_text(encoding='utf-8'),
                    'reference_order': reference_records, 'dimensions': list(im.size), 'mode': im.mode,
                    'source': data[species]['source'], 'feet': feet, 'height': height})
write(ASSETS / 'registration.json', data)
write(ASSETS / 'provenance.json', {'date': '2026-10-26', 'status': 'director_temporary_live_art_user_preference_pending', 'approved_family': 'B ordinary guards approved by user', 'items': records, 'processing': 'Original pixels preserved. Alpha threshold/foot measurement only; runtime cutout 0.5.'})
textures = sorted({v['file'] for v in data.values()})
script = 'extends RefCounted\n## Original source PNGs, alpha bounds and planted foot anchors.\nconst REGISTRATION := ' + json.dumps(data, ensure_ascii=False) + '\nconst TEXTURES := {\n'
script += '\n'.join('\t"%s":preload("%s"),' % (p, p) for p in textures) + '\n}\n'
script += '''
static func data() -> Dictionary:
	return REGISTRATION

static func pose(species: String) -> Dictionary:
	var entry:Dictionary=REGISTRATION[species]
	var source:=Rect2(entry.source[0],entry.source[1],entry.source[2],entry.source[3])
	return {"texture":TEXTURES[entry.file],"source":source,"anchor":Vector2(entry.feet[0],entry.feet[1]),"scale":float(entry.height)/source.size.y,"height":float(entry.height)}

static func radius(species: String) -> float:
	var entry:=pose(species)
	return ceilf(maxf(entry.anchor.x-entry.source.position.x,entry.source.end.x-entry.anchor.x)*entry.scale)
'''
(PROJECT / 'redesign/central_art.gd').write_text(script, encoding='utf-8')
print('Registered six central actors; all source PNGs preserved.')
