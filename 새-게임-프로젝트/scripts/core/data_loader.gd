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


## ── 클래스 문자열 파싱 헬퍼 ──
static func _parse_class(cls_str: String) -> int:
	match cls_str.strip_edges().lower():
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
		
	# 헤더 스킵
	var headers := file.get_csv_line()
	
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 11 or line[0] == "":
			continue
			
		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": line[1].strip_edges(),
			"class": _parse_class(line[2]),
			"magazine_capacity": int(line[3]),
			"has_chamber": line[4].strip_edges().lower() == "true",
			"reload_turns": int(line[5]),
			"parts_capacity": int(line[6]),
			"passive_dmg_bonus": int(line[7]),
			"passive_pen_bonus": int(line[8]),
			"passive_knockback_bonus": int(line[9]),
			"passive_acc_bonus": int(line[10])
		}
		_guns[id] = entry


## 🔴 탄환 스탯 CSV 로드
static func _load_bullet_stats() -> void:
	var path := "res://data/bullet_stats.csv"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("DataLoader ⚠️ 에러: bullet_stats.csv 파일을 열 수 없습니다.")
		return
		
	var headers := file.get_csv_line()
	
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 10 or line[0] == "":
			continue
			
		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": line[1].strip_edges(),
			"class": _parse_class(line[2]),
			"damage": int(line[3]),
			"penetration": int(line[4]),
			"accuracy": int(line[5]),
			"knockback": int(line[6]),
			"slow": int(line[7]),
			"effect_type": int(line[8]),
			"effect_value": int(line[9])
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


static func get_all_bullets() -> Array:
	ensure_loaded()
	return _bullets.values()
