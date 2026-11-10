"""Migrate existing world UI surface references without changing authored geometry."""
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'새-게임-프로젝트'
OUT=ROOT/'qa_runtime/line_theme_20261101/source_before'
def save(p,s):
 t=OUT/p.relative_to(ROOT)
 if not t.exists():t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,t)
 p.write_text(s,encoding='utf-8')
def migration(s):
 for folder in ['console','shop_preview']:
  s=re.sub(r'res://assets/ui/'+folder+r'/([\w]+)\.tres',lambda m:'res://assets/ui/line_theme_20261101/'+folder+'_'+m[1]+'.tres' if (P/'assets/ui/line_theme_20261101'/(folder+'_'+m[1]+'.tres')).exists() else m[0],s)
 return s
colors={'101920':'03141a','1b2a34':'04181e','e7e4d9':'e4f2ee','a4b4ba':'8fb0b0','e4bd72':'5cdddc','f2a38d':'ff6f61','17242c':'04181e','38515d':'1d4f56','142129':'04181e','63dce8':'5cdddc','ffd86b':'f3cf73','e4d2a5':'f3cf73','edc47a':'f3cf73','a4b6b7':'8fb0b0','d6bb84':'f3cf73','e9e2cc':'e4f2ee','adc7af':'5cdddc','e6a580':'ff9a6a','a5b4ac':'8fb0b0'}
for p in (P/'redesign').glob('*.tscn'):
 s=p.read_text(encoding='utf-8');new=migration(s)
 # Only scene surfaces already using the shared console kit, and the service heading.
 if new!=s or p.name in ['service_location.tscn','map_facility.tscn']:
  new=re.sub(r'(theme_override_font_sizes/(?:normal_)?font_size = )(\d+)',lambda m:m[1]+str(12 if int(m[2])<14 else 16 if int(m[2])<22 else 24 if int(m[2])<28 else 32),new)
  if p.name=='service_location.tscn':
   new=new.replace('[node name="ServiceLocation"','[ext_resource type="Theme" path="res://redesign/samples/hud/combat_hud_theme.tres" id="line_theme"]\n\n[node name="ServiceLocation"',1)
   new=new.replace('script = ExtResource("1")','script = ExtResource("1")\ntheme = ExtResource("line_theme")\ntexture_filter = 1',1)
   new=new.replace('Color(0.84, 0.73, 0.52, 1)','Color(0.36078,0.86667,0.86275,1)').replace('Color(0.71, 0.76, 0.76, 1)','Color(0.56078,0.6902,0.6902,1)')
  save(p,new)
for file in ['screen.gd','campaign_ui.gd','shop_screen.gd','service_location.gd','combat_pixel_skin.gd','console_widgets.gd','city_map_chart_view.gd','map_facility.gd']:
 p=P/'redesign'/file;s=p.read_text(encoding='utf-8');s=migration(s)
 for old,new in colors.items():s=s.replace('Color("'+old+'")','Color("'+new+'")')
 if file=='combat_pixel_skin.gd':
  s=s.replace('res://assets/ui/console/%s.tres','res://assets/ui/line_theme_20261101/console_%s.tres')
  s=s.replace('Color("d4ddd5")','Color("e4f2ee")').replace('Color("8dabae")','Color("8fb0b0")').replace('Color("b8d4bf")','Color("5cdddc")')
 if file=='shop_screen.gd':s=s.replace('res://assets/ui/shop_preview/offer_%s.tres','res://assets/ui/line_theme_20261101/shop_preview_offer_%s.tres')
 if file=='screen.gd':
  s=s.replace('preload("res://redesign/ui_font.tres")','preload("res://redesign/combat_pixel_font.tres")')
  s=s.replace('ui_theme.default_font_size = _scaled(20)','ui_theme.default_font_size = _font_scaled(20)')
  s=re.sub(r'(add_theme_font_size_override\([^\n]*?)_scaled\(',r'\1_font_scaled(',s)
  s=s.replace('func _console_style','func _font_scaled(value: int) -> int:\n\treturn preload("res://redesign/line_skin.gd").font_step(_scaled(value))\n\nfunc _console_style',1)
  s=s.replace('style.content_margin_top = 14 if state == "pressed" else 12','style.content_margin_top = 12').replace('style.content_margin_bottom = 10 if state == "pressed" else 12','style.content_margin_bottom = 12')
  # Primary glyphs are dark against the reference orange face.
  start=s.index('func _primary_button');end=s.index('\nfunc ',start+6)
  s=s[:start]+s[start:end].replace('Color("03141a")','Color("1c0903")')+s[end:]
 if file=='campaign_ui.gd':
  s=re.sub(r'(add_theme_font_size_override\([^\n]*?)ui\._scaled\(',r'\1ui._font_scaled(',s)
  s=s.replace('var shell_style: StyleBoxFlat = ui._style(Color("04181e"))','var shell_style: StyleBoxTexture = ui._console_style("panel")')
  s=s.replace('\tshell_style.border_color = Color("1d4f56")\n\tshell_style.set_border_width_all(1)\n','')
  s=s.replace('route_sheet.add_theme_stylebox_override("panel", ui._style(Color("04181e")))','route_sheet.add_theme_stylebox_override("panel", ui._console_style("panel"))')
 if file=='service_location.gd':
  s=s.replace('roundi(28 * text_scale)','preload("res://redesign/line_skin.gd").font_step(roundi(28 * text_scale))').replace('roundi(19 * text_scale)','preload("res://redesign/line_skin.gd").font_step(roundi(19 * text_scale))')
 if file=='city_map_chart_view.gd':
  s=re.sub(r'"paper": "[0-9a-f]+", "edge": "[0-9a-f]+"','"paper": "04181e", "edge": "2c7a80"',s)
  s=s.replace('draw_rect(chart, Color(palette.paper))','draw_style_box(preload("res://redesign/line_skin.gd").box("panel"), chart)')
  s=s.replace('Color("d2b479")','Color("f3cf73")').replace('Color("8e987f")','Color("5cdddc")').replace('Color("718887")','Color("8fb0b0")')
 save(p,s)
# Disable font smoothing on the font shared with the HTML reference.
p=P/'assets/fonts/NeoDunggeunmoPro-Regular.ttf.import';s=p.read_text(encoding='utf-8');s=s.replace('antialiasing=1','antialiasing=0').replace('subpixel_positioning=4','subpixel_positioning=0');save(p,s)
print('World UI appearance resources migrated; command and persistence code retained')
