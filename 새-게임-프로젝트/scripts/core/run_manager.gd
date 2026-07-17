class_name RunManager
extends RefCounted

## ═══════════════════════════════════════════════════
## 로그라이크 런 및 메타 영구 해금 매니저
## ═══════════════════════════════════════════════════

# ── 영구 메타 데이터 (정적 보존) ──
static var meta_credits: int = 100       # 시작 시 테스트용으로 100 크레딧 기본 제공
static var meta_backpack_lvl: int = 0    # 시작 덱 크기 업그레이드 (최대 3)
static var meta_hp_armor_lvl: int = 0    # 시작 HP 버퍼 업그레이드 (최대 2 -> 버퍼 1~3)
static var meta_discount_unlocked: bool = false # 탄환 폐기 수수료 면제
static var meta_tactical_data_cores: int = 0 # 전술 데이터 코어 누적 자원
static var meta_vault_lvl: int = 0           # 전술 금고 레벨 (0~3)
static var saved_vault_credits: int = 0     # 전술 금고 이월 크레딧
static var starting_bonus_available: bool = false # 스타팅 보증 사용 가능 여부
static var meta_unlocked_weapons: Array[String] = ["workhorse"] # 영구 해금된 총기 목록 (기본 workhorse 해금)
static var meta_unlocked_sections: Array[String] = ["section_a"] # 영구 해금된 작전 구역 목록 (기본 section_a 지하주차장 해금)
static var meta_lore_fragments: Array[int] = [] # 1~20 범위의 수집된 파편 번호
static var infiltration_risk_level: int = 1 # 1~5 침투 위험도 (정적 보존하여 런 밖에서도 난이도 세팅 유지)

# ── 런 가변 상태 ──
var current_gun: GunData = null                 # 현재 런에서 선택하여 고정된 총기
var equipped_parts: Array[PartData] = []        # 현재 장착된 총기 파츠들
var hold_part: PartData = null                  # 임시 보관 파츠 (최대 1칸)
var hp_buffer: int = 1
var credits: int = 0
const BACKPACK_CAPACITY: int = 8
var backpack_items: Array[Resource] = []
var current_floor: int = 1
var current_section: String = "section_a"        # 현재 런의 작전 구역 ID
const AIR_DUCT_DISTANCE_PENALTY: int = -2

var current_route_type: String = "stairs" # "stairs", "air_duct"
var current_node_id: int = 0
var pending_combat_distance_modifier: int = 0
var has_chamber_polish: bool = false     # 약실 소탕 리로드 면제 버프
var visible_magazine_slots: int = 2      # 전투 중 보여질 예고창 탄환 개수 (기본 2칸)
var tactical_data_cores: int = 0         # 이번 런에서 획득한 전술 데이터 코어 수

# ── 런 도전 과제 판정 통계 ──
var run_stats := {
	"lead_bullets_fired": 0,
	"min_dist_allowed": 99,
	"hard_zones_cleared": 0,
	"max_kills_in_single_turn": 0,
	"average_kill_distance": 0.0,
	"total_kills": 0,
	"total_kill_dist_sum": 0.0,
	"tanks_killed_by_shred_only": 0,
	"stance_shifts_killed_without_slow": 0,
	"perfect_battles_count": 0
}

var deck: Array[BulletData] = []
var discarded_bullets: Array[BulletData] = [] # Unload로 버려져 소실 위기에 놓인 탄환들
# ── 맵 구조 데이터 ──
var map_nodes: Dictionary = {}         # id(int) -> RunNode
var floor_connections: Dictionary = {} # floor(int) -> Array[int] (노드 ID 목록)

# ── 노드 정보 구조체 ──
class RunNode:
	var id: int
	var type_name: String
	var description: String
	var connected_routes: Array[String] # 레거시 노드 태그: "stairs", "air_duct"
	
	# 신설 필드
	var connected_node_ids: Array = [] # 다음 층의 타겟 노드 ID들
	var connected_node_routes: Dictionary = {} # target_node_id(int) -> route_type(String, "stairs", "air_duct")
	var is_hidden: bool = false            # 조건부 노출 여부
	var unlock_condition_type: String = ""  # "caliber_762", "chamber_polish", ""
	var hidden_type: String = ""            # ??? 노드 내부의 진짜 타입
	var scan_hint: String = ""              # 전술 스캔 힌트
	
	func _init(_id: int, _type: String, _desc: String, _routes: Array[String]):
		id = _id
		type_name = _type
		description = _desc
		connected_routes = _routes


