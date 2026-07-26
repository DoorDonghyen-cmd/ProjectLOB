extends RefCounted
## 컨버전 킷 회귀 — 데이터, 장착 제한, 소멸 면제, 승천 8등급, 드래프트 가중, 무기고 가격.

const MaintenanceOverlay := preload("res://scripts/ui/overlays/maintenance_overlay.gd")

const KIT_PATHS := [
	"res://resources/parts/conversion_pistol.tres",
	"res://resources/parts/conversion_smg.tres",
	"res://resources/parts/conversion_rifle.tres",
	"res://resources/parts/conversion_dmr.tres",
	"res://resources/parts/conversion_shotgun.tres",
]


static func _bullet(name: String, cls: int) -> BulletData:
	var b := BulletData.new()
	b.display_name = name
	b.weapon_class = cls
	return b


static func _deck_has(rm: RunManager, name: String) -> bool:
	for bullet in rm.deck:
		if bullet.display_name == name:
			return true
	return false


static func run(t) -> void:
	t.section("ConversionKit")

	# ── 5개 클래스 데이터 ──
	var kits: Array[PartData] = []
	for i in range(KIT_PATHS.size()):
		var kit := load(KIT_PATHS[i]) as PartData
		t.check(kit != null, "컨버전 킷 리소스 로드: %s" % KIT_PATHS[i].get_file())
		if kit != null:
			kits.append(kit)
			t.check(kit.is_conversion_kit(), "%s는 컨버전 킷" % kit.display_name)
			t.eq(kit.conversion_class, i, "%s 대상 클래스 일치" % kit.display_name)
	t.eq(kits.size(), 5, "탄환 클래스별 컨버전 킷 5종")

	# ── 총기별 가격 배수와 실제 가격 ──
	var expected_costs := {
		"trickster": 0.7, "gambler": 0.8,
		"revolver": 1.0, "smg": 1.0, "shotgun": 1.0, "suppressor": 1.0,
		"stance_hunter": 1.2, "heavy": 1.5, "dmr": 1.5,
	}
	for gun_id in expected_costs:
		var csv := DataLoader.get_gun(gun_id)
		t.check(not csv.is_empty(), "%s 총기 CSV 존재" % gun_id)
		t.eq(float(csv.conversion_cost), float(expected_costs[gun_id]), "%s conversion_cost" % gun_id)

	var trickster := load("res://resources/guns/trickster.tres") as GunData
	var revolver := load("res://resources/guns/revolver.tres") as GunData
	var heavy := load("res://resources/guns/heavy.tres") as GunData
	t.eq(MaintenanceOverlay.conversion_kit_price(trickster), 56, "곡예형 킷 가격 80×0.7 = 56Cr")
	t.eq(MaintenanceOverlay.conversion_kit_price(revolver), 80, "표준형 킷 가격 80Cr")
	t.eq(MaintenanceOverlay.conversion_kit_price(heavy), 120, "중장형 킷 가격 80×1.5 = 120Cr")

	# ── 장착 제한: 자기 클래스 금지, 총기당 1개, 기존 킷 교체 허용 ──
	var rm := RunManager.new()
	rm.current_gun = revolver.duplicate()
	var pistol_kit := kits[Enums.WeaponClass.PISTOL]
	var smg_kit := kits[Enums.WeaponClass.SMG]
	var rifle_kit := kits[Enums.WeaponClass.RIFLE]
	t.check(not rm.equip_part_to_slot(pistol_kit), "권총에 자기 클래스 9mm 킷 장착 불가")
	t.check(rm.equip_part_to_slot(rifle_kit), "권총에 5.56mm 킷 장착")
	t.check(not rm.equip_part_to_slot(smg_kit), "두 번째 컨버전 킷 동시 장착 불가")
	var replaced := rm.replace_equipped_part(0, smg_kit)
	t.eq(replaced, rifle_kit, "기존 킷 슬롯은 다른 킷으로 교체 가능")
	t.eq(rm.get_conversion_class(), Enums.WeaponClass.SMG, "교체 후 .45ACP 전용화")

	# ── 획득 가중치: 대상 클래스만 3배 ──
	t.eq(rm.bullet_draft_weight(_bullet("SMG", Enums.WeaponClass.SMG)), 3, "킷 대상 탄환 드래프트 가중치 3")
	t.eq(rm.bullet_draft_weight(_bullet("Rifle", Enums.WeaponClass.RIFLE)), 1, "비대상 탄환 드래프트 가중치 1")

	# ── 소멸 면제: 주력 클래스 + 킷 클래스 보호, 그 외는 소멸 ──
	var native := _bullet("native", Enums.WeaponClass.PISTOL)
	var converted := _bullet("converted", Enums.WeaponClass.SMG)
	var foreign := _bullet("foreign", Enums.WeaponClass.RIFLE)
	var universal := _bullet("universal", Enums.WeaponClass.UNIVERSAL)
	rm.deck = [native, converted, foreign]
	var old_ascension := RunManager.meta_ascension_level
	RunManager.meta_ascension_level = 0
	rm.exile_bullet_from_deck(native)
	rm.exile_bullet_from_deck(converted)
	rm.exile_bullet_from_deck(foreign)
	t.check(_deck_has(rm, "native"), "주력 권총탄 소멸 면제")
	t.check(_deck_has(rm, "converted"), "킷 대상 .45ACP 탄 소멸 면제")
	t.check(not _deck_has(rm, "foreign"), "비대상 5.56mm 탄은 영구 소멸")

	var no_kit_rm := RunManager.new()
	no_kit_rm.current_gun = revolver.duplicate()
	t.eq(no_kit_rm.bullet_draft_weight(universal), 1, "킷 미장착 시 범용탄 드래프트 가중치도 기본값")
	no_kit_rm.deck = [universal]
	no_kit_rm.exile_bullet_from_deck(universal)
	t.check(not _deck_has(no_kit_rm, "universal"), "킷 미장착 시 범용탄은 잘못 보호되지 않음")

	# 승천 8등급은 주력·킷 안전장치를 모두 해제한다.
	RunManager.meta_ascension_level = 8
	rm.deck = [native, converted]
	rm.exile_bullet_from_deck(native)
	rm.exile_bullet_from_deck(converted)
	t.check(not _deck_has(rm, "native"), "승천8: 주력탄 소멸 면제 해제")
	t.check(not _deck_has(rm, "converted"), "승천8: 킷 탄 소멸 면제 해제")
	RunManager.meta_ascension_level = old_ascension

	# ── 무기고: 자기 클래스를 뺀 킷 1종을 총기 배수 가격으로 진열 ──
	var shop := MaintenanceOverlay.new()
	shop.run_manager = rm
	rm.current_gun = revolver.duplicate()
	shop._generate_shop_items()
	var found_kit := 0
	for entry in shop._shop_items:
		var item = entry.item
		if item is PartData and item.is_conversion_kit():
			found_kit += 1
			t.check(item.conversion_class != Enums.WeaponClass.PISTOL, "무기고가 자기 클래스 킷을 제외")
			t.eq(int(entry.price), 80, "무기고 킷 가격에 revolver 배수 적용")
	t.eq(found_kit, 1, "무기고에 컨버전 킷 1종 진열")
	shop.free()
