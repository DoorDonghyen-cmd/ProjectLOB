extends RefCounted
## 공개 탄환 패 A/B 프로토타입 — 기존 규칙 보존, seeded 공개 패, 리로드 보충, LIFO 회귀.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")

const G_REVOLVER := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/cal_9mm.tres"
const BULLET_IDS := [
	"marker", "borer", "chain", "impact", "finale", "jammer",
	"guide", "align", "crosscal", "shred", "pierce", "opener",
]


static func _deck() -> Array[BulletData]:
	var result: Array[BulletData] = []
	for bullet_id in BULLET_IDS:
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % bullet_id)
		result.append(bullet.duplicate())
	return result


static func _enemy() -> EnemyData:
	var enemy := EnemyData.new()
	enemy.display_name = "탄환 패 테스트 표적"
	enemy.max_hp = 999
	enemy.defense = 0
	enemy.evasion = 0
	enemy.speed = 0
	enemy.start_distance = 10
	return enemy


static func _bullet_ids(bullets: Array[BulletData]) -> Array[String]:
	var result: Array[String] = []
	for bullet in bullets:
		result.append(PlaytestLoggerScript.resource_id(bullet))
	return result


static func _new_combat(hand_mode: bool, seed: int = 731042, test_mode: String = "") -> CombatManager:
	RandomStreamsScript.begin_run(seed, 9917)
	var cm := CombatManagerScript.new()
	cm.configure_ammo_hand_prototype(
		hand_mode, 7, 2, "B" if hand_mode else "A", test_mode)
	var enemies: Array[EnemyData] = [_enemy()]
	var no_parts: Array[PartData] = []
	cm.start_encounter(load(G_REVOLVER), enemies, _deck(), no_parts, load(B_BASIC))
	return cm


