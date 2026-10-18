extends RefCounted
## Native hit areas with matching painted-steel pixel keycaps.
static func finish_button(button: Button, primary: bool = false) -> void:
	var cooling:=button.name=="reload"
	var danger: bool=button.get_meta("reload_lethal",false)
	button.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var kind:="danger" if danger else ("primary" if primary else ("reload" if cooling else "button"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box:=preload("res://redesign/instrument_skin.gd").key_box(kind,state)
		button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_color",Color("e3d8bd"))
	button.add_theme_color_override("font_hover_color",Color("fff0ce"))
	button.add_theme_color_override("font_disabled_color",Color("708582"))
