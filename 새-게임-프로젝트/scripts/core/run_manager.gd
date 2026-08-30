class_name RunManager
extends RefCounted

const PlaytestLoggerScript = preload("res://scripts/core/playtest_logger.gd")
const RandomStreamsScript = preload("res://scripts/core/random_streams.gd")

## ═══════════════════════════════════════════════════
## 로그라이크 런 및 메타 영구 해금 매니저
## ═══════════════════════════════════════════════════

# ── 영구 메타 데이터 (정적 보존) ──
const DEFAULT_META_CREDITS := 100
static var meta_credits: int = DEFAULT_META_CREDITS
static var meta_backpack_lvl: int = 0    # 시작 전술탄 +1/레벨 업그레이드 (최대 3)
static var meta_hp_armor_lvl: int = 0    # 시작 HP 버퍼 업그레이드 (최대 2 -> 버퍼 1~3)
static var meta_discount_unlocked: bool = false # 탄환 폐기 수수료 면제
static var meta_tactical_data_cores: int = 0 # 전술 데이터 코어 누적 자원
static var meta_vault_lvl: int = 0           # 전술 금고 레벨 (0~3)
static var saved_vault_credits: int = 0     # 전술 금고 이월 크레딧
static var starting_bonus_available: bool = false # 스타팅 보증 사용 가능 여부
static var meta_unlocked_weapons: Array[String] = ["workhorse"] # 영구 해금된 총기 목록 (기본 workhorse 해금)
static var meta_unlocked_sections: Array[String] = ["section_a"] # 영구 해금된 작전 구역 목록 (기본 section_a 지하주차장 해금)
static var meta_lore_fragments: Array[int] = [] # 1~20 범위의 수집된 파편 번호
## gambler 해금 임계 — 적을 시작 거리의 이 비율 이내로 들이면 실패.
const GAMBLER_DIST_RATIO := 1.0 / 3.0
## 클래스별 시작 패키지 정본: [기본 보급탄, 전술 A, 전술 B].
## 기반탄의 전문축을 보완하도록 화력/관통/명중/제어 중 서로 다른 전술축을 지급한다.
## 리소스 경로를 여러 분기에 복사하지 않아 탄환 마이그레이션 시 유령 참조를 막는다.
const STARTING_AMMO_IDS := {
	Enums.WeaponClass.PISTOL: ["cal_9mm", "borer", "chain"],
	Enums.WeaponClass.SMG: ["cal_45acp", "marker", "borer"],
	Enums.WeaponClass.RIFLE: ["cal_556", "borer", "chain"],
	Enums.WeaponClass.DMR: ["cal_762", "borer", "chain"],
	Enums.WeaponClass.SHOTGUN: ["cal_12g", "shred", "impact"],
}

## ── 승천(Ascension) ── 정본: docs/gdd/20_ascension_intention.md
## 해금된 최고 등급. 정점 클리어 시 1이 열리고, 그 등급으로 완주할 때마다 하나씩 올라간다.
static var meta_ascension_unlocked: int = 0
## 이번 런에 적용할 등급(0 = 승천 없음). 타이틀에서 고르며 런 내내 고정된다.
static var meta_ascension_level: int = 0

static var infiltration_risk_level: int = 1 # 1~5 침투 위험도 (정적 보존하여 런 밖에서도 난이도 세팅 유지)

# ── 런 가변 상태 ──
var current_gun: GunData = null                 # 현재 런에서 선택하여 고정된 총기
var equipped_parts: Array[PartData] = []        # 현재 장착된 총기 파츠들
var hold_part: PartData = null                  # 임시 보관 파츠 (최대 1칸)
var hp_buffer: int = 1
var credits: int = 0
const BACKPACK_CAPACITY: int = 8
var backpack_items: Array[Resource] = []
## 준비 화면에서 고른 스타팅 보증은 런 초기화가 끝난 뒤 적용한다.
## 선택 즉시 credits/backpack에 넣으면 start_new_run()의 초기화로 보상이 사라진다.
var pending_starting_bonus_credits: int = 0
var pending_starting_bonus_part: PartData = null
var current_floor: int = 1
var current_section: String = "section_a"        # 현재 런의 작전 구역 ID
const AIR_DUCT_DISTANCE_PENALTY: int = -2

var current_route_type: String = "stairs" # "stairs", "air_duct"
var current_node_id: int = 0
var pending_combat_distance_modifier: int = 0
var has_chamber_polish: bool = false     # 약실 소탕 리로드 면제 버프
var visible_magazine_slots: int = 2      # 전투 중 보여질 예고창 탄환 개수 (기본 2칸)
var tactical_data_cores: int = 0         # 이번 런에서 획득한 전술 데이터 코어 수