static func run(t) -> void:
	t.section("AmmoHandPrototype")
	var random_snapshot := RandomStreamsScript.snapshot()

	# A안은 출시 규칙을 바꾸지 않는다: 전체 전술 덱이 그대로 장전 후보다.
	var legacy := _new_combat(false)
	t.eq(legacy.available_tactical_bullets().size(), 12, "A안은 기존 전체 12발을 모두 공개")
	t.eq(legacy.draw_pile.size(), 12, "A안 draw pile 계약 유지")
	t.eq(legacy.ammo_hand.size(), 0, "A안은 별도 탄환 패를 만들지 않음")
	var legacy_pick: BulletData = legacy.draw_pile[0]
	legacy.confirm_loading([legacy_pick] as Array[BulletData])
	t.eq(legacy.draw_pile.size(), 11, "A안 장전은 기존처럼 draw pile에서 제거")
	legacy.free()

	# B안은 선택지만 랜덤화하고 공개 결과는 시드로 완전히 재현한다.
	var cm := _new_combat(true, 731042, "fixed_comparison")
	t.eq(cm.ammo_hand.size(), 7, "B안 시작 공개 패는 7발")
	t.eq(cm.draw_pile.size(), 5, "B안 나머지 5발은 비공개 보충 더미")
	t.eq(cm.next_ammo_hand_preview().size(), 2, "다음 보충 2발을 미리 공개")
	t.eq(cm.basic_supply_current, 5, "무해법 방지용 기본탄 5발은 별도 보장")

	var first_hand_ids := _bullet_ids(cm.ammo_hand)
	var first_preview_ids := _bullet_ids(cm.next_ammo_hand_preview())
	var replay := _new_combat(true)
	t.eq(_bullet_ids(replay.ammo_hand), first_hand_ids, "동일 시드는 동일한 공개 패를 재현")
	t.eq(_bullet_ids(replay.next_ammo_hand_preview()), first_preview_ids, "동일 시드는 동일한 다음 보충 예고를 재현")
	replay.free()

	# 패 밖의 숨겨진 탄은 장전할 수 없고, 공개 패의 적재 순서는 기존 LIFO를 따른다.
	var hidden := _new_combat(true)
	var hidden_bullet: BulletData = hidden.draw_pile[0]
	hidden.confirm_loading([hidden_bullet] as Array[BulletData])
	t.eq(hidden.magazine.get_remaining(), 0, "비공개 보충 더미의 탄환은 장전 거부")
	hidden.free()

	var lifo := _new_combat(true)
	var lower: BulletData = lifo.ammo_hand[0]
	var upper: BulletData = lifo.ammo_hand[1]
	var load_order: Array[BulletData] = [lower, upper]
	lifo.confirm_loading(load_order)
	t.check(lifo.magazine.peek() == upper, "공개 패에서도 마지막에 넣은 탄이 먼저 발사되는 LIFO 유지")
	lifo.free()

	# 한 발을 소비한 뒤 리로드하면 기존 6발은 유지되고 예고 첫 탄만 보충된다.
	var fired: BulletData = cm.ammo_hand[0]
	var refill_transitions: Array[Dictionary] = []
	cm.ammo_hand_transitioned.connect(func(transition: Dictionary):
		refill_transitions.append(transition.duplicate(true)))
	var retained_ids := first_hand_ids.duplicate()
	retained_ids.erase(PlaytestLoggerScript.resource_id(fired))
	var expected_refill_id: String = first_preview_ids[0]
	cm.confirm_loading([fired] as Array[BulletData])
	cm.fire()
	t.eq(cm.ammo_hand.size(), 6, "발사한 전술탄만 공개 패에서 빠짐")
	cm.request_reload()
	t.eq(cm.ammo_hand.size(), 7, "리로드 시 공개 패를 7발까지 보충")
	var refilled_ids := _bullet_ids(cm.ammo_hand)
	t.check(refilled_ids.has(expected_refill_id), "예고된 첫 탄이 실제 보충 결과에 포함")
	var all_retained := true
	for retained_id in retained_ids:
		all_retained = all_retained and refilled_ids.has(retained_id)
	t.check(all_retained, "사용하지 않은 공개 패 6발은 리로드 후에도 유지")
	t.eq(refill_transitions.size(), 1, "리로드 보충은 UI용 패 전환 사건 1회 방출")
	if not refill_transitions.is_empty():
		var refill_transition := refill_transitions[0]
		t.eq(str(refill_transition.get("reason", "")), "refill", "패 전환 원인은 일반 보충")
		t.eq((refill_transition.get("retained", []) as Array).size(), 6,
			"보충 전환에 미사용 유지탄 6발 명시")
		t.eq((refill_transition.get("added", []) as Array).size(), 1,
			"보충 전환에 신규 탄환 1발 명시")
		t.eq(int(refill_transition.get("hidden_count", -1)), 4,
			"보충 뒤 미공개 더미 수 4발 명시")
	var report_hand: Dictionary = cm.build_playtest_report().get("ammo_hand", {})
	t.eq(str(report_hand.get("test_mode", "")), "fixed_comparison",
		"패 보고서에 고정 비교/랜덤 체감 모드 기록")
	cm.free()

	# 후보 탄환 카드는 현재 강제 대상의 두 게이트 결과를 정본 계산으로 받는다.
	var candidate_cm := _new_combat(true)
	var marker: BulletData = load("res://resources/bullets/marker.tres")
	candidate_cm.enemy.current_evasion = 9
	candidate_cm.enemy.current_def = 2
	var candidate_preview := candidate_cm.preview_candidate_bullet(marker)
	t.check(bool(candidate_preview.get("acc_ok", false)), "표식탄 명중 9는 현재 회피 9 게이트 통과")
	t.check(not bool(candidate_preview.get("pen_ok", true)), "표식탄 관통 1은 현재 방어 2 게이트 실패")
	candidate_cm.free()

	# 공개 패 운이 나빠도 기본탄만으로 합법적인 장전을 시작할 수 있다.
	var fallback := _new_combat(true)
	var basic: BulletData = load(B_BASIC)
	fallback.confirm_loading([basic] as Array[BulletData])
	t.eq(fallback.magazine.get_remaining(), 1, "B안에서도 기본탄은 항상 장전 가능")
	t.eq(fallback.basic_supply_current, 4, "기본탄 장전량은 고정 보급원에서 차감")
	fallback.free()

	# 여러 시드가 실제로 서로 다른 초기 문제를 제공한다.
	var signatures: Dictionary = {}
	for seed in range(731040, 731048):
		var seeded := _new_combat(true, seed)
		signatures["|".join(_bullet_ids(seeded.ammo_hand))] = true
		seeded.free()
	t.check(signatures.size() >= 4, "8개 시드에서 최소 4개의 서로 다른 공개 패 순서 생성")

	RandomStreamsScript.restore(random_snapshot)
