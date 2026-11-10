"""Read-only PNG measurement; exports Godot atlas clipping, never edits pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / '새-게임-프로젝트/assets/art/garden_leaders_20261024'

def measure(path, height):
    pixels = np.asarray(Image.open(path))
    mask = pixels[:, :, 3] > 128
    parents, spans, previous = [], [], []
    def find(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.pad(row.astype(int), (1, 1))))
        current = []
        for left, right in zip(edges[::2], edges[1::2]):
            ident = len(parents)
            parents.append(ident)
            for pl, pr, pi in previous:
                if pl <= right and pr >= left: parents[find(ident)] = find(pi)
            current.append((int(left), int(right), ident))
            spans.append((y, int(left), int(right), ident))
        previous = current
    groups = {}
    for y, left, right, ident in spans:
        groups.setdefault(find(ident), []).append((y, left, right))
    bodies = sorted(groups.values(), key=lambda g: sum(r-l for y,l,r in g), reverse=True)[:3]
    bodies.sort(key=lambda g: min(l for y,l,r in g))
    neutral_height = max(y for y,l,r in bodies[0])-min(y for y,l,r in bodies[0])+1
    scale = height/neutral_height
    poses = []
    for body in bodies:
        rows = {}
        for y, l, r in body:
            a,b = rows.get(y,(l,r)); rows[y] = min(a,l), max(b,r)
        top,bottom = min(rows),max(rows)+1
        left,right = min(l for l,r in rows.values()),max(r for l,r in rows.values())
        # A monotone polygon clips neighboring atlas poses whose bounds overlap.
        outline = [(max(0, rows[y][0]-2), y) for y in sorted(rows)]
        outline += [(min(mask.shape[1], rows[y][1]+2), y+1) for y in sorted(rows,reverse=True)]
        simplified = []
        for point in outline:
            while len(simplified)>1:
                a,b=simplified[-2:]
                if (b[0]-a[0])*(point[1]-b[1]) != (b[1]-a[1])*(point[0]-b[0]): break
                simplified.pop()
            simplified.append(point)
        poses.append({'file':'res://'+path.relative_to(ROOT/'새-게임-프로젝트').as_posix(),
            'source':[left,top,right-left,bottom-top],'feet':[(left+right)/2,bottom],
            'scale':scale,'uv':[n for point in simplified for n in point]})
    return {'height':height,'poses':poses}

species = {'longleg_foldrunner':measure(DIRECTORY/'longleg_states_v1.png',108),
           'waterway_mother':measure(DIRECTORY/'watermother_states_v1.png',136)}
(DIRECTORY/'registration.json').write_text(json.dumps({'species':species},indent=2)+'\n',encoding='utf-8')
for name,entry in species.items():
    print(name,[(p['source'],p['feet'],len(p['uv'])//2) for p in entry['poses']])

# Keep export-safe GDScript registration synchronized without modifying artwork.
registry = ROOT/"새-게임-프로젝트/redesign/garden_art.gd"
lines = registry.read_text(encoding="utf-8").splitlines()
lines = ["const REGISTRATION := "+json.dumps(species,separators=(",",":")) if line.startswith("const REGISTRATION :=") else line for line in lines]
registry.write_text("\n".join(lines)+"\n",encoding="utf-8")