## 게임 세이브와 분리된 로컬 플레이테스트 텔레메트리.
var playtest_logger = PlaytestLoggerScript.new()
var gameplay_seed: int = 0
var qa_session_id: String = ""

# ── 런 도전 과제 판정 통계 ──
var run_stats := {
	"lead_bullets_fired": 0,
	"min_dist_allowed": 99,
	"min_dist_ratio": 1.0,
	"hard_zones_cleared": 0,
	"max_kills_in_single_turn": 0,
	"average_kill_distance": 0.0,
	"total_kills": 0,
	"total_kill_dist_sum": 0.0,
	"tanks_killed_by_shred_only": 0,
	"stance_shifts_killed_without_slow": 0,
	"perfect_battles_count": 0,
	"magazine_emptied_wins": 0
}

var deck: Array[BulletData] = []
## 기본탄은 전술 덱에 들어가지 않는 총기 고정 보급원이다.
## 전투마다 총기의 실제 장전 한도까지 지급되고 리로드 때 같은 상한으로 복구된다.
var basic_supply_bullet: BulletData = null
var discarded_bullets: Array[BulletData] = [] # Unload로 버려져 소실 위기에 놓인 탄환들
# ── 맵 구조 데이터 ──
## ⚠️ 아래 두 변수는 **현재 계층의 맵을 가리키는 활성 뷰**다. 실체는 section_maps가 소유한다.
##    (기존 코드 전반이 이 이름을 참조하므로 시그니처를 유지한다)
var map_nodes: Dictionary = {}         # id(int) -> RunNode
var floor_connections: Dictionary = {} # floor(int) -> Array[int] (노드 ID 목록)

## 런 전체 지도. section(String) -> {map_nodes, floor_connections}
## 연속 런에서 지도는 35층 전체를 보여주므로, 아직 도달하지 않은 계층의 맵도 미리 갖고 있어야 한다.
var section_maps: Dictionary = {}

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
func start_new_run(
	section_id: String,
	gun: GunData,
	basic_bullet: BulletData,
	ap_bullet: BulletData,
	kb_bullet: BulletData,
	seed: int = 0,
	session_id: String = ""
) -> void:
	gameplay_seed = RandomStreamsScript.begin_run(seed)
	qa_session_id = session_id
	# 런타임 시작 시 CSV 데이터 동기화
	_sync_gun_stats_from_csv(gun)
	_sync_bullet_stats_from_csv(basic_bullet)
	_sync_bullet_stats_from_csv(ap_bullet)
	_sync_bullet_stats_from_csv(kb_bullet)

	current_section = section_id
	current_floor = 1
	# 승천은 메타 파워를 상쇄한다(§5) — HP 아머 업그레이드를 시작 아머 −N으로 되돌린다.
	# ⚠️ 최소 1은 보장한다. 0이면 첫 접근에 즉사해 "완벽한 플레이도 이길 수 없는" 상태가 된다(§6 바닥선).
	hp_buffer = maxi(1 + meta_hp_armor_lvl + int(ascension_effects().armor_delta), 1)
	credits = saved_vault_credits
	saved_vault_credits = 0
	backpack_items.clear()
	deck.clear()
	basic_supply_bullet = null
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
		"min_dist_ratio": 1.0,
		"hard_zones_cleared": 0,
		"max_kills_in_single_turn": 0,
		"average_kill_distance": 0.0,
		"total_kills": 0,
		"total_kill_dist_sum": 0.0,
		"tanks_killed_by_shred_only": 0,
		"stance_shifts_killed_without_slow": 0,
		"perfect_battles_count": 0,
		"magazine_emptied_wins": 0
	}
	
	# 총기 및 기본 파츠 초기화
	current_gun = gun
	equipped_parts.clear()
	hold_part = null
	if current_gun != null and current_gun.default_part != null:
		equipped_parts.append(current_gun.default_part)
	
	# 시작 패키지 구성. 기본탄은 고정 보급원으로 분리하고 전술탄만 런 덱에 넣는다.
	if current_gun != null:
		var cls: int = current_gun.weapon_class
		var basic_path := ""
		var specA_path := ""
		var specB_path := ""
		# 전술 백팩은 더 이상 무한 보급되는 기본탄을 늘리지 않는다.
		# 레벨당 전술탄 1발을 A/B에 번갈아 지급해 기존 +1발 성장량을 보존한다.
		var specA_cnt := 2 + ceili(float(meta_backpack_lvl) / 2.0)
		var specB_cnt := 1 + floori(float(meta_backpack_lvl) / 2.0)

		var ammo_ids: Array = STARTING_AMMO_IDS.get(cls, [])
		if ammo_ids.size() == 3:
			basic_path = "res://resources/bullets/%s.tres" % ammo_ids[0]
			specA_path = "res://resources/bullets/%s.tres" % ammo_ids[1]
			specB_path = "res://resources/bullets/%s.tres" % ammo_ids[2]
		else:
			push_error("RunManager: 클래스 %d의 시작 탄환 구성이 없습니다." % cls)

		# 승천: 전술 시작 덱 감소(§4.1 레버 ②). 각 계열에서 1발씩 빼되 최소 1발은 남긴다.
		# ⚠️ 0으로 만들면 해당 탄 계열이 통째로 사라져 빌드가 아니라 결함이 된다.
		var deck_delta: int = int(ascension_effects().deck_delta)
		if deck_delta != 0:
			specA_cnt = maxi(specA_cnt + deck_delta, 1)
			specB_cnt = maxi(specB_cnt + deck_delta, 1)

		var b_res: BulletData = load(basic_path)
		var sa_res: BulletData = load(specA_path)
		var sb_res: BulletData = load(specB_path)

		if b_res:
			_sync_bullet_stats_from_csv(b_res)
			basic_supply_bullet = b_res.duplicate()
		elif basic_bullet != null:
			basic_supply_bullet = basic_bullet.duplicate()
		if sa_res: _sync_bullet_stats_from_csv(sa_res)
		if sb_res: _sync_bullet_stats_from_csv(sb_res)

		for i in range(specA_cnt):
			if sa_res: deck.append(sa_res.duplicate())
		for i in range(specB_cnt):
			if sb_res: deck.append(sb_res.duplicate())

	_apply_pending_starting_bonus()
			
	# 맵 데이터 생성 및 조건부 우회 경로 업데이트
	generate_run_map()
	update_conditional_paths()
	var log_error := playtest_logger.begin_run(playtest_snapshot())
	if log_error != OK:
		push_warning("플레이테스트 로그 시작 실패: %d" % log_error)