## 신규 런 시작 및 상태 초기화
func start_new_run(section_id: String, gun: GunData, basic_bullet: BulletData, ap_bullet: BulletData, kb_bullet: BulletData) -> void:
	# 런타임 시작 시 CSV 데이터 동기화
	_sync_gun_stats_from_csv(gun)
	_sync_bullet_stats_from_csv(basic_bullet)
	_sync_bullet_stats_from_csv(ap_bullet)
	_sync_bullet_stats_from_csv(kb_bullet)

	current_section = section_id
	current_floor = 1
	hp_buffer = 1 + meta_hp_armor_lvl
	credits = saved_vault_credits
	saved_vault_credits = 0
	backpack_items.clear()
	deck.clear()
	discarded_bullets.clear()
	has_chamber_polish = false
	current_route_type = "stairs"
	current_node_id = 0
	pending_combat_distance_modifier = 0
	visible_magazine_slots = 2
	tactical_data_cores = 0
	
	# 통계 데이터 초기화
	run_stats = {
		"lead_bullets_fired": 0,
		"min_dist_allowed": 99,
		"hard_zones_cleared": 0,
		"max_kills_in_single_turn": 0,
		"average_kill_distance": 0.0,
		"total_kills": 0,
		"total_kill_dist_sum": 0.0,
		"tanks_killed_by_shred_only": 0,
		"stance_shifts_killed_without_slow": 0,
		"perfect_battles_count": 0
	}
	
	# 총기 및 기본 파츠 초기화
	current_gun = gun
	equipped_parts.clear()
	hold_part = null
	if current_gun != null and current_gun.default_part != null:
		equipped_parts.append(current_gun.default_part)
	
	# 기본 덱 구성 (총기 클래스에 따라 동적 매핑)
	if current_gun != null:
		var cls: int = current_gun.weapon_class
		var basic_path := ""
		var specA_path := ""
		var specB_path := ""
		var basic_cnt := 5
		var specA_cnt := 2
		var specB_cnt := 1

		match cls:
			Enums.WeaponClass.PISTOL:
				basic_path = "res://resources/bullets/basic_pistol.tres"
				specA_path = "res://resources/bullets/knockback_pistol.tres"
				specB_path = "res://resources/bullets/opening_pistol.tres"
				basic_cnt = 5 + meta_backpack_lvl
				specA_cnt = 2 + (1 if meta_backpack_lvl >= 2 else 0)
				specB_cnt = 1
			Enums.WeaponClass.SMG:
				basic_path = "res://resources/bullets/basic_smg.tres"
				specA_path = "res://resources/bullets/combo_smg.tres"
				specB_path = "res://resources/bullets/rhythm_smg.tres"
				basic_cnt = 6 + meta_backpack_lvl
				specA_cnt = 2
				specB_cnt = 1
			Enums.WeaponClass.RIFLE:
				basic_path = "res://resources/bullets/basic_rifle.tres"
				specA_path = "res://resources/bullets/shred_rifle.tres"
				specB_path = "res://resources/bullets/last_rifle.tres"
				basic_cnt = 6 + meta_backpack_lvl
				specA_cnt = 2
				specB_cnt = 1
			Enums.WeaponClass.DMR:
				basic_path = "res://resources/bullets/basic_dmr.tres"
				specA_path = "res://resources/bullets/heavy_dmr.tres"
				specB_path = "res://resources/bullets/pierce_dmr.tres"
				basic_cnt = 3 + meta_backpack_lvl
				specA_cnt = 2
				specB_cnt = 1
			Enums.WeaponClass.SHOTGUN:
				basic_path = "res://resources/bullets/basic_shotgun.tres"
				specA_path = "res://resources/bullets/shred_shotgun.tres"
				specB_path = "res://resources/bullets/heavy_shotgun.tres"
				basic_cnt = 5 + meta_backpack_lvl
				specA_cnt = 2
				specB_cnt = 1

		var b_res: BulletData = load(basic_path)
		var sa_res: BulletData = load(specA_path)
		var sb_res: BulletData = load(specB_path)

		if b_res: _sync_bullet_stats_from_csv(b_res)
		if sa_res: _sync_bullet_stats_from_csv(sa_res)
		if sb_res: _sync_bullet_stats_from_csv(sb_res)

		for i in range(basic_cnt):
			if b_res: deck.append(b_res.duplicate())
		for i in range(specA_cnt):
			if sa_res: deck.append(sa_res.duplicate())
		for i in range(specB_cnt):
			if sb_res: deck.append(sb_res.duplicate())
			
	# 맵 데이터 생성 및 조건부 우회 경로 업데이트
	generate_run_map()
	update_conditional_paths()


func _sync_gun_stats_from_csv(g: GunData) -> void:
	if g == null:
		return
	var res_id := g.resource_path.get_file().get_basename()
	var csv := DataLoader.get_gun(res_id)
	if not csv.is_empty():
		g.magazine_capacity = csv.magazine_capacity
		g.weapon_class = csv.class
		g.reload_turns = csv.reload_turns
		g.passive_dmg_bonus = csv.passive_dmg_bonus
		g.passive_pen_bonus = csv.passive_pen_bonus
		g.passive_knockback_bonus = csv.passive_knockback_bonus
		g.passive_acc_bonus = csv.passive_acc_bonus
		g.parts_capacity = csv.parts_capacity
		print("DataLoader: 총기 [%s] 스탯 CSV 동기화 완료 (장탄수: %d)" % [res_id, g.magazine_capacity])


func _sync_bullet_stats_from_csv(b: BulletData) -> void:
	if b == null:
		return
	var res_id := b.resource_path.get_file().get_basename()
	var csv := DataLoader.get_bullet(res_id)
	if not csv.is_empty():
		b.damage = csv.damage
		b.penetration = csv.penetration
		b.accuracy = csv.accuracy
		b.knockback = csv.knockback
		b.slow = csv.slow
		b.weapon_class = csv.class
		b.effect_type = csv.effect_type
		b.effect_value = csv.effect_value
		print("DataLoader: 탄환 [%s] 스탯 CSV 동기화 완료 (DMG: %d, PEN: %d)" % [res_id, b.damage, b.penetration])


## 침투 통로 선택 및 즉시 패널티 판정
## 반환: 플레이어에게 보여줄 알림 메시지
func select_route(route: String) -> String:
	current_route_type = route
	match route:
		"stairs":
			return "비상계단을 통해 조용히 전진합니다. 패널티가 없습니다."
		"air_duct":
			pending_combat_distance_modifier = AIR_DUCT_DISTANCE_PENALTY
			return "좁은 환기구를 포복 전진합니다.\n[환기 압박] 다음 교전의 적 시작 거리가 2m 단축됩니다. 비전투 노드를 지나도 유지됩니다."
	return ""


## 환기구에서 누적된 다음 교전 거리 비용을 1회 반환하고 소멸시킨다.
func consume_pending_combat_distance_modifier() -> int:
	var modifier := pending_combat_distance_modifier
	pending_combat_distance_modifier = 0
	return modifier


