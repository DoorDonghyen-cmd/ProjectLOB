extends RefCounted
## 탄환 v6 연결 무결성 및 구조 불변식.

const CSV_PATH := "res://data/bullet_stats.csv"
const BULLET_DIR := "res://resources/bullets"
const SELF_PATH := "res://tests/suite_ammo_integrity.gd"
const HISTORICAL_PROBE := "res://tests/lifo_depth_probe.gd"
const BulletRoleUI = preload("res://scripts/ui/bullet_role_ui.gd")

const RETIRED_IDS := [
	"basic_pistol", "flare_pistol", "overpressure_pistol", "slow_pistol", "impact_pistol",
	"basic_smg", "tuner_smg", "chain_smg", "surge_smg", "finale_smg",
	"basic_rifle", "borer_rifle", "ap_rifle", "shred_rifle", "heavyslug_rifle",
	"basic_dmr", "marker_dmr", "pierce_dmr", "burst_dmr", "decisive_dmr",
	"basic_shotgun", "spread_shotgun", "breach_shotgun", "opening_shotgun",
	"dense_shotgun", "crosscal_universal", "tracer_universal",
]


static func _csv_by_id() -> Dictionary:
	var rows: Dictionary = {}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return rows
	var headers := f.get_csv_line()
	var cols: Dictionary = {}
	for i in range(headers.size()):
		cols[headers[i].strip_edges()] = i
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.is_empty():
			continue
		var id_idx: int = int(cols.get("id", -1))
		if id_idx < 0 or id_idx >= line.size():
			continue
		var id := line[id_idx].strip_edges()
		if id == "":
			continue
		var row: Dictionary = {}
		for key in cols:
			var idx: int = int(cols[key])
			row[key] = line[idx].strip_edges() if idx < line.size() else ""
		rows[id] = row
	return rows


static func _resource_ids() -> Dictionary:
	var ids: Dictionary = {}
	var d := DirAccess.open(BULLET_DIR)
	if d == null:
		return ids
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if fn.ends_with(".tres"):
			ids[fn.get_basename()] = true
		fn = d.get_next()
	d.list_dir_end()
	return ids


static func _class_id(name: String) -> int:
	match name:
		"pistol": return Enums.WeaponClass.PISTOL
		"smg": return Enums.WeaponClass.SMG
		"rifle": return Enums.WeaponClass.RIFLE
		"dmr": return Enums.WeaponClass.DMR
		"shotgun": return Enums.WeaponClass.SHOTGUN
		"universal": return Enums.WeaponClass.UNIVERSAL
	return -1


static func _gd_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if d.current_is_dir():
			_gd_files(full, out)
		elif entry.ends_with(".gd") and full != SELF_PATH and full != HISTORICAL_PROBE:
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


static func _dominates(a: Dictionary, b: Dictionary) -> bool:
	var keys := ["damage", "penetration", "accuracy", "knockback"]
	var strictly_better := false
	for key in keys:
		var av := int(a[key])
		var bv := int(b[key])
		if av < bv:
			return false
		strictly_better = strictly_better or av > bv
	return strictly_better


