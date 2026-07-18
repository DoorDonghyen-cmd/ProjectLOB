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


## 지정 파츠를 장착하고 ACC6/DMG3 탄 5발을 격발한 뒤 적 잔여 HP를 반환한다.
static func _remaining_hp(gun: GunData, enemy_data: EnemyData, parts: Array[PartData]) -> int:
	var cm = CombatManagerScript.new()
	var loadout: Array[BulletData] = []
	for i in range(5):
		loadout.append(_bullet(3, 6, 0))
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


static func run(t) -> void:
	t.section("Parts(application)")
	RunManager.infiltration_risk_level = 1
	var gun: GunData = load(GUN)

	# ACC6 탄 vs EVA7 적: 파츠 없으면 전탄 빗나감(HP 불변)
	var no_parts: Array[PartData] = []
	var hp_without := _remaining_hp(gun, _enemy(20, 0, 7), no_parts)
	t.eq(hp_without, 20, "파츠 미장착: ACC6 < EVA7 전탄 빗나감 → HP 불변")

	# HIGH_PRECISION(ACC+2) 장착: ACC8 >= EVA7 → 명중 발생
	var with_hp: Array[PartData] = [_part(Enums.PartID.HIGH_PRECISION)]
	var hp_with := _remaining_hp(gun, _enemy(20, 0, 7), with_hp)
	t.check(hp_with < hp_without, "HIGH_PRECISION 장착 시 ACC+2로 명중 발생 → HP 감소 (%d < %d)" % [hp_with, hp_without])
	t.eq(hp_with, 5, "명중 5발 × DMG3 = 15 → HP 20→5 (파츠 효과 정확 반영)")

	# 대조군: 무관한 파츠(QUICK_LOAD)는 명중에 영향 없음 → 여전히 빗나감
	var irrelevant: Array[PartData] = [_part(Enums.PartID.QUICK_LOAD)]
	var hp_irrelevant := _remaining_hp(gun, _enemy(20, 0, 7), irrelevant)
	t.eq(hp_irrelevant, 20, "명중 무관 파츠(QUICK_LOAD)는 ACC 미변화 → 여전히 빗나감")
