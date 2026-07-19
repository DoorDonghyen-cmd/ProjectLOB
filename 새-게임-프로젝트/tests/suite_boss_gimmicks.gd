extends RefCounted
## 보스/특수 기믹 유닛 커버리지 (B3) — 앱소버 배리어·캐스터 차징·삼단 태세·페이즈 전환(함수 단위).
## 정본: scripts/core/enemy_instance.gd
## 주의: check_phase_transition은 "함수 자체"가 정상임을 검증한다.
##       실제 전투에서 호출되지 않는 통합 버그는 별건(task_tracker Backlog 등록)이다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const GUN := "res://resources/guns/revolver.tres"
const BOSS_FINAL_RES := "res://resources/enemies/boss_lob_core.tres"
const B_PIERCE := "res://resources/bullets/pierce_dmr.tres" # DMG4 / ACC7 / PEN3 — DEF3 게이트 통과


static func _enemy(arch: int) -> EnemyInstance:
	var d := EnemyData.new()
	d.archetype = arch
	return EnemyInstance.new(d)


## 최종 보스를 실제 CombatManager로 구동해 지정 발수만큼 격발한 뒤 상태를 반환한다.
static func _run_final_boss(shots: int) -> Dictionary:
	var cm = CombatManagerScript.new()
	var won := [false]
	cm.encounter_won.connect(func(): won[0] = true)

	var gun: GunData = load(GUN)
	var loadout: Array[BulletData] = []
	for i in range(shots):
		loadout.append((load(B_PIERCE) as BulletData).duplicate())
	var enemies: Array[EnemyData] = [load(BOSS_FINAL_RES) as EnemyData]
	var no_parts: Array[PartData] = []

	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()

	var boss = cm.enemies[0]
	var res := {
		"phase": boss.current_phase,
		"sponge": boss.is_stack_sponge,
		"hp": boss.current_hp,
		"barrier": boss.barrier_cells,
		"dead": boss.is_dead(),
		"won": won[0],
	}
	cm.free()
	return res


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

	# ── 최종 보스 페이즈 전환 [실제 전투 통합] ──
	# 회귀: combat_manager가 배리어 소진 시 check_phase_transition을 호출하지 않아
	#       페이즈2에 도달하지 못하고 즉사하던 버그(2026-07-18 수정).
	var r4 := _run_final_boss(4)
	t.eq(r4.phase, 1, "[전투] 배리어 1셀 잔존(4타) → 페이즈 1 유지")
	t.check(r4.sponge, "[전투] 페이즈1 배리어 모드 유지")

	var r5 := _run_final_boss(5)
	t.eq(r5.phase, 2, "[전투] 배리어 소진(5타) → 페이즈 2 전환")
	t.check(not r5.sponge, "[전투] 페이즈2에서 배리어 모드 해제")
	t.eq(r5.hp, 30, "[전투] 페이즈2 실체 HP 30 노출")
	t.check(not r5.dead, "[전투] 페이즈2 진입 — 즉사하지 않음")
	t.check(not r5.won, "[전투] 배리어 소진만으로 전투가 종료되지 않음")
