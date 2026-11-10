"""Read-only pixel/semantic inspection; LibreSprite handles native exports."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'docs/art/combat-pixel-study-20261101'
QA=ROOT/'qa_runtime/pixel_study_20261101'
QA.mkdir(parents=True,exist_ok=True)
states=json.loads((HERE/'states.json').read_text(encoding='utf-8'))
metrics=json.loads((HERE/'layout-metrics.json').read_text(encoding='utf-8'))
palette=json.loads((HERE/'palette.json').read_text(encoding='utf-8'))
colors={tuple(v['rgb']) for v in palette.values()}
def read(path):return np.asarray(Image.open(path).convert('RGB'))
def export(*args):
    p=subprocess.run([sys.executable,str(ROOT/'tools/pixel_editor.py'),'-b',*map(str,args)],capture_output=True)
    assert p.returncode==0,p.stderr
results={}
for key,state in states.items():
    native=read(OUT/f'{key}_native.png');display=read(OUT/f'{key}.png')
    assert native.shape==(400,640,3) and display.shape==(800,1280,3)
    for dy in range(2):
        for dx in range(2):assert np.array_equal(native,display[dy::2,dx::2])
    ui=np.concatenate((native[:44].reshape(-1,3),native[236:].reshape(-1,3)))
    used={tuple(int(c) for c in row) for row in np.unique(ui,axis=0)}
    assert used.issubset(colors),(key,used-colors)
    export(HERE/'captures'/f'{key}_source.png','--scale','0.5','--save-as',QA/f'{key}_baseline.png')
    baseline=read(QA/f'{key}_baseline.png')
    assert np.array_equal(native[44:236],baseline[44:236])
    export(OUT/f'{key}.ase','--save-as',QA/f'{key}_roundtrip.png')
    assert np.array_equal(native,read(QA/f'{key}_roundtrip.png'))
    m=metrics[key]
    assert not m['overflows']
    assert len(m['cards'])==state['capacity']
    assert sum(c['occupied'] for c in m['cards'])==len(state['rounds'])
    assert [c['index'] for c in m['cards'] if c['selected']]==state['selected']
    assert sum(c['active'] for c in m['cards'])==state['forecast']['fired_max']
    assert len(m['heat_cells'])==state['limit']
    assert sum(c['current'] for c in m['heat_cells'])==state['heat']
    assert sum(c['predicted'] for c in m['heat_cells'])==max(0,min(state['limit'],state['forecast']['peak_max'])-state['heat'])
    for label in m['labels']:
        assert label['x']>=0 and label['x']+label['width']<=640
        assert label['y']>=0 and label['y']+(12 if label['font']=='large' else 10)<=400
    results[key]={'size':[640,400],'display':[1280,800],'integer_2x':True,'palette_only_ui':True,'battlefield_retained':True,'ase_roundtrip':True,'text_overflows':0,'capacity':state['capacity'],'occupied':len(state['rounds']),'active':sum(c['active'] for c in m['cards']),'selected':state['selected'],'heat':[state['heat'],state['limit']]}
report={'scope':'Static pixel mockup checks; not interactive Godot UI or mobile play validation','palette_colors':len(colors),'states':results,'files':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted([*OUT.glob('*'),*HERE.glob('fonts/*'),*HERE.glob('captures/*')]) if p.is_file()}}
(HERE/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'states':len(results),'checks':'pixel grid / palette / source region / ASE roundtrip / labels / actual model values passed'},ensure_ascii=False))