## 현재 위치에서 목적지 노드로 연결된 통로를 반환한다.
func get_route_to_node(target_node_id: int) -> String:
	if current_node_id == 0 or not map_nodes.has(current_node_id):
		if map_nodes.has(target_node_id):
			var entry_node: RunNode = map_nodes[target_node_id]
			if not entry_node.connected_routes.is_empty():
				return entry_node.connected_routes[0]
		return "stairs"
	var current_node: RunNode = map_nodes[current_node_id]
	return current_node.connected_node_routes.get(target_node_id, "stairs")


## 첫 층은 모두 선택 가능하며, 이후에는 현재 노드의 실제 연결선만 허용한다.
func is_node_reachable(target_node_id: int) -> bool:
	if current_node_id == 0 or not map_nodes.has(current_node_id):
		return true
	var current_node: RunNode = map_nodes[current_node_id]
	return current_node.connected_node_ids.has(target_node_id)


## 통로가 아닌 목적지의 위험도에 따라 TDC를 지급한다.
func record_node_clear(node: RunNode) -> int:
	if node == null:
		return 0
	var earned := 0
	var resolved_type := node.hidden_type if node.type_name.begins_with("???") else node.type_name
	if resolved_type.contains("보스") or resolved_type.contains("Boss"):
		earned = 2
	elif node.type_name.begins_with("???") or resolved_type.contains("우회") or resolved_type.contains("보급"):
		earned = 1
	tactical_data_cores += earned
	return earned


## 전투 완료 시 드래프트 추가
func add_to_deck(bullet: BulletData) -> void:
	_sync_bullet_stats_from_csv(bullet)
	deck.append(bullet.duplicate())


## Unload 시 덱에서 해당 인덱스의 탄을 소실(버린 카드 풀)로 이동
func unload_bullet_to_discard(bullet: BulletData) -> void:
	# 덱에서 동일 display_name을 가진 첫 탄환을 제거
	for i in range(deck.size()):
		if deck[i].display_name == bullet.display_name:
			discarded_bullets.append(deck[i])
			deck.remove_at(i)
			break


## 소멸(Exile)되거나 분실된 탄환을 덱에서 영구 제거 (단, 기본 9mm는 리필 보장용으로 제거 생략)
func exile_bullet_from_deck(bullet: BulletData) -> void:
	if current_gun != null and bullet.weapon_class == current_gun.weapon_class:
		return # 전용 탄은 보존 (전투마다 복구)
		
	for i in range(deck.size()):
		if deck[i].display_name == bullet.display_name:
			deck.remove_at(i)
			break


## 대피소: 소실 탄환 전원 복구
func recover_discarded_bullets() -> int:
	var count := discarded_bullets.size()
	deck.append_array(discarded_bullets)
	discarded_bullets.clear()
	return count


## 무기 캐비닛: 탄환 장약 보강 (DMG +1 또는 KB +1)
func upgrade_bullet_in_deck(index: int, property: String) -> void:
	if index < 0 or index >= deck.size():
		return
	if property == "dmg":
		deck[index].damage += 1
	elif property == "kb":
		deck[index].knockback += 1


## 무기 캐비닛: 탄환 폐기
func discard_bullet_from_deck(index: int) -> void:
	if index < 0 or index >= deck.size():
		return
	deck.remove_at(index)


## 런 정산 및 크레딧 환전
func end_run(won: bool) -> int:
	var won_bonus := 50 if won else 0
	var earned := (current_floor * 15) + won_bonus
	meta_credits += earned
	
	# 전술 데이터 코어 영구 누적
	meta_tactical_data_cores += tactical_data_cores
	
	# 스타팅 보증금 보상 체크 (구역 1 이상 돌파 = 4층 상점 도달 이상)
	if current_floor >= 4:
		starting_bonus_available = true
	else:
		starting_bonus_available = false
		
	# 전술 금고 크레딧 이월 비율 산출
	var ratio := 0.0
	match meta_vault_lvl:
		1: ratio = 0.10
		2: ratio = 0.15
		3: ratio = 0.20
	saved_vault_credits = clampi(int(credits * ratio), 0, 100)

	save_meta()
	return earned


## 이번 런 통계를 검토하여 영구 해금될 무기들을 체크 및 해금
func check_weapon_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	
	# 1. 저격형 (marksman/dmr): [원거리 통제] 평균 처치 거리 >= 4.0 이며 완주
	if not meta_unlocked_weapons.has("marksman"):
		var avg_dist = 0.0
		if run_stats.total_kills > 0:
			avg_dist = run_stats.total_kill_dist_sum / run_stats.total_kills
		# 최소 1킬 이상은 있어야 하고, 평균 거리가 4.0 이상이어야 함
		if run_stats.total_kills > 0 and avg_dist >= 4.0:
			newly_unlocked.append("marksman")
			
	# 2. 돌격형 (bruiser/shotgun): [처치 연쇄] 한 턴 3+ 처치
	if not meta_unlocked_weapons.has("bruiser") and run_stats.max_kills_in_single_turn >= 3:
		newly_unlocked.append("bruiser")
		
	# 3. 발사형 (tempo/smg): [계획 규율] 납탄 격발 없이 완주
	if not meta_unlocked_weapons.has("tempo") and run_stats.lead_bullets_fired == 0:
		newly_unlocked.append("tempo")
		
	# 4. 곡예형 (trickster): [완벽 실행] 한 전투 빗나감/0뎀 없이 클리어한 판이 존재 (perfect_battles_count >= 1)
	if not meta_unlocked_weapons.has("trickster") and run_stats.perfect_battles_count >= 1:
		newly_unlocked.append("trickster")
		
	# 5. 중장형 (heavy): [시스템 파훼] 파쇄만으로 탱커 처치 >= 1
	if not meta_unlocked_weapons.has("heavy") and run_stats.tanks_killed_by_shred_only >= 1:
		newly_unlocked.append("heavy")
		
	# 6. 태세 사냥꾼 (stance_hunter): [시스템 파훼] 슬로우 없이 태세병 처치 >= 1
	if not meta_unlocked_weapons.has("stance_hunter") and run_stats.stance_shifts_killed_without_slow >= 1:
		newly_unlocked.append("stance_hunter")
		
	# 7. 도박형 (gambler): [리스크 감수] 무손실 완주 (런 전체에서 최소 적 접근 거리가 1 초과 유지)
	if not meta_unlocked_weapons.has("gambler") and run_stats.min_dist_allowed > 1:
		newly_unlocked.append("gambler")
		
	for weapon in newly_unlocked:
		meta_unlocked_weapons.append(weapon)
	return newly_unlocked


