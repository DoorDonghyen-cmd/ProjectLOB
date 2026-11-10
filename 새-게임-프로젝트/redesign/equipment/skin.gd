extends RefCounted
## Choice state changes only color/material; authored geometry belongs to scenes.
const INK := Color("e1dccc")
const MUTED := Color("a5a294")
const BRASS := Color("bea36b")
const LOCKED := Color("838579")

static func apply_choice(button: Button, selected: bool) -> void:
	button.theme_type_variation = &"EquipmentSelected" if selected else &"EquipmentChoice"
	var ink := LOCKED if button.disabled else (INK if selected else MUTED)
	for label in button.find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", ink)
	var stats := button.get_node_or_null("Copy/Stats") as Label
	if stats != null:
		stats.add_theme_color_override("font_color", LOCKED if button.disabled else (BRASS if selected else Color("8b9080")))
	var art := button.get_node_or_null("Icon") as CanvasItem
	if art == null:
		art = button.get_node_or_null("Art") as CanvasItem
	if art != null:
		art.self_modulate = Color(1, 1, 1, 0.52 if button.disabled else 1.0)
