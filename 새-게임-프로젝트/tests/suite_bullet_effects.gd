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