## 메타 업그레이드 조작
static func upgrade_meta_backpack() -> bool:
	if meta_credits >= 40 and meta_backpack_lvl < 3:
		meta_credits -= 40
		meta_backpack_lvl += 1
		save_meta()
		return true
	return false

static func upgrade_meta_hp_armor() -> bool:
	if meta_credits >= 50 and meta_hp_armor_lvl < 2:
		meta_credits -= 50
		meta_hp_armor_lvl += 1
		save_meta()
		return true
	return false

static func upgrade_meta_discount() -> bool:
	if meta_credits >= 30 and not meta_discount_unlocked:
		meta_credits -= 30
		meta_discount_unlocked = true
		save_meta()
		return true
	return false

static func upgrade_meta_vault() -> bool:
	var cost := 0
	match meta_vault_lvl:
		0: cost = 30
		1: cost = 45
		2: cost = 60
		_: return false
		
	if meta_credits >= cost:
		meta_credits -= cost
		meta_vault_lvl += 1
		save_meta()
		return true
	return false


# ══════════════════════════════════════════════════
# 메타 영속화 (세이브/로드) — user://meta_save.cfg (ConfigFile)
# ══════════════════════════════════════════════════
const DEFAULT_SAVE_PATH := "user://meta_save.cfg"
const SAVE_VERSION := 1
## 저장/로드 경로 오버라이드 (테스트·멀티슬롯용). ""이면 기본 경로 사용.
static var save_path_override: String = ""


static func _resolve_save_path(path: String) -> String:
	if path != "":
		return path
	if save_path_override != "":
		return save_path_override
	return DEFAULT_SAVE_PATH


## 메타 영속 데이터를 저장한다. (path 미지정 시 기본/오버라이드 경로)
static func save_meta(path := "") -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "credits", meta_credits)
	cfg.set_value("meta", "backpack_lvl", meta_backpack_lvl)
	cfg.set_value("meta", "hp_armor_lvl", meta_hp_armor_lvl)
	cfg.set_value("meta", "discount_unlocked", meta_discount_unlocked)
	cfg.set_value("meta", "tactical_data_cores", meta_tactical_data_cores)
	cfg.set_value("meta", "vault_lvl", meta_vault_lvl)
	cfg.set_value("meta", "saved_vault_credits", saved_vault_credits)
	cfg.set_value("meta", "starting_bonus_available", starting_bonus_available)
	cfg.set_value("meta", "unlocked_weapons", meta_unlocked_weapons)
	cfg.set_value("meta", "unlocked_sections", meta_unlocked_sections)
	cfg.set_value("meta", "lore_fragments", meta_lore_fragments)
	cfg.set_value("meta", "infiltration_risk_level", infiltration_risk_level)
	cfg.save(_resolve_save_path(path))


## 메타 영속 데이터를 불러온다. 파일이 없으면 현재(기본)값을 유지한다.
static func load_meta(path := "") -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_resolve_save_path(path)) != OK:
		return
	meta_credits = int(cfg.get_value("meta", "credits", meta_credits))
	meta_backpack_lvl = int(cfg.get_value("meta", "backpack_lvl", meta_backpack_lvl))
	meta_hp_armor_lvl = int(cfg.get_value("meta", "hp_armor_lvl", meta_hp_armor_lvl))
	meta_discount_unlocked = bool(cfg.get_value("meta", "discount_unlocked", meta_discount_unlocked))
	meta_tactical_data_cores = int(cfg.get_value("meta", "tactical_data_cores", meta_tactical_data_cores))
	meta_vault_lvl = int(cfg.get_value("meta", "vault_lvl", meta_vault_lvl))
	saved_vault_credits = int(cfg.get_value("meta", "saved_vault_credits", saved_vault_credits))
	starting_bonus_available = bool(cfg.get_value("meta", "starting_bonus_available", starting_bonus_available))
	meta_unlocked_weapons = _as_string_array(cfg.get_value("meta", "unlocked_weapons", meta_unlocked_weapons))
	meta_unlocked_sections = _as_string_array(cfg.get_value("meta", "unlocked_sections", meta_unlocked_sections))
	meta_lore_fragments = _as_int_array(cfg.get_value("meta", "lore_fragments", meta_lore_fragments))
	infiltration_risk_level = int(cfg.get_value("meta", "infiltration_risk_level", infiltration_risk_level))


static func _as_string_array(v) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x in v:
			out.append(String(x))
	return out


static func _as_int_array(v) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


## 층별 생성된 노드 정보 반환 (맵 구조 기반)
func get_nodes_for_floor(floor_num: int) -> Array[RunNode]:
	var nodes: Array[RunNode] = []
	if floor_connections.has(floor_num):
		for node_id in floor_connections[floor_num]:
			if map_nodes.has(node_id):
				nodes.append(map_nodes[node_id])
	return nodes


