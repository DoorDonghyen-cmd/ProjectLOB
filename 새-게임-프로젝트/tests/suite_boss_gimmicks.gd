extends RefCounted
## 보스/특수 기믹 유닛 커버리지 (B3) — 앱소버 배리어·캐스터 차징·삼단 태세·페이즈 전환(함수 단위).
## 정본: scripts/core/enemy_instance.gd
## 주의: check_phase_transition은 "함수 자체"가 정상임을 검증한다.
##       실제 전투에서 호출되지 않는 통합 버그는 별건(task_tracker Backlog 등록)이다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const GUN := "res://resources/guns/revolver.tres"
const BOSS_FINAL_RES := "res://resources/enemies/boss_lob_core.tres"
const BOSS_SERAPH_RES := "res://resources/enemies/boss_seraph.tres"
const RUSHER_RES := "res://resources/enemies/rusher.tres"
const TANK_RES := "res://resources/enemies/tank.tres"
const DODGER_RES := "res://resources/enemies/dodger.tres"
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


static func _start_formation(enemy_paths: Array[String]) -> CombatManager:
	var cm = CombatManagerScript.new()
	var gun: GunData = load(GUN)
	var enemies: Array[EnemyData] = []
	for path in enemy_paths:
		enemies.append(load(path) as EnemyData)
	var no_bullets: Array[BulletData] = []
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, no_bullets, no_parts)
	return cm


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

	# ── 세라프 호위 대열: 2m 스태거링 + 4턴 차징 ──
	var seraph_cm := _start_formation([RUSHER_RES, TANK_RES, BOSS_SERAPH_RES])
	t.eq(seraph_cm.enemies[0].current_distance, 10, "[대열] 세라프 선봉 돌격병 = 10m")
	t.eq(seraph_cm.enemies[1].current_distance, 14, "[대열] 방패병 = 기본 12m + 오프셋 2m")
	t.eq(seraph_cm.enemies[2].current_distance, 19, "[대열] 세라프 = 기본 15m + 오프셋 4m")

	# 선봉은 처치된 상태로 두어 차징 자체의 호위 압박을 격리 측정한다.
	seraph_cm.enemies[0].current_hp = 0
	for i in range(3):
		seraph_cm._all_enemies_advance()
	t.eq(seraph_cm.enemies[1].current_distance, 11, "[세라프] 3턴 동안 방패병 정상 전진")
	t.eq(seraph_cm.enemies[2].charge_turns_current, 3, "[세라프] 4턴 차징 중 3턴 누적")
	seraph_cm._all_enemies_advance()
	t.eq(seraph_cm.enemies[1].current_distance, 8, "[세라프] 4턴째 방패병 1m 전진 + 포격 2m 강제전진")
	t.eq(seraph_cm.enemies[2].current_distance, 19, "[세라프] 포격이 차징 주체 자신을 밀지 않음")
	t.eq(seraph_cm.enemies[2].charge_turns_current, 0, "[세라프] 포격 후 차징 카운터 리셋")
	seraph_cm.free()

	# ── L.O.B 코어 호위 대열: 2m 스태거링 + 3턴 차징 ──
	var lob_cm := _start_formation([RUSHER_RES, DODGER_RES, TANK_RES, BOSS_FINAL_RES])
	t.eq(lob_cm.enemies[0].current_distance, 10, "[대열] L.O.B 선봉 돌격병 = 10m")
	t.eq(lob_cm.enemies[1].current_distance, 11, "[대열] 회피병 = 기본 9m + 오프셋 2m")
	t.eq(lob_cm.enemies[2].current_distance, 16, "[대열] 방패병 = 기본 12m + 오프셋 4m")
	t.eq(lob_cm.enemies[3].current_distance, 21, "[대열] L.O.B 코어 = 기본 15m + 오프셋 6m")

	# 두 선봉을 제거하고 방패병에 가해지는 3턴 압박을 격리 측정한다.
	lob_cm.enemies[0].current_hp = 0
	lob_cm.enemies[1].current_hp = 0
	for i in range(2):
		lob_cm._all_enemies_advance()
	t.eq(lob_cm.enemies[2].current_distance, 14, "[L.O.B] 2턴 동안 방패병 정상 전진")
	t.eq(lob_cm.enemies[3].charge_turns_current, 2, "[L.O.B] 3턴 차징 중 2턴 누적")
	lob_cm._all_enemies_advance()
	t.eq(lob_cm.enemies[2].current_distance, 11, "[L.O.B] 3턴째 방패병 1m 전진 + 포격 2m 강제전진")
	t.eq(lob_cm.enemies[3].current_distance, 21, "[L.O.B] 포격이 차징 주체 자신을 밀지 않음")
	t.eq(lob_cm.enemies[3].charge_turns_current, 0, "[L.O.B] 포격 후 차징 카운터 리셋")

	# 넉백 2 기준: 선봉은 밀리지만 방패병(저항2)·코어(저항3)는 고정된다.
	t.eq(lob_cm.enemies[0].apply_knockback(2), 2, "[넉백] 돌격병은 충격탄 2m 전량 적용")
	t.eq(lob_cm.enemies[2].apply_knockback(2), 0, "[넉백] 방패병 저항2가 충격탄 2m 상쇄")
	t.eq(lob_cm.enemies[3].apply_knockback(2), 0, "[넉백] L.O.B 코어 저항3이 충격탄 2m 상쇄")

	# 페이즈 2는 SPD1 전진과 3턴 차징을 동시에 수행한다.
	lob_cm.enemies[3].barrier_cells = 0
	t.check(lob_cm.enemies[3].check_phase_transition(), "[L.O.B] 대열 시나리오 페이즈2 진입")
	for i in range(3):
		lob_cm._all_enemies_advance()
	t.eq(lob_cm.enemies[3].current_distance, 18, "[L.O.B] 페이즈2 코어는 3턴 동안 3m 전진")
	t.eq(lob_cm.enemies[2].current_distance, 6, "[L.O.B] 페이즈2 3턴째 호위에 포격 2m 추가 압박")
	t.eq(lob_cm.enemies[3].charge_turns_current, 0, "[L.O.B] 페이즈2에서도 차징 반복")
	lob_cm.free()
