"""Collect appearance-only invariants and same-size visual comparison artifacts."""
from pathlib import Path
import re,json,hashlib,sys,importlib.util
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'새-게임-프로젝트'
QA=ROOT/'qa_runtime/line_theme_20261101';BEFORE=QA/'source_before'
OUT=ROOT/'docs/qa/reports/ui_line_godot_2026-11-01_assets';OUT.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def nodes(path):
 s=path.read_text(encoding='utf-8');result={}
 for block in re.split(r'(?=\[node )',s):
  match=re.match(r'\[node name="([^"]+)"(.*?)\]',block)
  if not match:continue
  parent=re.search(r'parent="([^"]+)"',match[2]);key=(parent[1] if parent else '')+'/'+match[1]
  result[key]=(match[2],dict(re.findall(r'^([\w/]+) = (.*?)$',block,re.M)))
 return result
protected={}
for relative in ['project.godot','redesign/model.gd','redesign/campaign.gd','redesign/magazine_journey.gd','redesign/forecast.gd','redesign/samples/combat_magazine_journey.gd','redesign/samples/combat_weapon_magazine.gd','redesign/samples/hud/combat_journey_hud.gd']:
 old=BEFORE/'새-게임-프로젝트'/relative;current=P/relative
 protected[relative]={'before':sha(old),'after':sha(current),'unchanged':sha(old)==sha(current)}
geometry=[];mismatches=[];signals=[]
for old in (BEFORE/'새-게임-프로젝트/redesign').rglob('*.tscn'):
 current=ROOT/old.relative_to(BEFORE)
 a=nodes(old);b=nodes(current)
 for key,(kind,props) in a.items():
  if key not in b:mismatches.append(str(current)+': removed '+key);continue
  # Sprite geometry changes from downscaled steel art to native 2px tiled borders.
  if 'NinePatchRect' in kind:continue
  # Button child label inset is deliberately released from obsolete clamp padding.
  label=key.rsplit('/',1)[-1]
  if label in ['FireName','FireCost','CoolName','CoolCost','ReloadName','ReloadCost']:continue
  oldgeo={k:v for k,v in props.items() if k.startswith(('anchor_','offset_','grow_','size_flags_','custom_minimum_size','mouse_filter','focus_mode','layout_mode','scroll_'))}
  newgeo={k:v for k,v in b[key][1].items() if k in oldgeo}
  if oldgeo!=newgeo:mismatches.append(str(current.relative_to(P))+': '+key)
  geometry.append(str(current.relative_to(P))+': '+key)
for name in ['screen.gd','campaign_ui.gd','shop_screen.gd','service_location.gd','map_facility.gd']:
 old=BEFORE/'새-게임-프로젝트/redesign'/name;current=P/'redesign'/name
 extract=lambda p:[line.strip() for line in p.read_text(encoding='utf-8').splitlines() if '.connect(' in line]
 signals.append({'file':name,'connections_unchanged':extract(old)==extract(current)})
frames={}
for asset in (P/'assets/ui/line_theme_20261101').glob('px_*.png'):
 original=ROOT/'docs/qa/reports/ui_prototype_2026-10-31/assets'/asset.name
 if original.exists():
  a=Image.open(original).convert('RGBA');b=Image.open(asset).convert('RGBA')
  frames[asset.name]={'sha256':sha(asset),'exact_nearest_2x':a.resize((a.width*2,a.height*2),Image.Resampling.NEAREST).tobytes()==b.tobytes()}
provenance={'source':'tools/build_line_theme_assets.py and approved local HTML px_*.png','scale':2,'frames':frames,'additional_rules':'tools/build_line_rules.py; 2px dashes, 2px gaps'}
(P/'assets/ui/line_theme_20261101/provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
audit={'protected':protected,'geometry_controls_checked':len(geometry),'geometry_mismatches':mismatches,'signal_bindings':signals,'exact_2x_frames':all(v['exact_nearest_2x'] for v in frames.values())}
(QA/'invariants.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
assert all(v['unchanged'] for v in protected.values()),'Protected rules/save/entry file changed'
assert not mismatches,mismatches
assert all(v['connections_unchanged'] for v in signals)
assert audit['exact_2x_frames']
spec=importlib.util.spec_from_file_location('parity','D:/ProjectLoB/.agents/skills/godot-ui-integration/scripts/reference_parity_audit.py');parity=importlib.util.module_from_spec(spec);spec.loader.exec_module(parity)
captures=QA/'line_theme_20261101/capture'
comparisons={}
def compare(label,ref,live):
 a=Image.open(ref).convert('RGB');b=Image.open(live).convert('RGB');assert a.size==b.size
 w,h=a.size;sheet=Image.new('RGB',(w*2+16,h+30),'#03141a');sheet.paste(a,(0,30));sheet.paste(b,(w+16,30))
 draw=ImageDraw.Draw(sheet);draw.text((10,8),'HTML REFERENCE',fill='#e4f2ee');draw.text((w+26,8),'GODOT RUNTIME',fill='#e4f2ee')
 sheet.save(OUT/(label+'_side_by_side.png'))
 comparisons[label]=parity.create_audit(ref,live,OUT/(label+'_audit.png'),w,.5,False)
for size in ['740x360','844x390','1008x454','1280x800']:compare('elite_'+size,QA/'html'/('elite_'+size+'.jpg'),captures/('elite_'+size+'.png'))
compare('shop_1280x800',QA/'html/shop_1280x800.jpg',ROOT/'qa_runtime/shop_live/line_theme_20261101/shop/shop_1280x800.png')
compare('map_1280x800',QA/'html/map_1280x800.jpg',ROOT/'qa_runtime/maps/line_theme_20261101/map/map_1280x800.png')
# Pixel inspection, with no smoothing or modification of the captured screen.
im=Image.open(captures/'elite_1280x800.png');crop=im.crop((0,638,1280,800));crop.resize((3840,486),Image.Resampling.NEAREST).save(OUT/'hud_zoom_3x.png')
for name in ['selected_1280x800','menu_1280x800','detail_1280x800','supply_1280x800','workshop_1280x800']:
 Image.open(captures/(name+'.png')).save(OUT/(name+'.png'))
(QA/'comparisons.json').write_text(json.dumps(comparisons,indent=2),encoding='utf-8')
print(json.dumps({'protected_files':len(protected),'controls':len(geometry),'geometry_mismatches':mismatches,'signal_bindings_unchanged':True,'exact_2x_frames':len(frames),'comparisons':len(comparisons)}))
