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
static var meta_unlocked_weapons: Array[String] = ["workhorse"] # 영구 해금된 총기 목록 (기본 workhorse 해금)
static var meta_lore_fragments: Array[int] = [] # 1~20 범위의 수집된 파편 번호
static var infiltration_risk_level: int = 1 # 1~5 침투 위험도 (정적 보존하여 런 밖에서도 난이도 세팅 유지)

# ── 런 가변 상태 ──
var current_gun: GunData = null                 # 현재 런에서 선택하여 고정된 총기
var equipped_parts: Array[PartData] = []        # 현재 장착된 총기 파츠들
var hold_part: PartData = null                  # 임시 보관 파츠 (최대 1칸)
var hp_buffer: int = 1
var credits: int = 0
var current_floor: int = 1
var current_route_type: String = "stairs" # "stairs", "air_duct", "shaft"
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
var active_relics: Array[String] = []

# ── 맵 구조 데이터 ──
var map_nodes: Dictionary = {}         # id(int) -> RunNode
var floor_connections: Dictionary = {} # floor(int) -> Array[int] (노드 ID 목록)

# ── 노드 정보 구조체 ──
class RunNode:
	var id: int
	var type_name: String
	var description: String
	var connected_routes: Array[String] # 연결되는 통로들: "stairs", "air_duct", "shaft"
	
	# 신설 필드
	var connected_node_ids: Array = [] # 다음 층의 타겟 노드 ID들
	var connected_node_routes: Dictionary = {} # target_node_id(int) -> route_type(String, "stairs", "air_duct", "shaft")
	var is_hidden: bool = false            # 조건부 노출 여부
	var unlock_condition_type: String = ""  # "caliber_762", "gas_valve", "chamber_polish", ""
	var hidden_type: String = ""            # ??? 노드 내부의 진짜 타입
	var scan_hint: String = ""              # 전술 스캔 힌트
	
	func _init(_id: int, _type: String, _desc: String, _routes: Array[String]):
		id = _id
		type_name = _type
		description = _desc
		connected_routes = _routes


## 신규 런 시작 및 상태 초기화
func start_new_run(gun: GunData, basic_bullet: BulletData, ap_bullet: BulletData, kb_bullet: BulletData) -> void:
	# 런타임 시작 시 CSV 데이터 동기화
	_sync_gun_stats_from_csv(gun)
	_sync_bullet_stats_from_csv(basic_bullet)
	_sync_bullet_stats_from_csv(ap_bullet)
	_sync_bullet_stats_from_csv(kb_bullet)

	current_floor = 1
	hp_buffer = 1 + meta_hp_armor_lvl
	credits = 0
	deck.clear()
	discarded_bullets.clear()
	active_relics.clear()
	has_chamber_polish = false
	current_route_type = "stairs"
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
			return "좁은 환기구를 포복 전진합니다.\n[패널티] 공간의 제약으로 인해 전투 진입 시 적과의 시작 거리가 2칸 단축됩니다!"
		"shaft":
			# 와이어 끊어짐 확률 30%
			if randf() < 0.3:
				hp_buffer = maxi(hp_buffer - 1, 0)
				return "샤프트 와이어가 끊어지며 동체가 추락했습니다!\n[피해] 비상 제동 장치가 작동했으나 HP 버퍼가 1 소실되었습니다!"
			else:
				return "엘리베이터 샤프트 로프를 타고 고속 침투합니다.\n[패널티] 적의 급습으로 인해 전투 진입 시 거리 4칸의 초근접 대치가 시작됩니다!"
	return ""


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
	var earned := (current_floor * 15) + (active_relics.size() * 20) + won_bonus
	meta_credits += earned
	
	# 전술 데이터 코어 영구 누적
	meta_tactical_data_cores += tactical_data_cores
	return earned


## 전투 승리 시 침투 경로별 전술 데이터 코어(TDC) 가산
func record_combat_win(route_type: String) -> int:
	var earned_cores = 0
	match route_type:
		"air_duct":
			earned_cores = 1
		"shaft":
			earned_cores = 2
	
	tactical_data_cores += earned_cores
	if earned_cores > 0:
		run_stats.hard_zones_cleared += 1
	return earned_cores


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
		return true
	return false

static func upgrade_meta_hp_armor() -> bool:
	if meta_credits >= 50 and meta_hp_armor_lvl < 2:
		meta_credits -= 50
		meta_hp_armor_lvl += 1
		return true
	return false

