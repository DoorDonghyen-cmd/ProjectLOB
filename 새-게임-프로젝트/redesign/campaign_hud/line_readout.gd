extends RefCounted
## Shared actor scale and line readouts for the live campaign and HUD preview.
const LineSkin=preload("res://redesign/line_skin.gd")
# HTML reference: ~96px hero at 1280px width. Scene-script replacement resets
# exported multipliers, so the HUD uses one explicit scale independent of sky height.
const HERO_SCALE:=0.09
const House=preload("res://redesign/noble_house.gd")
const CARD_GAP:=6.0
var view: Control
var header_width:=294.0
var _placement_key:=PackedFloat64Array()
var _cards: Dictionary={}
var _intents: Dictionary={}
var _blockers: Dictionary={}
var _idle_heights: Dictionary={}
var row_layout:=false
func _init(surface: Control,intent_width: float=294.0)->void:
	view=surface
	header_width=intent_width

func draw_player(foot: Vector2)->void:
	if not is_instance_valid(view.weapon_viewport):return
	view.Pixel.shadow(view,foot+Vector2(0,1),21*view.actor_factor())
	var factor: float=view.character_scale()*view.WeaponActor.BODY_SCALE
	view.draw_texture_rect(view.weapon_viewport.get_texture(),Rect2((foot-view.WeaponActor.FOOT*factor).round(),(Vector2(view.weapon_viewport.size)*factor).round()),false)

func named(index: int)->bool:
	return str(view.enemies[index].get("rank","")) in ["elite","boss"]

func badge_numbers()->Dictionary:
	var order: Array=view._alive_indices()
	order.sort_custom(func(a,b):return view.enemy_feet(a).x<view.enemy_feet(b).x if not is_equal_approx(view.enemy_feet(a).x,view.enemy_feet(b).x) else a<b)
	var result: Dictionary={}
	for index in order:
		for other in order:
			if other!=index and absf(view.enemy_feet(index).x-view.enemy_feet(other).x)<46.0*view.actor_factor():
				result[index]=order.find(index)+1
				break
	return result

func hud_width(index: int)->float:
	return minf(144.0,(view.size.x-244.0)/4.0-8.0) if view.compact() else 180.0 if named(index) else 128.0

