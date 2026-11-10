extends "res://redesign/samples/combat_ui_stage1.gd"
## Playable, isolated A-layout comparison. It never reads campaign.json.
const SAVE_PATH := "user://combat_magazine_trial_v1.json"
@export var resume_saved := true
var receipt := ""
var save_ok := true
var resumed := false

func _ready() -> void:
	board.character_reference_height = 300.0
	node("Fire").pressed.connect(fire)
	node("Reload").pressed.connect(reload_magazine)
	node("Cool").pressed.connect(cool)
	node("Reset").pressed.connect(func(): mount(pressure))
	node("Pressure").pressed.connect(func(): mount(not pressure))
	node("Other").pressed.connect(func(): show_detail("탄창 비교 플레이", "다음 두 발 사격 → 적 1행동\n냉각 → 열 -%d · 적 1행동 · 잔탄 유지\n탄창 교체 → 적 2행동 · 미사용 탄은 예비 뒤로\n과열 → 강제 냉각 2행동 · 잔탄 유지\n사용한 탄은 이번 전투에 돌아오지 않습니다.\n기존 등반과 분리해 자동 저장합니다." % Model.MagazineTrial.cooling_amount(Content.reload_cooling(model.s))))
	node("Bag").pressed.connect(func(): show_detail("이번 전투의 탄약", "탄창 %d발 · 예비 %d발 · 사용 %d발\n보유 덱에서 섞인 순서대로 탄창을 채웁니다.\n첫 발/마지막 발 고정과 차지하는 칸을 지킵니다.\n넣지 못한 탄은 예비에 남습니다.\n미사용 탄을 버리지 않지만 교체 중 적이 접근합니다." % [model.s.magazine.size(), model.s.draw.size() + model.s.hand.size(), model.s.discard.size()]))
	node("Parts").pressed.connect(func(): show_detail("돌파 코어 · 실제 획득 상태", "적 처치의 초과 피해가 다음 적에게 이어집니다.\n마지막 탄 보너스는 탄창의 실제 끝에서 발동합니다.\n두 발마다 멈춰도 새 탄창으로 계산하지 않습니다.\n리벳+돌파 코어 6칸을 먼저 비교합니다."))
	node("CloseDetail").pressed.connect(close_detail)
	if resume_saved and FileAccess.file_exists(SAVE_PATH):
		var restored = Model.new()
		if restored.restore_run(SAVE_PATH) and Model.MagazineTrial.enabled(restored.s) and int(restored.s.get("encounter_id", 0)) in [401, 802]:
			model = restored
			pressure = int(model.s.encounter_id) == 802
			resumed = true
			receipt = "이전 비교 플레이를 이어갑니다"
			board.set_route_background(0, 8 if pressure else 4, 8)
			refresh()
			return
	mount(false)

func mount(boss: bool) -> void:
	pressure = boss
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_magazine_loop_%s.json" % ("boss" if boss else "normal")))
	model = Model.new()
	if not model.restore_state(fixture.state): push_error("Trial checkpoint cannot restore"); return
	model.s.magazine_trial_version = Model.MagazineTrial.VERSION
	if not model.trial_load_magazine(): push_error("Trial opening cannot load"); return
	receipt = "보유 덱에서 탄창을 채웠습니다 · 선택 중에는 적이 움직이지 않습니다"
	board.set_route_background(0, 8 if boss else 4, 8)
	close_detail()
	persist()
	refresh()

func persist() -> void:
	save_ok = model.save_run(SAVE_PATH) == OK

func action_preview(action: String) -> Dictionary:
	var copy = Model.new()
	copy.s = Model.simulation_state(model.s)
	var success := copy.cool_magazine() if action == "cool" else copy.emergency_resupply() if copy.can_emergency_resupply() else copy.reload_magazine()
	return {"valid": success, "lethal": success and copy.s.phase == "lost", "reason": copy.s.get("loss_reason", ""), "turns": int(copy.s.turns) - int(model.s.turns)}

