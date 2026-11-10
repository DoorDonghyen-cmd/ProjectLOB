"""Register approved PNGs and measured contacts. Does not alter image pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
PROJECT=next(p.parent for p in ROOT.glob('*/project.godot'))
ART=PROJECT/'assets/art/outfits_unified_20261025'
DATA=json.loads((ART/'registration_measured.json').read_text(encoding='utf-8'))
# Approved, visually reviewed idle contacts, local to each 887px cell.
IDLE={
 'work':{'long':[[204,48,410,788],[459,384],[564,464],[[435,361,49,43],[542,440,44,47]]]},
 'carrier':{'pistol':[[346,81,386,745],[605,394],None,[[582,374,45,39]]],'long':[[162,81,424,745],[412,407],[545,485],[[391,386,40,42],[523,461,43,46]]]},
 'scout':{'pistol':[[322,66,374,737],[589,377],None,[[565,356,47,43]]],'long':[[244,66,392,737],[490,398],[593,463],[[471,376,37,42],[572,442,42,41]]]},
 'heatworker':{'pistol':[[299,48,388,789],[553,383],None,[[529,360,48,46]]],'long':[[205,48,411,789],[461,383],[566,463],[[436,360,49,46],[543,438,45,49]]]},
 'hoist':{'pistol':[[278,47,407,786],[557,379],None,[[531,355,52,47]]],'long':[[192,47,426,786],[460,384],[566,465],[[435,360,50,47],[543,440,46,50]]]},
 'recovery':{'pistol':[[285,49,400,786],[557,377],None,[[531,353,52,47]]],'long':[[202,48,418,787],[468,381],[570,465],[[445,356,46,49],[547,439,46,52]]]},
 'expedition':{'pistol':[[290,46,395,790],[564,384],None,[[539,361,50,46]]],'long':[[207,47,419,789],[482,384],[580,469],[[457,361,50,46],[556,443,47,51]]]}}

for outfit,families in DATA.items():
    for family,item in families.items():
        if outfit=='work' and family=='pistol':continue
        b,g,s,h=IDLE[outfit][family]
        r={'source':[0 if family=='pistol' else 887,0,887,887],'bounds':b,'grip':g,'foot':[b[0]+b[2]/2,b[1]+b[3]],'hands':h,'scale':447/b[3],'angle':20 if family=='pistol' else 0}
        # Use feet, rather than the arm/backpack silhouette, to keep floor contact stable.
        a=np.array(Image.open(ART/(outfit+'_idle.png')))
        x=r['source'][0];m=a[b[1]+b[3]-15:b[1]+b[3]+2,x:x+887,3]>200
        yy,xx=np.where(m);r['foot'][0]=float((xx.min()+xx.max()+1)/2)
        if s:r['support']=s
        item['poses']['idle']=r

def gd(value,key=''):
    if isinstance(value,dict):return '{'+','.join(json.dumps(k)+':'+gd(v,k) for k,v in value.items())+'}'
    if isinstance(value,list):
        if key in ['source','bounds']:return 'Rect2('+','.join(map(str,value))+')'
        if key in ['foot','grip','support']:return 'Vector2('+','.join(map(str,value))+')'
        if key=='hands':return '['+','.join('Rect2('+','.join(map(str,r))+')' for r in value)+']'
    if isinstance(value,float):return str(round(value,7))
    return json.dumps(value)

lines=['extends RefCounted','## Approved idle sheets and measured six-pose art; gameplay stays in Content.','const BODIES := {']
for o,fs in DATA.items():lines.append('\t'+json.dumps(o)+':{'+','.join(json.dumps(f)+':preload('+json.dumps(d['texture'])+')' for f,d in fs.items())+'},')
lines+=['}','const IDLES := {']
for o in DATA:lines.append('\t'+json.dumps(o)+':preload("res://assets/art/outfits_unified_20261025/'+o+'_idle.png"),')
lines+=['}','const FRAMES := {']
for o,fs in DATA.items():
    lines.append('\t'+json.dumps(o)+':{')
    for f,d in fs.items():
        lines.append('\t\t'+json.dumps(f)+':{')
        for action,r in d['poses'].items():lines.append('\t\t\t'+json.dumps(action)+':'+gd(r)+',')
        lines.append('\t\t},')
    lines.append('\t},')
lines+=['}','']
(PROJECT/'redesign/outfit_art.gd').write_text('\n'.join(lines),encoding='utf-8')
(ART/'registration_final.json').write_text(json.dumps(DATA,indent=2),encoding='utf-8')

# All outfits now have real indoor poses, including carrier/scout (no work fallback).
catalog=['extends RefCounted','## Shared rooms, selected costume; unknown legacy IDs use the work fallback.','const POSES := {']
services={}
for outfit in DATA:
    a=np.array(Image.open(ART/(outfit+'_service.png')));services[outfit]={}
    catalog.append('\t"'+outfit+'":{')
    for i,place in enumerate(['shop','supply','workshop']):
        # The carrier's extended shop hand crosses the nominal 512px column.
        # Crop in the actual transparent gaps, keeping the entire hand and excluding it from supply.
        splits=[0,560,1050,1536] if outfit=='carrier' else [0,512,1024,1536]
        left,right=splits[i:i+2]
        cell=a[:,left:right];yy,xx=np.where(cell[:,:,3]>200)
        b=[int(xx.min()+left)-2,int(yy.min())-2,int(xx.max()-xx.min()+5),int(yy.max()-yy.min()+5)]
        # Foot center is registered to the existing room's floor anchor.
        mask=(cell[:,:,3]>200);mask[:int(yy.max())-12]=False;fy,fx=np.where(mask)
        foot=(float(fx.min()+fx.max()+1)/2+left-b[0])/b[2]
        name=f'service_actor_{place}_{outfit}_unified.tres'
        text='[gd_resource type="Resource" load_steps=3 format=3]\n[ext_resource type="Script" path="res://redesign/service_actor_profile.gd" id="1"]\n[ext_resource type="Texture2D" path="res://assets/art/outfits_unified_20261025/'+outfit+'_service.png" id="2"]\n[resource]\nscript = ExtResource("1")\ntexture = ExtResource("2")\nsource_rect = Rect2('+', '.join(map(str,b))+')\nfoot_in_source = Vector2('+str(round(foot,6))+', 0.997)\n'
        (PROJECT/'redesign'/name).write_text(text,encoding='utf-8')
        # Indoor poses have a later room-cohesion revision. Combat regeneration must not revert it.
        cohesive_name = f'service_actor_{place}_{outfit}_cohesive.tres'
        if (PROJECT/'redesign'/cohesive_name).exists():
            name = cohesive_name
        catalog.append('\t\t"'+place+'":preload("res://redesign/'+name+'"),')
        services[outfit][place]={'source':b,'foot_x':foot}
    catalog.append('\t},')
catalog+=['}','', 'static func resolve(outfit: String, place: String) -> Dictionary:', '\tvar selected: Dictionary = POSES.get(outfit, {})', '\tvar available := selected.has(place)', '\treturn {"profile": selected[place] if available else POSES.work.get(place), "requested": outfit, "displayed": outfit if available else "work", "fallback": not available}','']
(PROJECT/'redesign/service_actor_catalog.gd').write_text('\n'.join(catalog),encoding='utf-8')
(ART/'service_registration.json').write_text(json.dumps(services,indent=2),encoding='utf-8')
print('Registered 14 combat families, 7 approved idle sheets, 21 indoor poses.')
