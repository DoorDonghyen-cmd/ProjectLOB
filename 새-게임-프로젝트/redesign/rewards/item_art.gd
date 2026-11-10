@tool
extends "res://redesign/samples/shop_terminal_review/item_glyph.gd"

func _draw() -> void:
	if item_id != "third_striker":
		super._draw()
		return
	var center := (size * 0.5).floor()
	draw_set_transform(center - Vector2(32, 24), 0.0, Vector2(2, 2))
	PartArt.metal(self, 2, 12, 28, 8)
	PartArt.pipe(self, 4, 18, 24, 2)
	for index in range(3):
		var x := 4 + index * 9
		var height := 10 if index == 2 else 7
		PartArt.metal(self, x, 13 - height, 7, height, PartArt.COPPER if index == 2 else PartArt.STEEL)
		PartArt.rect(self, x + 2, 15, 3, 2, PartArt.INSET)
	PartArt.rect(self, 24, 5, 3, 2, Color("d1a56b"))
	draw_set_transform(Vector2.ZERO)
