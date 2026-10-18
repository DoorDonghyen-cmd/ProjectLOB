extends Control
## One quiet structural plane for combat. Functional controls share PixelSkin.
const PixelSkin = preload("res://redesign/combat_pixel_skin.gd")
var active := false
var hand := false

static func install(panel: PanelContainer, focused: bool, is_hand: bool) -> void:
	var surface: Control = load("res://redesign/combat_surface.gd").new()
	surface.name = "CombatSurface"
	surface.active = focused
	surface.hand = is_hand
	panel.add_child(surface)
	panel.move_child(surface,0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	var header := get_parent().find_child("HandHeader" if hand else "FiringRailHeader",true,false) as Control
	if header: header.item_rect_changed.connect(queue_redraw)

func header_shelf_rect() -> Rect2:
	var panel := get_parent() as PanelContainer
	var box := panel.get_theme_stylebox("panel")
	var origin := -Vector2(box.get_content_margin(SIDE_LEFT),box.get_content_margin(SIDE_TOP))
	var header := panel.find_child("HandHeader" if hand else "FiringRailHeader",true,false) as Control
	var bottom := header.get_global_rect().end.y - global_position.y + 4 if header else origin.y + 42
	return Rect2(origin+Vector2(6,6),Vector2(panel.size.x-12,bottom-origin.y-6))

func _draw() -> void:
	var panel := get_parent() as PanelContainer
	var box := panel.get_theme_stylebox("panel")
	var origin := -Vector2(box.get_content_margin(SIDE_LEFT),box.get_content_margin(SIDE_TOP))
	draw_style_box(PixelSkin.box("tray" if hand else "panel"),Rect2(origin,panel.size))
	# Header shelf joins the section to its controls; the reading plane stays quiet.
	var shelf := header_shelf_rect()
	draw_rect(shelf,Color("263d43") if hand else Color("2d4246"))
	draw_rect(Rect2(shelf.position.x,shelf.end.y,shelf.size.x,2),Color("14262e"))

static func finish_button(button: Button, primary: bool = false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preload("res://redesign/ui_impulse.gd").install(button)
	button.add_theme_font_override("font",PixelSkin.FONT)
	var reload := button.name == "reload"
	var danger := reload and bool(button.get_meta("reload_lethal", button.text.contains("접촉 위험")))
	var warning := reload and bool(button.get_meta("reload_warning", false))
	var kind := "danger" if danger else ("primary" if primary else ("reload" if reload else "button"))
	button.get_node("UIImpulse").action_ink = PixelSkin.HEAT if danger or warning else (PixelSkin.COOL if reload else (PixelSkin.SELECT if primary else PixelSkin.INK))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var old := button.get_theme_stylebox(state)
		var style := PixelSkin.box(kind,state)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			style.set_content_margin(side,(10 if side in [SIDE_LEFT,SIDE_RIGHT] else 4) if reload else old.get_content_margin(side))
		if reload and state == "pressed":
			style.content_margin_top = 6
			style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state,style)
	var ink := Color("192d31") if primary else (PixelSkin.HEAT if warning and not danger else PixelSkin.INK)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,ink)
	button.add_theme_color_override("font_disabled_color",Color("657f82"))
	button.add_theme_color_override("icon_normal_color",ink)
	button.add_theme_color_override("icon_hover_color",ink)
	button.add_theme_color_override("icon_focus_color",ink)
	button.add_theme_color_override("icon_pressed_color",ink)
	button.add_theme_color_override("icon_disabled_color",Color("657f82"))
	if primary or reload:
		button.icon = PixelSkin.glyph("reload" if reload else ("fire" if button.name == "fire" else "confirm"))
		button.add_theme_constant_override("h_separation",8)
