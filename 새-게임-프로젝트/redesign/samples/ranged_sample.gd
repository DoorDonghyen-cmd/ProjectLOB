extends "res://redesign/samples/ammo_risk.gd"
const RangedData = preload("res://redesign/samples/ranged_sample_data.gd")
const RangedBattle = preload("res://redesign/samples/ranged_battle_view.tscn")
const Ranged = preload("res://redesign/ranged.gd")

func _ready() -> void:
	hot_opening = false
	super._ready()
	DisplayServer.window_set_title("Last on Board · 원거리·요격 비교 · R 다시 시작")

func _seed_sample() -> void:
	campaign = null
	RangedData.seed_model(model, scenario_index)
	page = "run"
	hand_layout_key = ""
	selected_slot = 0
	show_full_forecast = false
	previous_forecast = {}
	combat_forecast = {}
	last_presentation = {}
	_hand_entries()
	for id in RangedData.initial_plan(hot_opening, scenario_index): model.load_round(id)

func select_case(index: int) -> void:
	if busy: return
	scenario_index = clampi(index, 0, 1)
	hot_opening = false
	reset_sample()

func _new_battle_view() -> Control:
	var view := RangedBattle.instantiate()
	view.reduced_feedback = reduced_feedback or str(preferences.data.motion) == "instant"
	view.feedback_changed.connect(_risk_feedback)
	view.projectile_inspected.connect(_projectile_details)
	return view

func _combat_header(compact: bool) -> void:
	super._combat_header(compact)
	var header := body.get_node("RiskHeader")
	header.get_node("Title").text = "원거리 시험"
	header.get_node("risk_case_0").text = "01 공격 예고"
	header.get_node("risk_case_1").text = "02 탄 요격"

func _combat() -> void:
	super._combat()
	var reload_button := find_child("reload", true, false) as Button
	if reload_button != null:
		var now := Forecast.reload_now(model.s)
		if now.get("loss_reason", "") == "projectile":
			reload_button.text = "재장전 %d턴 · 피격" % model.reload_cost()
			_primary_button(reload_button, DANGER)
			reload_button.tooltip_text = "재장전 도중 압력탄이 도달합니다. 남은 탄으로 요격할 수 있는지 확인하세요."

func _update_risk_status(status: Control) -> void:
	super._update_risk_status(status)
	status.get_node("Distance/Caption").text = "재장전 후 위협"
	if risk_prediction.is_empty(): return
	var interceptions := 0
	for shot in risk_prediction.get("shots", []):
		if shot.get("intercept", false): interceptions += 1
		for secondary in shot.get("secondary", []):
			if secondary.get("intercept", false): interceptions += 1
	if interceptions > 0: status.get_node("Shot/Value").text = "요격 %d · 적 피해 %d" % [interceptions, _enemy_damage(risk_prediction)]
	var outcome: Dictionary = risk_prediction.get("reload", {})
	var hazards: Array = Ranged.active(outcome)
	var label: Label = status.get_node("Distance/Value")
	if not hazards.is_empty():
		label.text = "압력탄 도달" if outcome.get("loss_reason", "") == "projectile" else "압력탄 %d턴 · %dm" % [Ranged.arrival(hazards[0]), int(hazards[0].distance)]
		label.add_theme_color_override("font_color", DANGER if outcome.get("loss_reason", "") == "projectile" else Color("edc47a"))
		label.tooltip_text = "사격 후 곧바로 재장전했을 때의 압력탄입니다.\n" + str(label.text)
	elif outcome.get("phase", "") not in ["won", "reward", "lost"]:
		for enemy in outcome.get("enemies", []):
			if str(enemy.kind) == "spitter" and int(enemy.hp) > 0:
				label.text = Ranged.intent(enemy)
				break

func _enemy_damage(prediction: Dictionary) -> int:
	var result := 0
	for i in range(model.s.enemies.size()): result += maxi(0, int(model.s.enemies[i].hp) - int(prediction.enemies[i].hp))
	return result

func _visual_impact(result: Dictionary) -> void:
	super._visual_impact(result)
	if result.get("intercept", false):
		preview_label.text = "%s · 요격" % AmmoVisual.SHORT[str(result.id)]
		if int(result.get("boost_granted", 0)) > 0: preview_label.text += " → 다음 2발 +%d" % int(result.boost_granted)
		elif not result.get("secondary", []).is_empty(): preview_label.text += " · 전이 −%d" % int(result.secondary[0].damage)

func _risk_feedback(event: Dictionary) -> void:
	super._risk_feedback(event)
	if str(event.kind) not in ["projectile_launch", "projectiles_updated", "turn_complete", "reload_turn", "cooling_turn"]: return
	var status := find_child("RiskStatus", true, false)
	if status == null: return
	var hazards := Ranged.active({"projectiles": event.get("projectiles", battle_view.projectiles)})
	status.get_node("Distance/Caption").text = "현재 원거리 위협"
	if not hazards.is_empty():
		status.get_node("Distance/Value").text = "압력탄 도달" if Ranged.arrival(hazards[0]) == 0 else "압력탄 %d턴 · %dm" % [Ranged.arrival(hazards[0]), int(hazards[0].distance)]
	else:
		status.get_node("Distance/Value").text = "압력탄 없음"
		for enemy in battle_view.enemies:
			if str(enemy.kind) == "spitter" and int(enemy.hp) > 0:
				status.get_node("Distance/Value").text = Ranged.intent(enemy)
				break

func _projectile_details(target_id: int) -> void:
	if busy: return
	var projectile: Dictionary = model.target_entity(target_id)
	if projectile.is_empty(): return
	var column := _dialog("압력탄", true)
	column.name = "ProjectileDetails"
	column.get_meta("dialog").get_ok_button().text = "닫기"
	_label(column, "%dm · 도달 %d턴 · HP 1" % [projectile.distance, Ranged.arrival(projectile)], 24)
	_label(column, "가장 가까운 위협이면 다음 탄이 자동으로 요격합니다. 산개도 확정 요격합니다.\n증폭탄의 강화와 전격탄의 전이는 요격해도 발동합니다.\n한 턴마다 6m 이동합니다. 재장전이 2턴이면 두 번 이동합니다.\n본체를 처치해도 이미 발사된 탄은 남고, 0m에 도달하면 패배합니다.", 19)

func _sample_result(won: bool) -> void:
	super._sample_result(won)
	var result := body.get_node("RiskResult")
	if not won and model.s.get("loss_reason", "") == "projectile": result.get_node("Title").text = "압력탄이 도달했습니다"
	var intercepts := 0
	for event in model.s.history:
		if event.get("action", "") != "fire": continue
		for shot in event.detail.results:
			if shot.get("intercept", false): intercepts += 1
			for secondary in shot.get("secondary", []):
				if secondary.get("intercept", false): intercepts += 1
	result.get_node("Summary").text = "%s · %d턴 · 요격 %d회\n재장전 %d회" % [RangedData.TITLES[scenario_index], model.s.turns, intercepts, model.s.reloads]
	result.get_node("Details").text = "두꺼비의 준비 → 발사 → 요격을 같은 전투 안에서 비교합니다.\n원거리 적 외형은 시험용이며 캠페인 진행은 저장하지 않습니다."
