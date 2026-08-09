extends RefCounted
## 조합탄 1단계 회귀 — 효과 범위 분류와 현재 LIFO 게이트 기여 예고.

const AmmoGuidanceScript := preload("res://scripts/ui/ammo_guidance.gd")


static func _make_enemy(defense: int, evasion: int) -> EnemyInstance:
	var data := EnemyData.new()
	data.display_name = "예고 검증 표적"
	data.defense = defense
	data.evasion = evasion
	data.max_hp = 20
	data.start_distance = 10
	return EnemyInstance.new(data)


static func _make_attack(name: String, accuracy: int, penetration: int) -> BulletData:
	var bullet := BulletData.new()
	bullet.display_name = name
	bullet.role = BulletRoleUI.ATTACK
	bullet.accuracy = accuracy
	bullet.penetration = penetration
	return bullet


static func _make_link(
	name: String,
	effect_type: Enums.BulletEffect,
	effect_value: int,
	scope: String,
	trigger: String,
	accuracy: int,
	penetration: int
) -> BulletData:
	var bullet := BulletData.new()
	bullet.display_name = name
	bullet.role = BulletRoleUI.LINK
	bullet.effect_type = effect_type
	bullet.effect_value = effect_value
	bullet.scope = scope
	bullet.trigger = trigger
	bullet.accuracy = accuracy
	bullet.penetration = penetration
	return bullet


