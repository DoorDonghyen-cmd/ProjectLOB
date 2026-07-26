class_name DataLoader
extends RefCounted

## ═══════════════════════════════════════════════════
## CSV 전술 밸런스 데이터 로더 (Static Loader)
## ═══════════════════════════════════════════════════

static var _loaded: bool = false

static var _guns: Dictionary = {}
static var _bullets: Dictionary = {}
static var _enemies: Dictionary = {}

static func ensure_loaded() -> void:
	if _loaded:
		return
	
	_load_gun_stats()
	_load_bullet_stats()
	_load_enemy_stats()
	_loaded = true
	print("DataLoader: 모든 CSV 전술 스탯 로딩 완료.")


## ── 헤더 이름 기반 접근 헬퍼 ──
##
## ⚠️ CSV를 **인덱스가 아니라 칼럼 이름으로** 읽는다.
##    인덱스 파싱은 칼럼을 하나 삽입할 때마다 그 뒤 전부가 한 칸씩 밀리는데,
##    파싱이 실패하지 않고 **엉뚱한 값을 조용히 읽어** 밸런스가 어긋난다.
##    (fire_mode 칼럼 도입 시 실제로 이 위험이 있었다.)
static func _col_map(headers: PackedStringArray) -> Dictionary:
	var m := {}
	for i in range(headers.size()):
		m[headers[i].strip_edges()] = i
	return m


static func _s(line: PackedStringArray, cols: Dictionary, key: String, fallback: String = "") -> String:
	if not cols.has(key):
		return fallback
	var idx: int = cols[key]
	if idx >= line.size():
		return fallback
	return line[idx].strip_edges()


static func _i(line: PackedStringArray, cols: Dictionary, key: String, fallback: int = 0) -> int:
	var raw := _s(line, cols, key, "")
	return int(raw) if raw != "" else fallback


static func _f(line: PackedStringArray, cols: Dictionary, key: String, fallback: float = 0.0) -> float:
	var raw := _s(line, cols, key, "")
	return float(raw) if raw != "" else fallback


static func _b(line: PackedStringArray, cols: Dictionary, key: String) -> bool:
	return _s(line, cols, key, "").to_lower() == "true"


## ── 발사 방식 파싱 ──
## 정본: docs/gdd/21_fire_mode.md
## 값은 single / full_auto 2종뿐이다.
static func _parse_fire_mode(s: String) -> int:
	match s.strip_edges().to_lower():
		"full_auto": return Enums.FireMode.FULL_AUTO
		"single": return Enums.FireMode.SINGLE
	return Enums.FireMode.SINGLE  # 미기입 총기는 단발(기존 동작 보존)


## ── 클래스 문자열 파싱 헬퍼 ──
static func _parse_class(cls_str: String) -> int:
	match cls_str.strip_edges().to_lower():
		"pistol": return Enums.WeaponClass.PISTOL
		"smg": return Enums.WeaponClass.SMG
		"rifle": return Enums.WeaponClass.RIFLE
		"dmr": return Enums.WeaponClass.DMR
		"shotgun": return Enums.WeaponClass.SHOTGUN
		"universal": return Enums.WeaponClass.UNIVERSAL
	return Enums.WeaponClass.PISTOL


## 🔫 총기 스탯 CSV 로드
static func _load_gun_stats() -> void:
	var path := "res://data/gun_stats.csv"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("DataLoader ⚠️ 에러: gun_stats.csv 파일을 열 수 없습니다.")
		return
		
	var cols := _col_map(file.get_csv_line())

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue

		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": _s(line, cols, "display_name"),
			"class": _parse_class(_s(line, cols, "class")),
			"fire_mode": _parse_fire_mode(_s(line, cols, "fire_mode")),
			"magazine_capacity": _i(line, cols, "magazine_capacity"),
			"has_chamber": _b(line, cols, "has_chamber"),
			"reload_turns": _i(line, cols, "reload_turns"),
			"parts_capacity": _i(line, cols, "parts_capacity"),
			"conversion_cost": _f(line, cols, "conversion_cost", 1.0),
			"passive_dmg_bonus": _i(line, cols, "passive_dmg_bonus"),
			"passive_pen_bonus": _i(line, cols, "passive_pen_bonus"),
			"passive_knockback_bonus": _i(line, cols, "passive_knockback_bonus"),
			"passive_acc_bonus": _i(line, cols, "passive_acc_bonus"),
			"preview_window_size": _i(line, cols, "preview_window_size", -1)
		}
		_guns[id] = entry


## 🔴 탄환 스탯 CSV 로드
static func _load_bullet_stats() -> void:
	var path := "res://data/bullet_stats.csv"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("DataLoader ⚠️ 에러: bullet_stats.csv 파일을 열 수 없습니다.")
		return
		
	var cols := _col_map(file.get_csv_line())
	
	while not file.eof_reached():
		var line := file.get_csv_line()
		var id := _s(line, cols, "id")
		if id == "":
			continue
			
		var entry := {
			"id": id,
			"display_name": _s(line, cols, "display_name"),
			"class": _parse_class(_s(line, cols, "class")),
			"is_basic": _b(line, cols, "is_basic"),
			"role": _s(line, cols, "role", "attack"),
			"damage": _i(line, cols, "damage"),
			"penetration": _i(line, cols, "penetration"),
			"accuracy": _i(line, cols, "accuracy"),
			"knockback": _i(line, cols, "knockback"),
			"slow": _i(line, cols, "slow"),
			"effect_type": _i(line, cols, "effect_type"),
			"effect_value": _i(line, cols, "effect_value"),
			"description": _s(line, cols, "description")
		}
		_bullets[id] = entry


## 👾 적 스탯 CSV 로드
static func _load_enemy_stats() -> void:
	var path := "res://data/enemy_stats.csv"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("DataLoader ⚠️ 에러: enemy_stats.csv 파일을 열 수 없습니다.")
		return
		
	var headers := file.get_csv_line()
	
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 9 or line[0] == "":
			continue
			
		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": line[1].strip_edges(),
			"archetype": int(line[2]),
			"max_hp": int(line[3]),
			"defense": int(line[4]),
			"evasion": int(line[5]),
			"speed": int(line[6]),
			"start_distance": int(line[7]),
			"knockback_resistance": int(line[8])
		}
		_enemies[id] = entry


# ── 데이터 룩업 인터페이스 ──

static func get_gun(id: String) -> Dictionary:
	ensure_loaded()
	if _guns.has(id):
		return _guns[id]
	return {}


static func get_bullet(id: String) -> Dictionary:
	ensure_loaded()
	if _bullets.has(id):
		return _bullets[id]
	return {}


static func get_enemy(id: String) -> Dictionary:
	ensure_loaded()
	if _enemies.has(id):
		return _enemies[id]
	return {}


static func get_all_enemies() -> Array:
	ensure_loaded()
	return _enemies.values()


static func get_all_bullet_ids() -> Array:
	ensure_loaded()
	return _bullets.keys()


static func get_all_gun_ids() -> Array:
	ensure_loaded()
	return _guns.keys()


static func get_all_bullets() -> Array:
	ensure_loaded()
	return _bullets.values()
