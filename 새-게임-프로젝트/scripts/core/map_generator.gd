class_name MapGenerator
extends RefCounted

## ═══════════════════════════════════════════════════
## 런 맵 생성기 — 계층별 침투 맵 구조 제너레이터 (RunManager에서 분리, SRP)
##
## ⚠️ 연속 런 구조 (docs/gdd/20_ascension_intention.md §3)
##   한 런 = 최하 계층부터 정점까지 연속. 총 35층(6/7/7/7/8)으로 압축.
##   과거 64층(10/12/12/15/15)은 구역별 독립 런 기준이었고, 연속화 시 2~2.5시간이 되어
##   장르 평균(45~60분)과 모바일 타겟에 부적합하므로 압축했다.
##
## 레이아웃은 층수별 3종(6·7·8층)이며, 계층 정체성은 명칭 테이블로만 구분한다.
## ═══════════════════════════════════════════════════


## 구역 메타데이터 — 표시명 · 절대 고도 기준값 · 층수 · 표시용 아이콘/브리핑.
## 도시 전체는 약 3000층 규모이며, 한 번의 런은 그중 얇은 한 조각을 오른다.
## (정점 구역의 최상층이 정확히 LV.3000이 되도록 기준값을 맞춤)
##
## ⚠️ UI는 계층 이름·층수·설명을 자체 상수로 복사하지 말고 **반드시 이 함수를 통해** 읽을 것.
##    과거 오버레이가 이 값들을 하드코딩해 두어, 세계관 개정과 층수 압축이 반영되지 않고
##    화면에만 구버전(지하 주차장/10층)이 남는 드리프트가 발생했다. (2026-07-24)
static func section_info(section: String) -> Dictionary:
	match section:
		"section_a": return {
			"name": "침전 거주구", "base_level": 407, "floors": 6, "icon": "🟤",
			"brief": "위층이 버린 것들로 지어진 거주구. 개조받지 못한 몸들이 산다."}
		"section_b": return {
			"name": "공역", "base_level": 1142, "floors": 7, "icon": "🟠",
			"brief": "생산과 물류의 층. 사람은 공정의 일부로 취급된다."}
		"section_c": return {
			"name": "정비 계층", "base_level": 1783, "floors": 7, "icon": "🟢",
			"brief": "몸을 고치고 바꾸는 층. 여기서부터 인간형 실루엣이 흔들린다."}
		"section_d": return {
			"name": "관리 계층", "base_level": 2461, "floors": 7, "icon": "🔵",
			"brief": "결정이 내려지는 층. 얼굴을 가진 것을 거의 만나지 못한다."}
		"section_e": return {
			"name": "정점", "base_level": 2993, "floors": 8, "icon": "🟣",
			"brief": "도시의 꼭대기. 더 오를 곳이 없다."}
	return {"name": "미상 구역", "base_level": 0, "floors": 6, "icon": "⬛", "brief": ""}


## 현재 층의 절대 고도(LV) 표기를 반환한다. 예: 침전 거주구 3층 → 409
static func absolute_level(section: String, floor_num: int) -> int:
	return int(section_info(section).base_level) + floor_num - 1


## 계층 안에서의 층 위치를 3구간으로 나눈다. 0 = 초반, 1 = 중반, 2 = 종반.
##
## ⚠️ 절대 층 번호로 구간을 가르지 말 것. 계층마다 층수가 다르고(6/7/7/7/8),
##    과거 `floor_num <= 8` 같은 구 층수(10~15층) 기준 임계값이 남아 있어
##    각 계층의 종반 스폰 구성이 통째로 도달 불가였다.
##    (정비 계층은 "스펀지 유입"이 설계 의도였는데 일반전에 한 번도 등장하지 않았다.)
static func floor_tier(section: String, floor_num: int) -> int:
	var floors := int(section_info(section).floors)
	if floor_num > floors * 2 / 3:
		return 2
	if floor_num > floors / 3:
		return 1
	return 0


# ══════════════════════════════════════════════════
# 계층별 노드 명칭 테이블
# 레이아웃(노드 ID·연결 구조)은 층수가 같으면 공유하고, 명칭·설명만 계층 테마로 교체한다.
# 형식: node_id -> [표시명, 설명]
# ⚠️ 표시명의 기능 접미사 (전투)(보급)(상점)(우회)(보스) 는 로직 분기에 쓰이므로 반드시 보존할 것.
#    ??? 미지 노드는 레이아웃에서 직접 생성하므로 테이블에 없다.
# 작명 규칙: 하층은 구체적·지저분한 명사, 상층으로 갈수록 추상적·기능적 명사.
# 설계 정본: docs/gdd/08_meta_progression.md §8.1-B
# ══════════════════════════════════════════════════

