extends RefCounted
## 보스/특수 기믹 유닛 커버리지 (B3) — 앱소버 배리어·캐스터 차징·삼단 태세·페이즈 전환(함수 단위).
## 정본: scripts/core/enemy_instance.gd
## 주의: check_phase_transition은 "함수 자체"가 정상임을 검증한다.
##       실제 전투에서 호출되지 않는 통합 버그는 별건(task_tracker Backlog 등록)이다.

static func _enemy(arch: int) -> EnemyInstance:
	var d := EnemyData.new()
	d.archetype = arch
	return EnemyInstance.new(d)


static func run(t) -> void:
	t.section("BossGimmicks")
	RunManager.infiltration_risk_level = 1

	# ── 앱소버(스택 스펀지): 배리어 셀로 사망 판정 ──
	var ab := _enemy(Enums.EnemyArchetype.ABSORBER)
	t.check(ab.is_stack_sponge, "앱소버 스택 스펀지 활성")
	t.eq(ab.barrier_cells, 3, "배리어 3셀")
	t.check(not ab.is_dead(), "배리어 남으면 생존")
	ab.barrier_cells = 0
	t.check(ab.is_dead(), "배리어 0 → 사망")

	# ── 캐스터 차징: N턴 충전 후 격발, 카운터 리셋 ──
	var cs := _enemy(Enums.EnemyArchetype.CASTER)
	t.check(cs.is_charger, "캐스터 차저 활성")
	t.eq(cs.current_speed, 0, "캐스터 비전진(SPD 0)")
	t.check(not cs.advance_charger(), "1턴 충전")
	t.check(not cs.advance_charger(), "2턴 충전")
	t.check(cs.advance_charger(), "3턴째 충전 완료 → 격발")
	t.check(not cs.advance_charger(), "격발 후 카운터 리셋")

	# ── 삼단 태세(실험체 Ω): IRON→DODGER→RUSH→IRON, 2발 주기 ──
	var om := _enemy(Enums.EnemyArchetype.BOSS_SCRAMBLER)
	t.check(om.has_triple_stance, "Ω 삼단 태세 활성")
	t.eq(om.current_stance, Enums.EnemyStance.IRON_SHIELD, "시작 IRON_SHIELD")
	om.apply_shot_and_check_shift(); om.apply_shot_and_check_shift()
	t.eq(om.current_stance, Enums.EnemyStance.ACTIVE_DODGER, "2발 후 → ACTIVE_DODGER")
	om.apply_shot_and_check_shift(); om.apply_shot_and_check_shift()
	t.eq(om.current_stance, Enums.EnemyStance.RUSH_CHARGE, "4발 후 → RUSH_CHARGE")
	om.apply_shot_and_check_shift(); om.apply_shot_and_check_shift()
	t.eq(om.current_stance, Enums.EnemyStance.IRON_SHIELD, "6발 후 → IRON_SHIELD 복귀(순환)")

	# ── 최종 보스 페이즈 전환(함수 단위) — 함수는 정상, 전투 호출 누락은 별건 ──
	var fb := _enemy(Enums.EnemyArchetype.BOSS_FINAL)
	t.check(fb.is_stack_sponge, "최종보스 페이즈1 배리어 활성")
	t.eq(fb.barrier_cells, 5, "배리어 5셀")
	t.check(not fb.check_phase_transition(), "배리어 남으면 전환 안 함")
	fb.barrier_cells = 0
	t.check(fb.check_phase_transition(), "배리어 0 → 페이즈2 전환(함수 정상)")
	t.eq(fb.current_phase, 2, "페이즈 2 진입")
	t.check(not fb.is_stack_sponge, "페이즈2 배리어 해제")
	t.eq(fb.current_hp, 30, "페이즈2 실체 HP 30 노출")