## 10층 압축 구조 및 가로 분기 맵 제너레이터
func generate_run_map() -> void:
	map_nodes.clear()
	floor_connections.clear()
	
	# 노드 추가 람다 헬퍼
	var add_node = func(f: int, id: int, type: String, desc: String, routes: Array, is_hidden: bool = false, cond_type: String = "") -> RunNode:
		# RunNode 내부에 string 배열로 전달하기 위해 변환
		var route_strings: Array[String] = []
		for r in routes:
			route_strings.append(String(r))
		var n = RunNode.new(id, type, desc, route_strings)
		n.is_hidden = is_hidden
		n.unlock_condition_type = cond_type
		
		# ??? 미지 노드 스캔 힌트 설정
		if type.begins_with("???"):
			var r = randf()
			if r < 0.35:
				n.hidden_type = "사무실 (전투)"
				n.scan_hint = "스캔: 다수의 생체 신호 감지 (위험도 HIGH)"
			elif r < 0.7:
				n.hidden_type = "보급 캐비닛 (정비)"
				n.scan_hint = "스캔: 군수 보급품 반응 감지 (보급고 유력)"
			else:
				n.hidden_type = "보안 통제실 (이벤트)"
				n.scan_hint = "스캔: 미세 전자기기 노이즈 감지 (상점 유력)"
				
		map_nodes[id] = n
		if not floor_connections.has(f):
			floor_connections[f] = []
		floor_connections[f].append(id)
		return n

	if current_section == "section_a":
		# 지하 주차장 (입문 - 10층 구조 / 보스 10층)
		add_node.call(1, 101, "사무실 (전투)", "무장 순찰 경비 대기 중", ["stairs", "air_duct"])
		add_node.call(1, 102, "환기 서버실 (전투)", "침투 드론 경비대 순찰 중", ["air_duct"])
		add_node.call(2, 201, "주차장 구역 A (전투)", "경보 장치가 삼엄한 구역", ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "어두운 지하실 코너", ["air_duct"])
		add_node.call(3, 301, "대기실 (전투)", "경찰 방패 좀비 포진", ["stairs"])
		add_node.call(3, 302, "보안 무기고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 전용 탄약 보급실", ["air_duct"], true, "caliber_762")
		add_node.call(4, 401, "무기 캐비닛 (상점)", "구역 A 무기고 상점 단말기", ["stairs"])
		add_node.call(5, 501, "물류 구역 (전투)", "좀비 떼 출몰", ["stairs", "air_duct"])
		add_node.call(5, 502, "환기 통로 (전투)", "돌발 매복 경비병", ["air_duct"])
		add_node.call(6, 601, "복도 A (전투)", "방패 요원이 전술 대기 중", ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "센서 교란 구역", ["air_duct"])
		add_node.call(7, 701, "??? (미지)", "센서 교란 구역", ["stairs"])
		add_node.call(7, 702, "가스 제어실 (우회)", "환기 설비를 이용한 독가스 차단 우회 통로", ["air_duct"])
		add_node.call(8, 801, "전력 제어실 (전투)", "전력 차단 복구 구역", ["stairs"])
		add_node.call(9, 901, "무기 캐비닛 (상점)", "구역 A 최종 무기고 상점 단말기", ["stairs"])
		add_node.call(10, 1001, "지하 출구 (보스)", "지하 주차장을 통제하는 핵심 병력", ["stairs"])

		map_nodes[101].connected_node_ids = [201, 202]
		map_nodes[101].connected_node_routes[201] = "stairs"
		map_nodes[101].connected_node_routes[202] = "air_duct"
		map_nodes[102].connected_node_ids = [202]
		map_nodes[102].connected_node_routes[202] = "air_duct"
		map_nodes[201].connected_node_ids = [301, 302]
		map_nodes[201].connected_node_routes[301] = "stairs"
		map_nodes[201].connected_node_routes[302] = "air_duct"
		map_nodes[202].connected_node_ids = [301]
		map_nodes[202].connected_node_routes[301] = "air_duct"
		map_nodes[301].connected_node_ids = [401]
		map_nodes[301].connected_node_routes[401] = "stairs"
		map_nodes[302].connected_node_ids = [401]
		map_nodes[302].connected_node_routes[401] = "air_duct"
		map_nodes[401].connected_node_ids = [501, 502]
		map_nodes[401].connected_node_routes[501] = "stairs"
		map_nodes[401].connected_node_routes[502] = "air_duct"
		map_nodes[501].connected_node_ids = [601, 602]
		map_nodes[501].connected_node_routes[601] = "stairs"
		map_nodes[501].connected_node_routes[602] = "air_duct"
		map_nodes[502].connected_node_ids = [602]
		map_nodes[502].connected_node_routes[602] = "air_duct"
		map_nodes[601].connected_node_ids = [701, 702]
		map_nodes[601].connected_node_routes[701] = "stairs"
		map_nodes[601].connected_node_routes[702] = "air_duct"
		map_nodes[602].connected_node_ids = [701]
		map_nodes[602].connected_node_routes[701] = "air_duct"
		map_nodes[701].connected_node_ids = [801]
		map_nodes[701].connected_node_routes[801] = "stairs"
		map_nodes[702].connected_node_ids = [801]
		map_nodes[702].connected_node_routes[801] = "air_duct"
		map_nodes[801].connected_node_ids = [901]
		map_nodes[801].connected_node_routes[901] = "stairs"
		map_nodes[901].connected_node_ids = [1001]
		map_nodes[901].connected_node_routes[1001] = "stairs"

	elif current_section == "section_b" or current_section == "section_c":
		# 사무동 하층 및 연구소 중층 (초/중급 - 12층 구조 / 보스 12층)
		add_node.call(1, 101, "진입 구역 (전투)", "침투 초기 방어선", ["stairs", "air_duct"])
		add_node.call(1, 102, "지하 통로 (전투)", "순찰 경비 대기", ["air_duct"])
		add_node.call(2, 201, "2층 복도 (전투)", "경보 센서 작동 중", ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "어두운 코너 서버실", ["air_duct"])
		add_node.call(3, 301, "3층 보급실 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 보급실", ["stairs"], true, "caliber_762")
		add_node.call(3, 302, "3층 대기실 (전투)", "술사 기동 대기 중", ["air_duct"])
		add_node.call(4, 401, "4층 사무공간 (전투)", "중장갑 좀비 포진", ["stairs"])
		add_node.call(5, 501, "5층 복도 (전투)", "경보 울린 보안 격실", ["stairs", "air_duct"])
		add_node.call(6, 601, "무기 캐비닛 (상점)", "구역 B/C 무기고 상점", ["stairs"])
		add_node.call(7, 701, "7층 통로 (전투)", "돌격 좀비 떼 발견", ["stairs", "air_duct"])
		add_node.call(7, 702, "??? (미지)", "독가스 누출 흔적", ["air_duct"])
		add_node.call(8, 801, "가스 제어실 (우회)", "환기 설비를 이용한 독가스 차단 우회 통로", ["stairs"])
		add_node.call(8, 802, "8층 실험동 (전투)", "방패병과 드론 경비대", ["air_duct"])
		add_node.call(9, 901, "9층 회랑 (전투)", "포위 요격 대기 중", ["stairs"])
		add_node.call(10, 1001, "약실 조율실 (정비)", "🔑 [약실 조율] 정밀 정비실", ["stairs"], true, "chamber_polish")
		add_node.call(10, 1002, "10층 통제실 (전투)", "최종 방어 병력 대치", ["air_duct"])
		add_node.call(11, 1101, "무기 캐비닛 (상점)", "최종 정비 무기고 상점", ["stairs"])
		add_node.call(12, 1201, "구역 탈출구 (보스)", "탈출용 엘리베이터 앞 최종 방어 요원", ["stairs"])

		map_nodes[101].connected_node_ids = [201, 202]
		map_nodes[101].connected_node_routes[201] = "stairs"
		map_nodes[101].connected_node_routes[202] = "air_duct"
		map_nodes[102].connected_node_ids = [202]
		map_nodes[102].connected_node_routes[202] = "air_duct"
		map_nodes[201].connected_node_ids = [301, 302]
		map_nodes[201].connected_node_routes[301] = "stairs"
		map_nodes[201].connected_node_routes[302] = "air_duct"
		map_nodes[202].connected_node_ids = [302]
		map_nodes[202].connected_node_routes[302] = "air_duct"
		map_nodes[301].connected_node_ids = [401]
		map_nodes[301].connected_node_routes[401] = "stairs"
		map_nodes[302].connected_node_ids = [401]
		map_nodes[302].connected_node_routes[401] = "air_duct"
		map_nodes[401].connected_node_ids = [501]
		map_nodes[401].connected_node_routes[501] = "stairs"
		map_nodes[501].connected_node_ids = [601]
		map_nodes[501].connected_node_routes[601] = "stairs"
		map_nodes[601].connected_node_ids = [701, 702]
		map_nodes[601].connected_node_routes[701] = "stairs"
		map_nodes[601].connected_node_routes[702] = "air_duct"
		map_nodes[701].connected_node_ids = [801, 802]
		map_nodes[701].connected_node_routes[801] = "stairs"
		map_nodes[701].connected_node_routes[802] = "air_duct"
		map_nodes[702].connected_node_ids = [802]
		map_nodes[702].connected_node_routes[802] = "air_duct"
		map_nodes[801].connected_node_ids = [901]
		map_nodes[801].connected_node_routes[901] = "stairs"
		map_nodes[802].connected_node_ids = [901]
		map_nodes[802].connected_node_routes[901] = "air_duct"
		map_nodes[901].connected_node_ids = [1001, 1002]
		map_nodes[901].connected_node_routes[1001] = "stairs"
		map_nodes[901].connected_node_routes[1002] = "air_duct"
		map_nodes[1001].connected_node_ids = [1101]
		map_nodes[1001].connected_node_routes[1101] = "stairs"
		map_nodes[1002].connected_node_ids = [1101]
		map_nodes[1002].connected_node_routes[1101] = "air_duct"
		map_nodes[1101].connected_node_ids = [1201]
		map_nodes[1101].connected_node_routes[1201] = "stairs"

	else:
		# 펜트하우스 및 무한 루프 (상급/도전 - 15층 구조 / 보스 15층)
		# 기존 15층 레이아웃 유지
		add_node.call(1, 101, "사무실 (전투)", "무장 순찰 경비 대기 중", ["stairs", "air_duct"])
		add_node.call(1, 102, "환기 서버실 (전투)", "침투 드론 경비대 순찰 중", ["air_duct"])
		add_node.call(2, 201, "연구실 복도 (전투)", "경보 장치가 삼엄한 복도", ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "센서 교란 구역", ["air_duct"])
		add_node.call(3, 301, "보안 대기실 (전투)", "정찰 경비대 순찰 중", ["stairs"])
		add_node.call(3, 302, "보안 무기고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 전용 탄약 보급실", ["air_duct"], true, "caliber_762")
		add_node.call(4, 401, "무기 캐비닛 (상점)", "구역 D/E 무기고 상점 단말기", ["stairs"])
		add_node.call(5, 501, "물류 창고 (전투)", "순찰 중인 경보 공중 드론 발견", ["stairs", "air_duct"])
		add_node.call(5, 502, "환기 대피소 (전투)", "돌발 공격대 매복 중", ["air_duct"])
		add_node.call(6, 601, "실험실 복도 (전투)", "방패 요원이 전술 대기 중", ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "센서 교란 구역", ["air_duct"])
		add_node.call(7, 701, "??? (미지)", "센서 교란 구역", ["stairs"])
		add_node.call(7, 702, "가스 제어실 (우회)", "환기 설비를 이용한 독가스 차단 우회 통로", ["air_duct"])
		add_node.call(8, 801, "전력 제어실 (전투)", "전력 복구를 방해하는 적 발견", ["stairs", "air_duct"])
		add_node.call(8, 802, "??? (미지)", "센서 교란 구역", ["stairs", "air_duct"])
		add_node.call(9, 901, "무기 캐비닛 (상점)", "구역 D/E 중층 무기고 상점 단말기", ["stairs"])
		add_node.call(10, 1001, "서버 보관실 (전투)", "중장갑 순찰대 경비 대기 중", ["stairs", "air_duct"])
		add_node.call(10, 1002, "보안실 통로 (전투)", "포위 공격대 대기 중", ["air_duct"])
		add_node.call(11, 1101, "연구동 회랑 (전투)", "정밀 센서 감지 삼엄한 구역", ["stairs", "air_duct"])
		add_node.call(11, 1102, "??? (미지)", "센서 교란 구역", ["air_duct"])
		add_node.call(12, 1201, "??? (미지)", "센서 교란 구역", ["stairs"])
		add_node.call(12, 1202, "약실 조율실 (정비)", "🔑 [약실 조율 구역] 정밀 소탕 조율실", ["air_duct"], true, "chamber_polish")
		add_node.call(13, 1301, "헬리패드 계단 (전투)", "최종 방어 병력 포진 구역", ["stairs", "air_duct"])
		add_node.call(13, 1302, "??? (미지)", "센서 교란 구역", ["stairs", "air_duct"])
		add_node.call(14, 1401, "무기 캐비닛 (상점)", "구역 D/E 최종 무기고 상점 단말기", ["stairs"])
		add_node.call(15, 1501, "옥상 헬리패드 (최종 보스)", "탈출을 가로막는 최종 병기 조우", ["stairs"])

		map_nodes[101].connected_node_ids = [201, 202]
		map_nodes[101].connected_node_routes[201] = "stairs"
		map_nodes[101].connected_node_routes[202] = "air_duct"
		map_nodes[102].connected_node_ids = [202]
		map_nodes[102].connected_node_routes[202] = "air_duct"
		map_nodes[201].connected_node_ids = [301, 302]
		map_nodes[201].connected_node_routes[301] = "stairs"
		map_nodes[201].connected_node_routes[302] = "air_duct"
		map_nodes[202].connected_node_ids = [301]
		map_nodes[202].connected_node_routes[301] = "air_duct"
		map_nodes[301].connected_node_ids = [401]
		map_nodes[301].connected_node_routes[401] = "stairs"
		map_nodes[302].connected_node_ids = [401]
		map_nodes[302].connected_node_routes[401] = "air_duct"
		map_nodes[401].connected_node_ids = [501, 502]
		map_nodes[401].connected_node_routes[501] = "stairs"
		map_nodes[401].connected_node_routes[502] = "air_duct"
		map_nodes[501].connected_node_ids = [601, 602]
		map_nodes[501].connected_node_routes[601] = "stairs"
		map_nodes[501].connected_node_routes[602] = "air_duct"
		map_nodes[502].connected_node_ids = [602]
		map_nodes[502].connected_node_routes[602] = "air_duct"
		map_nodes[601].connected_node_ids = [701, 702]
		map_nodes[601].connected_node_routes[701] = "stairs"
		map_nodes[601].connected_node_routes[702] = "air_duct"
		map_nodes[602].connected_node_ids = [701]
		map_nodes[602].connected_node_routes[701] = "air_duct"
		map_nodes[701].connected_node_ids = [801, 802]
		map_nodes[701].connected_node_routes[801] = "stairs"
		map_nodes[701].connected_node_routes[802] = "air_duct"
		map_nodes[702].connected_node_ids = [802]
		map_nodes[702].connected_node_routes[802] = "air_duct"
		map_nodes[801].connected_node_ids = [901]
		map_nodes[801].connected_node_routes[901] = "stairs"
		map_nodes[802].connected_node_ids = [901]
		map_nodes[802].connected_node_routes[901] = "stairs"
		map_nodes[901].connected_node_ids = [1001, 1002]
		map_nodes[901].connected_node_routes[1001] = "stairs"
		map_nodes[901].connected_node_routes[1002] = "air_duct"
		map_nodes[1001].connected_node_ids = [1101, 1102]
		map_nodes[1001].connected_node_routes[1101] = "stairs"
		map_nodes[1001].connected_node_routes[1102] = "air_duct"
		map_nodes[1002].connected_node_ids = [1102]
		map_nodes[1002].connected_node_routes[1102] = "air_duct"
		map_nodes[1101].connected_node_ids = [1201, 1202]
		map_nodes[1101].connected_node_routes[1201] = "stairs"
		map_nodes[1101].connected_node_routes[1202] = "air_duct"
		map_nodes[1102].connected_node_ids = [1201]
		map_nodes[1102].connected_node_routes[1201] = "air_duct"
		map_nodes[1201].connected_node_ids = [1301, 1302]
		map_nodes[1201].connected_node_routes[1301] = "stairs"
		map_nodes[1201].connected_node_routes[1302] = "air_duct"
		map_nodes[1202].connected_node_ids = [1302]
		map_nodes[1202].connected_node_routes[1302] = "air_duct"
		map_nodes[1301].connected_node_ids = [1401]
		map_nodes[1301].connected_node_routes[1401] = "stairs"
		map_nodes[1302].connected_node_ids = [1401]
		map_nodes[1302].connected_node_routes[1401] = "stairs"
		map_nodes[1401].connected_node_ids = [1501]
		map_nodes[1401].connected_node_routes[1501] = "stairs"

	_finalize_route_graph()