func queue_starting_bonus_credits(amount: int) -> void:
	pending_starting_bonus_credits = maxi(amount, 0)
	pending_starting_bonus_part = null


func queue_starting_bonus_part(part: PartData) -> void:
	pending_starting_bonus_credits = 0
	pending_starting_bonus_part = null if part == null else part.duplicate()


func _apply_pending_starting_bonus() -> void:
	var has_pending := pending_starting_bonus_credits > 0 or pending_starting_bonus_part != null
	if not has_pending:
		return
	if pending_starting_bonus_credits > 0:
		credits += pending_starting_bonus_credits
	elif pending_starting_bonus_part != null:
		# 새 런은 빈 가방으로 시작하므로 정상 경로에서는 반드시 성공한다.
		if not add_to_backpack(pending_starting_bonus_part):
			credits += 50
	pending_starting_bonus_credits = 0
	pending_starting_bonus_part = null
	starting_bonus_available = false
	save_meta()


## 전투 종료 시 CombatManager의 구조화 보고서와 현재 런 문맥을 함께 저장한다.
func record_playtest_encounter(encounter_report: Dictionary) -> Error:
	return playtest_logger.append_encounter(playtest_snapshot(), encounter_report)


func record_playtest_event(event_type: String, details: Dictionary) -> Error:
	return playtest_logger.append_event(event_type, playtest_snapshot(), details)


func finish_playtest_log(result: String) -> Error:
	return playtest_logger.finish_run(result, playtest_snapshot())


func playtest_log_path() -> String:
	return playtest_logger.latest_file_path()


