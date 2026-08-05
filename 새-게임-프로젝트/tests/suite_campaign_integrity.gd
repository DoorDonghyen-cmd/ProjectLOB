extends RefCounted
## 캠페인 관문 편성·정식 보상 카탈로그·스타팅 보증 적용 회귀.

const CampaignContentScript := preload("res://scripts/core/campaign_content.gd")
const ItemCatalogScript := preload("res://scripts/core/item_catalog.gd")
const CombatSceneScript := preload("res://scripts/ui/combat_scene.gd")

const GUN := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/cal_9mm.tres"
const B_LINK := "res://resources/bullets/borer.tres"
const B_CONTROL := "res://resources/bullets/shred.tres"


static func _enemy_ids(enemies: Array[EnemyData]) -> Array[String]:
	var result: Array[String] = []
	for enemy in enemies:
		result.append(enemy.resource_path.get_file().get_basename())
	return result


static func run(t) -> void:
	t.section("CampaignIntegrity")

	# ── 5개 관문: 보스 4종(A/B/C/E) + D 정예 관문 ──
	var expected := {
		"section_a": ["boss_director"],
		"section_b": ["rusher", "tank", "boss_seraph"],
		"section_c": ["boss_omega"],
		"section_d": ["absorber_mech", "rusher", "neuro_caster"],
		"section_e": ["rusher", "dodger", "tank", "boss_lob_core"],
	}
	for section in expected:
		var enemies := CampaignContentScript.load_gate_encounter(section)
		t.eq(_enemy_ids(enemies), expected[section], "%s 관문 편성 정본" % section)
		var boss_count := 0
		for enemy in enemies:
			if enemy.is_boss:
				boss_count += 1
		t.eq(boss_count, 1 if CampaignContentScript.is_boss_section(section) else 0,
			"%s 보스 수" % section)
	t.eq(CampaignContentScript.boss_count(), 4, "캠페인 보스는 4종")

	var map_rm := RunManager.new()
	map_rm.start_new_run("section_d", load(GUN), load(B_BASIC), load(B_LINK), load(B_CONTROL))
	t.check(map_rm.map_nodes[701].type_name.contains("정예 관문"),
		"관리 계층 마지막 노드는 보스가 아닌 정예 관문으로 표시")
	var elite_gate := RunManager.RunNode.new(
		701, "관리 중추 (정예 관문)", "", ["stairs"] as Array[String])
	t.eq(map_rm.record_node_clear(elite_gate), 2, "정예 관문도 주요 관문 TDC 2 지급")

	# ── 아이템 카탈로그: 디렉터리 전수 탐색 없이 정식 후보만 노출 ──
	var tier_one := ItemCatalogScript.general_parts(1)
	t.eq(tier_one.size(), 4, "스타팅 보증 1티어 파츠 후보 4종")
	for part in tier_one:
		t.eq(part.tier, 1, "%s는 실제 1티어" % part.display_name)
		t.check(not part.is_conversion_kit(), "%s는 컨버전 킷이 아님" % part.display_name)

	var gun := load(GUN) as GunData
	var tactical_bullets := ItemCatalogScript.tactical_bullets(gun)
	t.eq(tactical_bullets.size(), ItemCatalogScript.SHOP_BULLET_IDS.size(),
		"암시장 탄환은 정식 전술탄 카탈로그 사용")
	for bullet in tactical_bullets:
		t.check(not bullet.is_basic, "%s는 기본 보급탄이 아님" % bullet.display_name)
		t.check(bullet.weapon_class == Enums.WeaponClass.UNIVERSAL \
			or bullet.weapon_class == gun.weapon_class,
			"%s는 현재 총기 호환" % bullet.display_name)

	# ── 스타팅 보증: 런 초기화 뒤 한 번만 적용 ──
	var previous_vault := RunManager.saved_vault_credits
	var previous_bonus_available := RunManager.starting_bonus_available
	RunManager.saved_vault_credits = 0
	RunManager.starting_bonus_available = true
	var credit_rm := RunManager.new()
	credit_rm.queue_starting_bonus_credits(50)
	credit_rm.start_new_run("section_a", gun, load(B_BASIC), load(B_LINK), load(B_CONTROL))
	t.eq(credit_rm.credits, 50, "스타팅 50Cr가 런 초기화 뒤 적용")
	credit_rm.start_new_run("section_a", gun, load(B_BASIC), load(B_LINK), load(B_CONTROL))
	t.eq(credit_rm.credits, 0, "스타팅 50Cr는 다음 런에 반복 적용되지 않음")

	var part_rm := RunManager.new()
	part_rm.queue_starting_bonus_part(tier_one[0])
	part_rm.start_new_run("section_a", gun, load(B_BASIC), load(B_LINK), load(B_CONTROL))
	t.eq(part_rm.backpack_items.size(), 1, "스타팅 파츠가 런 초기화 뒤 가방에 지급")
	if not part_rm.backpack_items.is_empty():
		t.eq((part_rm.backpack_items[0] as PartData).tier, 1, "지급된 스타팅 파츠 티어 1")

	# ── 암시장: 가방 포화 결제 차단 + 정식 후보 지급 ──
	var scene = CombatSceneScript.new()
	var full_rm := RunManager.new()
	full_rm.current_gun = gun
	full_rm.credits = 100
	for i in range(RunManager.BACKPACK_CAPACITY):
		full_rm.backpack_items.append(PartData.new())
	scene._rm = full_rm
	t.check(not scene._purchase_blackmarket_part(), "가방 포화 시 암시장 파츠 구매 거부")
	t.eq(full_rm.credits, 100, "가방 포화 시 크레딧 미차감")

	var market_rm := RunManager.new()
	market_rm.current_gun = gun
	market_rm.credits = 100
	scene._rm = market_rm
	t.check(scene._purchase_blackmarket_part(), "암시장 정식 파츠 구매 성공")
	t.eq(market_rm.credits, 70, "암시장 파츠 비용 30Cr")
	if not market_rm.backpack_items.is_empty():
		var market_part := market_rm.backpack_items[0] as PartData
		t.check(not market_part.is_conversion_kit(), "암시장 파츠에 컨버전 킷 없음")
		var allowed_part_ids := {}
		for allowed_part in ItemCatalogScript.general_parts():
			allowed_part_ids[allowed_part.part_id] = true
		t.check(allowed_part_ids.has(market_part.part_id), "암시장 파츠가 정식 일반 풀에 속함")

	t.check(scene._purchase_blackmarket_bullet(), "암시장 정식 전술탄 구매 성공")
	t.eq(market_rm.credits, 55, "암시장 탄환 비용 15Cr")
	var bought_bullet := market_rm.deck.back() as BulletData
	t.check(not bought_bullet.is_basic, "암시장에서 기본 보급탄을 지급하지 않음")
	scene.free()

	RunManager.saved_vault_credits = previous_vault
	RunManager.starting_bonus_available = previous_bonus_available