## 상점 진입 가격(계단/환기구)을 런마다 배치한다.
## 상점이 2개 이상이면 최소 1개는 계단, 최소 1개는 환기구가 된다.
func _finalize_route_graph() -> void:
	var armory_ids: Array[int] = []
	for node_id in map_nodes.keys():
		var node: RunNode = map_nodes[node_id]
		if node.type_name.contains("상점"):
			armory_ids.append(node_id)

	if armory_ids.size() < 2:
		return

	armory_ids.shuffle()
	var air_duct_count := randi_range(1, armory_ids.size() - 1)
	var air_duct_armories: Array[int] = []
	for i in range(air_duct_count):
		air_duct_armories.append(armory_ids[i])

	for incoming_id in map_nodes.keys():
		var incoming_node: RunNode = map_nodes[incoming_id]
		for target_id in incoming_node.connected_node_routes.keys():
			if not armory_ids.has(target_id):
				continue
			var route := "air_duct" if air_duct_armories.has(target_id) else "stairs"
			incoming_node.connected_node_routes[target_id] = route
			var target_node: RunNode = map_nodes[target_id]
			target_node.connected_routes = [route]


## 조건부 우회 경로 실시간 해제 검사
func update_conditional_paths() -> void:
	for id in map_nodes.keys():
		var node = map_nodes[id]
		if node.is_hidden:
			var cond = node.unlock_condition_type
			var can_unlock = false
			if cond == "caliber_762":
				if current_gun and (current_gun.display_name.to_upper().contains("HEAVY") or "7.62" in current_gun.display_name or "중장형" in current_gun.display_name):
					can_unlock = true
			elif cond == "chamber_polish":
				if has_chamber_polish:
					can_unlock = true
					
			if can_unlock:
				node.is_hidden = false
				print("디버그: 조건부 우회 경로 해제! 노드 ID = %d, 조건 = %s" % [id, cond])