func layout(index: int)->Dictionary:
	var width:=hud_width(index)
	var hp_x:=28.0 if badge_numbers().has(index) else 7.0
	var x: float=hp_x+22.0+view.FONT.get_string_size(str(int(view.enemies[index].hp)),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+8.0
	var row:=0
	var cells: Array=[]
	for entry in view.EnemyStatusIcons.entries(view.enemies[index]):
		var cell_width: float=16.0+view.FONT.get_string_size(str(entry.value),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		if x+cell_width>width-7.0:row+=1;x=7.0
		cells.append({"entry":entry,"x":x,"y":5.0+18.0*row,"width":cell_width})
		x+=cell_width+6.0
	var bar_y:=25.0+18.0*row
	# Keep HP tags compact; next-action details remain in the enemy inspection.
	var focus:=8.0 if str(view.display_state.get("gun",""))=="burst" else 0.0
	var height:=maxf(44.0,bar_y+11.0+focus)
	if view.inspection_enabled:_idle_heights[index]=height
	else:height=maxf(height,float(_idle_heights.get(index,height)))
	return {"hp_x":hp_x,"cells":cells,"bar_y":bar_y,"focus":focus,"height":height}

func plaque(index: int)->Rect2:
	_place_cards()
	return _cards.get(index,Rect2())

func has_intent(index: int)->bool:
	var enemy: Dictionary=view.enemies[index]
	return named(index) or (House.shielded(enemy) and int(enemy.barrier)==0)

func intent_rect(index: int)->Rect2:
	_place_cards()
	return _intents.get(index,Rect2())

func _intent_above(rect: Rect2)->Rect2:
	var width:=minf(header_width,view.size.x-32.0)
	return Rect2(roundf(clampf(rect.get_center().x-width*0.5,16.0,view.size.x-width-16.0)),rect.position.y-18.0,width,18)

func _occupied(index: int,rect: Rect2)->Rect2:
	return rect.merge(_intent_above(rect)) if has_intent(index) else rect

func _place_cards()->void:
	var order: Array=view._alive_indices()
	var key:=PackedFloat64Array([view.size.x,view.size.y])
	var heights: Dictionary={}
	for index in order:
		heights[index]=float(layout(index).height)
		key.append_array(PackedFloat64Array([index,view.enemy_feet(index).x,view.enemy_head_y(index),hud_width(index),heights[index],int(has_intent(index)),int(named(index))]))
	if key==_placement_key:return
	_placement_key=key
	# Match the mockup: named actors own the nearest tier, then stable identity.
	# Do not sort by current distance: overtaking must not swap vertical priority.
	order.sort_custom(func(a,b):return named(a) if named(a)!=named(b) else a<b)
	var cards: Dictionary={}
	var occupied: Dictionary={}
	var blockers: Dictionary={}
	row_layout=view.size.y<230.0
	if not row_layout:
		for index in order:
			var width:=hud_width(index)
			var rect:=Rect2(Vector2(roundf(clampf(view.enemy_feet(index).x-width*0.5,4.0,view.size.x-width-4.0)),roundf(view.enemy_head_y(index)-heights[index]-10.0)),Vector2(width,heights[index]))
			var natural:=_occupied(index,rect)
			var held: Array=[]
			for attempt in range(order.size()+1):
				var moved:=false
				for other in occupied:
					var obstacle: Rect2=occupied[other]
					var area:=_occupied(index,rect)
					# A small release margin avoids tier flicker at a touching edge.
					var retained: bool=_blockers.get(index,[]).has(other) and natural.end.x+12>obstacle.position.x and natural.position.x-12<obstacle.end.x and natural.end.y>obstacle.position.y
					if not area.grow(CARD_GAP*0.5).intersects(obstacle.grow(CARD_GAP*0.5)) and not retained:continue
					if not held.has(other):held.append(other)
					var top:=minf(rect.position.y,obstacle.position.y-rect.size.y-CARD_GAP)
					if top<rect.position.y:rect.position.y=top;moved=true
				if not moved:break
			var area:=_occupied(index,rect)
			# Keep the encounter title clear as well as the top edge. A battlefield
			# that cannot hold every tier uses the mockup's low-height row fallback.
			if area.position.y<4 or area.intersects(Rect2(0,0,280,36)):
				row_layout=true
				break
			cards[index]=rect
			occupied[index]=area
			blockers[index]=held
	_intents.clear()
	if row_layout:
		cards.clear();blockers.clear()
		view._layout_plaques()
		var headers: Array=order.filter(func(i):return has_intent(i))
		var top:=4.0 if headers.is_empty() else 10.0+headers.size()*18.0
		for index in order:
			cards[index]=Rect2(Vector2(roundf(float(view._plaque_lefts.get(index,238))),top),Vector2(hud_width(index),heights[index]))
			if has_intent(index):_intents[index]=Rect2(220,2+headers.find(index)*18,maxf(100,view.size.x-232),16)
	else:
		for index in cards:
			if has_intent(index):_intents[index]=_intent_above(cards[index])
	_cards=cards
	_blockers=blockers
	# Rendering, pointer picking and keyboard focus use the same rectangles.
	for button in view.info_buttons:
		var index:=int(str(button.name).trim_prefix("enemy_info_"))
		button.visible=_cards.has(index)
		if _cards.has(index):
			button.position=_cards[index].position
			button.size=_cards[index].size

func connector(index: int)->PackedVector2Array:
	var rect:=plaque(index)
	if row_layout:return PackedVector2Array()
	var foot: Vector2=view.enemy_feet(index)
	var head: float=view.enemy_head_y(index)-3.0
	if head-rect.end.y<=12 and absf(rect.get_center().x-foot.x)<=10:return PackedVector2Array()
	if head<=rect.end.y:return PackedVector2Array()
	var x:=clampf(foot.x,rect.position.x+8,rect.end.x-8)
	return PackedVector2Array([Vector2(x,rect.end.y).round(),Vector2(foot.x,head).round()])

func draw_badges(canvas: CanvasItem)->void:
	# Connectors must be behind every card, including cards in a lower tier.
	for index in view._alive_indices():
		var points:=connector(index)
		if points.size()==2:canvas.draw_line(points[0],points[1],Color("2c7a80"),1,false)
	var badges:=badge_numbers()
	var edge: float=-100.0
	for index in badges:
		var foot: Vector2=view.enemy_feet(index)
		var left:=maxf(edge,foot.x-8.0)
		var point:=Vector2(left,foot.y+6.0).round()
		if absf(left+8-foot.x)>10:canvas.draw_line(foot+Vector2(0,2),point+Vector2(8,0),LineSkin.ACCENT,1,false)
		_draw_badge(canvas,point,int(badges[index]))
		edge=left+20.0

func _draw_badge(canvas: CanvasItem,point: Vector2,number: int)->void:
	canvas.draw_rect(Rect2(point,Vector2(16,16)),LineSkin.ACCENT)
	canvas.draw_string(view.FONT,point+Vector2(0,12),str(number),HORIZONTAL_ALIGNMENT_CENTER,16,12,Color("03141a"))

func _draw_enemy_plaque(index: int,canvas: CanvasItem=null)->void:
	if canvas==null:canvas=view
	var rect: Rect2=view.enemy_plaque(index)
	var p:=rect.position
	var info:=layout(index)
	var e: Dictionary=view.enemies[index]
	var threat: Dictionary=view.threat_readouts.get(index,{})
	var danger:=str(threat.get("tone","quiet")) in ["danger","lethal"]
	canvas.draw_style_box(LineSkin.surface("tag_reach" if danger else "tag_named" if named(index) else "tag"),rect)
	var badges:=badge_numbers()
	if badges.has(index):_draw_badge(canvas,p+Vector2(6,5),int(badges[index]))
	_draw_hud_text(p+Vector2(info.hp_x,18),"HP",HORIZONTAL_ALIGNMENT_LEFT,20,12,LineSkin.MUTED,canvas)
	_draw_hud_text(p+Vector2(info.hp_x+22,19),str(int(e.hp)),HORIZONTAL_ALIGNMENT_LEFT,48,16,LineSkin.INK,canvas)
	for cell in info.cells:
		view.EnemyStatusIcons.draw_icon(canvas,p+Vector2(cell.x,cell.y),str(cell.entry.icon),2,true)
		_draw_hud_text(p+Vector2(cell.x+16,cell.y+12),str(cell.entry.value),HORIZONTAL_ALIGNMENT_LEFT,cell.width-16,12,view.EnemyStatusIcons.COLORS[cell.entry.icon],canvas)
	_draw_line_hp(canvas,Rect2(p+Vector2(7,info.bar_y),Vector2(rect.size.x-14,4)),index)
	if info.focus>0:
		for pip in range(3):
			canvas.draw_rect(Rect2(p+Vector2(7+pip*6,info.bar_y+8),Vector2(4,4)),LineSkin.GOLD if pip<int(e.get("focus_hits",0)) or view.focus_flash==index else Color("123a40"))

func _draw_line_hp(canvas: CanvasItem,bar: Rect2,index: int)->void:
	var e: Dictionary=view.enemies[index]
	var filled:=bar.size.x*clampf(float(e.hp)/maxf(1,e.max_hp),0,1)
	var remaining:=bar.size.x*clampf(float(_line_remaining_hp(index))/maxf(1,e.max_hp),0,1)
	var previous:=bar.size.x*clampf(float(view.hit_hp_before.get(index,e.hp))/maxf(1,e.max_hp),0,1)
	for x in range(0,int(bar.size.x),6):
		var color:=LineSkin.ACCENT if x<remaining else LineSkin.GOLD if x<filled else Color(LineSkin.GOLD,1.0-view.pulse) if x<previous else Color("123a40")
		canvas.draw_rect(Rect2(bar.position+Vector2(x,0),Vector2(mini(4,int(bar.size.x)-x),4)),color)

func _line_remaining_hp(index: int)->int:
	var hp:=int(view.enemies[index].hp)
	var projected: Array=view.forecast.get("enemies",[])
	if not view.inspection_enabled or index>=projected.size():return hp
	# Random-target weapons show guaranteed damage only; never invent a roll.
	return clampi(int(projected[index].get("hp_max",projected[index].hp)),0,hp)

func _draw_hud_text(position: Vector2,text: String,alignment: int,width: float,font_size: int,color: Color,canvas: CanvasItem=null)->void:
	if canvas==null:canvas=view
	var step:=LineSkin.font_step(font_size)
	if text.begins_with("정예 ·") or text.begins_with("관문 ·"):color=LineSkin.ACCENT
	canvas.draw_string(view.FONT,position+Vector2(0,2),text,alignment,width,step,Color("01080a"))
	canvas.draw_string(view.FONT,position,text,alignment,width,step,color)
