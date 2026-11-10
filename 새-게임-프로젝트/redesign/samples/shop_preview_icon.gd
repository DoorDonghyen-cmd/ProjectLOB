@tool
extends Control
## Reuses production cartridge/device artwork; no text is baked into the icon.
@export var item_id := "precise_p1":
	set(value):
		item_id = value
		queue_redraw()
@export var is_part := false
@export var small := false

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := (size * 0.5).floor()
	if not small:
		# Short mounting shadow ties the object to its tray, without a nested box.
		var y := center.y + (35 if is_part else 44)
		draw_rect(Rect2(center.x - 39, y, 78, 4), Color("1b292c"))
		draw_rect(Rect2(center.x - 28, y + 4, 56, 2), Color("35413c"))
	if is_part:
		preload("res://redesign/part_icon_art.gd").draw(self, item_id, center, Color("b5b9a3"), 0.6 if small else 1.5)
	else:
		var extent := Vector2(40, 50) if small else Vector2(82, 94)
		preload("res://redesign/ammo_art.gd").draw(self, item_id, Rect2(center - extent * 0.5, extent))
