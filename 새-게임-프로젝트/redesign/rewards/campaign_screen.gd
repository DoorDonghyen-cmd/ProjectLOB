extends "res://redesign/rewards/screen.gd"

const AmmoReadability = preload("res://redesign/readability.gd")
const Engines = preload("res://redesign/damage_engines.gd")
const PartFeedback = preload("res://redesign/part_feedback.gd")

var host
var committed := false

func configure(screen) -> void:
	host = screen
	run = host.campaign
	reveal_duration = 0.0 if str(host.preferences.data.motion) == "instant" else 0.26 * host.preferences.motion_scale()

func _ready() -> void:
	super._ready()
	%Trade.pressed.connect(open_exchange)
	%RewardDetails.pressed.connect(open_details)
	%RewardRecord.pressed.connect(open_record)
	%RewardTools.pressed.connect(open_tools)
	present()

func refresh() -> void:
	super.refresh()
	var boss := run.boss_loot()
	var package := run.first_ammo_reward() and Focus.enabled(run.s)
	var inspecting := not choosing_outgoing and not selected.is_empty() and selected != TRIM
	%Credits.visible = not choosing_outgoing and not boss
	%Trade.visible = inspecting and not package and run.can_acquire_ammo(selected) and not exchange_choices().is_empty()
	%RewardDetails.visible = inspecting
	%RewardRecord.visible = not choosing_outgoing
	%RewardTools.visible = not choosing_outgoing
	if boss and not choosing_outgoing:
		%Skip.text = "관문으로" if int(run.s.region) < 4 else "정상으로"
	var receipts: PackedStringArray = []
	if boss:
		receipts.append("+%d Cr 수령" % run.boss_credits())
	elif run.s.get("encounter", {}).get("stage", "") == "cleared":
		receipts.append(str(run.s.message))
	for id in run.model.s.get("engine", {}).get("gains", []):
		receipts.append("%s · %s" % [Data.PARTS[id].name, Engines.gain_summary(run.model.s, id)])
	if not host.save_error.is_empty():
		receipts.insert(0, host.save_error)
	%Receipt.text = "  /  ".join(receipts)
	%Receipt.tooltip_text = %Receipt.text
	%Receipt.visible = not receipts.is_empty()

func claim(id: String, removed: String = "") -> void:
	if committed or not host._campaign_action("reward", id, removed):
		return
	committed = true
	%Confirm.disabled = true
	%Skip.disabled = true
	%Credits.disabled = true

func open_details() -> void:
	if Data.PARTS.has(selected):
		host.city_ui.part_details(selected)
	elif Data.AMMO.has(selected):
		var column: VBoxContainer = host._dialog(title_for(selected), true)
		host._label(column, AmmoReadability.description(selected, run.model.s), 18)

func open_record() -> void:
	host._encounter_record(PartFeedback.encounter_state(run.encounter_report_state()))

func open_tools() -> void:
	var column: VBoxContainer = host._workspace("전투 보상 메뉴")
	host._button(column, "빌드", "city_deck", host.city_ui.deck)
	host._button(column, "기록실", "city_archive", host.city_ui.archive)
	host._button(column, "설정", "settings", host._settings)
	host._button(column, "타이틀", "menu", host._to_menu)

func _input(event: InputEvent) -> void:
	if choosing_outgoing and event.is_action_pressed("ui_cancel"):
		cancel_exchange()
		get_viewport().set_input_as_handled()
