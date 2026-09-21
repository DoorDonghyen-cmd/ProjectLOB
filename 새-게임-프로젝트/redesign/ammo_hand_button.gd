extends Button
## A hand card keeps tap-to-load and exposes native Control drag/drop only when
## another visible copy can form a field-compression pair.

signal pair_dropped(ammo_id: String, source_center: Vector2, target_center: Vector2)

const AmmoCardView = preload("res://redesign/ammo_card_view.gd")

var ammo_id := "basic"
var card_token := ""
var compression_ready := false
var combat_state: Dictionary = {}

func setup(id: String, token: String, can_compress: bool, current_state: Dictionary) -> void:
	ammo_id = id
	card_token = token
	compression_ready = can_compress
	combat_state = current_state

func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or not compression_ready:
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(maxf(size.x, 176.0), maxf(size.y, 104.0))
	preview.size = preview.custom_minimum_size
	preview.modulate.a = 0.9
	var card := AmmoCardView.new()
	card.setup(ammo_id, 1, combat_state, false, true)
	preview.add_child(card)
	set_drag_preview(preview)
	return {
		"kind": "field_ammo",
		"id": ammo_id,
		"token": card_token,
		"source_center": get_global_rect().get_center(),
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		not disabled
		and compression_ready
		and data is Dictionary
		and str(data.get("kind", "")) == "field_ammo"
		and str(data.get("id", "")) == ammo_id
		and str(data.get("token", "")) != card_token
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	pair_dropped.emit(ammo_id, Vector2(data.source_center), get_global_rect().get_center())
