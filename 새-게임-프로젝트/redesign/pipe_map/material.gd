@tool
extends RefCounted
## Map-only materials and semantic state colors. No route/gameplay decisions.
const BACKGROUND := Color("0e130e")
const INK := Color("e1dccc")
const MUTED := Color("a5a294")
const METAL := Color("555c4c")
const BRASS := Color("bea36b")
const PICK := Color("e4be76")
const TRAIL := Color("957747")
const OPEN := Color("c8cfb7")
const FUTURE := Color("626d5e")
const PREVIEW := Color("929d7a")
const OFF := Color("303a30")
const PATHS := {"off":OFF,"later":FUTURE,"preview":PREVIEW,"open":OPEN,"trail":TRAIL,"pick":PICK}
const SELECTION = preload("res://redesign/pipe_map/selection.tres")
const GATE = preload("res://redesign/pipe_map/gate.tres")
const THEME = preload("res://redesign/pipe_map/theme.tres")
const PANEL = preload("res://redesign/pipe_map/panel.tres")

static func preserve_margins(style: StyleBox, original: StyleBox) -> void:
	style.content_margin_left=original.get_content_margin(SIDE_LEFT)
	style.content_margin_top=original.get_content_margin(SIDE_TOP)
	style.content_margin_right=original.get_content_margin(SIDE_RIGHT)
	style.content_margin_bottom=original.get_content_margin(SIDE_BOTTOM)

static func style_workspace(overlay: Control) -> void:
	if not is_instance_valid(overlay): return
	overlay.theme=THEME
	var controls: Array[Control]=[overlay]
	for item in overlay.find_children("*","Control",true,false):controls.append(item)
	for item in controls:
		if item is PanelContainer:
			var original: StyleBox=item.get_theme_stylebox("panel")
			var surface:=PANEL.duplicate() as StyleBoxFlat
			preserve_margins(surface,original)
			if item==overlay:
				surface.bg_color=BACKGROUND;surface.set_border_width_all(0);surface.set_corner_radius_all(0)
			item.add_theme_stylebox_override("panel",surface)
		elif item is Button:
			for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
				var original:StyleBox=item.get_theme_stylebox(state)
				var surface:StyleBox=THEME.get_stylebox(state,"Button").duplicate()
				preserve_margins(surface,original)
				item.add_theme_stylebox_override(state,surface)
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:item.add_theme_color_override(state,INK)
		elif item is Label:
			var original:Color=item.get_theme_color("font_color")
			if original.is_equal_approx(Color("5cdddc")):item.add_theme_color_override("font_color",BRASS)
			elif original.is_equal_approx(Color("8fb0b0")):item.add_theme_color_override("font_color",MUTED)
			elif original.is_equal_approx(Color("e4f2ee")):item.add_theme_color_override("font_color",INK)
