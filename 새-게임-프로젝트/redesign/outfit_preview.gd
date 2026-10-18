extends Control
## Independent art viewer: no Campaign, Model, Preferences or save calls.
const OUTFIT_IDS := ["heatworker", "hoist", "recovery", "expedition"]
const ServiceCatalog = preload("res://redesign/service_actor_catalog.gd")
const SKIN = preload("res://redesign/combat_pixel_skin.gd")
const CONCEPTS := [
	preload("res://assets/art/outfit_preview_20261011/07_heatworker_v1.png"),
	preload("res://assets/art/outfit_preview_20261011/08_hoist_v1.png"),
	preload("res://assets/art/outfit_preview_20261011/09_recovery_v1.png"),
	preload("res://assets/art/outfit_preview_20261011/10_expedition_v3.png")
]
const TITLES := ["배관공 방열복", "승강로 인양 장구", "봉쇄구역 회수 장구", "밀폐형 원정복"]
const ROOM_IMAGES := [
	preload("res://assets/art/service_layers_20261011/shop_background.png"),
	preload("res://assets/art/service_layers_20261011/supply_background.png"),
	preload("res://assets/art/service_layers_20261011/workshop_background.png")
]
const ROOM_FEET := [Vector2(0.409, 0.9), Vector2(0.402, 0.833), Vector2(0.49, 0.852)]
const ROOM_HEIGHTS := [0.643, 0.51, 0.535]
var selected := 3
var mode := 0
var return_focus: WeakRef
var outfit_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []

func _ready() -> void:
	set_meta("lob_modal", true)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: return_focus = weakref(focused)
	outfit_buttons.assign([%Heatworker, %Hoist, %Recovery, %Expedition])
	mode_buttons.assign([%ConceptButton, %BattleButton, %ShopButton, %SupplyButton, %WorkshopButton])
	for i in outfit_buttons.size(): outfit_buttons[i].pressed.connect(select_outfit.bind(i))
	for i in mode_buttons.size(): mode_buttons[i].pressed.connect(select_mode.bind(i))
	for node in find_children("*", "Button", true, false):
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			node.add_theme_stylebox_override(state, _skin("button", state))
	for entry in [[%Single,"single"],[%Burst,"burst"],[%Scatter,"scatter"],[%Heavy,"heavy"],[%Amplifier,"amplifier"]]:
		entry[0].pressed.connect(choose_gun.bind(entry[1]))
	for entry in [[%Idle,"idle"],[%Aim,"aim"],[%Recoil,"recoil"],[%ReloadOpen,"reload_open"],[%ReloadSeat,"reload_seat"],[%Cooling,"cooling"]]:
		entry[0].pressed.connect(%Battle.choose_pose.bind(entry[1]))
	%Fire.pressed.connect(%Battle.play_action.bind("fire"))
	%Reload.pressed.connect(%Battle.play_action.bind("reload"))
	%Zoom.toggled.connect(func(on: bool):
		%Battle.magnification = 2.0 if on else 1.0
		%Battle.queue_redraw()
	)
	%Close.pressed.connect(close)
	select_outfit(3)
	choose_gun("single")
	%Expedition.grab_focus()

func select_outfit(index: int) -> void:
	selected = clampi(index, 0, 3)
	%Name.text = TITLES[selected]
	%Concept.texture = CONCEPTS[selected]
	%Status.text = "본편 연결 · 전투·장소용 외형 검토"
	for i in outfit_buttons.size():
		outfit_buttons[i].set_pressed_no_signal(i == selected)
		outfit_buttons[i].add_theme_stylebox_override("normal", _skin("well", "selected" if i == selected else "normal"))
	for i in range(1, mode_buttons.size()):
		mode_buttons[i].disabled = false
		mode_buttons[i].tooltip_text = ""
	%Battle.actor.set_outfit(OUTFIT_IDS[selected])
	%Battle.choose_pose("idle")
	select_mode(0)

func select_mode(index: int) -> void:
	mode = clampi(index, 0, 4)
	%Concept.visible = mode == 0
	%Battle.visible = mode == 1
	%Room.visible = mode >= 2
	%CombatControls.visible = mode == 1
	for i in mode_buttons.size():
		mode_buttons[i].set_pressed_no_signal(i == mode)
		mode_buttons[i].add_theme_stylebox_override("normal", _skin("well", "selected" if i == mode else "normal"))
	if mode != 1: %Battle.animation = ""
	if mode >= 2:
		var room := mode - 2
		%Room.texture = ROOM_IMAGES[room]
		%RoomActor.profile = ServiceCatalog.resolve(OUTFIT_IDS[selected], ["shop", "supply", "workshop"][room]).profile
		%RoomActor.room_foot = ROOM_FEET[room]
		%RoomActor.room_height = ROOM_HEIGHTS[room]
		%RoomActor.queue_redraw()

func choose_gun(id: String) -> void:
	%Battle.choose_gun(id)
	for entry in [[%Single,"single"],[%Burst,"burst"],[%Scatter,"scatter"],[%Heavy,"heavy"],[%Amplifier,"amplifier"]]:
		entry[0].set_pressed_no_signal(entry[1] == id)
		entry[0].add_theme_stylebox_override("normal", _skin("well", "selected" if entry[1] == id else "normal"))

func close() -> void:
	if get_tree().current_scene == self:
		get_tree().quit()
	else:
		hide()
		if return_focus != null and is_instance_valid(return_focus.get_ref()): return_focus.get_ref().grab_focus()
		queue_free()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = []
		for item in find_children("*", "Button", true, false):
			if item.is_visible_in_tree() and not item.disabled: controls.append(item)
		if controls.is_empty(): return
		var at := controls.find(get_viewport().gui_get_focus_owner())
		controls[posmod(at + (-1 if event.is_action_pressed("ui_focus_prev") else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _skin(kind: String, state: String) -> StyleBox:
	var style := SKIN.box(kind, state)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
