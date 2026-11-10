extends "res://redesign/samples/combat_magazine_loop.gd"
const Approach = preload("res://redesign/combat_approach_trial.gd")
const COMPARISON_SAVE := "user://combat_weapon_magazine_v1.json"
var case_index := 0
const GUNS := ["single", "burst", "scatter", "heavy", "amplifier"]
const ROLES := ["breach", "boss", "sweep", "payoff"]
var gun_index := 0
var eject_mode := false
var eject_selected: Array[int] = []
var eject_preview: Dictionary = {}
var slot_count := 9

func _ready() -> void:
	board.character_reference_height = 300.0
	node("Fire").pressed.connect(fire)
	node("Reload").pressed.connect(reload_magazine)
	node("Cool").pressed.connect(cool)
	node("EjectToggle").pressed.connect(toggle_ejection)
	node("EjectApply").pressed.connect(apply_ejection)
	for i in range(slot_count): node("Select%d" % i).pressed.connect(select_ejection.bind(i))
	node("Reset").pressed.connect(func(): mount(false))
	node("Pressure").pressed.connect(next_case)
	node("Other").pressed.connect(next_weapon)
	node("Help").pressed.connect(func(): show_detail("총기별 탄창 운용", weapon_hint()+"\n냉각 → 열 -%d · 적 1행동 · 잔탄 보존\n탄창 교체 → 적 %d행동 · 잔탄은 예비로\n과열 냉각 → 적 %d행동 추가%s\n사용한 탄은 이번 전투에서 돌아오지 않습니다.\n빼내기 → 중간 탄도 탄창당2발까지 선택\n빼낸 탄은 이번 전투 소모 · 적 행동/열 변화 없음\n빈자리 보충 없음 · 다음 전투에 탄 복구\n상단 버튼으로 총기와 전투를 바꿔 비교합니다." % [Model.MagazineTrial.cooling_amount(Content.reload_cooling(model.s)), model.reload_cost(), model.base_reload_cost()+1, " · 강행 시 +1" if model.s.gun == "heavy" else ""]))
	node("Bag").pressed.connect(func(): show_detail("이번 전투의 탄약", "탄창 %d발 · 예비 %d발 · 사용 %d발\n보유 덱에서 섞인 순서대로 채웁니다.\n미사용 탄은 교체 시 예비 맨 뒤로 돌아갑니다.\n첫 발/마지막 발 고정과 차지하는 칸을 지킵니다.\n다음 전투는 독립된 획득 상태의 비교입니다." % [model.s.magazine.size(), model.s.draw.size()+model.s.hand.size(), model.s.discard.size()]))
	node("Parts").pressed.connect(show_parts)
	node("CloseDetail").pressed.connect(close_detail)
	node("DetailUp").pressed.connect(func(): node("DetailScroll").scroll_vertical -= 160)
	node("DetailDown").pressed.connect(func(): node("DetailScroll").scroll_vertical += 160)
	if resume_saved and restore_comparison():
		resumed = true
		receipt = "이전 비교 플레이를 이어갑니다"
		set_backdrop(); refresh(); return
	mount(false)

func set_backdrop() -> void:
	var floors := {"breach":4, "boss":8, "ambush":3, "sweep":2, "payoff":6}
	board.set_route_background(0, floors[ROLES[case_index]], 8)

func mount(_boss: bool) -> void:
	eject_mode=false; eject_selected.clear(); eject_preview={}
	var role: String = ROLES[case_index]
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_weapon_%s_%s.json" % [GUNS[gun_index],role]))
	model = Model.new()
	if not model.restore_state(fixture.state): push_error("Approach source cannot restore"); return
	model.s.magazine_trial_version = 1; model.s.weapon_magazine_version = 1
	if not Approach.apply_opening(model.s, role): push_error("Approach opening rejected"); return
	if not model.trial_load_magazine(): push_error("Approach opening magazine rejected"); return
	pressure = role == "boss"
	receipt = "전체 탄창 장전 · " + weapon_hint()
	set_backdrop(); close_detail(); persist(); refresh()

