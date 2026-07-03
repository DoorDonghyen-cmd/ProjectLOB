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
		if line.size() < 8 or line[0] == "":
			continue
			
		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": line[1].strip_edges(),
			"display_name_eng": line[2].strip_edges(),
			"capacity": int(line[3]),
			"reload_turns": int(line[4]),
			"passive_dmg_bonus": int(line[5]),
			"passive_pen_bonus": int(line[6]),
			"parts_capacity": int(line[7])
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
		if line.size() < 7 or line[0] == "":
			continue
			
		var id := line[0].strip_edges()
		var entry := {
			"id": id,
			"display_name": line[1].strip_edges(),
			"caliber": int(line[2]),
			"damage": int(line[3]),
			"penetration": int(line[4]),
			"accuracy": int(line[5]),
			"knockback": int(line[6])
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
