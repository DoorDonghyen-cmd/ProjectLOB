"""Author the isolated Godot shop composition, not a runtime layout builder."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / '새-게임-프로젝트/redesign/samples/shop_wireframe_preview.tscn'
ART = ROOT / '새-게임-프로젝트/assets/ui/shop_preview'
ART.mkdir(parents=True, exist_ok=True)

def skin(name, rects):
    # Hand-authored vector pixel geometry. Deliberate seams, no random noise/filter.
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48" shape-rendering="crispEdges">\n'
    for x,y,w,h,color in rects:
        svg += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>\n'
    (ART / f'{name}.svg').write_text(svg + '</svg>\n', encoding='utf-8')
    resource = f'''[gd_resource type="StyleBoxTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/ui/shop_preview/{name}.svg" id="1"]
[resource]
texture = ExtResource("1")
texture_margin_left = 8.0
texture_margin_top = 8.0
texture_margin_right = 8.0
texture_margin_bottom = 8.0
'''
    (ART / f'{name}.tres').write_text(resource, encoding='utf-8')

for state in ['normal','selected','hover']:
    face = '#273638' if state == 'normal' else '#2d3d3e'
    rects = [(2,2,44,46,'#0c171b'),(0,5,48,38,'#0c171b'),(2,2,44,40,face),
             (4,0,40,2,'#59635c'),(2,4,2,36,'#354847'),(44,4,2,38,'#17272b'),
             (4,42,40,3,'#18292b'),(6,44,36,2,'#39443f'),(6,5,5,2,'#8b8973')]
    if state != 'normal':
        rects += [(0,2,2,8,'#adbeaa'),(2,0,8,2,'#adbeaa'),(46,34,2,8,'#adbeaa'),(38,42,8,2,'#adbeaa')]
    skin('offer_'+state, rects)
skin('stat', [(0,0,48,48,'#192629'),(0,0,48,2,'#101b20'),(0,46,48,2,'#4c5c57'),(0,5,2,38,'#3d4c47')])
skin('shelf', [(0,0,48,48,'#142025'),(0,0,48,2,'#4c5148'),(0,2,48,2,'#202b2a'),(0,46,48,2,'#101a1e')])
skin('invoice', [(0,0,48,48,'#18272b'),(0,0,48,2,'#847963'),(0,46,48,2,'#31423f')])
skin('bare', [(0,0,48,2,'#344540')])
for state in ['normal','hover','pressed','disabled','focus']:
    face = {'normal':'#293c3d','hover':'#354d4a','pressed':'#203332','disabled':'#18272c','focus':'#354d4a'}[state]
    edge = '#9aa997' if state in ['hover','focus'] else '#596c61'
    skin('key_'+state, [(2,0,44,44,'#0c181c'),(0,3,48,38,'#0c181c'),(2,2,44,38,face),(4,0,40,2,edge),(2,40,44,4,'#132328'),(4,44,40,2,'#0c181c')])
for state in ['normal','hover','pressed','disabled']:
    face = {'normal':'#bba479','hover':'#d2bb8e','pressed':'#9b8968','disabled':'#53605a'}[state]
    skin('buy_'+state, [(2,0,44,46,'#101a1c'),(0,4,48,38,'#101a1c'),(2,2,44,38,face),(4,2,40,2,'#d5c59b' if state!='disabled' else '#657067'),(2,40,44,3,'#71664e'),(4,43,40,3,'#182322')])
lines = ['[gd_scene format=3]', '']
def ext(kind, path, key):
    lines.append(f'[ext_resource type="{kind}" path="res://{path}" id="{key}"]')
def s(text): return json.dumps(text, ensure_ascii=False)
ext('Script', 'redesign/samples/shop_wireframe_preview.gd', 'logic')
ext('Script', 'redesign/samples/shop_preview_icon.gd', 'icon')
ext('Script', 'redesign/service_actor_layer.gd', 'actor')
ext('Resource', 'redesign/service_actor_shop_carrier_cohesive.tres', 'pose')
ext('Texture2D', 'assets/art/service_background_grouped_20261025/shop.png', 'room')
ext('Font', 'redesign/combat_pixel_font.tres', 'font')
for name in ['panel_normal','well_normal','card_normal','card_selected','cartridge_normal','cartridge_selected','cartridge_hover','button_normal','button_hover','button_pressed','button_disabled','button_focus','primary_normal','primary_hover','primary_pressed','primary_disabled']:
    ext('StyleBox', f'assets/ui/console/{name}.tres', name)
for asset in ART.glob('*.tres'):
    ext('StyleBox', f'assets/ui/shop_preview/{asset.name}', 'shop_'+asset.stem)
lines += ['', '[sub_resource type="Theme" id="Theme"]', 'default_font = ExtResource("font")', 'default_font_size = 24', 'Label/colors/font_color = Color(0.83, 0.86, 0.82, 1)', 'Button/colors/font_color = Color(0.83, 0.86, 0.82, 1)', 'Button/colors/font_hover_color = Color(0.93, 0.94, 0.85, 1)', 'Button/colors/font_pressed_color = Color(0.93, 0.94, 0.85, 1)', 'Button/colors/font_disabled_color = Color(0.43, 0.51, 0.51, 1)']
for state in ['normal','hover','pressed','disabled','focus']:
    lines.append(f'Button/styles/{state} = ExtResource("shop_key_{state}")')

def node(name, kind, parent=None, **props):
    lines.append('')
    lines.append(f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent is not None else '')+']')
    for k,v in props.items(): lines.append(f'{k} = {v}')
    return name if parent == '.' else f'{parent}/{name}' if parent else '.'
def full(name,kind,parent='.',**props):
    return node(name,kind,parent, layout_mode=1,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,grow_horizontal=2,grow_vertical=2,**props)
def box(name,kind,parent,gap=12,**props):
    return node(name,kind,parent,layout_mode=2,**{'theme_override_constants/separation':gap},**props)
def margin(name,parent,n=18,**props):
    return node(name,'MarginContainer',parent,layout_mode=2,**{f'theme_override_constants/margin_{x}':n for x in ['left','top','right','bottom']},**props)
def label(name,parent,text,size=24,color=None,**props):
    p={'layout_mode':2,'mouse_filter':2,'text':s(text),'theme_override_font_sizes/font_size':size}
    if color: p['theme_override_colors/font_color']=f'Color({color})'
    p.update(props)
    return node(name,'Label',parent,**p)
def btn(name,parent,text,primary=False,**props):
    p={'layout_mode':2,'text':s(text),'custom_minimum_size':'Vector2(0, 56)','mouse_default_cursor_shape':2}
    if primary:
        for st in ['normal','hover','pressed','disabled']: p[f'theme_override_styles/{st}']=f'ExtResource("shop_buy_{st}")'
        for st in ['font_color','font_hover_color','font_pressed_color']: p[f'theme_override_colors/{st}']='Color(0.13, 0.20, 0.20, 1)'
    p.update(props)
    return node(name,'Button',parent,**p)
def panel(name,parent,style='panel_normal',**props):
    return node(name,'PanelContainer',parent,layout_mode=2,**{'theme_override_styles/panel':f'ExtResource("{style}")'},**props)

INK='0.84, 0.81, 0.71, 1'; MUTED='0.57, 0.64, 0.60, 1'; GOLD='0.75, 0.65, 0.47, 1'; MINT='0.72, 0.80, 0.71, 1'; HEAT='0.80, 0.57, 0.43, 1'
node('ShopWireframePreview','Control',None,layout_mode=3,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,grow_horizontal=2,grow_vertical=2,texture_filter=1,theme='SubResource("Theme")',script='ExtResource("logic")')
full('Backdrop','ColorRect',color='Color(0.055, 0.09, 0.105, 1)',mouse_filter=2)
safe=full('Safe','MarginContainer',**{f'theme_override_constants/margin_{x}':24 for x in ['left','top','right','bottom']})
root=box('Layout','VBoxContainer',safe,18)
head=box('Header','HBoxContainer',root,20,custom_minimum_size='Vector2(0, 58)')
label('Brand',head,'ORVASK',28,GOLD)
label('Location',head,'승강장 · 주거 통로',24,MUTED,size_flags_horizontal=3)
label('PreviewBadge',head,'상점 시안',20,MUTED)
label('Wallet',head,'75 Cr',34,GOLD,custom_minimum_size='Vector2(150, 0)',horizontal_alignment=2)
btn('Reset',head,'초기화',custom_minimum_size='Vector2(110, 52)',**{'theme_override_font_sizes/font_size':22})
rows=box('Rows','VBoxContainer',root,12,size_flags_vertical=3)
top=box('Overview','HBoxContainer',rows,24,size_flags_vertical=3)
left=box('Market','VBoxContainer',top,12,size_flags_horizontal=3,size_flags_stretch_ratio=2.05)
right=box('Inspector','VBoxContainer',top,16,size_flags_horizontal=3,size_flags_stretch_ratio=1.0,custom_minimum_size='Vector2(452, 0)')

story=box('Story','HBoxContainer',left,20,custom_minimum_size='Vector2(0, 212)',size_flags_vertical=3)
room=node('Room','TextureRect',story,layout_mode=2,custom_minimum_size='Vector2(550, 190)',size_flags_horizontal=3,size_flags_vertical=4,texture='ExtResource("room")',expand_mode=1,stretch_mode=5,mouse_filter=2)
full('Hero','Control',room,mouse_filter=2,script='ExtResource("actor")',profile='ExtResource("pose")',room_foot='Vector2(0.409, 0.9)',room_height=0.643)
copy=box('Copy','VBoxContainer',story,8,size_flags_horizontal=3,custom_minimum_size='Vector2(330, 0)',alignment=1)
label('Title',copy,'승강장 거래소',30,INK)
label('Greeting',copy,'“안쪽 문은 열어 둬요.\n거기까지 난방이 가야 해서.”',23,INK,autowrap_mode=2)
label('Narration',copy,'주소표가 묶인 코일 세 개가\n수리대 위에 놓여 있다.',19,MUTED,autowrap_mode=2)
label('Voice',copy,'“올라갈 거면 쓸 만한 걸 가져가.”',21,GOLD,autowrap_mode=2)
bar=box('StockHeading','HBoxContainer',left,12,custom_minimum_size='Vector2(0, 44)')
label('Heading',bar,'오늘의 물건',26,INK,size_flags_horizontal=3)
btn('Reroll',bar,'새 진열 · 3 Cr',custom_minimum_size='Vector2(188, 44)',**{'theme_override_font_sizes/font_size':21})
# One shared row gives the cards and inspector identical top/bottom edges.
selection=box('SelectionRow','HBoxContainer',rows,24,custom_minimum_size='Vector2(0, 324)')
offers=box('Offers','HBoxContainer',selection,14,custom_minimum_size='Vector2(0, 324)',size_flags_horizontal=3,size_flags_stretch_ratio=2.05)
for i,(name,kind,grade,item,stat,desc,price) in enumerate([
    ('연타탄','탄환','일반','precise_p1','1 × 2','같은 적을 두 번 타격',12),
    ('확장 탄창','파츠','고급','supply','탄창 +1칸','한 번에 더 긴 연쇄',30),
    ('가속 총열','파츠','일반','lens','관통 +2','관통이 있는 탄에 적용',30)]):
    card=btn(f'Offer{i}',offers,'',custom_minimum_size='Vector2(0, 324)',size_flags_horizontal=3,**{'theme_override_styles/normal':'ExtResource("shop_offer_selected")' if i==0 else 'ExtResource("shop_offer_normal")','theme_override_styles/hover':'ExtResource("shop_offer_hover")','theme_override_styles/pressed':'ExtResource("shop_offer_selected")'})
    m=full('Inset','MarginContainer',card,mouse_filter=2,**{f'theme_override_constants/margin_{x}':18 for x in ['left','right','top','bottom']})
    v=box('Content','VBoxContainer',m,8,mouse_filter=2)
    tags=box('Tags','HBoxContainer',v,12,mouse_filter=2)
    label('Kind',tags,kind,19,MUTED,size_flags_horizontal=3)
    label('Grade',tags,grade,19,GOLD if grade=='고급' else MUTED)
    node('Icon','Control',v,layout_mode=2,mouse_filter=2,custom_minimum_size='Vector2(0, 104)',script='ExtResource("icon")',item_id=s(item),is_part=str(i>0).lower())
    label('Name',v,name,28,INK)
    plate=panel('StatPlate',v,'shop_stat',mouse_filter=2)
    pm=margin('Inset',plate,8,mouse_filter=2)
    sr=box('StatRow','HBoxContainer',pm,8,mouse_filter=2)
    label('Stat',sr,stat,30,INK,size_flags_horizontal=3,text_overrun_behavior=3)
    label('Heat',sr,'열 +4' if i==0 else '',18,HEAT)
    label('Description',v,desc,20,MUTED)
    foot=box('Foot','HBoxContainer',v,8,mouse_filter=2,size_flags_vertical=3,alignment=2)
    label('Price',foot,f'{price} Cr',26,GOLD,size_flags_horizontal=3)
    label('Owned',foot,'보유 2장' if i==0 else '',20,MUTED)

footer=box('Footer','HBoxContainer',rows,24)
footer_left=box('MarketFooter','VBoxContainer',footer,12,size_flags_horizontal=3,size_flags_stretch_ratio=2.05)
footer_right=box('InspectorFooter','VBoxContainer',footer,12,size_flags_horizontal=3,size_flags_stretch_ratio=1.0,custom_minimum_size='Vector2(452, 0)')
bag=panel('AmmoSummary',footer_left,'shop_bare',custom_minimum_size='Vector2(0, 78)')
bm=margin('Inset',bag,12)
br=box('Row','HBoxContainer',bm,18)
label('DeckCount',br,'보유 탄약 20 / 32',23,INK)
label('Composition',br,'기본 16  ·  철갑 2  ·  연타 2',21,MUTED,size_flags_horizontal=3)
btn('Bag',br,'탄환 가방',custom_minimum_size='Vector2(152, 52)',**{'theme_override_font_sizes/font_size':22})
foot=box('Service','HBoxContainer',footer_left,16,custom_minimum_size='Vector2(0, 58)')
label('ChargeInfo',foot,'압축 충전 1 / 2',22,MUTED,size_flags_horizontal=3)
btn('Charge',foot,'1회 충전 · 18 Cr',custom_minimum_size='Vector2(224, 56)',**{'theme_override_font_sizes/font_size':22})

loadout=panel('Loadout',right,'shop_bare',custom_minimum_size='Vector2(0, 176)')
lm=margin('Inset',loadout,16); lv=box('Content','VBoxContainer',lm,6)
lr=box('TitleRow','HBoxContainer',lv,10)
label('Heading',lr,'현재 장착',24,INK,size_flags_horizontal=3)
label('SlotCount',lr,'2 / 5',22,MUTED)
slots=box('Slots','HBoxContainer',lv,8,custom_minimum_size='Vector2(0, 56)')
for i,id in enumerate(['volley_drive','radiator','','','']):
    sl=btn(f'Slot{i}',slots,'+' if not id else '',size_flags_horizontal=3,custom_minimum_size='Vector2(0, 56)')
    full('Icon','Control',sl,mouse_filter=2,script='ExtResource("icon")',item_id=s(id if id else 'none'),is_part='true',small='true',visible=str(bool(id)).lower(),offset_bottom=-16.0 if i==0 else 0.0)
    node('CoreBadge','Label',sl,layout_mode=1,anchor_right=1.0,anchor_top=1.0,anchor_bottom=1.0,offset_top=-22.0,offset_bottom=-4.0,grow_horizontal=2,grow_vertical=0,mouse_filter=2,text=s('코어'),horizontal_alignment=1,visible=str(i==0).lower(),**{'theme_override_font_sizes/font_size':16,'theme_override_colors/font_color':f'Color({GOLD})'})
label('PartName',lv,'코어 · 연쇄 구동핵',21,GOLD)
label('Weapon',lv,'래칫   탄창 4   열 한계 17',21,MUTED)

detail=panel('Detail',selection,'shop_invoice',custom_minimum_size='Vector2(452, 324)',size_flags_horizontal=3,size_flags_stretch_ratio=1.0)
dm=margin('Inset',detail,14); dv=box('Content','VBoxContainer',dm,8)
label('Eyebrow',dv,'선택한 물건',19,MUTED,visible='false')
title_row=box('ItemHeading','HBoxContainer',dv,12)
label('ItemName',title_row,'연타탄',32,INK,size_flags_horizontal=3)
btn('Details',title_row,'상세',custom_minimum_size='Vector2(76, 48)',**{'theme_override_font_sizes/font_size':20})
label('DetailText',dv,'같은 적에게 두 번 타격합니다.',21,INK,autowrap_mode=2,visible='false')
label('ChangeTitle',dv,'구매 시 변화',21,MUTED,visible='false')
label('Change',dv,'코어 적용 · 타격당 피해 +1',24,INK,autowrap_mode=2)
label('AffinityTitle',dv,'내 장비와의 연결',21,GOLD,visible='false')
label('Affinity',dv,'',21,INK,autowrap_mode=2,visible='false')
label('Cost',dv,'',20,HEAT,autowrap_mode=2,visible='false')
node('Space','Control',dv,layout_mode=2,size_flags_vertical=3,mouse_filter=2)
label('Feedback',dv,'',19,MUTED,custom_minimum_size='Vector2(0, 22)',autowrap_mode=2)
btn('Buy',dv,'12 Cr · 한 장 추가',True,custom_minimum_size='Vector2(0, 56)',**{'theme_override_font_sizes/font_size':26})
btn('Replace',dv,'보유 탄과 교체',custom_minimum_size='Vector2(0, 44)',**{'theme_override_font_sizes/font_size':22})
label('Balance',dv,'구매 후 63 Cr',21,MUTED,horizontal_alignment=2)
node('ExitSpace','Control',footer_right,layout_mode=2,size_flags_vertical=3,mouse_filter=2)
btn('Exit',footer_right,'시안 닫기  →',custom_minimum_size='Vector2(0, 58)',**{'theme_override_font_sizes/font_size':24})

# Authored modal: runtime populates labels only. Tap works on mobile too.
overlay=full('Overlay','ColorRect',visible='false',color='Color(0.025, 0.045, 0.055, 0.92)',mouse_filter=0)
center=full('Center','CenterContainer',overlay)
modal=panel('Modal',center,'panel_normal',custom_minimum_size='Vector2(720, 500)')
mm=margin('Inset',modal,28); mv=box('Content','VBoxContainer',mm,16)
label('ModalTitle',mv,'탄환 가방',32,INK)
label('ModalHint',mv,'시안 전용 탄약 · 실제 저장에는 반영되지 않습니다.',22,MUTED)
for i in range(4): btn(f'AmmoRow{i}',mv,'',custom_minimum_size='Vector2(0, 62)')
node('RulesText','RichTextLabel',mv,layout_mode=2,custom_minimum_size='Vector2(0, 280)',size_flags_vertical=3,visible='false',autowrap_mode=2,text=s(''),**{'theme_override_font_sizes/normal_font_size':23,'theme_override_colors/default_color':f'Color({INK})'})
btn('NextPage',mv,'다음 탄약 보기',custom_minimum_size='Vector2(0, 50)',visible='false')
btn('CloseOverlay',mv,'돌아가기',custom_minimum_size='Vector2(0, 56)')
DEST.write_text('\n'.join(lines)+'\n', encoding='utf-8')
print(DEST)
