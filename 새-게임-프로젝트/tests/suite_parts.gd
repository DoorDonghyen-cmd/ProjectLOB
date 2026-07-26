extends RefCounted
## 파츠 적용 회귀 검증 — 파츠를 start_encounter로 전달하면 실제 전투에 효과가 반영되는지.
##
## 배경: combat_overlay_v2가 start_encounter에 parts 인자를 누락해 실게임에서 파츠가
##       전혀 적용되지 않던 버그(2026-07-18 수정). 본 테스트는 "파츠 메커니즘"(_has_part 경유 효과)이
##       정상 동작함을 못박는다.
## 한계: UI 호출부의 parts 전달 자체는 레벨 B(자동 커버 밖)이므로 수동 확인이 별도로 필요하다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const GUN := "res://resources/guns/revolver.tres"


static func _bullet(dmg: int, acc: int, pen: int) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	return b


static func _enemy(hp: int, def_v: int, eva: int) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.RUSHER  # 태세 없음, 정지(SPD0)로 관측 안정
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = 0
	d.start_distance = 12
	return d


static func _part(pid: int) -> PartData:
	var p := PartData.new()
	p.part_id = pid
	return p


## 지정 파츠를 장착하고 ACC6/DMG3/PEN0 탄 5발을 격발한 뒤 적 잔여 HP를 반환한다.
static func _remaining_hp(gun: GunData, enemy_data: EnemyData, parts: Array[PartData]) -> int:
	return _fire_and_get_hp(gun, enemy_data, parts, 3, 6, 0, 5)


