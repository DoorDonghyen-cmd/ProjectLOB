extends "res://redesign/samples/combat_magazine_loop.gd"
const Approach = preload("res://redesign/combat_approach_trial.gd")
const COMPARISON_SAVE := "user://combat_approach_trial_v1.json"
var case_index := 0
var approach_on := true

func _ready() -> void:
	board.character_reference_height = 300.0
	node("Fire").pressed.connect(fire)
	node("Reload").pressed.connect(reload_magazine)
	node("Cool").pressed.connect(cool)
	node("Reset").pressed.connect(func(): mount(false))
	node("Pressure").pressed.connect(next_case)
	node("Other").pressed.connect(toggle_approach)
	node("Help").pressed.connect(func(): show_detail("탄창과 접근 압박", "사격 → 최대 두 발 · 적 1행동\n냉각 → 열 -6 · 적 1행동 · 잔탄 보존\n탄창 교체 → 적 2행동 · 잔탄은 예비 복귀\n과열 → 사격 뒤 강제 냉각 2행동\n접근하는 적과 압력탄의 위험을 함께 확인하세요.\n상단에서 이전 거리와 같은 전투를 비교합니다."))
	node("Bag").pressed.connect(func(): show_detail("이번 전투의 탄약", "탄창 %d발 · 예비 %d발 · 사용 %d발\n미사용 탄은 교체 시 예비 맨 뒤로 돌아갑니다.\n사용한 탄은 이번 전투에서 다시 나오지 않습니다.\n같은 전투를 재시작하면 같은 탄 순서로 시작합니다.\n다음 전투는 독립된 획득 상태의 비교입니다." % [model.s.magazine.size(), model.s.draw.size() + model.s.hand.size(), model.s.discard.size()]))
	node("Parts").pressed.connect(func(): show_detail("리벳 · 돌파 코어", "실제로 획득한 탄약과 파츠를 사용합니다.\n적 처치의 초과 피해가 다음 적에게 이어집니다.\n냉각해도 남은 탄과 탄창 안의 연계는 유지됩니다.\n접근 비교는 적의 체력·장갑을 늘리지 않습니다."))
	node("CloseDetail").pressed.connect(close_detail)
	if resume_saved and restore_comparison():
		resumed = true
		receipt = "이전 비교 플레이를 이어갑니다"
		set_backdrop(); refresh(); return
	mount(false)

func set_backdrop() -> void:
	var floors := {"breach":4, "boss":8, "ambush":3, "sweep":2, "payoff":6}
	board.set_route_background(0, floors[Approach.ROLES[case_index]], 8)

func mount(_boss: bool) -> void:
	var role: String = Approach.ROLES[case_index]
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_approach_%s.json" % role))
	model = Model.new()
	if not model.restore_state(fixture.state): push_error("Approach source cannot restore"); return
	model.s.magazine_trial_version = 1
	if approach_on and not Approach.apply_opening(model.s, role): push_error("Approach opening rejected"); return
	if not model.trial_load_magazine(): push_error("Approach opening magazine rejected"); return
	pressure = role == "boss"
	receipt = "같은 탄창 · 접근 속도와 거리 비교" if role in ["breach", "boss"] else "짧게 정리하는 전투의 호흡은 유지합니다"
	set_backdrop(); close_detail(); persist(); refresh()

func next_case() -> void:
	if busy or overlay_open: return
	case_index = (case_index + 1) % Approach.ROLES.size()
	mount(false)

func toggle_approach() -> void:
	if busy or overlay_open: return
	approach_on = not approach_on
	mount(false)

func persist() -> void:
	var file := FileAccess.open(COMPARISON_SAVE + ".tmp", FileAccess.WRITE)
	if file == null: save_ok = false; return
	file.store_string(JSON.stringify({"format":"lob_approach_trial", "version":1, "case_index":case_index, "approach":approach_on, "combat":model.s}))
	file.close()
	save_ok = DirAccess.rename_absolute(COMPARISON_SAVE + ".tmp", COMPARISON_SAVE) == OK

func restore_comparison() -> bool:
	if not FileAccess.file_exists(COMPARISON_SAVE): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(COMPARISON_SAVE)) != OK: return false
	var data: Variant = parser.data
	var restored = Model.new()
	if not data is Dictionary or data.get("format", "") != "lob_approach_trial" or not restored._whole(data.get("version"), 1, 1) or not restored._whole(data.get("case_index"), 0, Approach.ROLES.size()-1) or not data.get("approach") is bool or not data.get("combat") is Dictionary: return false
	if not restored.restore_state(data.combat) or not Model.MagazineTrial.enabled(restored.s) or restored.capacity() != 6: return false
	var role: String = Approach.ROLES[int(data.case_index)]
	if int(restored.s.get("encounter_id", 0)) != int(Approach.NODES[role]): return false
	if data.approach != (int(restored.s.get("approach_trial_version", 0)) == Approach.VERSION): return false
	case_index = int(data.case_index); approach_on = data.approach
	pressure = role == "boss"; model = restored
	return true

func refresh() -> void:
	super.refresh()
	var role: String = Approach.ROLES[case_index]
	node("Title").text = Approach.TITLES[role]
	node("PreviewLabel").text = "A안 · 접근 압박 적용" if approach_on else "A안 · 이전 거리 비교"
	node("StatusNote").text = "전투 %d / %d · 별도 자동 저장" % [case_index+1, Approach.ROLES.size()] if save_ok else "저장 실패 · 현재 플레이 유지"
	node("Pressure").text = "다음 전투"
	node("Other").text = "이전 거리" if approach_on else "접근 강화"
	node("Help").disabled = false
	node("Weapon").text = "리벳 · " + str(Content.OUTFITS[model.s.outfit].name)
	var active: bool = model.s.phase in ["plan", "ready"]
	var lethal_fire: bool = str(last_prediction.get("phase", "")) == "lost"
	if active and lethal_fire:
		node("Fire").text = "사격 · 피격 위험" if last_prediction.get("loss_reason", "") == "projectile" else "사격 · 접촉 위험"
		if float(last_prediction.get("heat", {}).get("forced_probability", 0.0)) > 0.0:
			node("IntentTitle").text = "과열 냉각 중 압력탄이 도달합니다" if last_prediction.get("loss_reason", "") == "projectile" else "과열 냉각 중 적이 도달합니다"
			node("IntentHint").text = "사격 뒤 강제 냉각 %d행동이 추가됩니다" % int(last_prediction.heat.forced_cost_max)
	node("Fire").modulate = Color("f4ad89") if lethal_fire else Color.WHITE
	if not active:
		node("IntentHint").text = "재시작 또는 다음 전투로 판단을 비교하세요"
	# Show the precise core multiplier instead of rounding 2.15 to 2.
	for i in range(mini(6, last_prediction.get("shots", []).size())):
		var shot: Dictionary = last_prediction.shots[i]
		if int(shot.get("engine_percent",100)) > 100:
			node("Gain%d" % i).text = "코어 ×" + String.num(float(shot.engine_percent)/100.0, 2)

func lock_actions() -> void:
	super.lock_actions()
	node("Help").disabled = true
