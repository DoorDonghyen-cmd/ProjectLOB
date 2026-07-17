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


static func _validate_bullets(t) -> void:
	var rows := _read_rows("res://data/bullet_stats.csv")
	t.check(rows.size() > 1, "bullet_stats.csv 로드 (행 %d)" % rows.size())
	if rows.size() <= 1:
		return

	var tres := _tres_basenames("res://resources/bullets")
	var seen: Dictionary = {}
	# 컬럼: 0 id,1 display,2 class,3 dmg,4 pen,5 acc,6 kb,7 slow,8 effect_type,9 effect_value,10 desc
	var int_cols := [3, 4, 5, 6, 7, 8, 9]
	for i in range(1, rows.size()):
		var r: Array = rows[i]
		var where := "bullet 행 %d" % (i + 1)
		if r.size() < 11:
			t.check(false, "%s: 컬럼 수 부족(%d < 11)" % [where, r.size()])
			continue
		var id: String = r[0].strip_edges()
		t.check(id != "", "%s: id 비어있지 않음" % where)
		t.check(not seen.has(id), "bullet id 유니크: '%s'" % id)
		seen[id] = true
		for c in int_cols:
			t.check(r[c].strip_edges().is_valid_int(), "%s: 컬럼[%d]='%s' 정수" % [where, c, r[c]])
		if id != "":
			t.warn(tres.has(id), "bullet '%s' → resources/bullets/%s.tres 존재" % [id, id])
		# 밸런스 밴드(WARN): DMG 1~5 / PEN 0~5 / ACC 4~8 / KB 0~2 / slow 0~2
		var dmg := int(r[3]); var pen := int(r[4]); var acc := int(r[5]); var kb := int(r[6]); var slow := int(r[7])
		t.warn(dmg >= 1 and dmg <= 5, "bullet '%s' DMG %d 밴드(1~5)" % [id, dmg])
		t.warn(pen >= 0 and pen <= 5, "bullet '%s' PEN %d 밴드(0~5)" % [id, pen])
		t.warn(acc >= 4 and acc <= 8, "bullet '%s' ACC %d 밴드(4~8)" % [id, acc])
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