## 🟤 침전 거주구 (6층) — 위층이 버린 것들로 지어진, 개조받지 못한 인간들의 거주구
static func _names_a() -> Dictionary:
	return {
		101: ["폐수로 (전투)", "상층에서 흘러내린 오수가 고인 수로"],
		102: ["판자촌 골목 (전투)", "폐자재로 세운 거처들이 빽빽한 통로"],
		201: ["고철 야적장 (전투)", "위에서 떨어진 폐기물이 산처럼 쌓인 구역"],
		301: ["밀수 창고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 전용 탄약이 숨겨진 창고"],
		302: ["배관 미로 (전투)", "낡은 급배수관이 얽힌 좁은 통로"],
		401: ["고물상 (상점)", "주워온 것들을 사고파는 하층 노점"],
		501: ["침수 구획 (전투)", "배수가 끊겨 물이 차오른 거주 구역"],
		502: ["배수 터널 (우회)", "오래전 말라붙은 배수로를 통한 우회 통로"],
		601: ["승강기 관문 (보스)", "위층으로 오르는 유일한 통로를 막아선 것"],
	}


## 🟠 공역 (7층) — 팔다리를 기계로 바꿔 생산성을 얻은 부분 개조 노동자들의 층
static func _names_b() -> Dictionary:
	return {
		101: ["하역장 (전투)", "화물이 밤낮없이 오르내리는 적재 구역"],
		102: ["폐열 배출구 (전투)", "공정에서 나온 열기가 뿜어져 나오는 통로"],
		201: ["컨베이어 홀 (전투)", "멈추지 않는 벨트가 가로지르는 홀"],
		301: ["공구 보관고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기용 탄약이 섞여 들어온 보관고"],
		302: ["주조 작업장 (전투)", "쇳물이 틀에 부어지는 구역"],
		401: ["부품 배급소 (상점)", "노동자에게 개조 부품을 배급하는 단말"],
		501: ["용광로 작업장 (전투)", "열기로 시야가 일그러지는 노 앞"],
		502: ["냉각 덕트 (우회)", "가동 중단된 냉각관을 통한 우회 통로"],
		601: ["조립 라인 (전투)", "규격품이 끝없이 흘러가는 라인"],
		701: ["공정 관리실 (보스)", "이 계층의 모든 생산을 통제하는 것"],
	}


## 🟢 정비 계층 (7층) — 인간이 사이보그가 되는 경계선
static func _names_c() -> Dictionary:
	return {
		101: ["시술 대기실 (전투)", "차례를 기다리던 자리들이 비어 있다"],
		102: ["검체 반입로 (전투)", "아래에서 올라온 것들이 들어오는 통로"],
		201: ["부품 선반 통로 (전투)", "규격별로 정렬된 이식용 부품들"],
		301: ["의료 물자고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기용 탄약이 오분류된 물자고"],
		302: ["마취 구획 (전투)", "감각을 끊는 처치가 이루어지던 곳"],
		401: ["이식 부품 상점 (상점)", "규격 미달품을 처분하는 단말"],
		501: ["배양조 구역 (전투)", "조직이 배양되는 수조들이 늘어선 구역"],
		502: ["검체 반출로 (우회)", "폐기 대상이 실려 나가는 우회 통로"],
		601: ["소각로 (전투)", "적합하지 않은 것들이 처리되는 곳"],
		701: ["적합성 심사실 (보스)", "누가 개조받을 자격이 있는지 판정하던 곳"],
	}


## 🔵 관리 계층 (7층) — 고도 개조체의 영역. 아름답지만 사람이 없다
static func _names_d() -> Dictionary:
	return {
		101: ["정온 회랑 (전투)", "온도와 습도가 일정하게 유지되는 복도"],
		102: ["여과 통로 (전투)", "공기가 몇 번이고 걸러지는 통로"],
		201: ["관측 아트리움 (전투)", "아래를 내려다볼 수 있게 뚫린 공간"],
		301: ["규격 보관실 (보급)", "🔑 [구경 보안 게이트] 규격 외 물품이 보관된 방"],
		302: ["대기 정원 (전투)", "관리되지만 아무도 머물지 않는 정원"],
		401: ["배급 단말 (상점)", "필요한 것이 자동으로 제공되는 단말"],
		501: ["데이터 열람실 (전투)", "기록을 열람하기 위한 정숙 구역"],
		502: ["정비 통로 (우회)", "관리용으로만 열리는 협소한 통로"],
		601: ["무향실 (전투)", "소리가 반사되지 않는 방"],
		701: ["관리 중추 (보스)", "이 계층의 모든 것을 조율하는 것"],
	}