func playtest_snapshot() -> Dictionary:
	var parts: Array[Dictionary] = []
	for part in equipped_parts:
		parts.append(PlaytestLoggerScript.resource_snapshot(part))
	var deck_counts: Dictionary = {}
	for bullet in deck:
		var bullet_id := PlaytestLoggerScript.resource_id(bullet)
		deck_counts[bullet_id] = int(deck_counts.get(bullet_id, 0)) + 1
	return {
		"qa_session_id": qa_session_id,
		"gameplay_seed": gameplay_seed,
		"rng": RandomStreamsScript.snapshot(),
		"section": current_section,
		"floor": current_floor,
		"node_id": current_node_id,
		"route": current_route_type,
		"ascension": meta_ascension_level,
		"infiltration_risk": infiltration_risk_level,
		"gun": PlaytestLoggerScript.resource_snapshot(current_gun),
		"basic_ammo": PlaytestLoggerScript.resource_snapshot(basic_supply_bullet),
		"equipped_parts": parts,
		"deck_counts": deck_counts,
		"credits": credits,
		"hp_buffer": hp_buffer,
		"run_stats": run_stats.duplicate(true),
	}


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
		g.conversion_cost = float(csv.get("conversion_cost", 1.0))
		g.fire_mode = csv.fire_mode
		# preview_window_size는 CSV에 없으면 -1로 오므로 .tres 값을 보존한다.
		if int(csv.get("preview_window_size", -1)) >= 0:
			g.preview_window_size = int(csv.preview_window_size)
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
		b.weapon_class = csv.caliber
		b.family = csv.family
		b.is_basic = csv.is_basic
		b.role = csv.role
		b.specialty = csv.specialty
		b.effect_type = csv.effect_type
		b.effect_value = csv.effect_value
		b.trigger = csv.trigger
		b.scope = csv.scope
		b.condition = csv.condition
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
	if CampaignContent.is_major_gate_type(resolved_type):
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


## 소멸(Exile)되거나 분실된 전술탄을 덱에서 영구 제거.
func exile_bullet_from_deck(bullet: BulletData) -> void:
	# 기본탄은 덱 바깥의 고정 보급원이므로 어떤 난이도에서도 영구 제거 대상이 아니다.
	if bullet == null or bullet.is_basic:
		return
	# 레거시 전용탄 보존 안전장치 — 컨버전 킷 세이브 호환을 위해 계약은 유지한다.
	# 컨버전 킷은 지정 클래스도 전용탄으로 취급한다.
	if current_gun != null and bullet.weapon_class == current_gun.weapon_class:
		return
	var conversion_class := get_conversion_class()
	if conversion_class != Enums.WeaponClass.UNIVERSAL and bullet.weapon_class == conversion_class:
		return
		
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


## 이번 런에서 오른 누적 층수.
##
## ⚠️ `current_floor`는 **계층 안에서의 층 번호**라 계층이 바뀔 때마다 1로 리셋된다.
##    연속 런에서 진척도를 재는 값은 이쪽이다. 정산에 current_floor를 쓰면
##    "공역 2층에서 죽은 사람(8층 등반)"이 "침전 5층에서 죽은 사람(5층 등반)"보다
##    보상을 적게 받는 역전이 생긴다.
func total_floors_climbed() -> int:
	var total := 0
	for sec in SECTION_ORDER:
		if sec == current_section:
			break
		total += int(MapGenerator.section_info(sec).floors)
	return total + current_floor


## 이번 런의 총 길이. 해금 상태와 무관하게 5계층·35층 전체가 한 번의 상승이다.
func total_run_length() -> int:
	var total := 0
	for sec in run_itinerary():
		total += int(MapGenerator.section_info(sec).floors)
	return maxi(total, 1)


## 층 진척도에 따른 교전 시작 거리 보정(m).
## 초반에는 적이 멀리서 나타나 탄창을 정리할 여유를 주고, 종반에는 거리를 좁혀 압박한다.
##
## ⚠️ 기준은 **누적 등반 층수의 비율**이다. 계층 내 층 번호(current_floor)를 쓰면
##    계층마다 난이도가 리셋되어 정점 1층에서도 초반 보너스 +6m가 붙는다.
##    절대 층수가 아니라 35층 전체 대비 비율로 판정해야 계층 경계에서도
##    난이도가 되감기지 않는다.
##
## 구간 비율은 구 15층 구역 기준 램프(20%/47%/67%/93%)를 그대로 옮긴 것이다.
func floor_distance_modifier() -> int:
	var progress := float(total_floors_climbed()) / float(total_run_length())
	if progress <= 0.20: return 6
	if progress <= 0.47: return 4
	if progress <= 0.67: return 2
	if progress <= 0.93: return 0
	return -2


## 런 정산 및 크레딧 환전
func end_run(won: bool) -> int:
	var won_bonus := 50 if won else 0
	var earned := (total_floors_climbed() * 15) + won_bonus
	# 승천은 이미 클리어한 플레이어의 영구 성장 반복을 늦추지 않는다.
	# 크레딧 압박은 현재 런의 전투 보상에 적용해 상점 구매 판단으로 체감시킨다.
	meta_credits += earned

	# 전술 데이터 코어 영구 누적
	meta_tactical_data_cores += tactical_data_cores

	# 스타팅 보증금 보상 체크 (4층 상점 도달 이상)
	if total_floors_climbed() >= 4:
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


