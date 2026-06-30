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

var deck: Array[BulletData] = []
var discarded_bullets: Array[BulletData] = [] # Unload로 버려져 소실 위기에 놓인 탄환들
var active_relics: Array[String] = []

# ── 노드 정보 구조체 ──
class RunNode:
	var id: int
	var type_name: String
	var description: String
	var connected_routes: Array[String] # 연결되는 통로들: "stairs", "air_duct", "shaft"
	
	func _init(_id: int, _type: String, _desc: String, _routes: Array[String]):
		id = _id
		type_name = _type
		description = _desc
		connected_routes = _routes


## 신규 런 시작 및 상태 초기화
func start_new_run(gun: GunData, basic_bullet: BulletData, ap_bullet: BulletData, kb_bullet: BulletData) -> void:
	current_floor = 1
	hp_buffer = 1 + meta_hp_armor_lvl
	credits = 0
	deck.clear()
	discarded_bullets.clear()
	active_relics.clear()
	has_chamber_polish = false
	current_route_type = "stairs"
	visible_magazine_slots = 2
	
	# 총기 및 기본 파츠 초기화
	current_gun = gun
	equipped_parts.clear()
	hold_part = null
	if current_gun != null and current_gun.default_part != null:
		equipped_parts.append(current_gun.default_part)
	
	# 기본 덱 구성 (메타 해금 레벨에 따라 수량 증가)
	var jhp_count := 5 + meta_backpack_lvl
	var fmj_count := 2 + (1 if meta_backpack_lvl >= 1 else 0) + (1 if meta_backpack_lvl >= 2 else 0) + (1 if meta_backpack_lvl >= 3 else 0)
	var kb_count := 1 + (1 if meta_backpack_lvl >= 2 else 0)
	
	for i in range(jhp_count):
		deck.append(basic_bullet.duplicate())
	for i in range(fmj_count):
		deck.append(ap_bullet.duplicate())
	for i in range(kb_count):
		deck.append(kb_bullet.duplicate())


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
	deck.append(bullet.duplicate())


## Unload 시 덱에서 해당 인덱스의 탄을 소실(버린 카드 풀)로 이동
func unload_bullet_to_discard(bullet: BulletData) -> void:
	# 덱에서 동일 display_name을 가진 첫 탄환을 제거
	for i in range(deck.size()):
		if deck[i].display_name == bullet.display_name:
			discarded_bullets.append(deck[i])
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
	return earned


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


## 층별 절차적 노드 정보 반환 (5층 주기 패턴)
func get_nodes_for_floor(floor_num: int) -> Array[RunNode]:
	var nodes: Array[RunNode] = []
	var base_id := floor_num * 100
	
	if floor_num % 5 == 0:
		var boss_name = "보안 구역 (보스)"
		if floor_num == 20: boss_name = "옥상 헬리패드 (최종 보스)"
		nodes.append(RunNode.new(base_id + 1, boss_name, "해당 구역의 보안 총책임자 조우", ["stairs"]))
	elif floor_num % 5 == 1:
		nodes.append(RunNode.new(base_id + 1, "사무실 (전투)", "무장 순찰 경비 대기 중", ["stairs", "air_duct"]))
		nodes.append(RunNode.new(base_id + 2, "환기 서버실 (전투)", "침투 드론 경비대 순찰 중", ["air_duct", "shaft"]))
	elif floor_num % 5 == 2:
		nodes.append(RunNode.new(base_id + 1, "무기 캐비닛 (정비)", "보안 정비 단말기와 장비 상자 발견", ["stairs"]))
		nodes.append(RunNode.new(base_id + 2, "보안 통제실 (이벤트)", "서버 랙 및 미승인 터미널 가동 중", ["air_duct", "shaft"]))
	elif floor_num % 5 == 3:
		nodes.append(RunNode.new(base_id + 1, "연구실 복도 (전투)", "방패 요원이 전술 방어 태세로 대치 중", ["stairs", "air_duct"]))
		nodes.append(RunNode.new(base_id + 2, "물류 창고 (전투)", "순찰 중인 경보 공중 드론 발견", ["stairs", "shaft"]))
	elif floor_num % 5 == 4:
		nodes.append(RunNode.new(base_id + 1, "안전한 대피소 (완충)", "요원 안전 구역 및 의료 상자 탑재", ["stairs", "air_duct"]))
		nodes.append(RunNode.new(base_id + 2, "보급 캐비닛 (정비)", "특수 작전용 정비 사물함 잔존", ["air_duct"]))
		
	return nodes


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
