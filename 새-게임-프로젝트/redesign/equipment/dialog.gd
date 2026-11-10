extends "res://redesign/console_dialog.gd"
## Equipment-only presentation; the original modal owns layout, input and closing.
const EQUIPMENT=preload("res://redesign/equipment/theme.tres")
const PANEL=preload("res://redesign/equipment/dialog_panel.tres")
const INK:=Color("e1dccc")
const MUTED:=Color("a5a294")
const BRASS:=Color("bea36b")

func setup(owner_screen: Control, title: String, small: bool) -> VBoxContainer:
	# Preserve all inherited metrics, symbols, font sizes and widget constants.
	theme=owner_screen.ui_theme.duplicate()
	var content:=super.setup(owner_screen,title,small)
	_material_theme()
	_paint_content.call_deferred()
	return content

func _face(state: String, original: StyleBox, primary: bool=false, panel: bool=false) -> StyleBox:
	if original is StyleBoxEmpty:return original.duplicate()
	var result: StyleBox
	if panel:result=PANEL.duplicate()
	else:
		var mapped:=state if state in ["normal","hover","pressed","hover_pressed","disabled","focus"] else "normal"
		result=EQUIPMENT.get_stylebox(mapped,"EquipmentPrimary" if primary else "Button").duplicate()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:result.set_content_margin(side,original.get_content_margin(side))
	return result

func _toggle(on: bool, disabled: bool) -> Texture2D:
	# Same 40x24 native pixel geometry as ConsoleWidgets; only its palette changes.
	var pixels:=Image.create(40,24,false,Image.FORMAT_RGBA8);pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(0,4,40,16),Color("11170f"))
	pixels.fill_rect(Rect2i(2,6,36,12),Color("424839"))
	var x:=24 if on else 2
	pixels.fill_rect(Rect2i(x,2,14,20),Color("131a10"))
	pixels.fill_rect(Rect2i(x,2,14,16),Color("6b725f") if disabled else BRASS if on else Color("8b9080"))
	pixels.fill_rect(Rect2i(x+4,6,6,2),INK if not disabled else MUTED)
	return ImageTexture.create_from_image(pixels)

func _material_theme() -> void:
	for kind in ["Button","OptionButton","CheckButton","LineEdit","PopupMenu","HScrollBar","VScrollBar","TooltipPanel"]:
		for state in theme.get_stylebox_list(kind):
			var original:=theme.get_stylebox(state,kind)
			var face:=_face(state,original,false,state=="panel")
			if kind in ["HScrollBar","VScrollBar"] and face is StyleBoxFlat:
				face.bg_color=Color("555c4c") if str(state).begins_with("grabber") else Color("11170f")
				face.border_color=Color("717a63");face.set_corner_radius_all(0)
			theme.set_stylebox(state,kind,face)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:theme.set_color(state,kind,INK)
		theme.set_color("font_disabled_color",kind,Color("8b9080"))
	for on in [true,false]:
		for disabled in [true,false]:theme.set_icon(("checked" if on else "unchecked")+("_disabled" if disabled else ""),"CheckButton",_toggle(on,disabled))
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","TooltipLabel",INK)

func _ink(original: Color) -> Color:
	if original.is_equal_approx(Color("e4f2ee")):return INK
	if original.is_equal_approx(Color("8fb0b0")):return MUTED
	if original.is_equal_approx(Color("5cdddc")):return BRASS
	return original # Weapon identity, risk and other functional colors stay distinct.

func _paint_content() -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	for item in find_children("*","Control",true,false):
		if item is Label:item.add_theme_color_override("font_color",_ink(item.get_theme_color("font_color")))
		elif item is BaseButton:
			var primary: bool=item==%DialogConfirm or item.get_theme_color("font_color").get_luminance()<0.08
			for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
				if item.has_theme_stylebox(state):item.add_theme_stylebox_override(state,_face(state,item.get_theme_stylebox(state),primary))
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:item.add_theme_color_override(state,Color("181b15") if primary else INK)
			if item is OptionButton:item.get_popup().theme=theme
		elif item is LineEdit:
			for state in ["normal","focus","read_only"]:
				if item.has_theme_stylebox(state):item.add_theme_stylebox_override(state,_face(state,item.get_theme_stylebox(state)))
			item.add_theme_color_override("font_color",INK);item.add_theme_color_override("caret_color",BRASS)
		elif item is PanelContainer:
			item.add_theme_stylebox_override("panel",_face("normal",item.get_theme_stylebox("panel"),false,true))