static func upgrade_meta_discount() -> bool:
	if meta_credits >= 30 and not meta_discount_unlocked:
		meta_credits -= 30
		meta_discount_unlocked = true
		return true
	return false


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
				n.scan_hint = "스캔: 렐릭 에너지 반응 감지 (보급고 유력)"
			else:
				n.hidden_type = "보안 통제실 (이벤트)"
				n.scan_hint = "스캔: 미세 전자기기 노이즈 감지 (상점 유력)"
				
		map_nodes[id] = n
		if not floor_connections.has(f):
			floor_connections[f] = []
		floor_connections[f].append(id)
		return n

	# 1층 (시작)
	add_node.call(1, 101, "사무실 (전투)", "무장 순찰 경비 대기 중", ["stairs", "air_duct"])
	add_node.call(1, 102, "환기 서버실 (전투)", "침투 드론 경비대 순찰 중", ["air_duct", "shaft"])
	
	# 2층
	add_node.call(2, 201, "연구실 복도 (전투)", "경보 장치가 삼엄한 복도", ["stairs", "air_duct"])
	add_node.call(2, 202, "??? (미지)", "센서 교란 구역", ["air_duct", "shaft"])
	
	# 3층 (정비)
	add_node.call(3, 301, "무기 캐비닛 (정비)", "보안 정비 단말기와 장비 상자 발견", ["stairs"])
	# 조건부 3층 노드 (7.62mm 중장형 총기 필요)
	add_node.call(3, 302, "보안 무기고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 전용 탄약 보급실", ["shaft"], true, "caliber_762")
	
	# 4층
	add_node.call(4, 401, "물류 창고 (전투)", "순찰 중인 경보 공중 드론 발견", ["stairs", "air_duct"])
	add_node.call(4, 402, "??? (미지)", "센서 교란 구역", ["stairs", "shaft"])
	
	# 5층 (중층 보스)
	add_node.call(5, 501, "보안 통제 센터 (보스)", "구역 보안 총책임자 대기 중", ["stairs"])
	
	# 6층 (휴식/완충)
	add_node.call(6, 601, "안전한 대피소 (완충)", "요원 안전 구역 및 의료 상자 탑재", ["stairs", "air_duct"])
	# 조건부 6층 노드 (가스 밸브 렐릭 요구)
	add_node.call(6, 602, "가스 제어실 (우회)", "🔑 [가스 제어 통로] 독가스 면제 우회 통로", ["air_duct"], true, "gas_valve")
	
	# 7층
	add_node.call(7, 701, "실험실 복도 (전투)", "방패 요원이 전술 대기 중", ["stairs", "air_duct"])
	add_node.call(7, 702, "??? (미지)", "센서 교란 구역", ["stairs", "shaft"])
	
	# 8층 (이벤트)
	add_node.call(8, 801, "보안 통제실 (이벤트)", "서버 랙 및 터미널 가동 중", ["stairs"])
	# 조건부 8층 노드 (약실 소탕 버프 요구)
	add_node.call(8, 802, "약실 조율실 (정비)", "🔑 [약실 조율 구역] 정밀 소탕 조율실", ["air_duct"], true, "chamber_polish")
	
	# 9층 (최종 정비)
	add_node.call(9, 901, "보급 캐비닛 (정비)", "특수 작전용 마지막 정비 캐비닛", ["stairs"])
	
	# 10층 (최종 보스)
	add_node.call(10, 1001, "옥상 헬리패드 (최종 보스)", "탈출을 가로막는 최종 병기 조우", ["stairs"])
	
	# ── 연결 정보 세팅 (connected_node_ids) ──
	map_nodes[101].connected_node_ids = [201, 202]
	map_nodes[101].connected_node_routes[201] = "stairs"
	map_nodes[101].connected_node_routes[202] = "air_duct"
	
	map_nodes[102].connected_node_ids = [202]
	map_nodes[102].connected_node_routes[202] = "air_duct"
	
	map_nodes[201].connected_node_ids = [301, 302]
	map_nodes[201].connected_node_routes[301] = "stairs"
	map_nodes[201].connected_node_routes[302] = "shaft"
	
	map_nodes[202].connected_node_ids = [301]
	map_nodes[202].connected_node_routes[301] = "air_duct"
	
	map_nodes[301].connected_node_ids = [401, 402]
	map_nodes[301].connected_node_routes[401] = "stairs"
	map_nodes[301].connected_node_routes[402] = "stairs"
	
	map_nodes[302].connected_node_ids = [402]
	map_nodes[302].connected_node_routes[402] = "shaft"
	
	map_nodes[401].connected_node_ids = [501]
	map_nodes[401].connected_node_routes[501] = "stairs"
	
	map_nodes[402].connected_node_ids = [501]
	map_nodes[402].connected_node_routes[501] = "stairs"
	
	map_nodes[501].connected_node_ids = [601, 602]
	map_nodes[501].connected_node_routes[601] = "stairs"
	map_nodes[501].connected_node_routes[602] = "air_duct"
	
	map_nodes[601].connected_node_ids = [701, 702]
	map_nodes[601].connected_node_routes[701] = "stairs"
	map_nodes[601].connected_node_routes[702] = "air_duct"
	
	map_nodes[602].connected_node_ids = [702]
	map_nodes[602].connected_node_routes[702] = "air_duct"
	
	map_nodes[701].connected_node_ids = [801, 802]
	map_nodes[701].connected_node_routes[801] = "stairs"
	map_nodes[701].connected_node_routes[802] = "air_duct"
	
	map_nodes[702].connected_node_ids = [801]
	map_nodes[702].connected_node_routes[801] = "stairs"
	
	map_nodes[801].connected_node_ids = [901]
	map_nodes[801].connected_node_routes[901] = "stairs"
	
	map_nodes[802].connected_node_ids = [901]
	map_nodes[802].connected_node_routes[901] = "air_duct"
	
	map_nodes[901].connected_node_ids = [1001]
	map_nodes[901].connected_node_routes[1001] = "stairs"


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
			elif cond == "gas_valve":
				if active_relics.has("gas_valve"):
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
