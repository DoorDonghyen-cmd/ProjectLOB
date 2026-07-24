extends RefCounted
## 탄환 특수효과(BulletEffect) 실증 검증.
## 파츠·총기 시그니처와 동일하게 "구현은 있으나 실제로 발동하는가"를 전투로 확인한다.
## 대상: ARMOR_SHRED · LAST_SHOT · COMBO · CALIBER_DIFF · OPENING_SHOT

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const G_REVOLVER := "res://resources/guns/revolver.tres"


static func _bullet(dmg: int, acc: int, pen: int, effect_type: int = 0, effect_value: int = 0,
		wclass: int = Enums.WeaponClass.PISTOL) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	b.effect_type = effect_type
	b.effect_value = effect_value
	b.weapon_class = wclass
	return b


static func _enemy(hp: int, def_v: int, eva: int, dist: int) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.RUSHER  # 태세 없음 · SPD0 정지로 관측 안정
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = 0
	d.start_distance = dist
	return d


## 지정 탄창을 모두 격발한 뒤 적 상태를 반환한다.
static func _fire(enemy_data: EnemyData, loadout: Array[BulletData]) -> Dictionary:
	var cm = CombatManagerScript.new()
	var gun: GunData = load(G_REVOLVER)
	var enemies: Array[EnemyData] = [enemy_data]
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()
	var e = cm.enemies[0]
	var res := {"hp": e.current_hp, "def": e.current_def, "dist": e.current_distance}
	cm.free()
	return res


