"""Build disposable, headless experiments from the current combat implementation.

No production source, save, resource, or global content dictionary is modified.
Every patch is an exact single anchor; drift fails before the experiment runs.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = next(ROOT.glob('*/project.godot')).parent
tag = sys.argv[1] if len(sys.argv) > 1 else 'current'
assert re.fullmatch(r'[A-Za-z0-9_-]+', tag)
OUT = ROOT / 'qa_runtime/heat_comparison' / tag
files = {}
class_paths = {}
for path in (SOURCE / 'scripts').rglob('*.gd'):
    match = re.search(r'^class_name\s+(\w+)', path.read_text(encoding='utf-8'), re.M)
    if match:
        class_paths[match[1]] = path.relative_to(SOURCE).as_posix()


def collect(relative):
    if relative in files:
        return
    data = (SOURCE / relative).read_text(encoding='utf-8')
    files[relative] = data
    for reference in re.findall(r'res://([^"\s]+\.gd)', data):
        collect(reference)
    for name in set(re.findall(r'\b[A-Z]\w*\b', data)) & class_paths.keys():
        collect(class_paths[name])


for entry in ['redesign/model.gd', 'redesign/forecast.gd', 'redesign/campaign_content.gd']:
    collect(entry)


def replace_once(data, old, new):
    assert data.count(old) == 1, f'Patch anchor drift: {old[:100]!r}'
    return data.replace(old, new, 1)


for variant in ['original', 'experiment']:
    target = OUT / variant
    for relative, source in files.items():
        data = source
        if variant == 'experiment' and relative == 'redesign/content.gd':
            data = replace_once(data, '\treturn maxi(1, limit)', '\tif state.get("qa_mode", "") == "limit_minus2": limit -= 2\n\treturn maxi(1, limit)')
        if variant == 'experiment' and relative == 'redesign/model.gd':
            data = replace_once(data, 'const VERSION := 15', 'const Experiment = preload("res://experiment.gd")\nconst VERSION := 15')
            data = replace_once(data, '\theat_added += Content.part_heat_bonus(id,s)', '\theat_added += Content.part_heat_bonus(id,s)\n\theat_added = maxi(0, heat_added + Experiment.extra_heat(s, id))')
            data = replace_once(data, '\tvar results: Array = []', '\tvar results: Array = []\n\tvar qa_fault := false')
            data = replace_once(data, '\t\tvar id: String = s.magazine.pop_front()', '''		if Experiment.fault(s, str(s.magazine.front())):
			var failed_id: String = s.magazine.pop_front()
			_discard_fired_round(failed_id)
			s.qa_failures = int(s.get("qa_failures", 0)) + 1
			qa_fault = true
			break
		var id: String = s.magazine.pop_front()''')
            data = replace_once(data, '\tdetail.overdrive = overdrive_used', '''	if qa_fault and s.phase == "ready" and detail.forced_reload.is_empty():
		s.qa_preserve_magazine = true
		reload_magazine()
		s.erase("qa_preserve_magazine")
		detail.fault_reload = last_reload_detail.duplicate(true)
	detail.qa_fault = qa_fault
	detail.overdrive = overdrive_used''')
            data = replace_once(data, '\tfor id in s.magazine.duplicate():\n\t\t_discard_fired_round(str(id))', '''	var qa_preserved: Array = s.magazine.duplicate() if s.get("qa_preserve_magazine", false) else []
	if not s.get("qa_preserve_magazine", false):
		for id in s.magazine.duplicate():
			_discard_fired_round(str(id))
	s.qa_chain = 0''')
            data = replace_once(data, '\tlast_reload_detail = {"cost": cost,', '''	if not qa_preserved.is_empty() and s.phase == "plan":
		s.magazine = qa_preserved
		s.phase = "ready"
	last_reload_detail = {"cost": cost,''')
        if variant == 'experiment' and relative == 'redesign/forecast.gd':
            data = replace_once(data, '\tcache_lock.lock()\n\tif key == cached_key:', '\tkey += JSON.stringify([state.get("qa_mode", ""), state.get("qa_chain", 0)])\n\tcache_lock.lock()\n\tif key == cached_key:')
            data = replace_once(data, '\tkey.append(state.get("prepared", []).duplicate())', '\tkey.append_array([state.get("qa_mode", ""), state.get("qa_chain", 0)])\n\tkey.append(state.get("prepared", []).duplicate())')
        path = target / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data, encoding='utf-8')
    for name in ['runner.gd', 'experiment.gd']:
        (target / name).write_bytes((Path(__file__).parent / name).read_bytes())
    (target / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="LoB Heat Comparison QA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    # Preserve real legacy type dependencies required by the current map adapter.
    # Copy only entries whose source files are included; no editor/UI import needed.
    cache = (SOURCE / '.godot/global_script_class_cache.cfg').read_text(encoding='utf-8')
    entries = [entry for entry in re.findall(r'\{[^}]+\}', cache) if any(f'"res://{path}"' in entry for path in files)]
    (target / '.godot').mkdir(exist_ok=True)
    (target / '.godot/global_script_class_cache.cfg').write_text('list=['+', '.join(entries)+']\n', encoding='utf-8')

manifest = {'source_project': str(SOURCE), 'source_sha256': {name: hashlib.sha256((SOURCE/name).read_bytes()).hexdigest() for name in sorted(files)}, 'experiment_only': True}
(OUT / 'source_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Prepared {len(files)} current dependency scripts in two isolated projects: {OUT}')
