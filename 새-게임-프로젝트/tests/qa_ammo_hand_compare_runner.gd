extends SceneTree
## 공개 후보만 읽는 고정 정책의 A/B 대조. 사람의 재미나 캠페인 승률을 대리하지 않는다.

const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")
const LoggerScript := preload("res://scripts/core/playtest_logger.gd")
const DECK_IDS := ["marker", "borer", "chain", "impact", "finale", "jammer",
	"guide", "align", "crosscal", "shred", "pierce", "opener"]
const SEEDS := [731042, 424242, 902113, 110926]
const GUNS := ["revolver", "smg", "shotgun"]
const SCENARIOS := ["rusher", "tank", "dodger"]


func _initialize() -> void:
	LoggerScript.enabled = false
	RunManager.infiltration_risk_level = 1
	var encounters: Array = []
	for seed in SEEDS:
		for gun_id in GUNS:
			for enemy_id in SCENARIOS:
				for variant in ["A", "B"]:
					encounters.append(_play(seed, gun_id, enemy_id, variant))
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty():
		output = "user://qa_runtime/ammo_hand_compare"
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("paired_encounters.json"), FileAccess.WRITE)
	if file == null:
		push_error("A/B 원본 보고서 저장 실패")
		quit(1)
		return
	file.store_string(JSON.stringify({"schema": "lob.ammo_hand_policy_probe", "version": 1,
		"encounters": encounters, "policy": "public_gate_then_payoff_v1",
		"scope": "isolated actual-enemy encounters, not campaign or human play"}, "\t"))
	print("AMMO_HAND_COMPARE encounters=%d path=%s" % [encounters.size(), output])
	quit(0)


func _play(seed: int, gun_id: String, enemy_id: String, variant: String) -> Dictionary:
	RandomStreamsScript.begin_run(seed, 17)
	var cm := CombatManager.new()
	cm.configure_ammo_hand_prototype(variant == "B", 7, 2, variant, "policy_comparison")
	var gun: GunData = load("res://resources/guns/%s.tres" % gun_id)
	var basic_id := "cal_12g" if gun_id == "shotgun" else "cal_9mm"
	var basic: BulletData = load("res://resources/bullets/%s.tres" % basic_id)
	var deck: Array[BulletData] = []
	for id in DECK_IDS:
		deck.append(load("res://resources/bullets/%s.tres" % id))
	var enemy_data: EnemyData = load("res://resources/enemies/%s.tres" % enemy_id)
	cm.start_encounter(gun, [enemy_data] as Array[EnemyData], deck, [] as Array[PartData], basic)
	var actions := 0
	while cm.state not in [CombatManager.State.WON, CombatManager.State.LOST] and actions < 60:
		actions += 1
		if cm.state == CombatManager.State.LOADING:
			cm.confirm_loading(_plan(cm))
		elif cm.magazine.is_empty():
			cm.request_reload()
		else:
			cm.fire()
	var report := cm.build_playtest_report()
	report["comparison"] = {"seed": seed, "scenario": enemy_id, "gun_id": gun_id,
		"parts": [], "deck": DECK_IDS, "policy": "public_gate_then_payoff_v1"}
	report["action_limit_reached"] = actions >= 60
	cm.free()
	return report


func _plan(cm: CombatManager) -> Array[BulletData]:
	var available := cm.available_tactical_bullets().duplicate()
	# 공개 ID로 동점을 풀어 A안 선택을 패 표시 순서 때문에 바꾸지 않는다.
	available.sort_custom(func(a: BulletData, b: BulletData):
		return LoggerScript.resource_id(a) < LoggerScript.resource_id(b))
	var firing: Array[BulletData] = []
	var slots := cm._max_load_capacity()
	var basic_left := cm.basic_supply_current
	var needs_accuracy := not bool(cm.preview_candidate_bullet(cm.basic_supply_bullet).get("acc_ok", false))
	var needs_penetration := not bool(cm.preview_candidate_bullet(cm.basic_supply_bullet).get("pen_ok", false))
	for index in range(slots):
		var pick: BulletData = null
		var best := -INF
		for candidate in available:
			var id := LoggerScript.resource_id(candidate)
			var preview := cm.preview_candidate_bullet(candidate)
			var score := 1.0
			if not bool(preview.get("acc_ok", false)):
				score -= 20.0
			if not bool(preview.get("pen_ok", false)):
				score -= 10.0
			if index == 0 and needs_accuracy and id in ["marker", "jammer", "guide"]:
				score += 30.0
			if index == 0 and needs_penetration and id in ["borer", "shred", "align"]:
				score += 30.0
			if id == "chain" and index < slots - 1:
				score += 8.0
			if id == "finale":
				score += 15.0 if index == slots - 1 else -5.0
			if id == "opener":
				score += 6.0 if index == 0 else -3.0
			if index > 0 and LoggerScript.resource_id(firing[-1]) in ["marker", "borer", "chain"]:
				score -= 15.0
			if score > best:
				best = score
				pick = candidate
		if basic_left > 0 and best < 2.0:
			pick = cm.basic_supply_bullet
			basic_left -= 1
		elif pick != null:
			available.erase(pick)
		if pick == null:
			break
		firing.append(pick)
	firing.reverse()
	return firing
