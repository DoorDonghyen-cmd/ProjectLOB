"""Serialize the approved pipe map composition; runtime only binds campaign data."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / '새-게임-프로젝트'
OUT = ROOT / 'redesign/pipe_map'
OUT.mkdir(exist_ok=True)
def ext(kind,path,id): return f'[ext_resource type="{kind}" path="res://{path}" id="{id}"]\n'
def node(name,kind,parent=None,props='',instance=None):
    head=f'[node name="{name}"'+(f' type="{kind}"' if kind else '')+(f' parent="{parent}"' if parent is not None else '')+(f' instance=ExtResource("{instance}")' if instance else '')+']\n'
    return head+props+'\n'
def label(name,parent,text,size=16,extra=''):
    return node(name,'Label',parent,f'layout_mode = 2\nmouse_filter = 2\ntheme_override_font_sizes/font_size = {size}\ntext = "{text}"\n'+extra)
def icon(name,parent,role,size=36):
    return node(name,'TextureRect',parent,f'custom_minimum_size = Vector2({size},{size})\nlayout_mode = 2\nsize_flags_vertical = 4\nmouse_filter = 2\ntexture = ExtResource("{role}")\nexpand_mode = 1\nstretch_mode = 5\n')
def button(name,parent,text,primary=False):
    return node(name,'Button',parent,'custom_minimum_size = Vector2(60,44)\nlayout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_font_sizes/font_size = 16\n'+('theme_override_colors/font_color = Color(0.11,0.035,0.012,1)\n' if primary else '')+''.join(f'theme_override_styles/{s} = ExtResource("{"fire" if primary else "slate"}")\n' for s in ['normal','hover','pressed','focus'])+f'text = "{text}"\n')
roles=['combat','elite','boss','boss_small','shop','workshop','supply','event','bypass','home','control','valve']
new_art='assets/ui/pipe_map_art_20261101/'
assets=''
for r in roles:
    if r in ['home','control']:
        path=f'assets/ui/pipe_map_20261101/pm_{r}.png'
    else:
        name={'boss':'gate_detail_closed','boss_small':'gate_closed','valve':'valve_closed'}.get(r,r)
        path=new_art+name+'.png'
    assets+=ext('Texture2D',path,r)
assets+=ext('Texture2D',new_art+'elite_detail.png','elite_detail')
for i,region in enumerate(['residential','foundry','garden','noble','central']):
    assets+=ext('Texture2D',new_art+'region_'+region+('_current' if i==0 else '_closed')+'.png','region'+str(i))
common=ext('Theme','redesign/samples/hud/combat_hud_theme.tres','theme')+assets
styles=''.join(ext('StyleBox',f'assets/ui/line_theme_20261101/{r}.tres',r) for r in ['panel','slate','fire','reload'])
# Independent repeated node, with representative content visible in the editor.
s='[gd_scene format=3]\n'+ext('Script','redesign/pipe_map/place.gd','logic')+ext('Texture2D',new_art+'combat.png','combat')+'\n[sub_resource type="StyleBoxEmpty" id="clear"]\n'
s+=node('PipePlace','Button',None,'custom_minimum_size = Vector2(60,44)\noffset_right = 60.0\noffset_bottom = 44.0\ntexture_filter = 1\nscript = ExtResource("logic")\ntoggle_mode = true\n'+''.join(f'theme_override_styles/{v} = SubResource("clear")\n' for v in ['normal','hover','pressed','disabled','focus']))
s+=node('Picture','TextureRect','.', 'layout_mode = 0\nanchor_left = 0.5\nanchor_top = 0.5\nanchor_right = 0.5\nanchor_bottom = 0.5\noffset_left = -18.0\noffset_top = -18.0\noffset_right = 18.0\noffset_bottom = 18.0\nmouse_filter = 2\ntexture = ExtResource("combat")\nexpand_mode = 1\nstretch_mode = 5\n')
s+=node('Risk','Label','.', 'visible = false\nlayout_mode = 0\nanchor_left = 1.0\nanchor_right = 1.0\noffset_left = -12.0\noffset_top = -4.0\noffset_bottom = 12.0\nmouse_filter = 2\ntheme_override_colors/font_color = Color(1,0.435,0.38,1)\ntheme_override_font_sizes/font_size = 12\ntext = "+"\n')
s+=node('Status','Label','.', 'visible = false\nmouse_filter = 2\n')
(OUT/'place.tscn').write_text(s,encoding='utf-8')
# Main screen: authored hierarchy, containers and representative selection.
s='[gd_scene format=3]\n'+common+styles+ext('Script','redesign/pipe_map/screen.gd','logic')+ext('Script','redesign/pipe_map/graph.gd','graph')+ext('Script','redesign/pipe_map/rail.gd','rail')+ext('Script','redesign/pipe_map/gate.gd','gate')+ext('StyleBox',new_art+'board.tres','board')+ext('PackedScene','redesign/pipe_map/place.tscn','place')
s+=node('PipeMapScreen','VBoxContainer',None,'offset_right = 1280.0\noffset_bottom = 800.0\nsize_flags_horizontal = 3\nsize_flags_vertical = 3\ntexture_filter = 1\ntheme = ExtResource("theme")\nscript = ExtResource("logic")\ntheme_override_constants/separation = 8\n')
s+=node('Header','HBoxContainer','.', 'custom_minimum_size = Vector2(0,48)\nlayout_mode = 2\ntheme_override_constants/separation = 8\n')
s+=node('Location','VBoxContainer','Header','layout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_constants/separation = 0\n')
s+=label('RunLocation','Header/Location','주거 통로',16,'theme_override_colors/font_color = Color(0.36,0.867,0.863,1)\n')+label('RunStatusBar','Header/Location','75 Cr · 탄약 10/30 · 난도 0',12)
for n,t in [('city_deck','빌드'),('city_archive','기록'),('settings','설정'),('menu','메뉴')]:s+=button(n,'Header',t).replace('size_flags_horizontal = 3','size_flags_horizontal = 0')
s+=label('Notice','.','',12,'visible = false\n')
s+=node('MapWorkspace','HBoxContainer','.', 'layout_mode = 2\nsize_flags_vertical = 3\ntheme_override_constants/separation = 8\n')
s+=node('RegionRail','VBoxContainer','MapWorkspace','custom_minimum_size = Vector2(128,0)\nlayout_mode = 2\nsize_flags_vertical = 3\nscript = ExtResource("rail")\nmouse_filter = 2\ntheme_override_constants/separation = 0\n')
stops=[('ControlRoom','중앙 제어실','차단 명령','control'),('Zone4','중앙 통제구','닫힘','region4'),('Zone3','귀족 거주구','닫힘','region3'),('Zone2','우수 정원','닫힘','region2'),('Zone1','축열 주조장','닫힘','region1'),('Zone0','주거 통로','지금 여기','region0'),('Home','우리 동네','공급 차단','home')]
for i,(n,t,state,r) in enumerate(stops):
    p='MapWorkspace/RegionRail'
    s+=node(n,'HBoxContainer',p,'layout_mode = 2\nmouse_filter = 2\ntheme_override_constants/separation = 8\n')+icon('Icon',p+'/'+n,r,28)
    s+=node('Copy','VBoxContainer',p+'/'+n,'layout_mode = 2\nmouse_filter = 2\ntheme_override_constants/separation = 0\n')
    s+=label('Name',p+'/'+n+'/Copy',t,12)+label('State',p+'/'+n+'/Copy',state,12,'theme_override_colors/font_color = Color(0.337,0.467,0.478,1)\n')
    if i<6:s+=node('Space'+str(i),'Control',p,'layout_mode = 2\nsize_flags_vertical = 3\nmouse_filter = 2\n')
s+=node('MapBoard','PanelContainer','MapWorkspace','layout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_styles/panel = ExtResource("board")\n')
s+=node('Board','VBoxContainer','MapWorkspace/MapBoard','layout_mode = 2\ntheme_override_constants/separation = 2\n')
p='MapWorkspace/MapBoard/Board'
s+=node('Gate','Button',p,'custom_minimum_size = Vector2(0,48)\nlayout_mode = 2\nscript = ExtResource("gate")\ntheme_override_styles/normal = ExtResource("reload")\n')
s+=node('Face','HBoxContainer',p+'/Gate','layout_mode = 0\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\nalignment = 1\n')+icon('Icon',p+'/Gate/Face','boss_small',32)+label('GateTitle',p+'/Gate/Face','구역 관문',16,'vertical_alignment = 1\n')
s+=node('MapScroll','ScrollContainer',p,'layout_mode = 2\nsize_flags_vertical = 3\nhorizontal_scroll_mode = 0\nfollow_focus = true\n')
s+=node('CityMap','Control',p+'/MapScroll','custom_minimum_size = Vector2(260,458)\nlayout_mode = 2\nsize_flags_horizontal = 3\nscript = ExtResource("graph")\n')
for i in range(4):s+=node('Example'+str(i),None,p+'/MapScroll/CityMap',f'offset_left = {70+i*130}.0\noffset_top = 360.0\noffset_right = {130+i*130}.0\noffset_bottom = 404.0\n',instance='place')
s+=node('SideColumn','VBoxContainer','MapWorkspace','custom_minimum_size = Vector2(216,0)\nlayout_mode = 2\n')
s+=node('Spacer','Control','MapWorkspace/SideColumn','layout_mode = 2\nsize_flags_vertical = 3\nmouse_filter = 2\n')
s+=node('MapRouteSheet','PanelContainer','MapWorkspace/SideColumn','layout_mode = 2\ntheme_override_styles/panel = ExtResource("panel")\n')
p='MapWorkspace/SideColumn/MapRouteSheet'
s+=node('Copy','VBoxContainer',p,'layout_mode = 2\ntheme_override_constants/separation = 8\n')
p+='/Copy'
s+=label('SelectionMode',p,'선택한 장소',12)
s+=node('SelectedPlace','HBoxContainer',p,'layout_mode = 2\n')+icon('SelectionIcon',p+'/SelectedPlace','combat',36)
s+=node('Text','VBoxContainer',p+'/SelectedPlace','layout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_constants/separation = 0\n')
s+=label('MapSelectionPrompt',p+'/SelectedPlace/Text','순찰 구역',16,'autowrap_mode = 3\n')+label('SelectionKind',p+'/SelectedPlace/Text','전투',12,'theme_override_colors/font_color = Color(0.953,0.812,0.451,1)\n')
s+=label('MapRouteDetail',p,'연결된 길로만 갈 수 있음',12,'visible = false\nautowrap_mode = 3\n')
s+=node('Actions','HBoxContainer',p,'layout_mode = 2\ntheme_override_constants/separation = 6\n')+button('MapKey',p+'/Actions','기호')+button('city_map_details',p+'/Actions','자세히')+button('Enter',p,'이동',True)
(OUT/'screen.tscn').write_text(s,encoding='utf-8')
# Legend content uses the shared, focus-trapped game workspace overlay.
s='[gd_scene format=3]\n'+common
s+=node('MapKeyContent','VBoxContainer',None,'offset_right = 760.0\noffset_bottom = 420.0\nsize_flags_horizontal = 3\ntheme = ExtResource("theme")\ntheme_override_constants/separation = 14\n')
s+=node('Kinds','GridContainer','.','layout_mode = 2\ncolumns = 4\ntheme_override_constants/h_separation = 24\ntheme_override_constants/v_separation = 8\n')
for r,t in [('combat','전투'),('elite','정예'),('shop','상점'),('workshop','공방'),('supply','탄약고'),('event','조우'),('bypass','샛길'),('boss','관문')]:
    s+=node(r,'HBoxContainer','Kinds','layout_mode = 2\n')+icon('Icon','Kinds/'+r,'elite_detail' if r=='elite' else r)+label('Name','Kinds/'+r,t)
for i,t in enumerate(['금색 관 · 지나온 길','밝은 청록 관 · 지금 갈 수 있는 길','옅은 청록 관 · 고른 후보 뒤의 갈래','흐린 점선 · 이제 갈 수 없는 길','샛길 · 전투 한 곳 생략, 그 보상과 코어 성장 없음','+ · 시작 거리 감소 등 추가 위험']):s+=label('Line'+str(i),'.',t,16,'autowrap_mode = 3\n')
(OUT/'key.tscn').write_text(s,encoding='utf-8')
print('Serialized pipe map screen, place and key scenes.')