## 작전 구역 해금 순서 — 앞 구역을 완주하면 다음 구역이 열린다.
const SECTION_ORDER: Array[String] = ["section_a", "section_b", "section_c", "section_d", "section_e"]


## 현재 계층 다음에 **이미 해금되어 있는** 계층 ID를 반환한다. 없으면 "".
## 메타/UI 호환용 조회이며 런 종료 판정에는 사용하지 않는다.
func get_next_unlocked_section() -> String:
	var idx := SECTION_ORDER.find(current_section)
	if idx < 0 or idx + 1 >= SECTION_ORDER.size():
		return ""
	var next_section: String = SECTION_ORDER[idx + 1]
	if not meta_unlocked_sections.has(next_section):
		return ""
	return next_section


## 현재 계층 바로 위의 계층 ID. 해금 여부와 무관하며 정점이면 "".
## 한 런은 35층 전체를 오르므로 구역 경계 진행은 이 함수를 기준으로 한다.
func get_next_section() -> String:
	var idx := SECTION_ORDER.find(current_section)
	if idx < 0 or idx + 1 >= SECTION_ORDER.size():
		return ""
	return String(SECTION_ORDER[idx + 1])


## 다음 계층으로 진입한다. **런 자원(덱·파츠·가방·크레딧)은 유지**되고
## 맵과 층 위치만 새 계층 기준으로 초기화된다.
## (start_new_run을 호출하면 덱이 리셋되므로 계층 이동에는 쓰면 안 된다)
func enter_section(section_id: String) -> void:
	current_section = section_id
	current_floor = 1
	current_node_id = 0
	current_route_type = "stairs"
	# 환기 압박은 계층 경계를 넘겨 이월하지 않는다(다음 교전 한정 비용이므로).
	pending_combat_distance_modifier = 0
	# ⚠️ 여기서 맵을 새로 만들지 않는다. 런 시작 시 전 계층을 확정했고,
	#    지도가 미리 보여준 구성과 실제 도착 시 구성이 달라지면 안 되기 때문이다.
	_bind_current_section_map()
	update_conditional_paths()


## 이번 런에 적용되는 승천 효과 묶음. 정본: scripts/core/ascension.gd
static func ascension_effects() -> Dictionary:
	return Ascension.effects_for(meta_ascension_level)


## 승천 배급 페널티가 반영된 런 중 전투 크레딧.
## 양수 보상은 최고 등급에서도 최소 1 Cr을 보장해 보상 선택지가 0이 되지 않게 한다.
static func adjusted_combat_credit_reward(base_amount: int) -> int:
	if base_amount <= 0:
		return base_amount
	var mult: float = float(ascension_effects().combat_credit_mult)
	return maxi(int(round(float(base_amount) * mult)), 1)


## 승천 등급 해금 판정 — **정점까지 완주**했을 때만.
## 반환: 새로 해금된 등급(없으면 0)
##
## ⚠️ 지금 적용 중인 등급으로 완주해야 다음 등급이 열린다.
##    낮은 등급으로 반복 완주해도 사다리가 올라가면 "등급 = 난이도" 신뢰가 깨진다.
func check_ascension_unlock(won: bool) -> int:
	if not won:
		return 0
	var last_section: String = String(SECTION_ORDER[SECTION_ORDER.size() - 1])
	if current_section != last_section:
		return 0  # 방어적 호출: 정점이 아닌 계층에서는 완주 신호가 와도 승천을 열지 않는다
	if meta_ascension_unlocked >= Ascension.MAX_LEVEL:
		return 0
	if meta_ascension_level < meta_ascension_unlocked:
		return 0  # 이미 넘은 등급으로 다시 깬 것 — 사다리는 오르지 않는다
	meta_ascension_unlocked += 1
	save_meta()
	return meta_ascension_unlocked


