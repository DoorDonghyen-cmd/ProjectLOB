@tool
extends RefCounted
## Collection/reward cards share the compact hand's matte palette and quiet edges.
## Pixel atlas art is shared; numbers and effect descriptions remain live game data.
const Ammo = preload("res://redesign/content.gd")
const Visual = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const INK := Color("202f32")
const PAPER := Color("c6c5ac")
const LIGHT := Color("ebe4cc")
const STEEL := Color("273b40")
const MUTED := Color("a5b4ac")

static func text(c: Control, value: String, at: Vector2, width: float, pixels: int, color: Color, center: bool = false) -> void:
	# Clip/shrink only the individual live field, never resize the card or its parent.
	var font_size := pixels
	while font_size > 13 and FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
		font_size -= 1
	c.draw_string(FONT,at.round(),value,HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,maxf(0,width),font_size,color)

static func surface(c: Control, r: Rect2, selected: bool, disabled: bool) -> void:
	var edge := Color("b9d5be") if selected else Color("798c86")
	if disabled: edge = Color("536866")
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	c.draw_rect(Rect2(p+Vector2(4,3),Vector2(w-8,h-3)),Color("0b171c"))
	c.draw_rect(Rect2(p+Vector2(0,8),Vector2(w,h-17)),Color("0b171c"))
	c.draw_rect(Rect2(p+Vector2(4,2),Vector2(w-8,h-9)),edge)
	c.draw_rect(Rect2(p+Vector2(2,7),Vector2(w-4,h-18)),edge)
	c.draw_rect(Rect2(p+Vector2(7,7),Vector2(w-14,h-19)),STEEL)
	c.draw_rect(Rect2(p+Vector2(10,2),Vector2(w-30,3)),Color("d3d5bc") if selected else Color("a6b3a3"))
	c.draw_rect(Rect2(p+Vector2(2,10),Vector2(3,h-27)),edge.lightened(0.12))
	c.draw_rect(Rect2(p+Vector2(w-10,10),Vector2(4,h-23)),Color("425a58"))
	c.draw_rect(Rect2(p+Vector2(10,h-10),Vector2(w-24,4)),Color("425a58"))
	# A single clipped corner and two fasteners, rather than random surface noise.
	c.draw_rect(Rect2(p+Vector2(w-15,0),Vector2(12,4)),Color("0b171c"))
	for dot in [Vector2(8,h-13),Vector2(w-12,9)]:
		c.draw_rect(Rect2(p+dot,Vector2(4,4)),edge)
		c.draw_rect(Rect2(p+dot+Vector2(1,1),Vector2(2,1)),Color("182a2e"))

static func draw(c: Control) -> void:
	var id: String=c.ammo_id
	var s: Dictionary=c.state
	var w: float=c.size.x
	var h: float=c.size.y
	var button: BaseButton=c.interaction
	var disabled: bool=c.is_disabled or (button!=null and button.disabled)
	var selected: bool=c.selected_visual or (button!=null and not disabled and (button.is_hovered() or button.has_focus()))
	var y:=2.0 if button!=null and button.is_pressed() and not disabled else 0.0
	var ink:=Color("ded5bb") if not disabled else Color("8b9690")
	var muted:=Color("9ca7a3")
	var accent: Color=Visual.COLORS[id].lerp(Color("b5b7a3"),0.45)
	c.draw_rect(Rect2(0,4+y,w,h-4-y),Color("080e12"))
	c.draw_rect(Rect2(0,y,w,h-5),Color("253337") if selected else Color("1a272c"))
	c.draw_rect(Rect2(0,y,w,2),Color("c5d3bd") if selected else Color("526260"))
	if selected:
		for x in [0.0,w-2]: c.draw_rect(Rect2(x,y,2,h-5),Color("a6baa7"))
	Visual.grade_mark(c,Vector2(10,1+y),id)
	text(c,str(Ammo.AMMO[id].name),Vector2(12,25+y),w-25-(45 if c.count>1 else 0),23 if c.showcase_ui else 20,ink)
	if c.count>1: text(c,"×%d"%c.count,Vector2(w-48,25+y),38,18,muted,true)
	c.draw_rect(Rect2(12,32+y,24,2),accent)
	var small:=h<130
	var stat: Dictionary=Ammo.primary_stat(id,s)
	var art_height:=32 if small else (70 if c.showcase_ui else 57)
	var art_width:=28 if small else (39 if c.showcase_ui else 31)
	preload("res://redesign/ammo_art.gd").draw(c,id,Rect2(14,40+y,art_width,art_height),0.7 if disabled else 1.0)
	var left:=65.0 if c.showcase_ui else 57.0
	if small:
		text(c,str(stat.label)+" "+str(stat.value),Vector2(left,67+y),w-left-12,23,ink)
	else:
		text(c,str(stat.label),Vector2(left,54+y),w-left-12,15,muted)
		text(c,str(stat.value),Vector2(left,91+y),w-left-12,34 if c.showcase_ui else 30,ink)
	var pen:=Ammo.penetration(id,s)
	if pen>0 and h>=198: text(c,"관통 %d"%pen,Vector2(left,114+y),w-left-12,17,accent)
	var thermal:=Color("96bac4") if Ammo.heat_delta(id,s)<0 or str(Ammo.AMMO[id].effect)=="vent" else Color("d29b78")
	var footer_y:=h-32.0 if h>=164 else h-14.0
	Visual.heat_icon(c,Vector2(20,footer_y-5+y),0.7,thermal)
	text(c,Ammo.heat_label(id,s),Vector2(31,footer_y+y),40,17,thermal)
	var fit:=str(Ammo.slot_cost(id))+"칸" if Ammo.is_compressed(id) else ""
	if Ammo.anchor(id)=="first": fit+=" · 첫 발"
	elif Ammo.anchor(id)=="last": fit+=" · 끝 발"
	if not fit.is_empty(): text(c,fit,Vector2(78,footer_y+y),w-90,16,accent)
	elif pen>0 and h<198: text(c,"관통 %d"%pen,Vector2(78,footer_y+y),w-90,16,accent)
	var tune:=str(Ammo.AMMO[id].get("tune",""))
	if not tune.is_empty(): text(c,"화력↑" if tune=="power" else "방열↓",Vector2(w-64,43+y),54,13,Color("bcb59e"))
	if h>=164:
		text(c,c.footer_text(),Vector2(12,h-54+y),w-24,17,ink)
		var context: String=c.context_text if not c.context_text.is_empty() else Ammo.grade_name(id)
		text(c,context,Vector2(12,h-15+y),w-24-(110 if c.offer_action else 0),15,muted)
		if c.offer_action: text(c,"확보 ›" if not disabled else "확보 불가",Vector2(w-104,h-15+y),92,17,Color("c5d3bd") if selected else ink,true)