static func run(t) -> void:
	t.section("AmmoIntegrity")
	var csv := _csv_by_id()
	var resources := _resource_ids()
	t.eq(csv.size(), 19, "탄환 CSV v6 19종")
	t.eq(resources.size(), 19, "탄환 리소스 v6 19종")
	for id in csv:
		t.check(resources.has(id), "CSV '%s'에 대응하는 .tres 존재" % id)
	for id in resources:
		t.check(csv.has(id), ".tres '%s'가 CSV에 등록됨" % id)

	var family_counts := {"basic": 0, "support": 0, "special": 0, "control": 0}
	var role_counts := {"attack": 0, "link": 0, "control": 0}
	var specialty_counts := {"damage": 0, "penetration": 0, "accuracy": 0, "control": 0}
	var nonzero_effects: Dictionary = {}
	var basics: Array[Dictionary] = []
	for id in csv:
		var row: Dictionary = csv[id]
		var bullet: BulletData = load("%s/%s.tres" % [BULLET_DIR, id])
		t.check(bullet != null, "탄환 '%s' 로드 가능" % id)
		if bullet == null:
			continue
		t.eq(bullet.display_name, str(row.display_name), "'%s' 표기명 CSV↔tres" % id)
		t.eq(bullet.description, str(row.description), "'%s' 설명문 CSV↔tres" % id)
		t.eq(bullet.weapon_class, _class_id(str(row.caliber)), "'%s' 구경 CSV↔tres" % id)
		t.eq(bullet.family, str(row.family), "'%s' 계열 CSV↔tres" % id)
		t.eq(bullet.is_basic, str(row.is_basic).to_lower() == "true", "'%s' is_basic" % id)
		t.eq(bullet.role, str(row.role), "'%s' 역할 CSV↔tres" % id)
		t.eq(bullet.specialty, str(row.specialty), "'%s' 전문축 CSV↔tres" % id)
		t.eq(bullet.trigger, str(row.trigger), "'%s' 발동 CSV↔tres" % id)
		t.eq(bullet.scope, str(row.scope), "'%s' 범위 CSV↔tres" % id)
		t.eq(bullet.condition, str(row.condition), "'%s' 조건 CSV↔tres" % id)
		for key in ["damage", "penetration", "accuracy", "knockback", "slow", "effect_type", "effect_value"]:
			t.eq(int(bullet.get(key)), int(row[key]), "'%s' %s CSV↔tres" % [id, key])

		family_counts[bullet.family] = int(family_counts.get(bullet.family, 0)) + 1
		role_counts[bullet.role] = int(role_counts.get(bullet.role, 0)) + 1
		specialty_counts[bullet.specialty] = int(specialty_counts.get(bullet.specialty, 0)) + 1
		t.check(bullet.damage >= 2, "'%s' DMG ≥ 2 불변식" % id)
		if bullet.is_basic:
			t.eq(bullet.family, "basic", "'%s' 기반탄 계열" % id)
			t.check(bullet.weapon_class != Enums.WeaponClass.UNIVERSAL,
				"'%s' 기반탄은 구체 구경" % id)
			basics.append(row)
		else:
			t.eq(bullet.weapon_class, Enums.WeaponClass.UNIVERSAL,
				"'%s' 비기반탄은 구경 무관" % id)
		if bullet.effect_type != Enums.BulletEffect.NONE:
			t.check(not nonzero_effects.has(bullet.effect_type),
				"'%s' 비영(非0) effect_type 중복 없음" % id)
			nonzero_effects[bullet.effect_type] = id

		var loaded := DataLoader.get_bullet(id)
		t.check(not loaded.is_empty(), "DataLoader 탄환 '%s' 조회 가능" % id)
		if not loaded.is_empty():
			t.eq(int(loaded.caliber), _class_id(str(row.caliber)), "'%s' 로더 구경" % id)
			t.eq(str(loaded.family), str(row.family), "'%s' 로더 계열" % id)
			t.eq(str(loaded.specialty), str(row.specialty), "'%s' 로더 전문축" % id)
			t.eq(str(loaded.trigger), str(row.trigger), "'%s' 로더 발동" % id)
			t.eq(str(loaded.scope), str(row.scope), "'%s' 로더 범위" % id)
			t.eq(str(loaded.condition), str(row.condition), "'%s' 로더 조건" % id)

	t.eq(int(family_counts.basic), 5, "기반탄 5종")
	t.eq(int(family_counts.support), 6, "보조탄 6종")
	t.eq(int(family_counts.special), 6, "조건부 공격탄 6종")
	t.eq(int(family_counts.control), 2, "제어탄 2종")
	t.eq(int(role_counts.attack), 11, "공격 역할 11종")
	t.eq(int(role_counts.link), 6, "연계 역할 6종")
	t.eq(int(role_counts.control), 2, "제어 역할 2종")
	t.eq(int(specialty_counts.damage), 5, "화력 전문축 5종(기반탄 포함)")
	t.eq(int(specialty_counts.penetration), 7, "관통 전문축 7종(기반탄 포함)")
	t.eq(int(specialty_counts.accuracy), 4, "명중 전문축 4종(기반탄 포함)")
	t.eq(int(specialty_counts.control), 3, "제어 전문축 3종")

	for i in range(basics.size()):
		for j in range(i + 1, basics.size()):
			var pair := [str(basics[i].id), str(basics[j].id)]
			pair.sort()
			if pair == ["cal_45acp", "cal_9mm"]:
				t.check(int(DataLoader.get_gun("smg").magazine_capacity) >= 5,
					".45ACP의 9mm 열세는 Tempo 6발 처리량으로 보상")
			else:
				t.check(not _dominates(basics[i], basics[j]) and not _dominates(basics[j], basics[i]),
					"기반탄 비지배: %s ↔ %s" % [basics[i].id, basics[j].id])
	var damages: Array[int] = []
	for row in basics:
		damages.append(int(row.damage))
	t.check(damages.max() - damages.min() <= 3, "기반탄 DMG 스프레드 ≤ 3")

	t.eq(RunManager.STARTING_AMMO_IDS.size(), 5, "시작 덱 클래스 구성 5종")
	for cls in RunManager.STARTING_AMMO_IDS:
		var ids: Array = RunManager.STARTING_AMMO_IDS[cls]
		t.eq(ids.size(), 3, "클래스 %d 시작 패키지 3종" % cls)
		if ids.size() != 3:
			continue
		var base: BulletData = load("%s/%s.tres" % [BULLET_DIR, ids[0]])
		t.check(base != null and base.is_basic and base.weapon_class == int(cls),
			"시작 기반탄 '%s'가 총기 구경과 일치" % ids[0])
		var starting_specialties := {base.specialty: true}
		for i in range(1, ids.size()):
			var support: BulletData = load("%s/%s.tres" % [BULLET_DIR, ids[i]])
			t.check(support != null and support.weapon_class == Enums.WeaponClass.UNIVERSAL,
				"시작 보조/제어탄 '%s' 구경 무관" % ids[i])
			if support != null:
				starting_specialties[support.specialty] = true
		t.check(starting_specialties.size() >= 2,
			"클래스 %d 시작 패키지가 최소 2개 전투 전문축 제공" % cls)

	t.eq(MaintenanceOverlay.SHOP_BULLET_IDS.size(), 14, "무기고 구경 무관 탄환 후보 14종")
	for id in MaintenanceOverlay.SHOP_BULLET_IDS:
		t.check(csv.has(id), "무기고 탄환 '%s' CSV 등록" % id)
		t.check(load("%s/%s.tres" % [BULLET_DIR, id]) != null,
			"무기고 탄환 '%s' 실제 로드 가능" % id)

	t.eq(BulletRoleUI.label("attack"), "공격", "역할 UI: attack")
	t.eq(BulletRoleUI.label("link"), "연계", "역할 UI: link")
	t.eq(BulletRoleUI.label("control"), "제어", "역할 UI: control")
	t.eq(BulletRoleUI.specialty_label("damage"), "화력", "전문축 UI: damage")
	t.eq(BulletRoleUI.specialty_label("penetration"), "관통", "전문축 UI: penetration")
	t.eq(BulletRoleUI.specialty_label("accuracy"), "명중", "전문축 UI: accuracy")
	t.eq(BulletRoleUI.specialty_label("control"), "제어", "전문축 UI: control")

	var gd_files: Array[String] = []
	_gd_files("res://scripts", gd_files)
	_gd_files("res://tests", gd_files)
	for retired in RETIRED_IDS:
		var hits: Array[String] = []
		for path in gd_files:
			if _read(path).find(retired) != -1:
				hits.append(path)
		t.check(hits.is_empty(), "삭제 탄환 ID '%s' 코드 잔존 없음%s" % [
			retired, "" if hits.is_empty() else " ← " + ", ".join(hits)
		])
