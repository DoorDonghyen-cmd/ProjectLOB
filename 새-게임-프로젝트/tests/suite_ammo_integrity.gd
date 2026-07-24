extends RefCounted
## 탄환 v5 연결 무결성 검사.
## CSV·리소스·시작 덱이 서로 다른 정본으로 갈라져 "유령 탄"이나 빈 덱이 생기는 것을 막는다.

const CSV_PATH := "res://data/bullet_stats.csv"
const BULLET_DIR := "res://resources/bullets"
const SELF_PATH := "res://tests/suite_ammo_integrity.gd"
const BulletRoleUI = preload("res://scripts/ui/bullet_role_ui.gd")

const RETIRED_IDS := [
	"knockback_pistol", "opening_pistol", "combo_smg", "rhythm_smg",
	"last_smg", "shred_ap_rifle", "last_rifle", "heavy_dmr",
	"critical_dmr", "shred_shotgun", "heavy_shotgun", "universal_caliber",
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
		elif entry.ends_with(".gd") and full != SELF_PATH:
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


static func run(t) -> void:
	t.section("AmmoIntegrity")

	var csv := _csv_by_id()
	var resources := _resource_ids()
	t.eq(csv.size(), 27, "탄환 CSV 27종")
	t.eq(resources.size(), 27, "탄환 리소스 27종")

	for id in csv:
		t.check(resources.has(id), "CSV '%s'에 대응하는 .tres 존재" % id)
	for id in resources:
		t.check(csv.has(id), ".tres '%s'가 CSV에 등록됨" % id)

	# CSV가 런타임 수치 정본이고 .tres가 UI 메타데이터 정본이므로 양쪽 값이 같아야 한다.
	var role_counts := {
		BulletRoleUI.STANDALONE: 0,
		BulletRoleUI.SETTER: 0,
		BulletRoleUI.PAYLOAD: 0,
		BulletRoleUI.UTILITY: 0,
	}
	var basic_count := 0
	for id in csv:
		var row: Dictionary = csv[id]
		var bullet: BulletData = load("%s/%s.tres" % [BULLET_DIR, id])
		t.check(bullet != null, "탄환 '%s' 로드 가능" % id)
		if bullet == null:
			continue
		t.eq(bullet.display_name, str(row.display_name), "'%s' 표기명 CSV↔tres" % id)
		t.eq(bullet.description, str(row.description), "'%s' 설명문 CSV↔tres" % id)
		t.eq(bullet.is_basic, str(row.is_basic).to_lower() == "true",
			"'%s' is_basic CSV↔tres" % id)
		t.eq(bullet.role, str(row.role), "'%s' 역할 CSV↔tres" % id)
		t.check(bullet.role in BulletRoleUI.VALID_ROLES, "'%s' 유효 역할값" % id)
		if bullet.role in role_counts:
			role_counts[bullet.role] += 1
		if bullet.is_basic:
			basic_count += 1
		t.eq(bullet.weapon_class, _class_id(str(row.class)), "'%s' 클래스 CSV↔tres" % id)
		t.eq(bullet.damage, int(row.damage), "'%s' DMG CSV↔tres" % id)
		t.eq(bullet.penetration, int(row.penetration), "'%s' PEN CSV↔tres" % id)
		t.eq(bullet.accuracy, int(row.accuracy), "'%s' ACC CSV↔tres" % id)
		t.eq(bullet.knockback, int(row.knockback), "'%s' KB CSV↔tres" % id)
		t.eq(bullet.slow, int(row.slow), "'%s' slow CSV↔tres" % id)
		t.eq(bullet.effect_type, int(row.effect_type), "'%s' effect_type CSV↔tres" % id)
		t.eq(bullet.effect_value, int(row.effect_value), "'%s' effect_value CSV↔tres" % id)

		# 헤더 기반 DataLoader가 13개 칼럼을 실제 런타임 Dictionary에 빠짐없이 옮기는지 전수 비교한다.
		var loaded: Dictionary = DataLoader.get_bullet(id)
		t.check(not loaded.is_empty(), "DataLoader 탄환 '%s' 조회 가능" % id)
		if loaded.is_empty():
			continue
		t.eq(str(loaded.id), id, "'%s' 로더 id" % id)
		t.eq(str(loaded.display_name), str(row.display_name), "'%s' 로더 표기명" % id)
		t.eq(int(loaded["class"]), _class_id(str(row["class"])), "'%s' 로더 클래스" % id)
		t.eq(bool(loaded.is_basic), str(row.is_basic).to_lower() == "true",
			"'%s' 로더 is_basic" % id)
		t.eq(str(loaded.role), str(row.role), "'%s' 로더 역할" % id)
		t.eq(int(loaded.damage), int(row.damage), "'%s' 로더 DMG" % id)
		t.eq(int(loaded.penetration), int(row.penetration), "'%s' 로더 PEN" % id)
		t.eq(int(loaded.accuracy), int(row.accuracy), "'%s' 로더 ACC" % id)
		t.eq(int(loaded.knockback), int(row.knockback), "'%s' 로더 KB" % id)
		t.eq(int(loaded.slow), int(row.slow), "'%s' 로더 slow" % id)
		t.eq(int(loaded.effect_type), int(row.effect_type), "'%s' 로더 effect_type" % id)
		t.eq(int(loaded.effect_value), int(row.effect_value), "'%s' 로더 effect_value" % id)
		t.eq(str(loaded.description), str(row.description), "'%s' 로더 설명문" % id)

	t.eq(basic_count, 5, "기본탄은 클래스별 1종씩 총 5종")
	t.eq(int(role_counts[BulletRoleUI.STANDALONE]), 9, "독립 역할 9종")
	t.eq(int(role_counts[BulletRoleUI.SETTER]), 8, "셋업 역할 8종")
	t.eq(int(role_counts[BulletRoleUI.PAYLOAD]), 8, "페이로드 역할 8종")
	t.eq(int(role_counts[BulletRoleUI.UTILITY]), 2, "유틸 역할 2종")

	# 사용자 문구와 LIFO 연계 판정은 모든 UI에서 이 헬퍼 하나를 공유한다.
	t.eq(BulletRoleUI.label("standalone"), "독립", "역할 UI: standalone")
	t.eq(BulletRoleUI.label("setter"), "셋업", "역할 UI: setter")
	t.eq(BulletRoleUI.label("payload"), "페이로드", "역할 UI: payload")
	t.eq(BulletRoleUI.label("utility"), "유틸", "역할 UI: utility")
	t.eq(BulletRoleUI.normalize("unknown"), BulletRoleUI.STANDALONE, "미지 역할은 독립으로 안전 폴백")
	var setter_probe := BulletData.new()
	setter_probe.role = "setter"
	var payload_probe := BulletData.new()
	payload_probe.role = "payload"
	t.check(BulletRoleUI.is_setup_chain(setter_probe, payload_probe),
		"역할 UI: 셋업→페이로드 연계 인식")
	t.check(not BulletRoleUI.is_setup_chain(payload_probe, setter_probe),
		"역할 UI: 역순은 연계로 오인하지 않음")

	# 시작 덱은 모든 클래스에서 기본 + 셋업 + 페이로드를 실제 로드할 수 있어야 한다.
	t.eq(RunManager.STARTING_AMMO_IDS.size(), 5, "시작 덱 클래스 구성 5종")
	for cls in RunManager.STARTING_AMMO_IDS:
		var ids: Array = RunManager.STARTING_AMMO_IDS[cls]
		t.eq(ids.size(), 3, "클래스 %d 시작 덱 역할 3종" % cls)
		if ids.size() != 3:
			continue
		for id in ids:
			var path := "%s/%s.tres" % [BULLET_DIR, id]
			var bullet: BulletData = load(path)
			t.check(bullet != null, "시작 덱 '%s' 실제 로드 가능" % id)
			if bullet != null:
				t.eq(bullet.weapon_class, int(cls), "시작 덱 '%s' 클래스 일치" % id)
		var basic := DataLoader.get_bullet(ids[0])
		var setter := DataLoader.get_bullet(ids[1])
		var payload := DataLoader.get_bullet(ids[2])
		t.check(bool(basic.get("is_basic", false)), "시작 덱 '%s' 기본탄 표시" % ids[0])
		t.eq(str(setter.get("role", "")), "setter", "시작 덱 '%s' 셋업 역할" % ids[1])
		t.eq(str(payload.get("role", "")), "payload", "시작 덱 '%s' 페이로드 역할" % ids[2])

	# 상점은 무작위로 하나만 뽑지만 후보 네 종은 모두 실제 도달 가능해야 한다.
	t.eq(MaintenanceOverlay.SHOP_BULLET_IDS.size(), 4, "무기고 탄환 후보 4종")
	for id in MaintenanceOverlay.SHOP_BULLET_IDS:
		t.check(csv.has(id), "무기고 탄환 '%s' CSV 등록" % id)
		t.check(load("%s/%s.tres" % [BULLET_DIR, id]) != null,
			"무기고 탄환 '%s' 실제 로드 가능" % id)

	# 삭제 ID가 프리로드가 아닌 문자열 참조로 남는 경우도 차단한다.
	var gd_files: Array[String] = []
	_gd_files("res://scripts", gd_files)
	_gd_files("res://tests", gd_files)
	for retired in RETIRED_IDS:
		var hits: Array[String] = []
		for path in gd_files:
			if _read(path).find(retired) != -1:
				hits.append(path)
		t.check(hits.is_empty(),
			"삭제 탄환 ID '%s' 코드 잔존 없음%s" % [
				retired,
				"" if hits.is_empty() else " ← " + ", ".join(hits)
			])