## 탄환 스펙과 발수를 지정해 격발한 뒤 적 잔여 HP를 반환한다.
static func _fire_and_get_hp(gun: GunData, enemy_data: EnemyData, parts: Array[PartData],
		dmg: int, acc: int, pen: int, shots: int) -> int:
	var cm = CombatManagerScript.new()
	var loadout: Array[BulletData] = []
	for i in range(shots):
		loadout.append(_bullet(dmg, acc, pen))
	var enemies: Array[EnemyData] = [enemy_data]
	cm.start_encounter(gun, enemies, loadout, parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()
	var hp: int = cm.enemies[0].current_hp
	cm.free()
	return hp


## 탱크형(태세 3발 주기) 적에게 지정 발수를 격발한 뒤 현재 태세를 반환한다.
static func _tank_stance_after_shots(gun: GunData, parts: Array[PartData], shots: int) -> int:
	var cm = CombatManagerScript.new()
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.TANK  # 시작 IRON_SHIELD, 3발마다 전환
	d.max_hp = 99
	d.defense = 0
	d.evasion = 0
	d.speed = 0
	d.start_distance = 12
	var loadout: Array[BulletData] = []
	for i in range(shots):
		loadout.append(_bullet(1, 7, 0))
	var enemies: Array[EnemyData] = [d]
	cm.start_encounter(gun, enemies, loadout, parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()
	var stance: int = cm.enemies[0].current_stance
	cm.free()
	return stance


static func run(t) -> void:
	t.section("Parts(application)")
	RunManager.infiltration_risk_level = 1
	var gun: GunData = load(GUN)

	# ACC6 탄 vs EVA7 적: 파츠 없으면 전탄 빗나감(HP 불변)
	var no_parts: Array[PartData] = []
	var hp_without := _remaining_hp(gun, _enemy(20, 0, 7), no_parts)
	t.eq(hp_without, 20, "파츠 미장착: ACC6 < EVA7 전탄 빗나감 → HP 불변")

	# ── HIGH_PRECISION: **직전 빗나감 시** ACC+3 (상시 아님) ──
	# 정본: docs/gdd/22_ammo_expansion §22.0-B — 버프탄과 겹치지 않게 "실패 보정" 조건.
	# ACC6 탄 vs EVA7: 첫 탄은 빗나감(보정 없음) → 그 다음부터 ACC6+3=9 ≥ 7 명중.
	var with_hp: Array[PartData] = [_part(Enums.PartID.HIGH_PRECISION)]
	var hp_with := _remaining_hp(gun, _enemy(20, 0, 7), with_hp)
	t.check(hp_with < hp_without, "HIGH_PRECISION: 빗나감 다음 탄부터 ACC+3로 명중 (%d < %d)" % [hp_with, hp_without])
	# 첫 탄 빗나감 + 이후 4발 명중(직전이 빗나감/명중 교대 아님 — 명중하면 다음은 보정 없음)
	# 실측을 고정값으로 박지 않고 "상시가 아님"을 검증한다:
	t.check(hp_with > 5, "⭐ HIGH_PRECISION은 상시 ACC가 아님 — 전탄 명중(HP 5)보다 덜 깎임 (%d)" % hp_with)

	# ⭐ 첫 탄에는 보정이 없다(직전 빗나감이 없으므로). 1발만 쏘면 빗나가야 한다.
	var hp_first_only := _fire_and_get_hp(gun, _enemy(20, 0, 7), with_hp, 3, 6, 0, 1)
	t.eq(hp_first_only, 20, "⭐ HIGH_PRECISION: 첫 탄은 보정 없음(직전 빗나감 부재) → 빗나감")

	# 대조군: 무관한 파츠(QUICK_LOAD)는 명중에 영향 없음 → 여전히 빗나감
	var irrelevant: Array[PartData] = [_part(Enums.PartID.QUICK_LOAD)]
	var hp_irrelevant := _remaining_hp(gun, _enemy(20, 0, 7), irrelevant)
	t.eq(hp_irrelevant, 20, "명중 무관 파츠(QUICK_LOAD)는 ACC 미변화 → 여전히 빗나감")

	# ── 신규 제작 파츠 효과 실증 (리소스 설명문 ↔ 실제 동작 일치 확인) ──
	var none_parts: Array[PartData] = []

	# ── 철갑 총열: **탄창 첫 탄에만** PEN+2 (상시 아님) ──
	# 정본: §22.0-B — LIFO 고유의 "첫 탄" 축. 연발에서 상시 PEN은 탄창 전체를 뒤집어 위험했다.
	# PEN2 탄 vs DEF3: 첫 탄만 PEN2+2=4 ≥ 3 관통(3뎀), 나머지 4발은 PEN2 < DEF3 도탄.
	var ap_on := _fire_and_get_hp(gun, _enemy(20, 3, 0), [_part(Enums.PartID.ARMOR_PIERCING)] as Array[PartData], 3, 7, 2, 5)
	t.eq(ap_on, 17, "⭐ 철갑총열: 첫 탄만 PEN+2 관통(3뎀), 나머지 도탄 → HP 20→17")

	# ⭐ 상시가 아님을 못박는다: 만약 상시 PEN+1이었다면 전탄 관통(HP 5)이 됐을 것.
	t.check(ap_on > 5, "⭐ 철갑총열은 상시 PEN이 아님 — 전탄 관통(HP 5)이 아니어야 함")

	# ── 만능 약실: **직전과 구경이 다를 때만** ACC+1/PEN+1 (교차 구경 조건) ──
	# 같은 구경만 연사하면 발동하지 않으므로 PEN2 < DEF3 도탄이 유지된다.
	# (상시 PEN+1이었다면 전탄 관통해 HP 5가 됐을 것 — 그렇지 않음을 확인한다.)
	var vc_same := _fire_and_get_hp(gun, _enemy(20, 3, 0), [_part(Enums.PartID.VERSATILE_CHAMBER)] as Array[PartData], 3, 7, 2, 5)
	t.check(vc_same > 5, "⭐ 만능약실: 동일 구경 연사 시 상시 보정 아님 (HP %d)" % vc_same)

	# 블라인드파이어(DMG+2): 발당 +2 → 5발 기준 +10
	var bf_off := _fire_and_get_hp(gun, _enemy(40, 0, 0), none_parts, 3, 7, 0, 5)
	var bf_on := _fire_and_get_hp(gun, _enemy(40, 0, 0), [_part(Enums.PartID.BLIND_FIRE)] as Array[PartData], 3, 7, 0, 5)
	t.eq(bf_off, 25, "블라인드파이어 미장착: 3×5=15 대미지 (HP 40→25)")
	t.eq(bf_on, 15, "블라인드파이어 장착: (3+2)×5=25 대미지 (HP 40→15)")

	# 언더플로우(마지막 탄 DMG+5): 마지막 1발에만 가산 → 총 +5
	var uf_on := _fire_and_get_hp(gun, _enemy(40, 0, 0), [_part(Enums.PartID.UNDERFLOW)] as Array[PartData], 3, 7, 0, 5)
	t.eq(uf_on, 20, "언더플로우 장착: 마지막 탄만 +5 → 총 20 대미지 (HP 40→20)")

	# 롱샷(거리 3+ 시 DMG + (거리-2)): 정지 적 거리 12 → 발당 +10
	var ls_off := _fire_and_get_hp(gun, _enemy(80, 0, 0), none_parts, 3, 7, 0, 5)
	var ls_on := _fire_and_get_hp(gun, _enemy(80, 0, 0), [_part(Enums.PartID.LONG_SHOT)] as Array[PartData], 3, 7, 0, 5)
	t.eq(ls_off, 65, "롱샷 미장착: 3×5=15 대미지 (HP 80→65)")
	t.check(ls_on < ls_off, "롱샷 장착: 원거리 비례 보너스로 추가 대미지 발생 (%d < %d)" % [ls_on, ls_off])

	# ── 태세 고정(STANCE_LOCK): 전투당 1회 태세 전환을 차단 ──
	# 탱크형(3발 주기)에 4발을 쏴서, 파츠 없으면 전환(EVA 1→7) / 있으면 유지되는지 확인
	var tank_off := _tank_stance_after_shots(gun, none_parts, 4)
	var tank_on := _tank_stance_after_shots(gun, [_part(Enums.PartID.STANCE_LOCK)] as Array[PartData], 4)
	t.eq(tank_off, Enums.EnemyStance.ACTIVE_DODGER, "태세 고정 미장착: 3발 주기로 전환 발생")
	t.eq(tank_on, Enums.EnemyStance.IRON_SHIELD, "태세 고정 장착: 전환이 차단되어 태세 유지")

	# 표적 지시기(턴 최초 1회 EVA 0): ACC6 vs EVA8 → 최소 1발은 확정 명중
	var ti_off := _fire_and_get_hp(gun, _enemy(20, 0, 8), none_parts, 3, 6, 0, 5)
	var ti_on := _fire_and_get_hp(gun, _enemy(20, 0, 8), [_part(Enums.PartID.TARGET_INDICATOR)] as Array[PartData], 3, 6, 0, 5)
	t.eq(ti_off, 20, "표적지시기 미장착: ACC6 < EVA8 전탄 빗나감")
	t.check(ti_on < ti_off, "표적지시기 장착: EVA 0 고정으로 확정 명중 발생 (%d < %d)" % [ti_on, ti_off])
