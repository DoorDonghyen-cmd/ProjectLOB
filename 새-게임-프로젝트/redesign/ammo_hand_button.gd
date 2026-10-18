extends Button
## A hand card keeps tap-to-load and exposes native Control drag/drop only when
## another visible copy can form a field-compression pair.

signal pair_dropped(ammo_id: String, source_center: Vector2, target_center: Vector2)
signal detail_requested(ammo_id: String)

const AmmoCardView = preload("res://redesign/ammo_card_view.gd")

var ammo_id := "basic"
var card_token := ""
var compression_ready := false
var combat_state: Dictionary = {}
var suppress_activation := false
var hold_remaining := 0.0
var hold_origin := Vector2.ZERO

func _ready() -> void:
	button_down.connect(_begin_hold)
	button_up.connect(_cancel_hold)
	gui_input.connect(_inspect_input)
	set_process(false)

func _begin_hold() -> void:
	suppress_activation=false
	hold_remaining=0.5
	hold_origin=get_global_mouse_position()
	set_process(true)

func _cancel_hold() -> void:
	hold_remaining=0.0
	set_process(false)

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			suppress_activation=true
			_cancel_hold()
			detail_requested.emit(ammo_id)
			accept_event()
		elif disabled and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_hold()
			else: _cancel_hold()
	elif event is InputEventMouseMotion and hold_remaining>0:
		if get_global_mouse_position().distance_to(hold_origin)>12: _cancel_hold()

func _process(delta: float) -> void:
	if get_viewport().gui_is_dragging():
		_cancel_hold()
		return
	hold_remaining-=delta
	if hold_remaining<=0:
		_cancel_hold()
		suppress_activation=true
		set_pressed_no_signal(false)
		detail_requested.emit(ammo_id)

func setup(id: String, token: String, can_compress: bool, current_state: Dictionary) -> void:
	ammo_id = id
	card_token = token
	compression_ready = can_compress
	combat_state = current_state

func _get_drag_data(_at_position: Vector2) -> Variant:
	_cancel_hold()
	if disabled or not compression_ready:
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(maxf(size.x, 176.0), maxf(size.y, 104.0))
	preview.size = preview.custom_minimum_size
	preview.modulate.a = 0.9
	var card := AmmoCardView.new()
	card.compact_ui = true
	card.combat_skin = true
	card.hand_skin = true
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
