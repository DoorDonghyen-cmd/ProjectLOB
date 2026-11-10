@tool
extends Button
## Content width belongs to the role, never to spare viewport space.
var fitting := false

func _ready() -> void:
	theme_changed.connect(_fit_width)
	minimum_size_changed.connect(_fit_width)
	_fit_width.call_deferred()

func set_caption(value: String) -> void:
	text = value
	_fit_width()

func _fit_width() -> void:
	if fitting or not is_inside_tree(): return
	fitting = true
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var style := get_theme_stylebox("normal")
	var desired := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
	var width := clampf(desired, get_theme_constant("min_width"), get_theme_constant("max_width"))
	var wanted := Vector2(width, get_theme_constant("touch_height"))
	if custom_minimum_size != wanted: custom_minimum_size = wanted
	fitting = false

