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

	# ── LAST_SHOT: 탄창 마지막 탄 정액 피해 +4 ──
	# LIFO이므로 먼저 장전한 탄이 마지막에 발사된다 → 마무리탄을 맨 앞에 적재
	var plain3: Array[BulletData] = [_bullet(4, 7, 0), _bullet(4, 7, 0), _bullet(4, 7, 0)]
	var last3: Array[BulletData] = [_bullet(4, 7, 0, Enums.BulletEffect.LAST_SHOT, 4), _bullet(4, 7, 0), _bullet(4, 7, 0)]
	var r_plain := _fire(_enemy(50, 0, 0, 10), plain3)
	var r_last := _fire(_enemy(50, 0, 0, 10), last3)
	t.eq(r_plain.hp, 38, "기준: 4x3=12 대미지 (HP 50→38)")
	t.eq(r_last.hp, 34, "마무리탄: 마지막 탄 4→8(+4) → 16 대미지 (HP 50→34)")

	# ── COMBO: 직전 격발이 명중했을 때 추가 대미지 ──
	# 첫 발은 직전 명중 이력이 없어 보너스 없음, 2발째부터 가산
	var combo3: Array[BulletData] = [
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2),
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2),
		_bullet(3, 7, 0, Enums.BulletEffect.COMBO, 2)]
	var r_combo := _fire(_enemy(50, 0, 0, 10), combo3)
	t.eq(r_combo.hp, 37, "콤보 사격: 3 + 5 + 5 = 13 대미지 (HP 50→37)")

	# ── CALIBER_DIFF: 구체 구경 경계 뒤에서만 추가 대미지 ──
	var uni2: Array[BulletData] = [
		_bullet(3, 7, 0, Enums.BulletEffect.CALIBER_DIFF, 4, Enums.WeaponClass.UNIVERSAL),
		_bullet(3, 7, 0, Enums.BulletEffect.NONE, 0, Enums.WeaponClass.DMR)]
	var r_uni := _fire(_enemy(50, 0, 0, 10), uni2)
	t.eq(r_uni.hp, 40, "교차 구경: 3 + (3+4)=10 대미지 (HP 50→40)")

	# ── OPENING_SHOT: 첫 탄 넉백 + 장갑 파쇄 -1 ──
	var opening: Array[BulletData] = [_bullet(3, 7, 3, Enums.BulletEffect.OPENING_SHOT, 2)]
	var r_open := _fire(_enemy(50, 3, 0, 10), opening)
	t.eq(r_open.def, 2, "선제 사격: 장갑 파쇄로 DEF 3→2")
	t.eq(r_open.dist, 12, "선제 사격: 첫 탄 넉백 +2 → 거리 10→12")

	# ══════════════════════════════════════════════════════════
	# 연계 버프 (BUFF_ACC / BUFF_PEN) — 정본: docs/gdd/22_ammo_expansion.md §22.2
	#
	# 규칙: 다음 1발만 · 유효 적중 시에만 · 중첩 없음 · 리로드 소멸
	# ⚠️ LIFO — 나중에 넣은 탄이 먼저 나간다. 연계탄을 뒤에 적재해야 먼저 발사된다.
	# ══════════════════════════════════════════════════════════

	# ── 공격탄은 일반 적에게 단독으로 작동한다 ──
	var attack_only: Array[BulletData] = []
	for i in range(4):
		attack_only.append(_bullet(5, 5, 1))
	var r_solo := _fire(_enemy(30, 0, 5, 10), attack_only)
	t.eq(int(r_solo.hp), 10, "⭐ 공격탄 단독 → 일반 EVA5 적에게 5×4=20 피해")

	# ── 연계탄은 같은 공격탄의 대응 범위를 고회피 적까지 넓힌다 ──
	var chained: Array[BulletData] = []
	for i in range(2):
		chained.append(_bullet(5, 5, 1))                                             # 공격(먼저 적재)
		chained.append(_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3))             # 연계(나중 적재)
	var r_chain := _fire(_enemy(30, 0, 7, 10), chained)
	t.eq(int(r_chain.hp), 14,
		"⭐ ACC 연계→크리티컬 공격 2쌍 = 16 피해, EVA7 전문 적까지 대응")

	# ── PEN2 공격탄은 일반 장갑에 단독으로 작동한다 ──
	var pen_solo: Array[BulletData] = []
	for i in range(4):
		pen_solo.append(_bullet(5, 7, 2))
	var r_pen_solo := _fire(_enemy(40, 2, 0, 10), pen_solo)
	t.eq(int(r_pen_solo.hp), 20, "⭐ PEN2 공격탄 단독 → 일반 DEF2 적에게 5×4=20 피해")

	# PEN 연계는 동일 공격탄을 DEF3 전문 적까지 확장한다.
	var pen_chain: Array[BulletData] = []
	for i in range(2):
		pen_chain.append(_bullet(5, 7, 2))
		pen_chain.append(_bullet(1, 7, 3, Enums.BulletEffect.BUFF_PEN, 3))
	var r_pen_chain := _fire(_enemy(40, 3, 0, 10), pen_chain)
	t.eq(int(r_pen_chain.hp), 24,
		"⭐ PEN 연계→크리티컬 공격 2쌍 = 16 피해, DEF3 전문 적까지 대응")

	# ── 버프는 다음 1발만 (탄창 전체 지속 아님) ──
	# 연계 1발 + 공격 3발 → 첫 공격만 맞고 나머지 둘은 빗나가야 한다.
	var leak_test: Array[BulletData] = []
	for i in range(3):
		leak_test.append(_bullet(5, 5, 1))
	leak_test.append(_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3))
	var r_leak := _fire(_enemy(30, 0, 7, 10), leak_test)
	# 연계 1 + 버프받은 크리티컬 공격 7 = 8 피해. 나머지 2발은 빗나감.
	t.eq(int(r_leak.hp), 22,
		"⭐ 버프는 다음 1발만 — 공격탄 3발 중 1발만 명중 (누수 없음)")

	# ── 막힌 연계탄은 버프를 주지 않는다 ──
	# "막힌 탄은 아무 일도 일으키지 않는다" — 연계 자체가 리스크가 되어야 한다.
	var blocked_link: Array[BulletData] = []
	for i in range(2):
		blocked_link.append(_bullet(5, 5, 5))                                         # 공격 ACC5
		blocked_link.append(_bullet(1, 8, 0, Enums.BulletEffect.BUFF_ACC, 3))         # 연계 PEN0 → DEF3 도탄
	var r_blocked := _fire(_enemy(40, 3, 7, 10), blocked_link)
	t.eq(int(r_blocked.hp), 40,
		"⭐ 관통 실패한 연계는 버프 미부여 → 뒤 공격탄도 EVA7에 빗나감")

	# ══════════════════════════════════════════════════════════
	# 버프-인지 게이트 미리보기 (정본: CombatManager.preview_next_shot)
	#
	# ⚠️ v5 이전의 판정 표시는 버프를 무시해 "실제로는 뚫리는데 도탄 ✗"로 거짓말을 했다.
	#    preview_next_shot이 대기 버프를 반영하는지 실증한다. UI는 이 값만 읽는다.
	# ══════════════════════════════════════════════════════════
	var cm := CombatManagerScript.new()
	var gun2: GunData = load(G_REVOLVER)
	var e2: Array[EnemyData] = [_enemy(30, 3, 0, 10)]  # DEF3
	# 연계(PEN2, BUFF_PEN+3) → 공격(PEN0). LIFO: 연계탄을 뒤에 넣어 먼저 발사.
	var lo2: Array[BulletData] = [_bullet(7, 7, 0), _bullet(1, 7, 2, Enums.BulletEffect.BUFF_PEN, 3)]
	var np2: Array[PartData] = []
	cm.start_encounter(gun2, e2, lo2, np2)
	cm.confirm_loading(lo2)

	# 첫 탄(셋업) 발사 전 — 셋업 자체는 PEN2 < DEF3
	var pv_link: Dictionary = cm.preview_next_shot()
	t.eq(int(pv_link.pen), 2, "미리보기: 연계탄 PEN 2 (버프 대기 없음)")
	t.check(not pv_link.buffed_pen, "미리보기: 아직 버프 없음")

	cm.fire()  # 연계탄 PEN2 < DEF3 → 도탄, 버프 미생성.
	var pv_after_blocked: Dictionary = cm.preview_next_shot()
	t.check(not pv_after_blocked.buffed_pen, "⭐ 막힌 연계 후 — 공격탄 미리보기에 버프 없음")
	cm.free()

	# 이번엔 연계가 게이트를 넘는 경우: DEF1 적 → PEN2 ≥ 1 통과 → 버프 부여
	var cm3 := CombatManagerScript.new()
	var e3: Array[EnemyData] = [_enemy(30, 1, 0, 10)]  # DEF1
	var lo3: Array[BulletData] = [_bullet(7, 7, 0), _bullet(1, 7, 2, Enums.BulletEffect.BUFF_PEN, 3)]
	cm3.start_encounter(gun2, e3, lo3, np2)
	cm3.confirm_loading(lo3)
	cm3.fire()  # 연계탄 발사(PEN2 ≥ DEF1 통과) → BUFF_PEN+3 대기
	var pv_buffed: Dictionary = cm3.preview_next_shot()
	t.eq(int(pv_buffed.pen), 0 + 3, "⭐ 연계 적중 후 — 공격탄 미리보기 PEN 0→3")
	t.check(pv_buffed.buffed_pen, "⭐ 미리보기가 버프 적용을 표시 (거짓 도탄 표시 해소)")
	t.check(bool(pv_buffed.critical), "⭐ 인접 버프만으로 열린 게이트를 격발 전에 크리티컬 표시")
	cm3.free()

	# 구경 무관 탄은 실패 시 런 덱 영구 소실 위험을 격발 전에 공개한다.
	var cm4 := CombatManagerScript.new()
	var universal := _bullet(2, 7, 1, Enums.BulletEffect.NONE, 0, Enums.WeaponClass.UNIVERSAL)
	var e4: Array[EnemyData] = [_enemy(30, 3, 0, 10)]
	var lo4: Array[BulletData] = [universal]
	cm4.start_encounter(gun2, e4, lo4, np2)
	cm4.confirm_loading(lo4)
	var pv_loss := cm4.preview_next_shot()
	t.check(bool(pv_loss.permanent_loss_on_failure),
		"⭐ 범용탄 게이트 실패의 런 덱 영구 소실 위험 사전 표시")
	cm4.free()
