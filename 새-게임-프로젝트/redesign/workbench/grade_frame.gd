@tool
extends Control
## Card grade identity uses rail/notch shape as well as colour.
@export_range(0, 3) var tier := 0:
	set(value):
		tier = value
		queue_redraw()
const INKS := [Color("817e70"), Color("bb9d62"), Color("9a92ad"), Color("b47b62")]

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var c: Color = INKS[tier]
	var w := floorf(size.x)
	var h := floorf(size.y)
	draw_rect(Rect2(0, 0, w, h), Color("171612"))
	draw_rect(Rect2(0, 0, w, h), c.darkened(0.42), false, 1)
	# Distinct material rails; no full-card glow or repeated socket ornament.
	for i in range(tier + 1):
		draw_rect(Rect2(8 + i * 8, 0, 4, 3), c)
	if tier >= 1:
		draw_rect(Rect2(0, h - 3, w, 2), c)
	if tier >= 2:
		draw_rect(Rect2(w - 3, 8, 2, h - 16), c.darkened(0.15))
	if tier == 3:
		for x in [0.0, w - 12]:
			draw_rect(Rect2(x, 0, 12, 3), c)
			draw_rect(Rect2(x, h - 4, 12, 4), c)