## 런을 완주(구역 보스 처치)했을 때 다음 작전 구역을 영구 해금한다.
## 반환: 새로 해금된 구역 ID 배열 (없으면 빈 배열)
func check_section_unlocks(won: bool) -> Array[String]:
	var newly: Array[String] = []
	if not won:
		return newly

	var idx := SECTION_ORDER.find(current_section)
	if idx < 0 or idx + 1 >= SECTION_ORDER.size():
		return newly  # 미등록 구역이거나 마지막 구역이면 해금할 다음이 없다

	var next_section: String = SECTION_ORDER[idx + 1]
	if not meta_unlocked_sections.has(next_section):
		meta_unlocked_sections.append(next_section)
		newly.append(next_section)
		# 해금은 영구 데이터이므로 즉시 저장한다.
		# (디브리핑은 end_run() → 해금 순서로 호출하는데 end_run 내부 save_meta()가
		#  먼저 실행되므로, 여기서 저장하지 않으면 재시작 시 해금이 유실된다)
		save_meta()
	return newly


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
		
	# 7. 도박형 (gambler): [거리 통제] 어떤 적도 **시작 거리의 1/3 이내**로 들이지 않고 완주
	#
	# ⚠️ 절대 거리("최소 접근 거리 > 1")를 쓰지 않는다. 승천이 시작 거리를 좁히고 적 SPD를
	#    올리면 절대 임계값은 사실상 달성 불가가 되어 진행이 막힌다.
	#    비율 기준이면 난이도가 올라도 "거리를 통제했는가"라는 의도가 그대로 유지된다.
	#    정본: docs/gdd/20_ascension_intention.md §5
	if not meta_unlocked_weapons.has("gambler") and run_stats.get("min_dist_ratio", 1.0) >= GAMBLER_DIST_RATIO:
		newly_unlocked.append("gambler")

	# 8. 제압형 (suppressor): [전탄 소모] 탄창을 한 발도 남기지 않고 비운 채 전투 승리
	# 연발이 강제하는 행동(전량 커밋)을 단발 총으로 미리 연습시키는 조건이다.
	if not meta_unlocked_weapons.has("suppressor") and run_stats.get("magazine_emptied_wins", 0) >= 1:
		newly_unlocked.append("suppressor")
		
	for weapon in newly_unlocked:
		meta_unlocked_weapons.append(weapon)

	# 해금은 영구 데이터이므로 즉시 저장한다.
	# (디브리핑은 end_run() → check_weapon_unlocks() 순서로 호출하는데,
	#  end_run 내부 save_meta()가 먼저 실행되므로 여기서 저장하지 않으면
	#  "신규 해금" 표시를 보고도 재시작 시 해금이 유실된다)
	if not newly_unlocked.is_empty():
		save_meta()
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
static func save_meta(path := "") -> Error:
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
	cfg.set_value("meta", "ascension_unlocked", meta_ascension_unlocked)
	cfg.set_value("meta", "ascension_level", meta_ascension_level)
	return cfg.save(_resolve_save_path(path))


## 영구 진행을 첫 실행 상태로 되돌리고 기존 세이브 파일을 제거한다.
## 파일 삭제가 막히면 기본값 세이브로 덮어써 다음 실행에서도 초기 상태를 보장한다.
static func reset_meta_progress(path := "") -> Error:
	meta_credits = DEFAULT_META_CREDITS
	meta_backpack_lvl = 0
	meta_hp_armor_lvl = 0
	meta_discount_unlocked = false
	meta_tactical_data_cores = 0
	meta_vault_lvl = 0
	saved_vault_credits = 0
	starting_bonus_available = false
	meta_unlocked_weapons = ["workhorse"] as Array[String]
	meta_unlocked_sections = ["section_a"] as Array[String]
	meta_lore_fragments = [] as Array[int]
	meta_ascension_unlocked = 0
	meta_ascension_level = 0
	infiltration_risk_level = 1

	var save_path := _resolve_save_path(path)
	if not FileAccess.file_exists(save_path):
		return OK

	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if remove_error == OK:
		return OK

	# 삭제 권한이 없는 환경에서도 오래된 진행이 되살아나지 않도록 기본값을 기록한다.
	return save_meta(save_path)