func refresh() -> void:
	for id in ["Reset", "Pressure", "Other", "Bag", "Parts"]: node(id).disabled = false
	var active: bool = model.s.phase in ["plan", "ready"]
	var stack: Array = model.s.magazine
	last_prediction = Forecast.analyze(model.s, true) if active and not stack.is_empty() else {}
	var swap := action_preview("swap") if active else {}
	var cooling := action_preview("cool") if active else {}
	var lethal_swap := bool(swap.get("lethal", false))
	var lethal_cool := bool(cooling.get("lethal", false))
	var forced := int(last_prediction.get("heat", {}).get("forced_cost_max", 0))
	# The heat forecast names below are shared with the existing exact resolver.
	var overheats: bool = float(last_prediction.get("heat", {}).get("forced_probability", 0.0)) > 0.0
	board.sync(model.s, {})
	board.salvo_receipt = {}; board.receipt_is_previous = false; board.queue_redraw()
	node("Title").text = "첫 관문 · 보스" if pressure else "교대 방패 진지"
	node("PreviewLabel").text = "A안 · 6칸 탄창 플레이"
	node("StatusNote").text = "비교 플레이 · 자동 저장" if save_ok else "저장 실패 · 현재 플레이는 유지됩니다"
	node("Pressure").text = "일반전" if pressure else "보스전"
	node("Other").text = "규칙"
	node("Reset").text = "재시작"
	node("HeatLabel").text = "발열  %d / %d" % [model.s.heat, Content.heat_limit(model.s)]
	node("HeatBar").value = model.s.heat
	node("HeatBar").max_value = Content.heat_limit(model.s)
	node("MagazineTitle").text = "남은 탄창  %d발 / %d칸" % [stack.size(), model.capacity()]
	node("Bag").text = "남은 %d발" % Reserve.remaining(model.s)
	node("Parts").text = "파츠"
	node("Fire").disabled = not active or stack.is_empty()
	node("Fire").text = "%d발 사격 · 적 1행동" % mini(2, stack.size()) if not stack.is_empty() else "빈 탄창"
	if str(last_prediction.get("phase", "")) in ["won", "reward"]: node("Fire").text = "%d발 사격 · 마무리" % last_prediction.shots.size()
	if overheats: node("Fire").text = "사격 · 과열 주의"
	var emergency: bool = model.can_emergency_resupply()
	node("Reload").disabled = not active or (not emergency and (model.s.hand + model.s.draw).is_empty())
	node("Reload").text = "비상 보급 · 적 %d행동" % model.emergency_cost() if emergency else "탄창 교체 · 적 %d행동" % model.reload_cost()
	if lethal_swap: node("Reload").text = "교체 시 피격 위험" if swap.get("reason", "") == "projectile" else "교체 시 접촉 위험"
	node("Cool").disabled = not active or int(model.s.heat) <= 0
	node("Cool").text = ("냉각 · 피격 위험" if cooling.get("reason", "") == "projectile" else "냉각 · 접촉 위험") if lethal_cool else "냉각 · 적 1행동"
	for pair in [["Reload", lethal_swap], ["Cool", lethal_cool]]: node(pair[0]).modulate = Color("f4ad89") if pair[1] else Color.WHITE
	var title := "남은 한 발을 쏠 차례입니다" if stack.size() == 1 else "다음 두 발을 쏠 차례입니다"
	var hint := "냉각은 잔탄 유지 · 교체는 미사용 탄을 예비 뒤로"
	if overheats:
		title = "계속 쏘면 과열됩니다"
		hint = "강제 냉각 중 적 %d행동 · 남은 탄은 보존됩니다" % (forced if forced > 0 else model.base_reload_cost() + 1)
	if lethal_swap or lethal_cool:
		var projectile_danger: bool = (lethal_swap and swap.get("reason", "") == "projectile") or (lethal_cool and cooling.get("reason", "") == "projectile")
		title = "압력탄이 곧 도달합니다" if projectile_danger else "적이 눈앞까지 다가왔습니다"
		hint = "사격으로 요격하거나 행동별 위험을 확인하세요" if projectile_danger else "행동 전 접촉 위험을 확인하세요"
	if str(last_prediction.get("phase", "")) == "lost":
		title = "사격 후에도 피격 위험이 있습니다" if last_prediction.get("loss_reason", "") == "projectile" else "사격 후에도 접촉 위험이 있습니다"
		hint = "사격 결과와 도달하는 위협을 확인하세요"
	if not active:
		title = "길을 열었습니다" if model.s.phase in ["reward", "won"] else "압력탄에 맞았습니다" if model.s.get("loss_reason", "") == "projectile" else "적이 도달했습니다"
		hint = "재시작으로 다른 판단을 비교하거나 다른 전투를 선택하세요"
	node("IntentTitle").text = title
	node("IntentHint").text = hint
	var shots: Array = last_prediction.get("shots", [])
	node("Prediction").text = "다음 %d발 예상 · 최고 열 %d / %d" % [shots.size(), int(last_prediction.get("heat", {}).get("peak_max", model.s.heat)), Content.heat_limit(model.s)] if active and not shots.is_empty() else "새 탄창을 교체하세요" if active else "비교 전투 종료 · 재시작 가능"
	node("CapacityNote").text = receipt
	for i in range(6):
		var occupied := i < stack.size()
		var firing := i < shots.size()
		node("Round%d" % i).modulate.a = 1.0 if firing else 0.8 if occupied else 0.38
		node("Icon%d" % i).visible = occupied
		node("Name%d" % i).text = Content.AMMO[stack[i]].name if occupied else "빈칸"
		node("Role%d" % i).text = "이번 사격" if firing else "다음 순서" if occupied else ""
		node("Value%d" % i).text = "—"
		node("Cost%d" % i).text = "열 " + Content.heat_label(str(stack[i]), model.s) if occupied else ""
		node("Gain%d" % i).text = "탄창에 보존" if occupied and not firing else ""
		if occupied: node("Icon%d" % i).item_id = str(stack[i])
		if not firing: continue
		var shot: Dictionary = shots[i]
		var damage := int(shot.get("damage", 0))
		for secondary in shot.get("secondary", []): damage += int(secondary.get("damage", 0))
		node("Role%d" % i).text = "총 피해 예상"
		node("Value%d" % i).text = str(damage)
		if shot.has("boost_granted") and int(shot.boost_granted) > 0:
			node("Role%d" % i).text = "다음 공격 강화"
			node("Value%d" % i).text = "+%d" % int(shot.boost_granted)
		node("Gain%d" % i).text = "코어 ×%.0f" % (float(shot.get("engine_percent", 100)) / 100.0) if int(shot.get("engine_percent", 100)) > 100 else ""