static func run(t) -> void:
	t.section("AmmoGuidance")

	var expected_scopes := {
		"marker": BulletRoleUI.SCOPE_NEXT_SHOT,
		"borer": BulletRoleUI.SCOPE_NEXT_SHOT,
		"jammer": BulletRoleUI.SCOPE_TARGET,
		"shred": BulletRoleUI.SCOPE_TARGET,
		"guide": BulletRoleUI.SCOPE_REMAINING_MAG,
		"align": BulletRoleUI.SCOPE_REMAINING_MAG,
	}
	var counts := {
		BulletRoleUI.SCOPE_NEXT_SHOT: 0,
		BulletRoleUI.SCOPE_TARGET: 0,
		BulletRoleUI.SCOPE_REMAINING_MAG: 0,
	}
	for bullet_id_variant in expected_scopes.keys():
		var bullet_id := str(bullet_id_variant)
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % bullet_id)
		t.check(bullet != null, "%s 연계탄 리소스 로드" % bullet_id)
		if bullet == null:
			continue
		var expected_scope: String = expected_scopes[bullet_id]
		t.eq(BulletRoleUI.normalize_scope(bullet.scope), expected_scope,
			"%s 효과 범위 분류" % bullet.display_name)
		t.check(not BulletRoleUI.scope_badge_text(bullet.scope).is_empty(),
			"%s 전체 범위 배지 제공" % bullet.display_name)
		t.check(not BulletRoleUI.compact_scope_badge_text(bullet.scope).is_empty(),
			"%s 축약 범위 배지 제공" % bullet.display_name)
		counts[expected_scope] += 1
	for scope in counts:
		t.eq(counts[scope], 2, "%s 범위 연계탄이 정확히 2종" % BulletRoleUI.scope_label(scope))

	for payoff_id in ["chain", "crosscal"]:
		var payoff: BulletData = load("res://resources/bullets/%s.tres" % payoff_id)
		t.check(BulletRoleUI.is_payoff(payoff), "%s 결산탄 분류" % payoff.display_name)
		t.eq(BulletRoleUI.payoff_badge_text(payoff), "[결산]", "%s 결산 배지" % payoff.display_name)
		t.check(BulletRoleUI.tooltip(payoff).contains("결산탄"), "%s 결산 운용 툴팁" % payoff.display_name)

	var gun := GunData.new()
	var armored := _make_enemy(3, 7)

	# loaded_bullets는 삽탄 순서, 마지막 원소가 먼저 발사되는 LIFO다.
	var borer := _make_link(
		"천공탄", Enums.BulletEffect.BUFF_PEN, 3,
		BulletRoleUI.SCOPE_NEXT_SHOT, "on_effective_hit", 7, 3)
	var low_pen := _make_attack("저관통탄", 7, 0)
	var next_stack: Array[BulletData] = [low_pen, borer]
	var next_entries := AmmoGuidanceScript.preview_entries(next_stack, gun, armored)
	t.eq(next_entries.size(), 1, "다음 1발 예고 1건 생성")
	if not next_entries.is_empty():
		t.eq(int(next_entries[0].converted), 1, "다음 1발 관통 게이트 전환 1발")

	var shred := _make_link(
		"파쇄탄", Enums.BulletEffect.ARMOR_SHRED, 2,
		BulletRoleUI.SCOPE_TARGET, "on_hit", 7, 0)
	var target_stack: Array[BulletData] = [_make_attack("후속탄", 7, 1), shred]
	var target_entries := AmmoGuidanceScript.preview_entries(target_stack, gun, armored)
	t.eq(int(target_entries[0].converted), 1, "대상 지속 방어 약화가 후속 1발을 관통 전환")

	var guide := _make_link(
		"유도탄", Enums.BulletEffect.BUFF_MAG_ACC, 1,
		BulletRoleUI.SCOPE_REMAINING_MAG, "on_effective_hit", 7, 3)
	var mag_stack: Array[BulletData] = [
		_make_attack("후속탄 B", 6, 3),
		_make_attack("후속탄 A", 6, 3),
		guide,
	]
	var mag_entries := AmmoGuidanceScript.preview_entries(mag_stack, gun, armored)
	t.eq(int(mag_entries[0].converted), 2, "잔여 탄창 명중 게이트 전환 2발")

	var failed_link := _make_link(
		"실패 연계탄", Enums.BulletEffect.BUFF_PEN, 3,
		BulletRoleUI.SCOPE_NEXT_SHOT, "on_effective_hit", 6, 3)
	var failed_stack: Array[BulletData] = [low_pen, failed_link]
	var failed_text := AmmoGuidanceScript.summary_text(failed_stack, gun, armored)
	t.check(failed_text.contains("발동 불가"), "연계탄 자체 게이트 실패를 예고")

	var enough_pen := _make_attack("이미 관통", 7, 3)
	var no_change_stack: Array[BulletData] = [enough_pen, borer]
	var no_change_text := AmmoGuidanceScript.summary_text(no_change_stack, gun, armored)
	t.check(no_change_text.contains("전환 없음"), "이미 통과하는 탄은 기여 발수에서 제외")

	# 앞 연계탄이 뒤 연계탄 자체의 발동 게이트를 열어 주는 실제 LIFO 체인도 누적 계산한다.
	var chain_target := _make_enemy(0, 7)
	var marker := _make_link(
		"표식탄", Enums.BulletEffect.BUFF_ACC, 3,
		BulletRoleUI.SCOPE_NEXT_SHOT, "on_effective_hit", 8, 1)
	var jammer := _make_link(
		"교란탄", Enums.BulletEffect.DEBUFF_EVA, 2,
		BulletRoleUI.SCOPE_TARGET, "on_hit", 4, 0)
	var chained_attack := _make_attack("연계 후속탄", 5, 0)
	var chained_stack: Array[BulletData] = [chained_attack, jammer, marker]
	var chained_entries := AmmoGuidanceScript.preview_entries(chained_stack, gun, chain_target)
	t.eq(chained_entries.size(), 2, "연계탄→연계탄 LIFO 예고 2건 생성")
	if chained_entries.size() == 2:
		t.eq(int(chained_entries[0].converted), 1, "표식탄이 뒤 교란탄 명중을 전환")
		t.check(bool(chained_entries[1].triggered), "앞 연계 보정을 받아 교란탄이 발동 가능")
		t.eq(int(chained_entries[1].converted), 1, "교란탄이 뒤 공격탄 명중을 전환")

	# 결산탄은 선행 연계의 실제 게이트 개방과 조건부 피해를 전투 순서대로 합산한다.
	var payoff_target := _make_enemy(0, 8)
	var chain: BulletData = (load("res://resources/bullets/chain.tres") as BulletData).duplicate()
	var payoff_stack: Array[BulletData] = [chain, marker]
	var payoff_entries := AmmoGuidanceScript.preview_entries(payoff_stack, gun, payoff_target)
	t.eq(payoff_entries.size(), 2, "표식탄→연쇄탄은 연계·결산 예고 2건 생성")
	if payoff_entries.size() == 2:
		t.eq(str(payoff_entries[1].kind), "payoff", "두 번째 예고는 결산 결과")
		t.check(bool(payoff_entries[1].triggered), "직전 유효 적중으로 연쇄탄 결산 성공")
		t.check(bool(payoff_entries[1].critical), "표식탄이 명중 게이트를 열어 결정형 크리티컬 예고")
		t.eq(int(payoff_entries[1].expected_damage), 7, "연쇄탄 2+3 뒤 크리티컬 = 예상 주 피해 7")
		t.check(str(payoff_entries[1].text).contains("결산 성공"), "결산 성공 문구 제공")

	var crosscal: BulletData = (load("res://resources/bullets/crosscal.tres") as BulletData).duplicate()
	var first_payoff: Array[BulletData] = [crosscal]
	var first_payoff_text := AmmoGuidanceScript.summary_text(first_payoff, gun, payoff_target)
	t.check(first_payoff_text.contains("역할 교대 필요"), "첫 발 교대탄은 결산 실패 이유 예고")

	var attack_only: Array[BulletData] = [low_pen]
	t.eq(AmmoGuidanceScript.summary_text(attack_only, gun, armored), "",
		"연계탄이 없으면 예고 영역용 문구 없음")

	# 시작 연계탄은 있지만 결산탄이 없을 때만 보상 한 칸을 보증한다.
	var old_ascension := RunManager.meta_ascension_level
	RunManager.meta_ascension_level = 0
	var rm := RunManager.new()
	rm.current_gun = load("res://resources/guns/smg.tres")
	rm.deck = [(load("res://resources/bullets/marker.tres") as BulletData).duplicate()] as Array[BulletData]
	var draft := RewardDraftPanel.new()
	draft.run_manager = rm
	t.check(draft._needs_payoff_offer(), "연계 보유·결산 미보유 시 결산탄 첫 노출 필요")
	var choices := draft._generate_draft_choices()
	var offered_payoff := false
	for choice in choices:
		offered_payoff = offered_payoff or BulletRoleUI.is_payoff(choice)
	t.check(offered_payoff, "⭐ 결산탄 미보유 드래프트 1칸에 연쇄/교대탄 보증")
	t.eq(draft._draft_weight(crosscal), 3, "미보유 탄환 드래프트 가중치 3")
	rm.deck.append(chain.duplicate())
	t.check(not draft._needs_payoff_offer(), "결산탄 1발 획득 뒤 첫 노출 보증 해제")
	t.eq(draft._draft_weight(chain), 2, "동일 탄 1발 보유 시 가중치 2")
	rm.deck.append(chain.duplicate())
	t.eq(draft._draft_weight(chain), 1, "동일 탄 2발 이상 보유 시 최소 가중치 1")
	draft.free()
	RunManager.meta_ascension_level = old_ascension
