extends Control
## Tag chips on a combat magazine card (2026-11-11, tag build runs only). One syllable per
## tag (tag_build.gd SHORT/COLORS). A chip is a filled box when an equipped tag part reads that
## tag, a bare letter otherwise. Words and numbers are in the round details.
const Tags = preload("res://redesign/tag_build.gd")
const CHIP := 16
const GAP := 1
var tags: Array = []
var lit: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_tags(value: Array, read: Array) -> void:
	tags = value.duplicate()
	lit = read.filter(func(tag): return tags.has(tag))
	custom_minimum_size = Vector2(maxi(0, tags.size() * (CHIP + GAP) - GAP), CHIP)
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	var font := get_theme_font("font", "Label")
	for i in range(tags.size()):
		var tag := str(tags[i])
		var color: Color = Tags.COLORS.get(tag, Color("aab8bd"))
		var box := Rect2(Vector2(i * (CHIP + GAP), 0), Vector2(CHIP, CHIP))
		var on := lit.has(tag)
		# Filled box = a part reads this tag; letter only = the round has the tag, nothing reads it.
		# (An outlined box looked filled: the 16px glyph fills the whole chip.)
		if on: draw_rect(box, color)
		var text := str(Tags.SHORT.get(tag, tag.left(1)))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(box.position.x + roundf((CHIP - width) * 0.5), 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("0b161a") if on else color)