## 개발자 테스트용 전체 초기화. 영구 메타와 현재 런 메모리를 함께 비운다.
func reset_all_progress(path := "") -> Error:
	var result := reset_meta_progress(path)

	current_gun = null
	equipped_parts.clear()
	hold_part = null
	hp_buffer = 1
	credits = 0
	backpack_items.clear()
	current_floor = 1
	current_section = "section_a"
	current_route_type = "stairs"
	current_node_id = 0
	pending_combat_distance_modifier = 0
	has_chamber_polish = false
	visible_magazine_slots = 2
	tactical_data_cores = 0
	run_stats = {
		"lead_bullets_fired": 0,
		"min_dist_allowed": 99,
		"min_dist_ratio": 1.0,
		"hard_zones_cleared": 0,
		"max_kills_in_single_turn": 0,
		"average_kill_distance": 0.0,
		"total_kills": 0,
		"total_kill_dist_sum": 0.0,
		"tanks_killed_by_shred_only": 0,
		"stance_shifts_killed_without_slow": 0,
		"perfect_battles_count": 0,
		"magazine_emptied_wins": 0
	}
	deck.clear()
	basic_supply_bullet = null
	discarded_bullets.clear()
	map_nodes.clear()
	floor_connections.clear()
	section_maps.clear()
	return result


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
	meta_ascension_unlocked = clampi(int(cfg.get_value("meta", "ascension_unlocked", meta_ascension_unlocked)), 0, Ascension.MAX_LEVEL)
	# 적용 등급은 해금 범위를 넘을 수 없다(세이브 조작·롤백 방어).
	meta_ascension_level = clampi(int(cfg.get_value("meta", "ascension_level", meta_ascension_level)), 0, meta_ascension_unlocked)


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


## 이번 런에 오를 계층 목록. 해금 여부와 무관하게 최하 계층부터 정점까지 전부다.
func run_itinerary() -> Array[String]:
	var out: Array[String] = []
	for sec in SECTION_ORDER:
		out.append(String(sec))
	return out


## 도시 사다리 전체 길이(항상 35층). 현행 연속 런에서는 total_run_length()와 같다.
## 별도 함수는 지도 표시 의도를 명확히 하고 향후 표시 범위 변경과 진행 계약을 분리하기 위해 둔다.
func full_ladder_length() -> int:
	var total := 0
	for sec in SECTION_ORDER:
		total += int(MapGenerator.section_info(sec).floors)
	return total


## 사다리 전체 기준 절대 층 번호 → {section, floor}. 잠긴 계층도 반환한다(표시용).
func resolve_ladder_floor(abs_floor: int) -> Dictionary:
	var acc := 0
	for sec in SECTION_ORDER:
		var f := int(MapGenerator.section_info(sec).floors)
		if abs_floor <= acc + f:
			return {"section": String(sec), "floor": abs_floor - acc}
		acc += f
	return {}


## 해당 계층이 지도에서 공개된 곳인가. 잠긴 계층도 같은 런에서 관문 돌파 시 즉시 열린다.
func is_section_in_run(section: String) -> bool:
	return meta_unlocked_sections.has(section)


## (계층, 계층 내 층) → 런 전체 기준 절대 층 번호(1..35).
func absolute_run_floor(section: String, local_floor: int) -> int:
	var acc := 0
	for sec in run_itinerary():
		if sec == section:
			return acc + local_floor
		acc += int(MapGenerator.section_info(sec).floors)
	return acc + local_floor


## 런 전체 기준 절대 층 번호 → {section, floor}. 범위를 벗어나면 빈 Dictionary.
func resolve_run_floor(abs_floor: int) -> Dictionary:
	var acc := 0
	for sec in run_itinerary():
		var f := int(MapGenerator.section_info(sec).floors)
		if abs_floor <= acc + f:
			return {"section": sec, "floor": abs_floor - acc}
		acc += f
	return {}


## 특정 계층의 특정 층에 있는 노드들. 아직 도달하지 않은 계층도 조회할 수 있다.
func nodes_for(section: String, floor_num: int) -> Array[RunNode]:
	var nodes: Array[RunNode] = []
	if not section_maps.has(section):
		return nodes
	var data: Dictionary = section_maps[section]
	var conns: Dictionary = data.floor_connections
	var nodes_by_id: Dictionary = data.map_nodes
	if conns.has(floor_num):
		for node_id in conns[floor_num]:
			if nodes_by_id.has(node_id):
				nodes.append(nodes_by_id[node_id])
	return nodes


## 런에 오를 전 계층의 맵을 **한 번에** 생성한다.
##
## ⚠️ 계층에 도착할 때마다 새로 생성하면, 지도에서 미리 본 구성과 실제 도착했을 때의 구성이
##    달라진다(??? 노드의 스캔 힌트는 생성 시 무작위로 정해지므로 특히 그렇다).
##    지도가 런 전체를 보여주는 이상, 그 표시는 약속이어야 하므로 런 시작 시 확정한다.
func generate_full_run_map() -> void:
	section_maps.clear()
	for sec in run_itinerary():
		var result := MapGenerator.generate(sec)
		section_maps[sec] = {
			"map_nodes": result.map_nodes,
			"floor_connections": result.floor_connections,
		}
	_bind_current_section_map()