func fire() -> void:
	if busy or overlay_open: return
	var before: Dictionary = model.s.duplicate(true)
	if not model.fire(): return
	var detail: Dictionary = model.s.history.back().detail
	var cooling: Dictionary = detail.get("forced_cooling", {})
	receipt = "%d발 발사 · 남은 %d발 유지" % [detail.results.size(), model.s.magazine.size()]
	if not cooling.is_empty(): receipt += " · 과열 냉각으로 적 %d행동 추가" % cooling.elapsed
	persist()
	var firing: Dictionary = model.s.duplicate(true)
	for key in ["enemies", "projectiles", "reinforcements"]: firing[key] = detail.get("firing_" + key, model.s[key])
	if not cooling.is_empty():
		# This snapshot ends at the shot's enemy action, before forced cooling.
		# Final turns/heat here would consume the cooling ticks in the first
		# playback and leave the second playback with no movement to animate.
		firing.phase = "ready"
		firing.turns = int(model.s.turns) - int(cooling.elapsed)
		firing.heat = int(cooling.heat_before)
	lock_actions()
	await board.play_action(before, firing, detail.results, detail.advance_events, false, detail.deployments)
	if not cooling.is_empty():
		board.cooling_cost = int(cooling.cost)
		await board.play_action(firing, model.s, [], cooling.advance_events, true, cooling.deployments)
		board.cooling_cost = 0
	busy = false; refresh()

func cool() -> void:
	if busy or overlay_open: return
	var before: Dictionary = model.s.duplicate(true)
	if not model.cool_magazine(): return
	var detail: Dictionary = model.s.history.back().detail
	receipt = "냉각 %d→%d · 적 %d행동 · 남은 %d발 유지" % [detail.heat_before, detail.heat_after, detail.elapsed, model.s.magazine.size()]
	persist(); lock_actions()
	board.cooling_cost = int(detail.cost)
	await board.play_action(before, model.s, [], detail.advance_events, true, detail.deployments)
	board.cooling_cost = 0
	busy = false; refresh()

func reload_magazine() -> void:
	if busy or overlay_open: return
	var before: Dictionary = model.s.duplicate(true)
	var returned: int = model.s.magazine.size()
	var emergency: bool = model.can_emergency_resupply()
	if not (model.emergency_resupply() if emergency else model.reload_magazine()): return
	receipt = "비상 보급 · 적 %d행동" % model.last_reload_detail.cost if emergency else "탄창 교체 · 미사용 %d발 예비 복귀 · 새 탄창 %d발" % [returned, model.s.magazine.size()]
	persist(); lock_actions()
	await board.play_action(before, model.s, [], model.last_reload_detail.advance_events, true, model.last_reload_detail.deployments)
	busy = false; refresh()

func lock_actions() -> void:
	busy = true
	for id in ["Fire", "Reload", "Cool", "Reset", "Pressure", "Other", "Bag", "Parts"]: node(id).disabled = true
