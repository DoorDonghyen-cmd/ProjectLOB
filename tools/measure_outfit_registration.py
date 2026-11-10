"""Read-only PNG analysis. Writes registration metadata, never rewrites pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = next(p.parent for p in ROOT.glob('*/project.godot'))
ART = PROJECT / 'assets/art/outfits_unified_20261025'
ACTIONS = ['idle', 'aim', 'recoil', 'reload_open', 'reload_seat', 'cooling']
EXPECTED = {
 'pistol': [[(344,226)],[(314,205)],[(294,162)],[(351,205),(392,174)],[(293,198),(322,233)],[(240,212)]],
 'long': [[(327,224),(405,267)],[(260,194),(350,160)],[(232,189),(300,160)],[(331,200),(420,269)],[(276,201),(304,227)],[(232,228),(294,256)]]}

def bounds(mask):
    y,x=np.where(mask)
    return [int(x.min()),int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)]

def components(mask):
    seen=mask.copy(); result=[]
    for y,x in zip(*np.where(mask)):
        if not seen[y,x]: continue
        stack=[(int(y),int(x))]; seen[y,x]=False; pts=[]
        while stack:
            cy,cx=stack.pop();pts.append((cy,cx))
            for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
                yy,xx=cy+dy,cx+dx
                if 0<=yy<mask.shape[0] and 0<=xx<mask.shape[1] and seen[yy,xx]:
                    seen[yy,xx]=False;stack.append((yy,xx))
        if len(pts)<25:continue
        ar=np.array(pts); lo=ar.min(axis=0);hi=ar.max(axis=0)
        result.append({'rect':[int(lo[1]),int(lo[0]),int(hi[1]-lo[1]+1),int(hi[0]-lo[0]+1)],'area':len(pts)})
    return result

def measure(path, family):
    src=np.array(Image.open(path).convert('RGBA')); records={}
    for i,action in enumerate(ACTIONS):
        x,y=i%3*512,i//3*512; a=src[y:y+512,x:x+512].astype(float)
        opaque=a[:,:,3]>200; box=bounds(opaque)
        bottom=box[1]+box[3];footmask=opaque.copy();footmask[:bottom-15]=False
        fb=bounds(footmask);foot=[fb[0]+fb[2]/2,bottom]
        skin=(a[:,:,0]>185)&(a[:,:,1]>120)&(a[:,:,1]<210)&(a[:,:,2]<175)&(a[:,:,0]>a[:,:,1]*1.15)&opaque
        cc=components(skin); hands=[]; chosen=[]
        for ex,ey in EXPECTED[family][i]:
            eligible=[c for c in cc if c not in chosen]
            c=min(eligible,key=lambda c:(c['rect'][0]+c['rect'][2]/2-ex)**2+(c['rect'][1]+c['rect'][3]/2-ey)**2)
            chosen.append(c); xx,yy,w,h=c['rect'];hands.append([xx-2,yy-2,w+4,h+4])
        centers=[[r[0]+r[2]/2,r[1]+r[3]/2] for r in hands]
        record={'source':[x,y,512,512],'bounds':box,'foot':foot,'grip':centers[0],'hands':hands,'scale':447.0/box[3]}
        if family=='long' and action in ['idle','aim','recoil','cooling']:record['support']=centers[1]
        record['angle']={'pistol':[20,0,-8,8,8,18],'long':[0,0,0,12,12,0]}[family][i]
        records[action]=record
    return records

out={}
for outfit in ['work','carrier','scout','heatworker','hoist','recovery','expedition']:
    out[outfit]={}
    for family in ['pistol','long']:
        name=f'{outfit}_{family}'
        path=ART/(name+'.png')
        if name in ['hoist_long','scout_long']:path=ART/(name+'_v2.png')
        if name=='work_pistol':path=PROJECT/'assets/art/hero_contours_20261025/work_pistol.png'
        out[outfit][family]={'texture':'res://'+path.relative_to(PROJECT).as_posix(),'poses':measure(path,family)}
(ART/'registration_measured.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps({o:{f:{a:{k:v for k,v in r.items() if k in ['foot','grip','support','scale']} for a,r in d['poses'].items()} for f,d in families.items()} for o,families in out.items()},indent=1))