static func run(t) -> void:
	t.section("BulletEffects")
	RunManager.infiltration_risk_level = 1

	# ── ARMOR_SHRED: 피격 시 적 DEF 영구 감소 ──
	var shred: Array[BulletData] = [_bullet(3, 7, 3, Enums.BulletEffect.ARMOR_SHRED, 1)]
	var r_shred := _fire(_enemy(50, 3, 0, 10), shred)
	t.eq(r_shred.def, 2, "장갑 파쇄: 1발 명중 후 적 DEF 3→2")

	# ── LAST_SHOT: 탄창 마지막 탄 대미지 배율(x1.5) ──
	# LIFO이므로 먼저 장전한 탄이 마지막에 발사된다 → 배율탄을 맨 앞에 적재
	var plain3: Array[BulletData] = [_bullet(4, 7, 0), _bullet(4, 7, 0), _bullet(4, 7, 0)]
	var last3: Array[BulletData] = [_bullet(4, 7, 0, Enums.BulletEffect.LAST_SHOT, 150), _bullet(4, 7, 0), _bullet(4, 7, 0)]
	var r_plain := _fire(_enemy(50, 0, 0, 10), plain3)
	var r_last := _fire(_enemy(50, 0, 0, 10), last3)
	t.eq(r_plain.hp, 38, "기준: 4x3=12 대미지 (HP 50→38)")
	t.eq(r_last.hp, 36, "막탄 강화: 마지막 탄 4→6(x1.5) → 14 대미지 (HP 50→36)")

	# ── COMBO: 직전 격발이 명중했을 때 추가 대미지 ──
	# 첫 발은 직전 명중 이력이 없어 보너스 없음, 2발째부터 가산
	var combo3: Array[BulletData] = [
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2),
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2),
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2)]
	var r_combo := _fire(_enemy(50, 0, 0, 10), combo3)
	t.eq(r_combo.hp, 37, "콤보 사격: 3 + 5 + 5 = 13 대미지 (HP 50→37)")

	# ── CALIBER_DIFF: 교차 구경(UNIVERSAL)은 항상 추가 대미지 ──
	var uni2: Array[BulletData] = [
		_bullet(3, 7, 0, Enums.BulletEffect.CALIBER_DIFF, 4, Enums.WeaponClass.UNIVERSAL),
		_bullet(3, 7, 0, Enums.BulletEffect.CALIBER_DIFF, 4, Enums.WeaponClass.UNIVERSAL)]
	var r_uni := _fire(_enemy(50, 0, 0, 10), uni2)
	t.eq(r_uni.hp, 36, "교차 구경: (3+4)x2=14 대미지 (HP 50→36)")

	# ── OPENING_SHOT: 첫 탄 넉백 + 장갑 파쇄 -1 ──
	var opening: Array[BulletData] = [_bullet(3, 7, 3, Enums.BulletEffect.OPENING_SHOT, 2)]
	var r_open := _fire(_enemy(50, 3, 0, 10), opening)
	t.eq(r_open.def, 2, "선제 사격: 장갑 파쇄로 DEF 3→2")
	t.eq(r_open.dist, 12, "선제 사격: 첫 탄 넉백 +2 → 거리 10→12")

	# ══════════════════════════════════════════════════════════
	# 셋업 버프 (BUFF_ACC / BUFF_PEN) — 정본: docs/gdd/22_ammo_expansion.md §22.2
	#
	# 규칙: 다음 1발만 · 유효 적중 시에만 · 중첩 없음 · 리로드 소멸
	# ⚠️ LIFO — 나중에 넣은 탄이 먼저 나간다. 셋업을 뒤에 적재해야 먼저 발사된다.
	# ══════════════════════════════════════════════════════════

	# ── ACC 페이로드는 단독으로 빗나간다 ──
	var payload_only: Array[BulletData] = []
	for i in range(4):
		payload_only.append(_bullet(6, 2, 1))          # ACC2
	var r_solo := _fire(_enemy(30, 0, 5, 10), payload_only)   # EVA5
	t.eq(int(r_solo.hp), 30, "⭐ ACC 페이로드 단독 → 전탄 빗나감 (ACC2 < EVA5)")

	# ── 셋업을 끼우면 같은 탄이 통한다 ──
	var chained: Array[BulletData] = []
	for i in range(2):
		chained.append(_bullet(6, 2, 1))                                             # 페이로드(먼저 적재)
		chained.append(_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3))             # 셋업(나중 적재 = 먼저 발사)
	var r_chain := _fire(_enemy(30, 0, 5, 10), chained)
	t.check(int(r_chain.hp) < 30,
		"⭐ 셋업 + 페이로드 → 명중 (HP 30 → %d), 단독 실패에서 반전" % int(r_chain.hp))

	# ── PEN 셋업도 같은 구조 ──
	var pen_solo: Array[BulletData] = []
	for i in range(4):
		pen_solo.append(_bullet(7, 7, 0))              # PEN0
	var r_pen_solo := _fire(_enemy(40, 2, 0, 10), pen_solo)   # DEF2
	t.eq(int(r_pen_solo.hp), 40, "⭐ PEN 페이로드 단독 → 관통 실패 (PEN0 < DEF2)")

	var pen_chain: Array[BulletData] = []
	for i in range(2):
		pen_chain.append(_bullet(7, 7, 0))
		pen_chain.append(_bullet(1, 7, 2, Enums.BulletEffect.BUFF_PEN, 3))
	var r_pen_chain := _fire(_enemy(40, 2, 0, 10), pen_chain)
	t.check(int(r_pen_chain.hp) < 40,
		"⭐ PEN 셋업 + 페이로드 → 관통 (HP 40 → %d)" % int(r_pen_chain.hp))

	# ── 버프는 다음 1발만 (탄창 전체 지속 아님) ──
	# 셋업 1발 + 페이로드 3발 → 첫 페이로드만 맞고 나머지 둘은 빗나가야 한다.
	var leak_test: Array[BulletData] = []
	for i in range(3):
		leak_test.append(_bullet(6, 2, 1))
	leak_test.append(_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3))
	var r_leak := _fire(_enemy(30, 0, 5, 10), leak_test)
	# 셋업 1 + 버프받은 페이로드 6 = 7 피해. 나머지 2발은 빗나감.
	t.eq(int(r_leak.hp), 30 - 7,
		"⭐ 버프는 다음 1발만 — 페이로드 3발 중 1발만 명중 (누수 없음)")

	# ── 막힌 셋업은 버프를 주지 않는다 ──
	# "막힌 탄은 아무 일도 일으키지 않는다" — 셋업 자체가 리스크가 되어야 한다.
	var blocked_setter: Array[BulletData] = []
	for i in range(2):
		blocked_setter.append(_bullet(7, 2, 5))                                       # 페이로드(ACC2, PEN5)
		blocked_setter.append(_bullet(1, 8, 0, Enums.BulletEffect.BUFF_ACC, 3))       # 셋업 PEN0 → DEF3에 막힘
	var r_blocked := _fire(_enemy(40, 3, 5, 10), blocked_setter)
	t.eq(int(r_blocked.hp), 40,
		"⭐ 관통 실패한 셋업은 버프 미부여 → 뒤 페이로드도 빗나감 (유효 적중 조건)")
