"""Rebuild the pixel study using the native LibreSprite renderer only."""
import json
import subprocess
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
QA=ROOT/'qa_runtime/pixel_study_20261101'
OUT=ROOT/'docs/art/combat-pixel-study-20261101'
subprocess.run([sys.executable,'-X','utf8',str(HERE/'prepare.py')],check=True)
states=json.loads((HERE/'states.json').read_text(encoding='utf-8'))
metrics={}
def editor(*args):
    p=subprocess.run([sys.executable,str(ROOT/'tools/pixel_editor.py'),'-b',*map(str,args)],capture_output=True)
    output=p.stdout.decode('utf-8',errors='replace')+p.stderr.decode('utf-8',errors='replace')
    if p.returncode:raise RuntimeError(output)
    return output

for key in states:
    output=editor(HERE/'captures'/f'{key}_source.png','--scale','0.5','--script',QA/f'{key}.js')
    (QA/f'{key}_render.log').write_text(output,encoding='utf-8')
    prefix=f'PIXEL STUDY {key} '
    line=next((s for s in output.splitlines() if s.startswith(prefix)),None)
    if line is None:raise RuntimeError(output)
    metrics[key]=json.loads(line[len(prefix):])
    editor(OUT/f'{key}_native.png','--scale','2','--save-as',OUT/f'{key}.png')
    print(f'{key}: {len(metrics[key]["cards"])} sockets, {len(metrics[key]["overflows"])} text overflows')
(HERE/'layout-metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')
