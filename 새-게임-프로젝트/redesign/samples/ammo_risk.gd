extends "res://redesign/samples/tower_battle.gd"
const RiskData = preload("res://redesign/samples/risk_sample_data.gd")
const RiskHeader = preload("res://redesign/samples/risk_header.tscn")
const RiskStatus = preload("res://redesign/samples/risk_status.tscn")
const RiskResult = preload("res://redesign/samples/risk_result.tscn")
const RiskBattle = preload("res://redesign/samples/risk_battle_view.tscn")

var scenario_index := 0
var hot_opening := true
var risk_prediction: Dictionary = {}
var reduced_feedback := false

func _new_battle_view() -> Control:
	var view := RiskBattle.instantiate()
	view.reduced_feedback = reduced_feedback or str(preferences.data.motion) == "instant"
	view.feedback_changed.connect(_risk_feedback)
	return view

func _toggle_feedback() -> void:
	if busy: return
	reduced_feedback = not reduced_feedback
	redraw()

func _ready() -> void:
	super._ready()
	DisplayServer.window_set_title("Last on Board · 탄환 출력 비교 · R 다시 시작")

func _seed_sample() -> void:
	campaign = null
	RiskData.seed_model(model, scenario_index)
	page = "run"
	hand_layout_key = ""
	selected_slot = 0
	show_full_forecast = false
	previous_forecast = {}
	combat_forecast = {}
	last_presentation = {}
	_hand_entries()
	for id in RiskData.initial_plan(hot_opening): model.load_round(id)

func select_case(index: int) -> void:
	if busy: return
	scenario_index = clampi(index, 0, 1)
	hot_opening = scenario_index == 0
	reset_sample()

func select_output(index: int) -> void:
	if busy: return
	hot_opening = index == 1
	reset_sample()

func _combat_header(_compact: bool) -> void:
	var header := RiskHeader.instantiate()
	body.add_child(header)
	for i in range(2):
		var button := header.get_node("risk_case_%d" % i) as Button
		button.set_pressed_no_signal(scenario_index == i)
		button.pressed.connect(select_case.bind(i))
		button.disabled = busy
		if scenario_index == i: _primary_button(button)
	for i in range(2):
		var button := header.get_node("risk_hot" if i == 1 else "risk_normal") as Button
		button.set_pressed_no_signal(hot_opening == (i == 1))
		button.pressed.connect(select_output.bind(i))
		button.disabled = busy
		if hot_opening == (i == 1): _primary_button(button, Color("ed9167") if hot_opening else ACCENT)
	header.get_node("risk_reset").pressed.connect(reset_sample)
	header.get_node("menu").pressed.connect(_to_menu)
	header.get_node("skip_animation").pressed.connect(_skip_animation)
	header.get_node("risk_motion").set_pressed_no_signal(reduced_feedback)
	header.get_node("risk_motion").pressed.connect(_toggle_feedback)
	for key in ["risk_reset", "menu", "risk_motion"]: header.get_node(key).disabled = busy

func _combat() -> void:
	super._combat()
	# Keep the approved tower composition and the existing editable combat rail.
	battle_view.custom_minimum_size.y = maxf(172.0, minf(450.0, size.y - 572.0))
	var prompt := find_child("DecisionPrompt", true, false) as Label
	prompt.text = RiskData.HINTS[scenario_index] if int(model.s.turns) == 0 else "고출력탄: 발사 시 다음 재장전 +1턴 · 장전 중에는 과열 없음"
	prompt.tooltip_text = "상단 출력 선택은 같은 전투를 처음부터 비교합니다. 손패의 일반·고출력 증폭탄은 직접 회수하고 바꿔 넣어도 됩니다."
	var status := RiskStatus.instantiate()
	var old_label := preview_label
	var host := old_label.get_parent()
	host.add_child(status)
	host.move_child(status, old_label.get_index())
	host.remove_child(old_label)
	old_label.queue_free()
	preview_label = status.get_node("Shot/Value")
	_update_risk_status(status)
	var reload_button := find_child("reload", true, false) as Button
	if reload_button != null and int(model.s.get("reload_heat", 0)) > 0:
		var lethal: bool = risk_prediction.get("reload", {}).get("phase", "") == "lost"
		reload_button.text = ("재장전 %d턴 · 위험" if lethal else "냉각·재장전 %d턴") % model.reload_cost()
		_primary_button(reload_button, DANGER if lethal else Color("ed9167"))
		reload_button.tooltip_text = "기본 %d턴 + 과열 %d턴. 추가 시간에도 적이 행동합니다." % [model.base_reload_cost(), int(model.s.reload_heat)]

func _visual_shot(result: Dictionary) -> void:
	super._visual_shot(result)
	var button := find_child("reload", true, false) as Button
	if button != null: button.text = "다음 재장전 %d턴" % model.reload_cost()

func _visual_impact(result: Dictionary) -> void:
	super._visual_impact(result)
	var grant := int(result.get("boost_granted", 0))
	if grant > 0:
		magazine_view.live_boost_slots = [magazine_view.fired_count, magazine_view.fired_count + 1]
		magazine_view.live_boost_value = grant
		magazine_view.queue_redraw()

