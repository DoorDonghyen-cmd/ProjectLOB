extends RefCounted
## 파츠 중심 빌드 분기 상점 회귀.

const MaintenanceOverlay := preload("res://scripts/ui/overlays/maintenance_overlay.gd")


static func _part_entries(shop: MaintenanceOverlay) -> Array:
	var entries: Array = []
	for entry in shop._shop_items:
		if entry.item is PartData:
			entries.append(entry)
	return entries


static func _part_ids_from_paths(paths: Array) -> Array[int]:
	var ids: Array[int] = []
	for path in paths:
		var part := load(str(path)) as PartData
		if part != null:
			ids.append(part.part_id)
	return ids


static func run(t) -> void:
	t.section("PartShop")

	# 첫 구역 첫 상점: 탄환 1 + 리듬 유지/역할 전환 파츠 2, 파츠는 둘 중 하나만 구매.
	var rm := RunManager.new()
	rm.current_section = "section_a"
	rm.current_gun = (load("res://resources/guns/revolver.tres") as GunData).duplicate()
	var shop := MaintenanceOverlay.new()
	shop.run_manager = rm
	shop._reroll_count = 0
	shop._generate_shop_items()
	var first_parts := _part_entries(shop)
	t.eq(shop._shop_items.size(), 3, "상점 카드 수는 전술탄 1 + 파츠 분기 2")
	t.eq(first_parts.size(), 2, "첫 상점에 파츠 두 장 노출")
	if first_parts.size() == 2:
		t.eq(first_parts[0].item.part_id, Enums.PartID.RHYTHM_CHAMBER, "첫 분기 A는 동일 역할 유지용 리듬 챔버")
		t.eq(first_parts[1].item.part_id, Enums.PartID.INTERRUPTER, "첫 분기 B는 역할 전환용 인터럽터")
		t.eq(str(first_parts[0].offer_kind), "maintain", "첫 분기 A의 연속 운용 문법 태그")
		t.eq(str(first_parts[0].offer_label), "A · 연속 운용", "첫 분기 A를 카드에서 직접 설명")
		t.eq(str(first_parts[1].offer_kind), "switch", "첫 분기 B의 운용 전환 문법 태그")
		t.eq(str(first_parts[1].offer_label), "B · 운용 전환", "첫 분기 B를 카드에서 직접 설명")
		for entry in first_parts:
			t.eq(entry.price, MaintenanceOverlay.FIRST_SECTION_PART_PRICE, "첫 구역 파츠 가격 30Cr 고정")
			t.eq(str(entry.exclusive_group), MaintenanceOverlay.PART_CHOICE_GROUP, "두 파츠가 동일 배타 그룹")
			t.check(not str(entry.offer_reason).is_empty(), "분기 카드에 선택 이유 표시")

	shop._mark_shop_offer_sold(1)
	t.check(not bool(shop._shop_items[0].sold_out), "파츠 구매 후 전술탄 카드는 유지")
	t.check(bool(shop._shop_items[1].sold_out), "구매한 파츠 품절")
	t.check(bool(shop._shop_items[2].sold_out), "반대 빌드 분기도 함께 품절")
	t.check(bool(shop._shop_items[1].selected), "구매한 카드는 선택 완료 상태")
	t.check(bool(shop._shop_items[2].locked_by_choice), "반대 카드는 분기 폐쇄 상태")
	var offer_snapshots := shop._shop_offer_snapshots()
	t.eq(str(offer_snapshots[1].id), "rhythm_chamber", "로그 스냅샷에 선택 파츠 ID")
	t.eq(str(offer_snapshots[1].offer_kind), "maintain", "로그 스냅샷에 빌드 분기 유형")
	t.check(bool(offer_snapshots[1].selected), "로그 스냅샷에 선택 완료 상태")
	t.check(bool(offer_snapshots[2].locked_by_choice), "로그 스냅샷에 반대 분기 폐쇄 상태")
	shop.free()

	# 일반 풀은 실제 장착 가능한 20종만 포함하며 고유/전용/컨버전 파츠를 섞지 않는다.
	var general_ids := _part_ids_from_paths(MaintenanceOverlay.SHOP_GENERAL_PART_PATHS)
	t.eq(general_ids.size(), 20, "일반 상점 파츠 풀 20종")
	var unique_ids := {}
	for part_id in general_ids:
		unique_ids[part_id] = true
	t.eq(unique_ids.size(), general_ids.size(), "일반 파츠 풀에 중복 경로 없음")
	t.check(unique_ids.has(Enums.PartID.SCOPE), "누락됐던 일반 스코프를 상점 풀에 포함")
	t.check(not unique_ids.has(Enums.PartID.POINT_BLANK), "샷건 고정 포인트블랭크 일반 풀 제외")
	t.check(not unique_ids.has(Enums.PartID.MARKSMAN_SCOPE), "DMR 고정 저격경 일반 풀 제외")
	t.check(not unique_ids.has(Enums.PartID.SPREAD_SHOT), "확산 격발은 샷건 친화 풀에만 배치")
	for part_id in general_ids:
		t.check(part_id < Enums.PartID.CONVERSION_PISTOL, "일반 풀에 컨버전 킷 없음: PartID %d" % part_id)

	var shotgun_affinity := _part_ids_from_paths(
		MaintenanceOverlay.GUN_AFFINITY_PART_PATHS[Enums.WeaponClass.SHOTGUN]
	)
	t.check(shotgun_affinity.has(Enums.PartID.SPREAD_SHOT), "확산 격발을 샷건 친화 보상으로 획득 가능")

	# 이후 구역: 보유 앵커의 후속 파츠 + 현재 총기 친화 파츠를 제시하고 중복은 제외.
	var later_rm := RunManager.new()
	later_rm.current_section = "section_b"
	later_rm.current_gun = (load("res://resources/guns/revolver.tres") as GunData).duplicate()
	later_rm.equipped_parts.append(load("res://resources/parts/rhythm_chamber.tres") as PartData)
	later_rm.backpack_items.append(load("res://resources/parts/target_indicator.tres") as PartData)
	later_rm.hold_part = load("res://resources/parts/high_precision.tres") as PartData
	var later_shop := MaintenanceOverlay.new()
	later_shop.run_manager = later_rm
	later_shop._generate_shop_items()
	var later_parts := _part_entries(later_shop)
	t.eq(later_parts.size(), 2, "후속 구역도 파츠 분기 두 장")
	if later_parts.size() == 2:
		var followup_ids := _part_ids_from_paths(
			MaintenanceOverlay.PART_FOLLOWUP_PATHS[Enums.PartID.RHYTHM_CHAMBER]
		)
		t.check(followup_ids.has(later_parts[0].item.part_id), "첫 카드는 현재 리듬 빌드의 후속 시너지")
		t.eq(later_parts[1].item.part_id, Enums.PartID.RECOIL_PUSH, "둘째 카드는 보유 중복을 뺀 권총 친화 파츠")
		t.eq(str(later_parts[0].offer_label), "A · 후속 시너지", "후속 파츠 선택 이유 라벨")
		t.check(str(later_parts[0].offer_reason).contains("리듬 챔버"), "후속 시너지 설명에 실제 앵커 파츠명 표시")
		t.eq(str(later_parts[1].offer_label), "B · 총기 친화", "총기 친화 선택 이유 라벨")
		t.check(str(later_parts[1].offer_reason).contains(later_rm.current_gun.display_name), "친화 설명에 현재 총기명 표시")
		t.check(later_parts[0].item.part_id != later_parts[1].item.part_id, "두 분기 파츠는 서로 다름")
		for entry in later_parts:
			t.check(entry.item.part_id != Enums.PartID.RHYTHM_CHAMBER, "장착 파츠 중복 제안 제외")
			t.check(entry.item.part_id != Enums.PartID.TARGET_INDICATOR, "가방 파츠 중복 제안 제외")
			t.check(entry.item.part_id != Enums.PartID.HIGH_PRECISION, "임시 보관 파츠 중복 제안 제외")
	later_shop.free()