func next_case() -> void:
	if busy or overlay_open or eject_mode: return
	case_index = (case_index + 1) % ROLES.size()
	mount(false)

func next_weapon() -> void:
	if busy or overlay_open or eject_mode: return
	gun_index = (gun_index + 1) % GUNS.size()
	mount(false)

func persist() -> void:
	var file := FileAccess.open(COMPARISON_SAVE + ".tmp", FileAccess.WRITE)
	if file == null: save_ok = false; return
	file.store_string(JSON.stringify({"format":"lob_weapon_magazine", "version":1, "case_index":case_index, "gun_index":gun_index, "combat":model.s}))
	file.close()
	save_ok = DirAccess.rename_absolute(COMPARISON_SAVE + ".tmp", COMPARISON_SAVE) == OK

func restore_comparison() -> bool:
	if not FileAccess.file_exists(COMPARISON_SAVE): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(COMPARISON_SAVE)) != OK: return false
	var data: Variant = parser.data
	var restored = Model.new()
	if not data is Dictionary or data.get("format", "") != "lob_weapon_magazine" or not restored._whole(data.get("version"), 1, 1) or not restored._whole(data.get("case_index"), 0, ROLES.size()-1) or not restored._whole(data.get("gun_index"), 0, GUNS.size()-1) or not data.get("combat") is Dictionary: return false
	if not restored.restore_state(data.combat) or not Model.MagazineTrial.weapons_enabled(restored.s) or restored.capacity() > 9: return false
	var role: String = ROLES[int(data.case_index)]
	if int(restored.s.get("encounter_id", 0)) != int(Approach.NODES[role]): return false
	if int(restored.s.get("approach_trial_version",0)) != Approach.VERSION or restored.s.gun != GUNS[int(data.gun_index)]: return false
	case_index = int(data.case_index); gun_index = int(data.gun_index)
	pressure = role == "boss"; model = restored
	eject_mode=false; eject_selected.clear(); eject_preview={}
	return true

