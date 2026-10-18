extends RefCounted
## Production hand face: ten equal positions; every field uses current card data.
const Content = preload("res://redesign/content.gd")
const Visual = preload("res://redesign/ammo_visual.gd")
const Art = preload("res://redesign/ammo_art.gd")
const Hardware = preload("res://redesign/instrument_skin.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")

static func label(c: Control, value: String, at: Vector2, width: float, pixels: int, color: Color) -> void:
	var font_size := pixels
	while font_size>13 and FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width: font_size-=1
	c.draw_string(FONT,at.round(),value,HORIZONTAL_ALIGNMENT_LEFT,maxf(0,width),font_size,color)

static func secondary(id: String, state: Dictionary) -> String:
	var spec: Dictionary=Content.AMMO[id]
	match str(spec.effect):
		"double": return "같은 적"
		"boost":
			if spec.get("boost_hot",false): return "열%d↑"%Content.hot_threshold(state)
			if Content.is_compressed(id): return "다음 탄창"
			return "다음%d발"%Content.boost_rounds(id)
		"burn": return "화상%d"%Content.burn_amount(id,state)
		"arc": return "전이%d"%Content.effect_value(id,state)
		"push": return "+%dm"%Content.effect_value(id,state)
		"thermal": return "열%d↑"%Content.hot_threshold(state)
		"vent": return "열×%d"%Content.effect_value(id,state)
		"detonate": return "기폭"
		"chase": return "처치+%d"%Content.effect_value(id,state)
		"bypass": return "후열"
		"sequence": return "종류+%d"%Content.effect_value(id,state)
	if Content.penetration(id,state)>0: return "관통%d"%Content.penetration(id,state)
	return ""

static func draw(c: Control) -> void:
	var id: String=c.ammo_id
	var state: Dictionary=c.state
	var w: float=c.size.x
	var h: float=c.size.y
	var held: bool=c.context_text=="장전한 탄"
	var button: BaseButton=c.interaction
	var focus: bool=button!=null and (button.has_focus() or button.is_hovered())
	var down: bool=button!=null and button.is_pressed() and not button.disabled
	var y:=2.0 if down else 0.0
	var alpha:=0.72 if c.is_disabled and not held else 1.0
	var ink:=Color("ded5bb",alpha)
	var muted:=Color("9ca7a3",alpha)
	var accent: Color=Visual.COLORS[id].lerp(Color("b5b7a3"),0.45)
	# Use the same stepped steel lip as the rail and thermal instrument.
	# Quiet inset surfaces keep the large value distinct from the casing.
	var face:=Color("354a47") if held or focus else Color("26393d")
	var edge:=Color("c5d3bd") if held or focus else Color("667b70")
	if c.is_disabled and not held:
		face=face.darkened(0.16)
		edge=edge.darkened(0.22)
	Hardware.plate(c,Rect2(0,y,w,h-2),face,edge)
	c.draw_rect(Rect2(7,7+y,w-14,27),Color("3a4b46") if held or focus else Color("2e4140"))
	c.draw_rect(Rect2(8,37+y,34,61),Color("17282e"))
	c.draw_rect(Rect2(8,37+y,3,61),Color("102026"))
	c.draw_rect(Rect2(11,96+y,31,2),Color("4b6059"))
	c.draw_rect(Rect2(7,h-28+y,w-14,18),Color("17282e"))
	if held or focus:
		c.draw_rect(Rect2(0,9+y,3,18),edge)
		c.draw_rect(Rect2(w-6,h-23+y,3,12),edge)
	Visual.grade_mark(c,Vector2(9,1+y),id,alpha)
	label(c,str(Content.AMMO[id].name),Vector2(9,24+y),w-(29 if held else 18),21,ink)
	c.draw_rect(Rect2(9,30+y,22,2),accent)
	Art.draw(c,id,Rect2(9,39+y,31,57),alpha)
	var stat: Dictionary=Content.primary_stat(id,state)
	label(c,str(stat.label),Vector2(48,53+y),w-55,16,muted)
	label(c,str(stat.value),Vector2(48,82+y),w-55,32,ink)
	var thermal:=Color("96bac4",alpha) if Content.heat_delta(id,state)<0 or str(Content.AMMO[id].effect)=="vent" else Color("d29b78",alpha)
	Visual.heat_icon(c,Vector2(14,h-18+y),0.65,thermal)
	var heat:=Content.heat_label(id,state)
	var heat_width:=maxf(28,FONT.get_string_size(heat,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)
	label(c,heat,Vector2(25,h-12+y),heat_width,18,thermal)
	var secondary_x:=maxf(58,29+heat_width)
	label(c,secondary(id,state),Vector2(secondary_x,h-12+y),w-secondary_x-5,16,accent)
	if held: label(c,"✓",Vector2(w-21,23+y),16,15,Color("c5d3bd"))
	# Compression footprint and positional constraints remain visible without long labels.
	if Content.is_compressed(id) or not Content.anchor(id).is_empty():
		for i in range(2):
			var fill:=Content.slot_cost(id)==2 or (i==0 and Content.anchor(id)=="first") or (i==1 and Content.anchor(id)=="last")
			c.draw_rect(Rect2(11+i*13,99+y,10,4),accent if fill else Color("415856"))
	var tune:=str(Content.AMMO[id].get("tune",""))
	if not tune.is_empty(): label(c,"↑" if tune=="power" else "↓",Vector2(37,104+y),14,14,Color("dab36e") if tune=="power" else Color("96bac4"))
	if c.compression_ready and not c.is_disabled:
		for x in [w-14,w-8]:
			c.draw_polyline(PackedVector2Array([Vector2(x-3,94+y),Vector2(x,91+y),Vector2(x+3,94+y),Vector2(x,97+y),Vector2(x-3,94+y)]),Color("92c9c6"),1)
