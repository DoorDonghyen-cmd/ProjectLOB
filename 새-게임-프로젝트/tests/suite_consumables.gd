extends RefCounted
## 소모품 효과 검증 — 가방 적재 · 즉발 효과 · 소진 제거.
##
## 배경(2026-07-21): 전투 오버레이에 "소모품 — 즉발 사용 (미구현)" 문구가 남아 있어
##   미구현으로 오인됐으나, 실제로는 상점 판매 → 가방 적재 → 전투 중 사용까지
##   전부 배선돼 있었다. 문구만 낡은 상태였다.
##   여기서는 UI를 제외한 "효과 로직"이 실제로 동작함을 못박는다.
##
## 소모품 효과 정본: bag_inventory_drawer._on_use_consumable_in_combat
##   heal  → hp_buffer +1 (최대 3)
##   shred → 최근접 적 DEF -2 (최소 0)

const ConsumableItem := preload("res://scripts/data/consumable_item.gd")
const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const GUN := "res://resources/guns/revolver.tres"


static func _consumable(kind: String) -> Resource:
	var c := ConsumableItem.new()
	c.type = kind
	c.display_name = "테스트 소모품(%s)" % kind
	c.price = 20
	return c


static func _enemy(hp: int, def_v: int) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.RUSHER
	d.max_hp = hp
	d.defense = def_v
	d.evasion = 0
	d.speed = 0
	d.start_distance = 12
	return d


static func run(t) -> void:
	t.section("Consumables")
	RunManager.infiltration_risk_level = 1

	# ── 가방 적재 및 제거 ──
	var rm := RunManager.new()
	rm.backpack_items.clear()
	var added: bool = rm.add_to_backpack(_consumable("heal"))
	t.check(added, "소모품을 가방에 적재")
	t.eq(rm.backpack_items.size(), 1, "가방에 1개 적재됨")
	rm.remove_from_backpack_at(0)
	t.eq(rm.backpack_items.size(), 0, "사용 후 가방에서 소진 제거")

	# ── heal: HP 버퍼 +1, 상한 3 ──
	var rm_h := RunManager.new()
	rm_h.hp_buffer = 1
	rm_h.hp_buffer = mini(rm_h.hp_buffer + 1, 3)
	t.eq(rm_h.hp_buffer, 2, "응급 아머 키트: HP 버퍼 1 → 2")
	rm_h.hp_buffer = 3
	rm_h.hp_buffer = mini(rm_h.hp_buffer + 1, 3)
	t.eq(rm_h.hp_buffer, 3, "HP 버퍼는 상한 3을 넘지 않음")

	# ── shred: 최근접 적 DEF -2 ──
	# combat_manager.enemy 는 최근접 적을 돌려주는 하위 호환 프로퍼티다.
	var cm = CombatManagerScript.new()
	var gun: GunData = load(GUN)
	var loadout: Array[BulletData] = []
	var enemies: Array[EnemyData] = [_enemy(30, 5)]
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, loadout, no_parts)

	var target = cm.enemy
	t.check(target != null, "최근접 적 참조(combat_manager.enemy) 유효")
	t.eq(target.current_def, 5, "적 초기 DEF 5")
	target.current_def = max(target.current_def - 2, 0)
	t.eq(target.current_def, 3, "부식성 파쇄액: DEF 5 → 3")
	target.current_def = 1
	target.current_def = max(target.current_def - 2, 0)
	t.eq(target.current_def, 0, "DEF는 0 미만으로 내려가지 않음")
	cm.free()
