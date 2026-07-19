class_name MapGenerator
extends RefCounted

## ═══════════════════════════════════════════════════
## 런 맵 생성기 — RunManager에서 분리한 층별 침투 맵 구조 제너레이터 (SRP).
## 섹션별 레이아웃: section_a=10층 / section_b·c=12층 / 그 외=15층.
## RunManager.generate_run_map()이 이 클래스를 호출한다.
## ═══════════════════════════════════════════════════


## 섹션에 맞는 맵을 생성해 { "map_nodes": Dictionary, "floor_connections": Dictionary }를 반환한다.
## 노드 구조체는 RunManager.RunNode를 그대로 사용한다.
static func generate(section: String) -> Dictionary:
	var map_nodes: Dictionary = {}
	var floor_connections: Dictionary = {}

	# 노드 추가 람다 헬퍼 (로컬 map_nodes/floor_connections에 적재)
	var add_node = func(f: int, id: int, type: String, desc: String, routes: Array, is_hidden: bool = false, cond_type: String = ""):
		# RunNode 내부에 string 배열로 전달하기 위해 변환
		var route_strings: Array[String] = []
		for r in routes:
			route_strings.append(String(r))
		var n = RunManager.RunNode.new(id, type, desc, route_strings)
		n.is_hidden = is_hidden
		n.unlock_condition_type = cond_type

		# ??? 미지 노드 스캔 힌트 설정
		if type.begins_with("???"):
			var r = randf()
			if r < 0.35:
				# ⚠️ 이 문자열은 combat_scene.gd의 정확 일치 검사와 연동됨. 함께 수정할 것.
				n.hidden_type = "매복 구획 (전투)"
				n.scan_hint = "스캔: 다수의 열원 감지 (위험도 HIGH)"
			elif r < 0.7:
				n.hidden_type = "은닉 물자고 (정비)"
				n.scan_hint = "스캔: 밀봉된 보급 용기 반응 (물자고 유력)"
			else:
				n.hidden_type = "방치된 단말 (이벤트)"
				n.scan_hint = "스캔: 미약한 전자 노이즈 감지 (거래 단말 유력)"

		map_nodes[id] = n
		if not floor_connections.has(f):
			floor_connections[f] = []
		floor_connections[f].append(id)
		return n

	if section == "section_a":
		# 🟤 침전 거주구 (입문 - 10층 구조 / 보스 10층)
		# 위층이 버린 것들이 쌓여 만들어진 층. 개조받지 못한 순수 인간들의 거주구.
		add_node.call(1, 101, "폐수로 (전투)", "상층에서 흘러내린 오수가 고인 수로", ["stairs", "air_duct"])
		add_node.call(1, 102, "판자촌 골목 (전투)", "폐자재로 세운 거처들이 빽빽한 통로", ["air_duct"])
		add_node.call(2, 201, "고철 야적장 (전투)", "위에서 떨어진 폐기물이 산처럼 쌓인 구역", ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "빛이 닿지 않는 구석", ["air_duct"])
		add_node.call(3, 301, "배관 미로 (전투)", "낡은 급배수관이 얽힌 좁은 통로", ["stairs"])
		add_node.call(3, 302, "밀수 창고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기 전용 탄약이 숨겨진 창고", ["air_duct"], true, "caliber_762")
		add_node.call(4, 401, "고물상 (상점)", "주워온 것들을 사고파는 하층 노점", ["stairs"])
		add_node.call(5, 501, "침수 구획 (전투)", "배수가 끊겨 물이 차오른 거주 구역", ["stairs", "air_duct"])
		add_node.call(5, 502, "폐수로 지선 (전투)", "본류에서 갈라진 좁은 수로", ["air_duct"])
		add_node.call(6, 601, "판자촌 상단 (전투)", "위태롭게 층층이 얹힌 거처들", ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(7, 701, "??? (미지)", "신호가 잡히지 않는 구획", ["stairs"])
		add_node.call(7, 702, "배수 터널 (우회)", "오래전 말라붙은 배수로를 통한 우회 통로", ["air_duct"])
		add_node.call(8, 801, "정전 구획 (전투)", "전력이 끊긴 채 방치된 구역", ["stairs"])
		add_node.call(9, 901, "고물상 (상점)", "침전 거주구 최상단의 마지막 노점", ["stairs"])
		add_node.call(10, 1001, "승강기 관문 (보스)", "위층으로 오르는 유일한 통로를 막아선 것", ["stairs"])

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

	elif section == "section_b" or section == "section_c":
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

	_finalize_route_graph(map_nodes)
	return {"map_nodes": map_nodes, "floor_connections": floor_connections}


## 상점 진입 가격(계단/환기구)을 런마다 배치한다.
## 상점이 2개 이상이면 최소 1개는 계단, 최소 1개는 환기구가 된다.
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