func _risk_feedback(event: Dictionary) -> void:
	var status := find_child("RiskStatus", true, false)
	if status == null: return
	var label := status.get_node("Reload/Value") as Label
	match str(event.kind):
		"heat_added":
			status.get_node("Reload/Caption").text = "과열 발생 · 다음 재장전"
			label.text = "%d + %d = %d턴" % [event.base, event.heat, int(event.base) + int(event.heat)]
			label.add_theme_color_override("font_color", Color("ed9167"))
		"reload_turn", "cooling_turn":
			var cooling: bool = event.kind == "cooling_turn"
			status.get_node("Reload/Caption").text = "과열 때문에 추가 행동" if cooling else "재장전 진행 중"
			label.text = "%s · %d/%d턴" % ["냉각" if cooling else "재장전", int(event.turn) + 1, int(event.total)]
			label.add_theme_color_override("font_color", Color("ed9167") if cooling else INK)
			status.get_node("Distance/Caption").text = "현재 적 거리"
		"reload_complete":
			label.text = "접촉 · 재장전 중단" if event.phase == "lost" else ("교전 돌파" if event.phase in ["won", "reward"] else "냉각·재장전 완료")
	if str(event.kind) in ["reload_turn", "cooling_turn", "turn_complete"] and battle_view.reload_tick > 0:
		var distances := PackedStringArray()
		for i in range(battle_view.enemies.size()):
			var enemy: Dictionary = battle_view.enemies[i]
			if int(enemy.hp) > 0: distances.append("%s %dm" % [Forecast.tag(i), roundi(enemy.distance)])
		status.get_node("Distance/Value").text = " · ".join(distances)

func _update_risk_status(status: Control) -> void:
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	var shot_value: Label = status.get_node("Shot/Value")
	var reload_value: Label = status.get_node("Reload/Value")
	var distance_value: Label = status.get_node("Distance/Value")
	var reload_result: Dictionary
	if stack.is_empty() and model.s.phase == "plan":
		risk_prediction = {}
		shot_value.text = "탄환을 선택하세요"
		reload_value.text = "%d턴" % model.reload_cost()
		distance_value.text = "장전 후 예측"
		return
	if stack.is_empty():
		risk_prediction = {"reload": Forecast.reload_now(model.s)}
		shot_value.text = "사격 완료"
		status.get_node("Reload/Caption").text = "지금 재장전"
	else:
		risk_prediction = Forecast.analyze(model.s, true, true)
		var damage := 0
		var kills := 0
		for i in range(model.s.enemies.size()):
			damage += maxi(0, int(model.s.enemies[i].hp) - int(risk_prediction.enemies[i].hp))
			if int(model.s.enemies[i].hp) > 0 and int(risk_prediction.enemies[i].hp) <= 0: kills += 1
		shot_value.text = "%d 피해 · %d 처치" % [damage, kills]
		shot_value.tooltip_text = Forecast.compact_summary(risk_prediction)
	reload_result = risk_prediction.reload
	if not reload_result.required:
		reload_value.text = "필요 없음" if reload_result.phase in ["reward", "won"] else "—"
		distance_value.text = "교전 돌파" if reload_result.phase in ["reward", "won"] else "사격 후 접촉"
		distance_value.add_theme_color_override("font_color", DANGER if reload_result.phase == "lost" else ACCENT)
		return
	reload_value.text = "%d → %d턴 · 과열 +%d" % [reload_result.base, reload_result.cost, reload_result.heat] if int(reload_result.heat) > 0 else "%d턴 · 추가 부담 없음" % reload_result.cost
	reload_value.add_theme_color_override("font_color", Color("ed9167") if int(reload_result.heat) > 0 else INK)
	var distances := PackedStringArray()
	for i in range(reload_result.enemies.size()):
		var enemy: Dictionary = reload_result.enemies[i]
		if int(enemy.hp) > 0: distances.append("%s %dm" % [Forecast.tag(i), int(enemy.distance)])
	distance_value.text = " · ".join(distances)
	if reload_result.phase == "lost": distance_value.text += " · 접촉!"
	elif reload_result.phase in ["won", "reward"]: distance_value.text = "화상으로 교전 돌파"
	distance_value.tooltip_text = distance_value.text + "\n발사 후 곧바로 재장전하는 경우입니다. 재장전 시간에는 화상·적 충전·태세 변화도 진행됩니다."
	distance_value.add_theme_color_override("font_color", DANGER if reload_result.phase == "lost" else INK)
	status.set_meta("reload_prediction", reload_result)

func _reward() -> void:
	_sample_result(true)

func _ending() -> void:
	_sample_result(model.s.phase == "won")

func _sample_result(won: bool) -> void:
	var result := RiskResult.instantiate()
	body.add_child(result)
	result.get_node("Title").text = "교전 돌파" if won else "적이 도달했습니다"
	result.get_node("Title").add_theme_color_override("font_color", ACCENT if won else DANGER)
	var paid := 0
	var hot_shots := 0
	for event in model.s.history:
		if str(event.get("action", "")) == "reload": paid += int(event.detail.get("heat_paid", 0))
		if str(event.get("action", "")) == "fire":
			for shot in event.detail.results: hot_shots += int(shot.get("heat_added", 0))
	result.get_node("Summary").text = "%s · %d턴 · 재장전 %d회\n고출력 %d발 · 재장전에 부과한 과열 +%d턴" % [RiskData.TITLES[scenario_index], model.s.turns, model.s.reloads, hot_shots, paid]
	result.get_node("Details").text = "같은 적·같은 패에서 첫 증폭탄을 바꿔 비교할 수 있습니다.\n실험용 전투이며 캠페인 진행은 저장하지 않습니다."
	result.get_node("Actions/risk_retry").pressed.connect(reset_sample)
	result.get_node("Actions/risk_compare").pressed.connect(func(): select_output(0 if hot_opening else 1))
	result.get_node("Actions/risk_next").pressed.connect(select_case.bind(1 - scenario_index))