## 🟣 정점 / 코어 (8층) — 인간을 상정하지 않은 공간
static func _names_e() -> Dictionary:
	return {
		101: ["연산 회랑 (전투)", "통로라기보다 배선에 가까운 공간"],
		102: ["신호 격자 (전투)", "빛으로 된 격자가 끊임없이 명멸한다"],
		201: ["냉각 심부 (전투)", "열을 빨아들이는 거대한 구조 안쪽"],
		301: ["예비 부품고 (보급)", "🔑 [구경 보안 게이트] 규격 외 잔여물이 남은 보관부"],
		302: ["비인간 규격 통로 (전투)", "사람이 지나갈 것을 상정하지 않은 통로"],
		401: ["배분 단말 (상점)", "자원을 재배분하는 접점"],
		501: ["연산 격자 (전투)", "계산이 물리적으로 배열된 구역"],
		502: ["우회 도선 (우회)", "신호가 돌아가도록 설계된 예비 경로"],
		601: ["침묵 구획 (전투)", "어떤 소리도 발생하지 않는 공간"],
		701: ["상위 연산부 (전투)", "판단이 이루어지는 층위"],
		702: ["열 교환부 (전투)", "막대한 열이 오가는 구조물 사이"],
		801: ["코어 (보스)", "이 도시가 그것을 중심으로 지어졌다"],
	}


## 계층에 맞는 명칭 테이블을 반환한다.
static func _names_for(section: String) -> Dictionary:
	match section:
		"section_a": return _names_a()
		"section_b": return _names_b()
		"section_c": return _names_c()
		"section_d": return _names_d()
		"section_e": return _names_e()
	return _names_a()


