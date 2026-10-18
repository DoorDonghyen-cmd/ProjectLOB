extends Control
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/ui_font.tres")
var outfit_id := "work"
var chosen := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var data: Dictionary = Content.OUTFITS[outfit_id]
	var ink := Color("e7e4d9")
	var quiet := Color("94a9ae")
	var accent := Color("acc3b1") if chosen else Color("94a9ae")
	# Small cloth-and-pocket symbol; the character costume art is a separate asset.
	var unit := 3
	var cloth := Color("637c7e") if outfit_id == "work" else (Color("8c7760") if outfit_id == "carrier" else Color("6d8064"))
	draw_set_transform(Vector2(floorf(size.x * 0.5) - 42, 28), 0, Vector2.ONE * unit)
	draw_rect(Rect2(8, 2, 12, 23 if outfit_id == "carrier" else 19), cloth)
	draw_rect(Rect2(4, 4, 4, 13), cloth.darkened(0.15))
	draw_rect(Rect2(20, 4, 4, 13), cloth.darkened(0.15))
	draw_rect(Rect2(12, 0, 4, 5), Color("263b42"))
	draw_rect(Rect2(13, 5, 1, 16), cloth.darkened(0.32))
	for x in [8, 16]:
		draw_rect(Rect2(x, 12, 4, 5), cloth.darkened(0.26))
		draw_rect(Rect2(x, 12, 4, 1), cloth.lightened(0.18))
	if outfit_id == "carrier":
		for x in [5, 19]: draw_rect(Rect2(x, 18, 4, 6), Color("a08b66"))
	if outfit_id == "scout": draw_rect(Rect2(7, 7, 14, 2), Color("a69a77"))
	draw_set_transform(Vector2.ZERO)
	draw_string(FONT, Vector2(10, 137), str(data.name), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 22, ink)
	draw_string(FONT, Vector2(10, 177), "가방 %d장" % data.hand, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 29, ink)
	draw_string(FONT, Vector2(10, 207), "패 교환 %d회" % data.exchange, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 20, quiet)
	draw_string(FONT, Vector2(10, 242), "선택됨" if chosen else str(data.role), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 17, accent)
