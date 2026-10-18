"""Isolated Godot 4.7 import smoke checks; does not enable plugins in LoB."""
from pathlib import Path
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'qa_runtime/reference_candidates'
ENGINE = Path('D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe')


def run(project, args, name):
    env = os.environ.copy()
    env['APPDATA'] = str(project / 'userdata/Roaming')
    env['LOCALAPPDATA'] = str(project / 'userdata/Local')
    for key in ('APPDATA', 'LOCALAPPDATA'): Path(env[key]).mkdir(parents=True, exist_ok=True)
    result = subprocess.run([str(ENGINE), '--headless', '--path', str(project), *args],
                            env=env, capture_output=True, timeout=90,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    log = result.stdout.decode('utf-8', errors='replace') + result.stderr.decode('utf-8', errors='replace')
    (project / (name+'.log')).write_text(log, encoding='utf-8')
    return result.returncode == 0 and not any(marker in log for marker in ('SCRIPT ERROR:', 'ERROR:', 'Parse Error')), log


def main():
    lock = json.loads((ROOT / 'reference_library/sources.lock.json').read_text(encoding='utf-8'))
    sources = {row['id']:row for row in lock['sources']}
    results = []
    for key, addon, enabled in [('pixel-ui', 'pixel_ui_fantasy', False),
                                ('importality', 'nklbdev.importality', True),
                                ('card-skeleton', 'CardGameSkeleton', True)]:
        project = OUT / key
        project.mkdir(parents=True, exist_ok=True)
        original = ROOT / sources[key]['directory'] / 'addons' / addon
        shutil.copytree(original, project / 'addons' / addon, dirs_exist_ok=True)
        config = 'config_version=5\n[application]\nconfig/name="LoB Reference Trial"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        if enabled: config += f'[editor_plugins]\nenabled=PackedStringArray("res://addons/{addon}/plugin.cfg")\n'
        (project / 'project.godot').write_text(config, encoding='utf-8')
        passed, log = run(project, ['--editor', '--import', '--quit'], 'import')
        if passed and key == 'pixel-ui':
            (project / 'check.gd').write_text('''extends SceneTree
func _initialize():
    var theme = load("res://addons/pixel_ui_fantasy/themes/parchment.tres") as Theme
    if theme == null: quit(1); return
    for widget in ["Button", "OptionButton", "HSlider", "VScrollBar", "TabContainer", "PopupMenu"]:
        if not theme.get_type_list().has(widget):
            push_error("Missing themed widget: " + widget); quit(1); return
    print("PIXEL UI THEME LOAD PASS")
    quit(0)
''', encoding='utf-8')
            passed, log = run(project, ['--script', 'res://check.gd'], 'theme')
        errors = [line for line in log.splitlines() if 'ERROR' in line or 'Parse Error' in line]
        entry = {'id':key, 'commit':sources[key]['commit'], 'passed':passed,
                 'scope':'Godot 4.7 headless editor load; no visual or production compatibility claim',
                 'logs':project.relative_to(ROOT).as_posix(), 'errors':errors[:12]}
        results.append(entry)
        print(key+': '+('LOAD PASS' if passed else 'NOT READY - see log'), flush=True)
    (OUT / 'result.json').write_text(json.dumps(results, indent=2), encoding='utf-8')


if __name__ == '__main__': main()