## 섹션에 맞는 맵을 생성해 { "map_nodes": Dictionary, "floor_connections": Dictionary }를 반환한다.
## 노드 구조체는 RunManager.RunNode를 그대로 사용한다.
static func generate(section: String) -> Dictionary:
	var map_nodes: Dictionary = {}
	var floor_connections: Dictionary = {}
	var n := _names_for(section)

	# 노드 추가 람다 헬퍼 (로컬 map_nodes/floor_connections에 적재)
	var add_node = func(f: int, id: int, type: String, desc: String, routes: Array, is_hidden: bool = false, cond_type: String = ""):
		# RunNode 내부에 string 배열로 전달하기 위해 변환
		var route_strings: Array[String] = []
		for r in routes:
			route_strings.append(String(r))
		var node = RunManager.RunNode.new(id, type, desc, route_strings)
		node.is_hidden = is_hidden
		node.unlock_condition_type = cond_type

		# ??? 미지 노드 스캔 힌트 설정
		if type.begins_with("???"):
			var r = randf()
			if r < 0.35:
				# ⚠️ 이 문자열은 combat_scene.gd의 정확 일치 검사와 연동됨. 함께 수정할 것.
				node.hidden_type = "매복 구획 (전투)"
				node.scan_hint = "스캔: 다수의 열원 감지 (위험도 HIGH)"
			elif r < 0.7:
				node.hidden_type = "은닉 물자고 (정비)"
				node.scan_hint = "스캔: 밀봉된 보급 용기 반응 (물자고 유력)"
			else:
				node.hidden_type = "방치된 단말 (이벤트)"
				node.scan_hint = "스캔: 미약한 전자 노이즈 감지 (거래 단말 유력)"

		map_nodes[id] = node
		if not floor_connections.has(f):
			floor_connections[f] = []
		floor_connections[f].append(id)
		return node

	# ── 공통 도입부 (1~4층) — 전 계층이 공유하는 리듬 ──
	# F1 전투 2갈래 → F2 전투/미지 → F3 보급(조건부)/전투 → F4 상점(합류점)
	add_node.call(1, 101, n[101][0], n[101][1], ["stairs", "air_duct"])
	add_node.call(1, 102, n[102][0], n[102][1], ["air_duct"])
	add_node.call(2, 201, n[201][0], n[201][1], ["stairs", "air_duct"])
	add_node.call(2, 202, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
	add_node.call(3, 301, n[301][0], n[301][1], ["stairs"], true, "caliber_762")
	add_node.call(3, 302, n[302][0], n[302][1], ["air_duct"])
	add_node.call(4, 401, n[401][0], n[401][1], ["stairs"])

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

	var floors := int(section_info(section).floors)

	if floors == 6:
		# 🟤 6층 (침전 거주구) — F5 전투/우회 → F6 보스
		add_node.call(5, 501, n[501][0], n[501][1], ["stairs", "air_duct"])
		add_node.call(5, 502, n[502][0], n[502][1], ["air_duct"])
		add_node.call(6, 601, n[601][0], n[601][1], ["stairs"])

		map_nodes[401].connected_node_ids = [501, 502]
		map_nodes[401].connected_node_routes[501] = "stairs"
		map_nodes[401].connected_node_routes[502] = "air_duct"
		map_nodes[501].connected_node_ids = [601]
		map_nodes[501].connected_node_routes[601] = "stairs"
		map_nodes[502].connected_node_ids = [601]
		map_nodes[502].connected_node_routes[601] = "air_duct"

	elif floors == 7:
		# 🟠🟢🔵 7층 (공역·정비·관리) — F5 전투/우회 → F6 전투/미지 → F7 보스
		add_node.call(5, 501, n[501][0], n[501][1], ["stairs", "air_duct"])
		add_node.call(5, 502, n[502][0], n[502][1], ["air_duct"])
		add_node.call(6, 601, n[601][0], n[601][1], ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(7, 701, n[701][0], n[701][1], ["stairs"])

		map_nodes[401].connected_node_ids = [501, 502]
		map_nodes[401].connected_node_routes[501] = "stairs"
		map_nodes[401].connected_node_routes[502] = "air_duct"
		map_nodes[501].connected_node_ids = [601, 602]
		map_nodes[501].connected_node_routes[601] = "stairs"
		map_nodes[501].connected_node_routes[602] = "air_duct"
		map_nodes[502].connected_node_ids = [602]
		map_nodes[502].connected_node_routes[602] = "air_duct"
		map_nodes[601].connected_node_ids = [701]
		map_nodes[601].connected_node_routes[701] = "stairs"
		map_nodes[602].connected_node_ids = [701]
		map_nodes[602].connected_node_routes[701] = "air_duct"

	else:
		# 🟣 8층 (정점) — F5 전투/우회 → F6 전투/미지 → F7 전투 2갈래 → F8 코어
		add_node.call(5, 501, n[501][0], n[501][1], ["stairs", "air_duct"])
		add_node.call(5, 502, n[502][0], n[502][1], ["air_duct"])
		add_node.call(6, 601, n[601][0], n[601][1], ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(7, 701, n[701][0], n[701][1], ["stairs", "air_duct"])
		add_node.call(7, 702, n[702][0], n[702][1], ["air_duct"])
		add_node.call(8, 801, n[801][0], n[801][1], ["stairs"])

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
		map_nodes[602].connected_node_ids = [702]
		map_nodes[602].connected_node_routes[702] = "air_duct"
		map_nodes[701].connected_node_ids = [801]
		map_nodes[701].connected_node_routes[801] = "stairs"
		map_nodes[702].connected_node_ids = [801]
		map_nodes[702].connected_node_routes[801] = "air_duct"

	_finalize_route_graph(map_nodes)
	return {"map_nodes": map_nodes, "floor_connections": floor_connections}


## 상점 진입 가격(계단/환기구)을 런마다 배치한다.
## 상점이 2개 이상이면 최소 1개는 계단, 최소 1개는 환기구가 된다.
## (압축 후에는 계층당 상점이 1개이므로 계층 단위에서는 대개 동작하지 않는다.
##  향후 계층당 상점이 늘어날 때를 대비해 유지한다.)
static func _finalize_route_graph(map_nodes: Dictionary) -> void:
	var armory_ids: Array[int] = []
	for node_id in map_nodes.keys():
		var node = map_nodes[node_id]
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
		var incoming_node = map_nodes[incoming_id]
		for target_id in incoming_node.connected_node_routes.keys():
			if not armory_ids.has(target_id):
				continue
			var route := "air_duct" if air_duct_armories.has(target_id) else "stairs"
			incoming_node.connected_node_routes[target_id] = route
			var target_node = map_nodes[target_id]
			var one_route: Array[String] = [route]
			target_node.connected_routes = one_route
