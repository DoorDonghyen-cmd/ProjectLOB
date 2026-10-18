extends RefCounted
## Original LoB widget skin. Coverage informed by the reference theme, no copied art.
const ConsoleSkin = preload("res://redesign/combat_pixel_skin.gd")

static func _bar(color: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func _toggle(on: bool, disabled: bool) -> Texture2D:
	var image := Image.create(40, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(0, 4, 40, 16), Color("101e26"))
	image.fill_rect(Rect2i(2, 6, 36, 12), Color("344a4e"))
	var color := Color("637875") if disabled else (ConsoleSkin.SELECT if on else Color("8dabae"))
	var x := 24 if on else 2
	image.fill_rect(Rect2i(x, 2, 14, 20), Color("17272e"))
	image.fill_rect(Rect2i(x, 2, 14, 16), color)
	image.fill_rect(Rect2i(x+4, 6, 6, 2), Color("d4ddd5") if not disabled else Color("8dabae"))
	return ImageTexture.create_from_image(image)

static func apply_to(theme: Theme) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := ConsoleSkin.box("button", state)
		box.content_margin_left = 16
		box.content_margin_right = 36
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		theme.set_stylebox(state, "OptionButton", box)
	theme.set_color("font_color", "OptionButton", ConsoleSkin.INK)
	theme.set_color("font_hover_color", "OptionButton", ConsoleSkin.INK)
	theme.set_color("font_pressed_color", "OptionButton", ConsoleSkin.INK)
	theme.set_color("font_disabled_color", "OptionButton", ConsoleSkin.MUTED)
	theme.set_constant("arrow_margin", "OptionButton", 12)
	theme.set_stylebox("panel", "PopupMenu", ConsoleSkin.box("panel"))
	theme.set_stylebox("hover", "PopupMenu", _bar(Color("35494e"), Color("758886")))
	theme.set_color("font_color", "PopupMenu", ConsoleSkin.INK)
	theme.set_color("font_hover_color", "PopupMenu", ConsoleSkin.INK)
	theme.set_constant("v_separation", "PopupMenu", 14)
	for axis in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", axis, _bar(Color("14252c"), Color("203238")))
		theme.set_stylebox("grabber", axis, _bar(Color("607473"), Color("344a4e")))
		theme.set_stylebox("grabber_highlight", axis, _bar(Color("8dabae"), Color("53686b")))
		theme.set_stylebox("grabber_pressed", axis, _bar(Color("9abdc8"), Color("53686b")))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var blank := StyleBoxEmpty.new()
		blank.content_margin_left = 4
		blank.content_margin_right = 4
		theme.set_stylebox(state, "CheckButton", blank)
	theme.set_stylebox("focus", "CheckButton", ConsoleSkin.box("button", "focus"))
	theme.set_icon("checked", "CheckButton", _toggle(true, false))
	theme.set_icon("unchecked", "CheckButton", _toggle(false, false))
	theme.set_icon("checked_disabled", "CheckButton", _toggle(true, true))
	theme.set_icon("unchecked_disabled", "CheckButton", _toggle(false, true))
	theme.set_color("font_color", "CheckButton", ConsoleSkin.INK)
	theme.set_color("font_hover_color", "CheckButton", ConsoleSkin.INK)
	theme.set_color("font_pressed_color", "CheckButton", ConsoleSkin.INK)
	theme.set_color("font_disabled_color", "CheckButton", ConsoleSkin.MUTED)
	theme.set_stylebox("panel", "TooltipPanel", ConsoleSkin.box("panel"))
	theme.set_color("font_color", "TooltipLabel", ConsoleSkin.INK)
