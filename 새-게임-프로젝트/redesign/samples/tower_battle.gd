extends "res://redesign/screen.gd"
## Reuses the real combat controller; no campaign writes or random art-only rules.
const SampleBattle = preload("res://redesign/samples/tower_battle_view.tscn")

func _ready() -> void:
	save_enabled = false
	debug_session = true
	_seed_sample()
	super._ready()
	DisplayServer.window_set_title("Last on Board · 기상탑 전투 샘플 · R 다시 시작")

func _seed_sample() -> void:
	campaign = null
	model.start("single", 731042)
	model.s.floor = 4
	model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "charge", "precise", "pierce"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = model.s.deck.slice(5)
	model.s.discard = []
	model.s.plan = []
	model.s.magazine = []
	model.s.plan_load_order = []
	model.s.reinforcements = []
	model.s.enemies = [
		{"kind": "runner", "name": Content.ENEMY_NAMES.runner, "hp": 8, "max_hp": 8, "def": 0, "speed": 2, "distance": 12, "burn": 0, "lane": 0},
		{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 16, "max_hp": 16, "def": 3, "speed": 1, "distance": 18, "burn": 0, "lane": 1},
		{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 12, "max_hp": 12, "def": 0, "speed": 2, "distance": 25, "burn": 0, "lane": 2, "weakness": "electric"},
	]
	model.s.encounter_total = 3
	model.s.deployed = 3
	page = "run"
	hand_layout_key = ""
	selected_slot = 0
	show_full_forecast = false
	previous_forecast = {}
	# Establish all six hand cards before loading so spent cards retain their places.
	_hand_entries()
	for id in ["charge", "precise", "pierce"]: model.load_round(id)

func reset_sample() -> void:
	if busy: return
	_seed_sample()
	redraw()

func _new_battle_view() -> Control:
	return SampleBattle.instantiate()

func _combat() -> void:
	super._combat()
	# Give the reference environment the spare vertical room at desktop size.
	# At short mobile aspect ratios the regular compact footprint is retained.
	battle_view.custom_minimum_size.y = maxf(180.0, minf(450.0, size.y - 565.0))
	battle_view.caption = ""

func _combat_header(compact: bool) -> void:
	super._combat_header(compact)
	var bar := body.get_node("CombatStatusBar")
	var row := bar.get_child(0)
	(row.get_child(0) as Label).text = "폐쇄 주거구"
	var menu := find_child("menu", true, false) as Button
	if menu != null: menu.text = "종료"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reset_sample()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _to_menu() -> void:
	if not busy: get_tree().quit()