## 기밀 파편 수집 잠금 해제 (중복 없음)
func collect_lore_fragment(fragment_id: int) -> bool:
	if fragment_id < 1 or fragment_id > 20:
		return false
	if not meta_lore_fragments.has(fragment_id):
		meta_lore_fragments.append(fragment_id)
		meta_lore_fragments.sort()
		return true # 신규 수집 성공
	return false # 이미 수집됨


# ── 파츠 장착 및 교체 제어 ──

## 빈 슬롯이 있으면 파츠를 즉시 장착한다. 성공 시 true, 슬롯이 가득 찬 경우 false 반환.
func equip_part_to_slot(part: PartData) -> bool:
	if current_gun == null:
		return false
	if equipped_parts.size() < current_gun.parts_capacity:
		equipped_parts.append(part)
		return true
	return false


## 지정한 인덱스의 장착 파츠를 새 파츠로 강제 교체 장착하고, 기존 파츠는 버린다(파괴).
## 반환: 버려진 이전 파츠
func replace_equipped_part(index: int, new_part: PartData) -> PartData:
	if index < 0 or index >= equipped_parts.size():
		return null
	var old_part = equipped_parts[index]
	equipped_parts[index] = new_part
	return old_part


# ── Hold (임시 보관) 슬롯 제어 ──

