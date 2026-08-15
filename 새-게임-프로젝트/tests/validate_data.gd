extends RefCounted
## CSV 데이터 정합성 검증 — 구조 오류는 FAIL, 밸런스 밴드 이탈은 WARN.
## 정본: 10-balance-designer 스킬 밴드 + data/*.csv, scripts/data 의 @export_range
##   ERROR(FAIL): id 중복/공백, 컬럼 수 부족, 정수 파싱 불가, 밴드 범위(구조적) 초과
##   WARN       : 밸런스 밴드 이탈, .tres 파일명 불일치


static func _read_rows(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return rows
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		rows.append(line)
	return rows


static func _col_map(headers: Variant) -> Dictionary:
	var cols: Dictionary = {}
	for i in range(headers.size()):
		cols[str(headers[i]).strip_edges()] = i
	return cols


static func _cell(row: Variant, cols: Dictionary, key: String) -> String:
	if not cols.has(key):
		return ""
	var idx: int = int(cols[key])
	if idx < 0 or idx >= row.size():
		return ""
	return str(row[idx]).strip_edges()


static func _tres_basenames(dir_path: String) -> Dictionary:
	var names: Dictionary = {}
	var d := DirAccess.open(dir_path)
	if not d:
		return names
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if fn.ends_with(".tres"):
			names[fn.get_basename()] = true
		fn = d.get_next()
	d.list_dir_end()
	return names


static func run(t) -> void:
	t.section("DataValidation")
	_validate_bullets(t)
	_validate_enemies(t)
	_validate_parts(t)


## 파츠 리소스 검증 — 로드 가능·part_id 유효/유니크·tier 범위.
static func _validate_parts(t) -> void:
	var dir := DirAccess.open("res://resources/parts")
	t.check(dir != null, "resources/parts 디렉터리 접근")
	if dir == null:
		return

	var pid_count := Enums.PartID.size()
	var seen_ids := {}
	var total := 0
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(".tres"):
			total += 1
			var res = load("res://resources/parts/" + fn)
			var base := fn.get_basename()
			t.check(res != null, "part '%s' 로드 가능" % base)
			if res != null:
				var pid: int = res.part_id
				t.check(pid > 0 and pid < pid_count, "part '%s' part_id %d ∈ (0,%d)" % [base, pid, pid_count])
				t.check(not seen_ids.has(pid), "part '%s' part_id %d 유니크" % [base, pid])
				seen_ids[pid] = base
				t.check(res.tier >= 1 and res.tier <= 5, "part '%s' tier %d ∈ [1,5]" % [base, res.tier])
				t.check(res.display_name != "", "part '%s' 표기명 존재" % base)
		fn = dir.get_next()
	dir.list_dir_end()
	t.check(total > 0, "파츠 리소스 %d종 발견" % total)


static func _validate_bullets(t) -> void:
	var rows := _read_rows("res://data/bullet_stats.csv")
	t.check(rows.size() > 1, "bullet_stats.csv 로드 (행 %d)" % rows.size())
	if rows.size() <= 1:
		return

	var tres := _tres_basenames("res://resources/bullets")
	var seen: Dictionary = {}
	var cols := _col_map(rows[0])
	var required := [
		"id", "display_name", "caliber", "family", "is_basic", "role", "specialty",
		"damage", "penetration", "accuracy", "knockback", "slow",
		"effect_type", "effect_value", "trigger", "scope", "condition", "description"
	]
	var schema_ok := true
	for key in required:
		var exists := cols.has(key)
		t.check(exists, "bullet_stats.csv 필수 헤더 '%s' 존재" % key)
		schema_ok = schema_ok and exists
	if not schema_ok:
		return

	var int_keys := [
		"damage", "penetration", "accuracy", "knockback",
		"slow", "effect_type", "effect_value"
	]
	var valid_classes := ["pistol", "smg", "rifle", "dmr", "shotgun", "universal"]
	var valid_families := ["basic", "support", "special", "control"]
	var valid_roles := ["attack", "link", "control"]
	var valid_specialties := ["damage", "penetration", "accuracy", "control"]
	var valid_triggers := ["none", "on_hit", "on_effective_hit"]
	var valid_scopes := ["none", "next_shot", "target", "remaining_mag", "formation", "self"]
	var valid_conditions := ["none", "previous_effective", "last_shot", "first_shot", "role_change"]
	for i in range(1, rows.size()):
		var r: Variant = rows[i]
		var where := "bullet 행 %d" % (i + 1)
		var id := _cell(r, cols, "id")
		t.check(id != "", "%s: id 비어있지 않음" % where)
		t.check(not seen.has(id), "bullet id 유니크: '%s'" % id)
		seen[id] = true
		for key in int_keys:
			var raw := _cell(r, cols, key)
			t.check(raw.is_valid_int(), "%s: %s='%s' 정수" % [where, key, raw])

		var is_basic := _cell(r, cols, "is_basic").to_lower()
		var role := _cell(r, cols, "role").to_lower()
		var specialty := _cell(r, cols, "specialty").to_lower()
		var cls := _cell(r, cols, "caliber").to_lower()
		var family := _cell(r, cols, "family").to_lower()
		var trigger := _cell(r, cols, "trigger").to_lower()
		var scope := _cell(r, cols, "scope").to_lower()
		var condition := _cell(r, cols, "condition").to_lower()
		t.check(is_basic in ["true", "false"], "%s: is_basic bool" % where)
		t.check(role in valid_roles, "%s: role '%s' 유효" % [where, role])
		t.check(specialty in valid_specialties,
			"%s: specialty '%s' 유효" % [where, specialty])
		t.check(cls in valid_classes, "%s: caliber '%s' 유효" % [where, cls])
		t.check(family in valid_families, "%s: family '%s' 유효" % [where, family])
		t.check(trigger in valid_triggers, "%s: trigger '%s' 유효" % [where, trigger])
		t.check(scope in valid_scopes, "%s: scope '%s' 유효" % [where, scope])
		t.check(condition in valid_conditions, "%s: condition '%s' 유효" % [where, condition])
		t.check(_cell(r, cols, "display_name") != "", "%s: 표기명 존재" % where)
		t.check(_cell(r, cols, "description") != "", "%s: 설명문 존재" % where)

		if id != "":
			t.check(tres.has(id), "bullet '%s' → resources/bullets/%s.tres 존재" % [id, id])

		# 공격탄은 일반 적에게 단독으로 작동하고, 연계탄은 전문 게이트 대응 범위를 넓힌다.
		# 모든 값은 결정론적 인지 밴드 안에서 유지한다.
		var dmg := int(_cell(r, cols, "damage"))
		var pen := int(_cell(r, cols, "penetration"))
		var acc := int(_cell(r, cols, "accuracy"))
		var kb := int(_cell(r, cols, "knockback"))
		var slow := int(_cell(r, cols, "slow"))
		var effect_type := int(_cell(r, cols, "effect_type"))
		t.check(effect_type >= 0 and effect_type < Enums.BulletEffect.size(),
			"bullet '%s' effect_type %d 유효" % [id, effect_type])
		t.check(dmg >= 2 and dmg <= 9, "bullet '%s' DMG %d 밴드(2~9)" % [id, dmg])
		t.warn(pen >= 0 and pen <= 5, "bullet '%s' PEN %d 밴드(0~5)" % [id, pen])
		t.warn(acc >= 2 and acc <= 9, "bullet '%s' ACC %d 밴드(2~9)" % [id, acc])
		t.warn(kb >= 0 and kb <= 2, "bullet '%s' KB %d 밴드(0~2)" % [id, kb])
		t.warn(slow >= 0 and slow <= 2, "bullet '%s' slow %d 밴드(0~2)" % [id, slow])


static func _validate_enemies(t) -> void:
	var rows := _read_rows("res://data/enemy_stats.csv")
	t.check(rows.size() > 1, "enemy_stats.csv 로드 (행 %d)" % rows.size())
	if rows.size() <= 1:
		return

	var tres := _tres_basenames("res://resources/enemies")
	var seen: Dictionary = {}
	var arch_count := Enums.EnemyArchetype.size()
	# 컬럼: 0 id,1 display,2 archetype,3 hp,4 def,5 eva,6 spd,7 start_dist,8 kb_res
	var int_cols := [2, 3, 4, 5, 6, 7, 8]
	for i in range(1, rows.size()):
		var r: Array = rows[i]
		var where := "enemy 행 %d" % (i + 1)
		if r.size() < 9:
			t.check(false, "%s: 컬럼 수 부족(%d < 9)" % [where, r.size()])
			continue
		var id: String = r[0].strip_edges()
		t.check(id != "", "%s: id 비어있지 않음" % where)
		t.check(not seen.has(id), "enemy id 유니크: '%s'" % id)
		seen[id] = true
		for c in int_cols:
			t.check(r[c].strip_edges().is_valid_int(), "%s: 컬럼[%d]='%s' 정수" % [where, c, r[c]])
		# 구조적 범위(FAIL)
		var arch := int(r[2]); var hp := int(r[3]); var def_v := int(r[4]); var eva := int(r[5])
		t.check(arch >= 0 and arch < arch_count, "enemy '%s' archetype %d ∈ [0,%d)" % [id, arch, arch_count])
		t.check(eva >= 0 and eva <= 12, "enemy '%s' EVA %d ∈ [0,12] (구조 상한)" % [id, eva])
		t.check(def_v >= 0 and def_v <= 10, "enemy '%s' DEF %d ∈ [0,10]" % [id, def_v])
		t.check(hp >= 1, "enemy '%s' HP %d >= 1" % [id, hp])
		# EVA 밴드(0~8): 초과 시 탄환 ACC 상한(8)으로 명중 불가 위험 → 경보
		t.warn(eva <= 8, "enemy '%s' EVA %d 밴드(0~8) — 초과 시 명중 불가 위험" % [id, eva])
		if id != "":
			t.warn(tres.has(id), "enemy '%s' → resources/enemies/%s.tres 존재" % [id, id])
		# 밸런스 밴드(WARN): HP 6~30 / SPD 0~7 (보스 포함)
		var spd := int(r[6])
		t.warn(hp >= 6 and hp <= 30, "enemy '%s' HP %d 밴드(6~30)" % [id, hp])
		t.warn(spd >= 0 and spd <= 7, "enemy '%s' SPD %d 밴드(0~7)" % [id, spd])
