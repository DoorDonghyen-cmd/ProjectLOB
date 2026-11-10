"""Read font bitmaps and source colors; prepare native LibreSprite scripts.

This helper writes text/JSON only. LibreSprite writes every mockup pixel.
"""
import json
import re
import shutil
from pathlib import Path
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
QA=ROOT/'qa_runtime/pixel_study_20261101'
OUT=ROOT/'docs/art/combat-pixel-study-20261101'
CAPTURES=HERE/'captures'
CAPTURES.mkdir(exist_ok=True)
# Freeze the fresh game captures with this study; rebuilding then works without
# ignored QA files. Capture snapshots never become production game resources.
if (QA/'states.json').exists():
    shutil.copy2(QA/'states.json',HERE/'states.json')
    for path in QA.glob('*_source.png'):shutil.copy2(path,CAPTURES/path.name)
states=json.loads((HERE/'states.json').read_text(encoding='utf-8'))
QA.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)

def font_data(path):
    result={}
    for block in path.read_text(encoding='utf-8').split('STARTCHAR ')[1:]:
        code=int(re.search(r'^ENCODING (-?\d+)',block,re.M)[1])
        if code<0:continue
        advance=int(re.search(r'^DWIDTH (\d+)',block,re.M)[1])
        w,h,x,y=map(int,re.search(r'^BBX ([\d -]+)',block,re.M)[1].split())
        rows=block.split('BITMAP\n',1)[1].split('ENDCHAR',1)[0].strip().splitlines()
        result[code]={'advance':advance,'w':w,'h':h,'x':x,'y':y,'bits':((w+7)//8)*8,'rows':[int(r,16) for r in rows if r]}
    return result

fonts={'large':font_data(HERE/'fonts/Galmuri11.bdf'),'small':font_data(HERE/'fonts/Galmuri9.bdf')}
# Read exact colors from the current captured battlefield. Text and danger
# colors are deliberately derived for legibility rather than claimed samples.
image=Image.open(CAPTURES/'partial_source.png').convert('RGB')
samples={}
for y in range(90,465,2):
    for x in range(24,1255,2):samples.setdefault(image.getpixel((x,y)),(x,y))
targets={'page':'172428','panel':'20343a','panelRaised':'2c454b','socket':'15262c','shadow':'101d25','rim':'30484c','edge':'4d6b6c','secondary':'abb7a5','muted':'71817b','brass':'b58c51','brassMuted':'776d4e','amber':'d4a564','warmLight':'e7bd79','blue':'3b6572','blueLight':'7a9b96','rust':'954c3d','fire':'673e38'}
palette={};origins={}
for key,h in targets.items():
    target=tuple(int(h[i:i+2],16) for i in (0,2,4))
    rgb=min(samples,key=lambda c:sum((a-b)**2 for a,b in zip(c,target)))
    palette[key]=rgb;origins[key]={'rgb':rgb,'sample_xy':samples[rgb],'source':'partial_source.png'}
palette['text']=(222,222,195)
palette['warning']=(224,160,119)
origins['text']={'rgb':palette['text'],'source':'derived legibility color'}
origins['warning']={'rgb':palette['warning'],'source':'derived danger legibility color'}
(HERE/'palette.json').write_text(json.dumps(origins,ensure_ascii=False,indent=2),encoding='utf-8')
template=(HERE/'draw.js').read_text(encoding='utf-8')
for key,state in states.items():
    state['danger']=float(state['forecast'].get('forced_probability',0))>0
    title=' '.join(state['title'].split())
    strings=[title,'메뉴','발열','과열','탄창','선택','취소','빼내기','제외',' / ','0123456789',state['weapon'],state['bag'],state['parts']]
    for r in state['rounds']:strings.extend((r['name'],r['value'],r['role']))
    for b in state['buttons'].values():strings.extend((b['name'],b['cost']))
    codes=set(map(ord,''.join(strings)))
    subset={name:{code:glyphs[code] for code in sorted(codes)} for name,glyphs in fonts.items()}
    data={'key':key,'title':title,'state':state,'palette':palette,'fonts':subset,'output':(OUT/key).as_posix()}
    (QA/(key+'.js')).write_text('var DATA='+json.dumps(data,ensure_ascii=True)+';\n'+template,encoding='utf-8')
(HERE/'states.json').write_text(json.dumps(states,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'states':list(states),'palette_colors':len(set(palette.values())),'fonts':'BDF native glyph bits; no antialiasing'},ensure_ascii=False))