## Hold 슬롯에 파츠를 보관한다. 기존에 Hold 파츠가 들어있었다면 밀어내어 폐기한다.
## 반환: 버려진 이전 Hold 파츠
func store_in_hold(part: PartData) -> PartData:
	var old_hold = hold_part
	hold_part = part
	return old_hold


## Hold 슬롯의 파츠와 장착 중인 특정 인덱스의 파츠 간 스왑을 처리한다.
## 만약 해당 장착 인덱스가 비어 있다면 Hold 파츠를 그 자리에 즉시 장착하고 Hold 슬롯은 비운다.
func swap_hold_with_equipped(equipped_index: int) -> void:
	if current_gun == null or hold_part == null:
		return
	
	# 인덱스가 빈 슬롯(새 장착) 범위인 경우
	if equipped_index == equipped_parts.size() and equipped_parts.size() < current_gun.parts_capacity:
		equipped_parts.append(hold_part)
		hold_part = null
		return
		
	# 인덱스가 기존 장착 범위인 경우 스왑
	if equipped_index >= 0 and equipped_index < equipped_parts.size():
		var temp = equipped_parts[equipped_index]
		equipped_parts[equipped_index] = hold_part
		hold_part = temp


# ── 무기 캐비닛 (Tactical Locker Node) 전술 조율 ──

## 장착 중인 파츠 중 하나를 Hold 슬롯으로 안전 추출한다.
## 성공 시 true, Hold 슬롯이 차 있어서 추출 불가인 경우 false 반환.
func extract_to_hold(equipped_index: int) -> bool:
	if hold_part != null or equipped_index < 0 or equipped_index >= equipped_parts.size():
		return false
	hold_part = equipped_parts[equipped_index]
	equipped_parts.remove_at(equipped_index)
	return true


## 장착 중인 두 파츠 간의 슬롯 배치 순서를 서로 스왑한다. (LIFO 순서 튜닝용)
func swap_equipped_parts(idx1: int, idx2: int) -> void:
	if idx1 < 0 or idx1 >= equipped_parts.size() or idx2 < 0 or idx2 >= equipped_parts.size():
		return
	var temp = equipped_parts[idx1]
	equipped_parts[idx1] = equipped_parts[idx2]
	equipped_parts[idx2] = temp


# ── 가방 인벤토리 및 크레딧 조작 제어 ──

## 가방의 빈 슬롯이 있으면 아이템(개조 파츠/소모품/탄약박스 등)을 보관한다. 성공 시 true, 슬롯 가득 찬 경우 false 반환.
func add_to_backpack(item: Resource) -> bool:
	if backpack_items.size() < BACKPACK_CAPACITY:
		backpack_items.append(item)
		return true
	return false

## 지정 인덱스의 아이템을 가방에서 추출 및 제거하여 반환한다.
func remove_from_backpack_at(index: int) -> Resource:
	if index >= 0 and index < backpack_items.size():
		var item = backpack_items[index]
		backpack_items.remove_at(index)
		return item
	return null

## 크레딧을 소비한다. 잔액이 충족되면 차감 후 true 반환, 부족하면 false 반환.
func spend_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		return true
	return false