func refresh() -> void:
	for id in ["Reset", "Pressure", "Other", "Bag", "Parts"]: node(id).disabled = false
	var active: bool = model.s.phase in ["plan", "ready"]
	var stack: Array = model.s.magazine
	eject_preview = {}
	var prediction_state: Dictionary = model.s
	if eject_mode and not eject_selected.is_empty():
		var projected = Model.new(); projected.s = Model.simulation_state(model.s)
		if projected.eject_magazine_rounds(eject_selected):
			eject_preview = projected.s; prediction_state = eject_preview
	last_prediction = Forecast.analyze(prediction_state, true) if prediction_state.phase == "ready" and not prediction_state.magazine.is_empty() else {}
	var swap := action_preview("swap") if active else {}
	var cooling := action_preview("cool") if active else {}
	var lethal_swap := bool(swap.get("lethal", false))
	var lethal_cool := bool(cooling.get("lethal", false))
	var forced := int(last_prediction.get("heat", {}).get("forced_cost_max", 0))
	# The heat forecast names below are shared with the existing exact resolver.
	var overheats: bool = float(last_prediction.get("heat", {}).get("forced_probability", 0.0)) > 0.0
	# Action animation disables inspection. Restore it for the next decision and
	# pass the same public forecast used by the heat/fire controls (including
	# ejection previews and random-target ranges, never a separate RNG roll).
	board.inspection_enabled = active and not busy
	board.sync(model.s, last_prediction)
	board.salvo_receipt = {}; board.receipt_is_previous = false; board.queue_redraw()
	node("Title").text = "첫 관문 · 보스" if pressure else "교대 방패 진지"
	node("PreviewLabel").text = "%s · %d칸" % [Content.GUNS[model.s.gun].name, model.capacity()]
	node("StatusNote").text = "비교 플레이 · 자동 저장" if save_ok else "저장 실패 · 현재 플레이는 유지됩니다"
	node("Pressure").text = "일반전" if pressure else "다음 전투"
	node("Other").text = "다음 총기"
	node("Reset").text = "재시작"
	node("HeatLabel").text = "발열  %d / %d" % [model.s.heat, Content.heat_limit(model.s)]
	node("HeatBar").value = model.s.heat
	node("HeatBar").max_value = Content.heat_limit(model.s)
	node("MagazineTitle").text = "남은 탄창  %d발 / %d칸" % [stack.size(), model.capacity()]
	node("Bag").text = "남은 %d발" % Reserve.remaining(model.s)
	node("Parts").text = "파츠"
	node("Fire").disabled = not active or stack.is_empty()
	node("Fire").text = "%d발 사격 · 적 1행동" % mini(Model.MagazineTrial.pulse(model.s), stack.size()) if not stack.is_empty() else "빈 탄창"
	if str(last_prediction.get("phase", "")) in ["won", "reward"]: node("Fire").text = "%d발 사격 · 마무리" % last_prediction.shots.size()
	if overheats: node("Fire").text = "사격 · 과열 주의"
	var emergency: bool = model.can_emergency_resupply()
	node("Reload").disabled = not active or (not emergency and (model.s.hand + model.s.draw).is_empty())
	node("Reload").text = "비상 보급 · 적 %d행동" % model.emergency_cost() if emergency else "탄창 교체 · 적 %d행동" % model.reload_cost()
	if lethal_swap: node("Reload").text = "교체 시 피격 위험" if swap.get("reason", "") == "projectile" else "교체 시 접촉 위험"
	node("Cool").disabled = not active or int(model.s.heat) <= 0
	node("Cool").text = ("냉각 · 피격 위험" if cooling.get("reason", "") == "projectile" else "냉각 · 접촉 위험") if lethal_cool else "냉각 · 적 1행동"
	for pair in [["Reload", lethal_swap], ["Cool", lethal_cool]]: node(pair[0]).modulate = Color("f4ad89") if pair[1] else Color.WHITE
	var title := weapon_hint()
	var hint := "냉각은 잔탄 유지 · 교체는 예비로 복귀"
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
	for i in range(slot_count):
		node("Round%d" % i).visible = i < model.capacity()
		var occupied := i < stack.size()
		var removed := eject_mode and eject_selected.has(i)
		var predicted_index: int = i - eject_selected.filter(func(index): return index < i).size() if eject_mode else i
		var firing := not removed and predicted_index < shots.size() and float(shots[predicted_index].get("used_probability",1.0)) > 0
		var selector: Button = node("Select%d" % i)
		selector.visible = eject_mode and occupied
		selector.disabled = not occupied or (not removed and eject_selected.size() >= model.ejection_remaining())
		selector.set_pressed_no_signal(removed)
		node("Round%d" % i).modulate.a = 1.0 if firing else 0.8 if occupied else 0.38
		node("Icon%d" % i).visible = occupied
		node("Name%d" % i).text = Content.AMMO[stack[i]].name if occupied else "빈칸"
		node("Role%d" % i).text = "이번 사격" if firing else "다음 순서" if occupied else ""
		node("Value%d" % i).text = "—"
		node("Cost%d" % i).text = "열 " + Content.heat_label(str(stack[i]), model.s) if occupied else ""
		node("Gain%d" % i).text = "탄창에 보존" if occupied and not firing else ""
		if occupied: node("Icon%d" % i).item_id = str(stack[i])
		if removed:
			node("Round%d" % i).modulate.a = 1.0
			node("Role%d" % i).text = "빼낼 탄"
			node("Value%d" % i).text = "제외"
			node("Cost%d" % i).text = "발사 안 함"
			node("Gain%d" % i).text = "이번 전투 소모"
		if not firing: continue
		var shot: Dictionary = shots[predicted_index]
		var damage := int(shot.get("damage", 0))
		for secondary in shot.get("secondary", []): damage += int(secondary.get("damage", 0))
		node("Role%d" % i).text = "총 피해"
		node("Value%d" % i).text = str(damage)
		if shot.has("boost_granted") and int(shot.boost_granted) > 0:
			node("Role%d" % i).text = "공격 강화"
			node("Value%d" % i).text = "+%d" % int(shot.boost_granted)
		node("Gain%d" % i).text = "×" + String.num(float(shot.get("engine_percent",100))/100.0,2) if int(shot.get("engine_percent", 100)) > 100 else ""

		if shot.get("random", false):
			node("Role%d" % i).text = "직접 피해"
			node("Value%d" % i).text = "%d~%d" % [shot.damage_min,shot.damage_max]
			node("Gain%d" % i).text = "무작위 표적"
		if not Content.is_attack(str(stack[i])):
			var effect: Dictionary = Content.primary_stat(str(stack[i]), model.s)
			node("Role%d" % i).text = effect.label
			node("Value%d" % i).text = effect.value
			node("Gain%d" % i).text = "지원 효과"
			if str(Content.AMMO[stack[i]].get("effect","")) == "cool" and shot.has("cooled"):
				node("Value%d" % i).text = "−%d" % int(shot.cooled) if int(shot.cooled)>0 else "0"
				node("Gain%d" % i).text = "열이 없습니다" if int(shot.cooled) == 0 else "실제 열 감소"
	# Scoped prediction never reveals the hidden random target stream.
	node("Title").text = Approach.TITLES[ROLES[case_index]]
	node("Pressure").text = "다음 전투"
	node("Help").disabled = false
	node("Weapon").text = Content.GUNS[model.s.gun].name + " · " + Content.OUTFITS[model.s.outfit].name
	node("StatusNote").text = "전투 %d / 4 · 별도 저장" % (case_index+1) if save_ok else "저장 실패 · 현재 플레이 유지"
	if model.s.gun == "amplifier" and active and not stack.is_empty(): node("Fire").text = "단발 · 처치 시 연속"
	var lost_chance: float = float(last_prediction.get("lost_probability", 1.0 if last_prediction.get("phase", "") == "lost" else 0.0))
	node("Fire").modulate = Color("f4ad89") if lost_chance > 0 else Color.WHITE
	if active and last_prediction.get("random",false):
		node("Prediction").text = "다음 사격 · 표적 무작위 · 승리 %s / 패배 %s" % [chance_text(float(last_prediction.win_probability)), chance_text(lost_chance)]
		if overheats:
			node("IntentTitle").text = "사격 결과에 따라 과열될 수 있습니다"
			node("IntentHint").text = "강제 냉각 확률 %s · 적 최대 %d행동 추가" % [chance_text(float(last_prediction.heat.forced_probability)), forced]
	if active and lost_chance > 0:
		node("Fire").text = "사격 · 패배 " + chance_text(lost_chance)
		node("IntentTitle").text = "사격 후에도 도달 위험이 있습니다"
	if active and model.s.gun == "heavy" and last_prediction.get("shots",[]).any(func(shot): return shot.get("overdrive", false)):
		node("Fire").text = "강행 사격 · 과열 주의" if lost_chance == 0 else node("Fire").text
	if active and stack.is_empty(): node("IntentTitle").text = "빈 탄창을 교체하세요"

	if not active and model.s.get("loss_reason","")=="ammo":node("IntentTitle").text="탄약이 소진되었습니다"
	refresh_ejection(active)

