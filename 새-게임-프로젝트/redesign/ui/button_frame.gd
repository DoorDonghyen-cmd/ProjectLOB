@tool
extends StyleBoxFlat
## Shared metal edge for action buttons. The scene owns its colors and padding.

@export var brass_face := false
@export var brass_accent := Color.TRANSPARENT
@export var focus_ring := false:
	set(value):
		focus_ring = value
		set_border_width_all(2 if value else 1)
		border_width_bottom = 2
		draw_center = not value

func _init() -> void:
	anti_aliasing = false
	corner_detail = 1
	set_corner_radius_all(4)
	set_border_width_all(1)
	border_width_bottom = 2

static func with_margins(frame: StyleBox, original: StyleBox) -> StyleBox:
	var style := frame.duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, original.get_content_margin(side))
	return style

static func paint_brass(canvas: CanvasItem, button: Button) -> bool:
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	if normal == null or normal.get("brass_face") != true: return false
	if button.disabled or button.size.x < 32 or button.size.y < 24: return true
	var style_name := &"normal"
	match button.get_draw_mode():
		BaseButton.DRAW_HOVER: style_name = &"hover"
		BaseButton.DRAW_PRESSED: style_name = &"pressed"
		BaseButton.DRAW_HOVER_PRESSED: style_name = &"hover_pressed"
	var face := button.get_theme_stylebox(style_name) as StyleBoxFlat
	var tone := normal.bg_color if face == null else face.bg_color
	var width := floorf(button.size.x)
	var height := floorf(button.size.y)
	var pressed := style_name in [&"pressed", &"hover_pressed"]
	var accent: Color = normal.get("brass_accent")
	var accent_on_edge := accent.a > 0.0
	var highlight := accent if accent_on_edge else tone.lightened(0.40)
	if pressed: highlight = highlight.darkened(0.42) if accent_on_edge else tone.darkened(0.28)
	var upper_edge := tone.lerp(accent, 0.48) if accent_on_edge else tone.lightened(0.12)
	var left_edge := tone.lerp(accent, 0.46) if accent_on_edge else tone.lightened(0.17)
	var right_edge := tone.darkened(0.39 if accent_on_edge else 0.23)
	# Pixel steps at the edges keep the label area flat and readable.
	canvas.draw_rect(Rect2(6, 2, width - 12, 2), highlight)
	canvas.draw_rect(Rect2(9, 4, width - 18, 1), upper_edge)
	canvas.draw_rect(Rect2(2, 6, 1, height - 12), left_edge)
	canvas.draw_rect(Rect2(width - 3, 6, 1, height - 12), right_edge)
	if not accent_on_edge:
		canvas.draw_rect(Rect2(8, height - 6, width - 16, 2), tone.darkened(0.16))
	canvas.draw_rect(Rect2(5, height - 4, width - 10, 2), tone.darkened(0.47 if pressed or accent_on_edge else 0.40))
	return true