## 현재 계층의 맵을 활성 뷰(map_nodes/floor_connections)에 연결한다.
## 두 변수는 기존 코드 전반이 참조하므로 유지하되, 실체는 section_maps가 소유한다.
func _bind_current_section_map() -> void:
	if not section_maps.has(current_section):
		var result := MapGenerator.generate(current_section)
		section_maps[current_section] = {
			"map_nodes": result.map_nodes,
			"floor_connections": result.floor_connections,
		}
	var data: Dictionary = section_maps[current_section]
	map_nodes = data.map_nodes
	floor_connections = data.floor_connections


## 맵 생성은 MapGenerator로 분리됨 (SRP). 여기서는 결과를 런 상태에 반영만 한다.
func generate_run_map() -> void:
	generate_full_run_map()


## 조건부 우회 경로 실시간 해제 검사.
## ⚠️ 런 전체 지도를 대상으로 돈다 — 해제 조건(총기 구경 등)은 런 내내 고정이므로,
##    아직 도달하지 않은 계층의 숨김 노드도 지도에 미리 드러나야 표시가 일관된다.
func update_conditional_paths() -> void:
	for sec in section_maps.keys():
		_update_conditional_paths_in(section_maps[sec].map_nodes)


func _update_conditional_paths_in(nodes_by_id: Dictionary) -> void:
	for id in nodes_by_id.keys():
		var node = nodes_by_id[id]
		if node.is_hidden:
			var cond = node.unlock_condition_type
			var can_unlock = false
			if cond == "caliber_762":
				if current_gun != null and current_gun.weapon_class == Enums.WeaponClass.DMR:
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

## 현재 장착된 컨버전 킷의 대상 클래스. 미장착이면 UNIVERSAL.
func get_conversion_class() -> int:
	for part in equipped_parts:
		if part != null and part.is_conversion_kit():
			return part.conversion_class
	return Enums.WeaponClass.UNIVERSAL


## 컨버전 대상 탄환의 획득 가중치. 선언한 클래스는 기본의 3배로 등장한다.
func bullet_draft_weight(bullet: BulletData) -> int:
	var conversion_class := get_conversion_class()
	if conversion_class != Enums.WeaponClass.UNIVERSAL \
			and bullet != null and bullet.weapon_class == conversion_class:
		return 3
	return 1


## 구경은 선택 총기의 고정 프로필이다. 드래프트에는 해당 총기의 기반탄과 공용 전술탄만 나온다.
func bullet_is_draft_eligible(bullet: BulletData) -> bool:
	if bullet == null:
		return false
	# 기본탄은 총기 고정 보급 슬롯에서만 제공한다. 드래프트는 전술탄 선택에 집중한다.
	return not bullet.is_basic and bullet.weapon_class == Enums.WeaponClass.UNIVERSAL


## 자기 클래스 킷과 복수 킷 장착을 차단한다.
## replacing_index는 해당 슬롯을 교체한다고 가정해 중복 검사에서 제외한다.
func can_equip_part(part: PartData, replacing_index: int = -1) -> bool:
	if current_gun == null or part == null:
		return false
	if not part.is_conversion_kit():
		return true
	if part.conversion_class == current_gun.weapon_class:
		return false
	for i in range(equipped_parts.size()):
		if i == replacing_index:
			continue
		var equipped := equipped_parts[i]
		if equipped != null and equipped.is_conversion_kit():
			return false
	return true


## 빈 슬롯이 있으면 파츠를 즉시 장착한다. 성공 시 true, 슬롯이 가득 찬 경우 false 반환.
func equip_part_to_slot(part: PartData) -> bool:
	if current_gun == null:
		return false
	if equipped_parts.size() < current_gun.parts_capacity and can_equip_part(part):
		equipped_parts.append(part)
		return true
	return false


## 지정한 인덱스의 장착 파츠를 새 파츠로 강제 교체 장착하고, 기존 파츠는 버린다(파괴).
## 반환: 버려진 이전 파츠
func replace_equipped_part(index: int, new_part: PartData) -> PartData:
	if index < 0 or index >= equipped_parts.size():
		return null
	if not can_equip_part(new_part, index):
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
	if equipped_index == equipped_parts.size() and equipped_parts.size() < current_gun.parts_capacity \
			and can_equip_part(hold_part):
		equipped_parts.append(hold_part)
		hold_part = null
		return
		
	# 인덱스가 기존 장착 범위인 경우 스왑
	if equipped_index >= 0 and equipped_index < equipped_parts.size() \
			and can_equip_part(hold_part, equipped_index):
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