func lock_actions() -> void:
	super.lock_actions()
	node("Help").disabled = true
	node("EjectToggle").disabled = true
	node("EjectApply").disabled = true
	for i in range(slot_count): node("Select%d" % i).disabled = true

func weapon_hint() -> String:
	if Model.WeaponRoles.enabled(model.s): return Model.WeaponRoles.TEXT[Model.WeaponRoles.kind(model.s)]
	var normal: int=Model.MagazineTrial.WEAPON_PULSES[model.s.gun]+Model.Roles.pulse_bonus(model.s)
	return ("최대 %d발 · "%normal if model.s.gun!="amplifier" else "")+{"single":"공격탄 피해 +1", "burst":"같은 적 3회 적중 시 +4", "scatter":"탄마다 무작위 표적", "heavy":"과열 뒤 1발 강행", "amplifier":"단발 효과 2배 · 처치하면 연속"}[model.s.gun]

func show_parts() -> void:
	var lines: PackedStringArray = [weapon_hint()]
	for id in Content.equipped_parts(model.s):
		lines.append(str(Content.PARTS[id].name))
		lines.append(str(Content.part_spec(id,model.s).text))
	lines.append("냉각해도 탄창 안의 연계는 유지됩니다.")
	show_detail("총기와 장착 파츠", "\n".join(lines))

