extends RefCounted
## 총기 시그니처 회귀 검증 — 총기 고유 능력이 실제 전투에서 발동하는지.
##
## 배경: 시그니처 판정이 표시명 문자열(`display_name.contains("저격"/"돌격")`)에 의존했는데
##       실제 총기 표시명이 "정밀 지정사수소총"·"브리칭 샷건"이라 매칭되지 않아
##       DMR·샷건 시그니처가 전혀 발동하지 않던 버그(2026-07-18 수정).
##       리소스 ID 판정(_gun_is)으로 교체 후 발동을 못박는다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const G_REVOLVER := "res://resources/guns/revolver.tres"
const G_DMR := "res://resources/guns/dmr.tres"
const G_SHOTGUN := "res://resources/guns/shotgun.tres"


static func _bullet(dmg: int, acc: int, pen: int) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	return b


static func _enemy(hp: int, def_v: int, eva: int, dist: int) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.RUSHER  # 태세 없음 · 정지(SPD0)로 관측 안정
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = 0
	d.start_distance = dist
	return d


## 지정 총기로 격발 후 적 잔여 HP 반환.
static func _hp_after(gun_path: String, enemy_data: EnemyData, dmg: int, acc: int, pen: int, shots: int) -> int:
	var cm = CombatManagerScript.new()
	var gun: GunData = load(gun_path)
	var loadout: Array[BulletData] = []
	for i in range(shots):
		loadout.append(_bullet(dmg, acc, pen))
	var enemies: Array[EnemyData] = [enemy_data]
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()
	var hp: int = cm.enemies[0].current_hp
	cm.free()
	return hp


static func run(t) -> void:
	t.section("GunSignatures")
	RunManager.infiltration_risk_level = 1

	# ── DMR(저격형): 거리 > 1에서 명중 게이트 무시 ──
	# ACC1 탄 vs EVA8 적 → 일반 총기는 전탄 빗나감, DMR은 게이트 무시로 명중
	var rev_hp := _hp_after(G_REVOLVER, _enemy(30, 0, 8, 12), 3, 1, 0, 3)
	t.eq(rev_hp, 30, "리볼버: ACC1 < EVA8 전탄 빗나감 (HP 불변)")
	var dmr_hp := _hp_after(G_DMR, _enemy(30, 0, 8, 12), 3, 1, 0, 3)
	t.check(dmr_hp < rev_hp, "DMR 저격 시그니처: 원거리 명중 게이트 무시로 명중 발생 (%d < %d)" % [dmr_hp, rev_hp])

	# ── 샷건(돌격형): 거리 <= 2 초근접 DMG +4 ──
	# 동일 조건에서 샷건이 초근접 보너스만큼 더 큰 피해를 준다
	var rev_close := _hp_after(G_REVOLVER, _enemy(60, 0, 0, 2), 3, 7, 0, 3)
	var sg_close := _hp_after(G_SHOTGUN, _enemy(60, 0, 0, 2), 3, 7, 0, 3)
	t.eq(rev_close, 51, "리볼버 초근접: 3x3=9 대미지 (HP 60→51)")
	t.check(sg_close < rev_close, "샷건 돌격 시그니처: 초근접 DMG+4 보너스 발동 (%d < %d)" % [sg_close, rev_close])
	# 자기모순 수정(2026-07-18): 초근접 구간에서는 샷건 패시브 넉백을 제외하므로
	# 적이 보너스 구간에 머물러 3발 모두 +4를 받는다. (수정 전에는 첫 발만 적용되고 13 대미지)
	t.eq(sg_close, 39, "샷건 초근접: 넉백 제외로 구간 유지 → (3+4)x3=21 대미지 (HP 60→39)")

	# ── 샷건 원거리 페널티: 거리 >= 4에서 ACC -4 ──
	# ACC5 탄 vs EVA2 적: 리볼버는 명중, 샷건은 ACC 1로 떨어져 빗나감
	var rev_far := _hp_after(G_REVOLVER, _enemy(30, 0, 2, 10), 3, 5, 0, 3)
	var sg_far := _hp_after(G_SHOTGUN, _enemy(30, 0, 2, 10), 3, 5, 0, 3)
	t.eq(rev_far, 21, "리볼버 원거리: ACC5 >= EVA2 명중 (HP 30→21)")
	t.eq(sg_far, 30, "샷건 원거리 페널티: ACC-4로 EVA2 미달 → 전탄 빗나감 (HP 불변)")

	# ── 스텔스 적 카운터: nano_stalker(EVA 9) ──
	# 탄환 ACC 상한이 8이라 일반 총기로는 원천 명중 불가한 설계지만,
	# DMR 저격 시그니처(거리>1 명중 게이트 무시)가 전용 카운터로 작동해야 한다.
	var stalker_rev := _hp_after(G_REVOLVER, load("res://resources/enemies/nano_stalker.tres").duplicate() as EnemyData, 3, 8, 0, 3)
	t.eq(stalker_rev, 4, "나노 스토커: 리볼버 최대 ACC8 < EVA9 → 전탄 빗나감 (HP 4 불변)")
	var stalker_dmr := _hp_after(G_DMR, load("res://resources/enemies/nano_stalker.tres").duplicate() as EnemyData, 3, 8, 0, 3)
	t.check(stalker_dmr < 4, "나노 스토커 카운터: DMR 저격 시그니처로 명중 성공 (HP %d < 4)" % stalker_dmr)
