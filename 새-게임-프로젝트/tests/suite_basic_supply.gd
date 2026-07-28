extends RefCounted
## 기본탄 고정 보급 슬롯 — 덱 분리 · 총기별 상한 · 리로드 복구 · LIFO 슬롯 점유.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const G_REVOLVER := "res://resources/guns/revolver.tres"
const G_DMR := "res://resources/guns/dmr.tres"
const B_BASIC := "res://resources/bullets/cal_9mm.tres"
const B_DMR := "res://resources/bullets/cal_762.tres"
const B_LINK := "res://resources/bullets/borer.tres"
const B_CONTROL := "res://resources/bullets/shred.tres"


static func _enemy(evasion: int = 0) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.display_name = "보급 테스트 표적"
	enemy.max_hp = 99
	enemy.defense = 0
	enemy.evasion = evasion
	enemy.speed = 0
	enemy.start_distance = 10
	return enemy


static func run(t) -> void:
	t.section("BasicSupply")

	var previous_ascension := RunManager.meta_ascension_level
	var previous_backpack := RunManager.meta_backpack_lvl
	RunManager.meta_ascension_level = 0
	RunManager.meta_backpack_lvl = 0

	var revolver: GunData = load(G_REVOLVER)
	var basic: BulletData = load(B_BASIC)
	var rm := RunManager.new()
	rm.start_new_run("section_a", revolver, basic, load(B_LINK), load(B_CONTROL))
	t.check(rm.basic_supply_bullet != null and rm.basic_supply_bullet.is_basic,
		"런이 선택 총기의 기반탄을 고정 보급원으로 보관")
	t.eq(rm.deck.size(), 3, "시작 전술 덱은 연계 2 + 공격 1 = 3발")
	t.check(rm.deck.all(func(b: BulletData) -> bool: return not b.is_basic),
		"기본탄은 런 덱 용량을 차지하지 않음")
	t.check(not rm.bullet_is_draft_eligible(basic), "기본탄은 드래프트 후보에서 제외")

	var cm := CombatManagerScript.new()
	var enemies: Array[EnemyData] = [_enemy()]
	var no_parts: Array[PartData] = []
	cm.start_encounter(revolver, enemies, rm.deck, no_parts, rm.basic_supply_bullet)
	t.eq(cm.basic_supply_capacity, 5, "리볼버 기본 보급 상한 = 탄창 5발")
	t.eq(cm.basic_supply_current, 5, "전투 시작 시 기본탄을 상한까지 지급")
	t.eq(cm.magazine.get_remaining(), 0, "보급탄은 탄창 한 칸을 강제 예약하지 않음")

	var loadout: Array[BulletData] = [basic, basic]
	cm.confirm_loading(loadout)
	t.eq(cm.magazine.get_remaining(), 2, "기본탄도 장전한 발마다 탄창 슬롯 1칸 점유")
	t.eq(cm.basic_supply_current, 3, "기본탄 2발 장전 시 보급 잔량 5→3")
	cm.fire()
	t.eq(cm.discard_pile.size(), 1, "유효 적중 기본탄은 리로드 전까지 버림 더미에 기록")
	cm.request_reload()
	t.eq(cm.basic_supply_current, 5, "리로드 완료 시 기본탄을 상한까지 복구")
	t.eq(cm.discard_pile.size(), 0, "복구된 기본탄은 버림 더미에서 제거")
	t.eq(cm.exile_pile.size(), 0, "복구 후 기본탄 소멸 기록 없음")
	cm.free()

	# 실패한 기본탄도 이번 사이클에서는 사라지지만 리로드 뒤 복구된다.
	var miss_cm := CombatManagerScript.new()
	var evasive: Array[EnemyData] = [_enemy(9)]
	miss_cm.start_encounter(revolver, evasive, rm.deck, no_parts, rm.basic_supply_bullet)
	var miss_loadout: Array[BulletData] = [basic]
	miss_cm.confirm_loading(miss_loadout)
	miss_cm.fire()
	t.eq(miss_cm.exile_pile.size(), 1, "실패 기본탄은 현재 재장전 사이클에서 소멸")
	miss_cm.request_reload()
	t.eq(miss_cm.basic_supply_current, 5, "실패 기본탄도 리로드 뒤 정량 복구")
	t.eq(miss_cm.exile_pile.size(), 0, "복구된 기본탄은 소멸 탭에서 제거")
	miss_cm.free()

	# 약실이 있는 총기는 실제 장전 한도(탄창+약실)를 보급 상한으로 사용한다.
	var dmr: GunData = load(G_DMR)
	var dmr_cm := CombatManagerScript.new()
	var empty_deck: Array[BulletData] = []
	dmr_cm.start_encounter(dmr, enemies, empty_deck, no_parts, load(B_DMR))
	t.eq(dmr_cm.basic_supply_capacity, 4, "DMR 보급 상한 = 탄창 3 + 약실 1")
	dmr_cm.free()

	# 기본탄은 승천 8에서도 런 덱 영구 소실 대상이 아니다.
	RunManager.meta_ascension_level = 8
	rm.deck = [basic]
	rm.exile_bullet_from_deck(basic)
	t.eq(rm.deck.size(), 1, "승천 8에서도 고정 보급 기본탄은 영구 제거하지 않음")

	RunManager.meta_ascension_level = previous_ascension
	RunManager.meta_backpack_lvl = previous_backpack
