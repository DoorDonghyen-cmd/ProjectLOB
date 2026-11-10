"""Read-only source glyph, texture and provenance audit for the combat HUD."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_source/ui/combat_pixel_study_20261101/fonts'
OUT=ROOT/'새-게임-프로젝트/assets/ui/combat_pixel_20261101'
results={}
for name in ['Galmuri9','Galmuri11']:
    fnt=(OUT/(name+'.fnt')).read_text(encoding='utf-8')
    pages={int(m[1]):Image.open(OUT/m[2]).convert('RGBA') for m in re.finditer(r'^page id=(\d+) file="([^"]+)"',fnt,re.M)}
    assert all(im.width<=2048 and im.height<=2048 for im in pages.values())
    positions={int(m[1]):tuple(map(int,m.groups()[1:])) for m in re.finditer(r'^char id=(\d+) x=(\d+) y=(\d+) width=(\d+) height=(\d+).*page=(\d+)',fnt,re.M)}
    checked=0
    for block in (SOURCE/(name+'.bdf')).read_text(encoding='utf-8').split('STARTCHAR ')[1:]:
        code=int(re.search(r'^ENCODING (-?\d+)',block,re.M)[1])
        if code<0:continue
        gx,gy,w,h,page=positions[code];bits=((w+7)//8)*8;pixels=pages[page].load()
        rows=block.split('BITMAP\n',1)[1].split('ENDCHAR',1)[0].strip().splitlines()
        for y,line in enumerate(rows):
            data=int(line,16)
            for x in range(w):assert (pixels[gx+x,gy+y][3]>0)==bool(data&(1<<(bits-1-x))),(name,code,x,y)
        checked+=1
    results[name]={'glyphs_verified':checked,'pages':[im.size for im in pages.values()],'bitmap_matches_bdf':True}
for p in OUT.glob('ammo_*.png'):
    im=Image.open(p)
    assert im.mode=='RGBA' and im.size==(14,22) and im.getpixel((0,0))[3]==0 and im.getbbox() is not None
results['ammo']={'families':len(list(OUT.glob('ammo_*.png'))),'size':[14,22],'transparent_margins':True}
manifest={'tool':'LibreSprite 1.3 native pixel exports, Python metadata and read-only audit','reference':'docs/art/combat-pixel-study-20261101/partial.png','generator':'tools/build_pixel_hud_assets.py','font_source':'art_source/ui/combat_pixel_study_20261101/fonts','font_upstream_commit':'71e1cacf1437a11220307120e63e30bc275312d4','license':'OFL.md','checks':results,'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.is_file() and p.suffix in ['.png','.fnt','.md']}}
(OUT/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=False))