func chance_text(probability: float) -> String:
	if probability <= 0.0: return "0%"
	if probability >= 0.999999: return "100%"
	if probability < 0.01: return "<1%"
	if probability > 0.99: return ">99%"
	return "%.0f%%" % (100*probability)

func show_detail(title: String, body: String) -> void:
	super.show_detail(title,body)
	node("DetailScroll").scroll_vertical = 0

func toggle_ejection() -> void:
	if busy or overlay_open: return
	if not eject_mode and (model.s.phase != "ready" or model.s.magazine.is_empty() or model.ejection_remaining() <= 0): return
	eject_mode = not eject_mode
	eject_selected.clear()
	refresh()

func select_ejection(index: int) -> void:
	if busy or overlay_open or not eject_mode or index < 0 or index >= model.s.magazine.size(): return
	if eject_selected.has(index): eject_selected.erase(index)
	elif eject_selected.size() < model.ejection_remaining(): eject_selected.append(index)
	refresh()

func apply_ejection() -> void:
	if busy or overlay_open or not eject_mode: return
	var count := eject_selected.size()
	if not model.eject_magazine_rounds(eject_selected): return
	eject_mode = false; eject_selected.clear()
	receipt = "%d발 빼냄 · 이번 전투 소모 · 남은 %d발 · 추가로 %d발 가능" % [count,model.s.magazine.size(),model.ejection_remaining()]
	persist(); refresh()

func refresh_ejection(active: bool) -> void:
	node("EjectToggle").disabled = not active or (not eject_mode and (model.ejection_remaining() <= 0 or model.s.magazine.is_empty()))
	node("EjectToggle").text = "빼내기 취소" if eject_mode else "탄 빼내기 · %d발" % model.ejection_remaining()
	node("EjectApply").visible = eject_mode
	node("Fire").visible = not eject_mode
	node("SequenceHint").text = "선택 %d / %d발" % [eject_selected.size(),model.ejection_remaining()] if eject_mode else "왼쪽부터 발사"
	if not eject_mode: return
	for id in ["Fire","Reload","Cool","Reset","Pressure","Other"]: node(id).disabled=true
	node("EjectApply").disabled = eject_selected.is_empty()
	node("EjectApply").text = "%d발 빼내기 · 소모" % eject_selected.size()
	node("IntentTitle").text = "이번 전투에서 포기할 탄을 고르세요"
	node("IntentHint").text = "적 행동 없음 · 발열과 연속 사격 유지"
	node("CapacityNote").text = "탄창당 최대2발 · 빈자리 보충 없음 · 다음 전투에 복구"
	if eject_selected.is_empty():
		node("Prediction").text = "빼낼 탄을 누르면 남은 탄의 다음 사격을 미리 봅니다"
	elif eject_preview.get("phase","") == "lost":
		node("Prediction").text = "빼내면 탄약 소진으로 패배합니다"
		node("EjectApply").text = "빼내기 · 탄약 소진"
	elif eject_preview.get("magazine",[]).is_empty():
		node("Prediction").text = "빼낸 뒤 빈 탄창 · 교체 또는 비상 보급 필요"
	elif last_prediction.get("random",false):
		node("Prediction").text = "빼낸 뒤 사격 · 승리 %s / 패배 %s" % [chance_text(float(last_prediction.win_probability)),chance_text(float(last_prediction.lost_probability))]
	else:
		node("Prediction").text = "빼낸 뒤 %d발 사격 · 최고 열 %d / %d%s" % [last_prediction.get("shots",[]).size(),int(last_prediction.get("heat",{}).get("peak_max",model.s.heat)),Content.heat_limit(model.s)," · 도달 위험" if last_prediction.get("phase","")=="lost" else ""]

func fire() -> void:
	if eject_mode: return
	await super.fire()

func cool() -> void:
	if eject_mode: return
	await super.cool()

func reload_magazine() -> void:
	if eject_mode: return
	await super.reload_magazine()
