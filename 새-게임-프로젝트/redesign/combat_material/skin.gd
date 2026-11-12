@tool
extends RefCounted
## Combat-only neutral iron. State colors retain their existing combat meaning.
const INK := Color("e1dccc")
const MUTED := Color("a5a294")
const DIM := Color("8e9380")
const SELECT := Color("5cdddc")
const DANGER := Color("ff6f61")
const ButtonFrame = preload("res://redesign/ui/button_frame.gd")
static var faces: Dictionary={}

static func box(kind: String, state: String="normal") -> StyleBoxFlat:
	var key:=kind+":"+state
	if faces.has(key):return faces[key]
	var fill:=Color("20251c")
	var edge:=Color("555c4c")
	if kind=="panel":fill=Color("12190f")
	elif kind=="card":fill=Color("192116");edge=Color("4b5442")
	elif kind=="heat":fill=Color("111b15");edge=Color("7d8571")
	elif kind=="cool":fill=Color("19271f");edge=Color("7e9b93")
	elif kind=="reload":fill=Color("292b1e");edge=Color("89764e")
	elif kind=="fire":fill=Color("bd7655");edge=Color("dfa77a")
	if state=="disabled":fill=Color("11170f");edge=Color("424b39")
	elif state=="empty":fill=Color("10170f");edge=Color("4b5442")
	elif state=="firing" or state=="active":edge=SELECT
	elif state=="removed":edge=DANGER
	elif state=="pressed":fill=fill.darkened(0.12)
	var is_action := kind in ["button", "cool", "reload", "fire"]
	var style: StyleBoxFlat = ButtonFrame.new() if is_action else StyleBoxFlat.new()
	style.bg_color=fill;style.border_color=edge
	if not is_action:
		style.set_border_width_all(1);style.border_width_bottom=2
		style.set_corner_radius_all(4);style.corner_detail=1;style.anti_aliasing=false
	if state in ["firing","removed","active"]:style.set_border_width_all(2)
	style.set_content_margin_all(0)
	faces[key]=style
	return style
