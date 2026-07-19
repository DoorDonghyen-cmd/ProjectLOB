class_name MapGenerator
extends RefCounted

## ═══════════════════════════════════════════════════
## 런 맵 생성기 — RunManager에서 분리한 층별 침투 맵 구조 제너레이터 (SRP).
## 섹션별 레이아웃: section_a=10층 / section_b·c=12층 / 그 외=15층.
## RunManager.generate_run_map()이 이 클래스를 호출한다.
## ═══════════════════════════════════════════════════


## 구역 메타데이터 — 표시명 · 절대 고도 기준값 · 층수.
## 도시 전체는 약 3000층 규모이며, 한 번의 런은 그중 얇은 한 조각을 오른다.
## (정점 구역의 최상층이 정확히 LV.3000이 되도록 기준값을 맞춤)
static func section_info(section: String) -> Dictionary:
	match section:
		"section_a": return {"name": "침전 거주구", "base_level": 407, "floors": 10}
		"section_b": return {"name": "공역", "base_level": 1142, "floors": 12}
		"section_c": return {"name": "정비 계층", "base_level": 1783, "floors": 12}
		"section_d": return {"name": "관리 계층", "base_level": 2461, "floors": 15}
		"section_e": return {"name": "정점", "base_level": 2986, "floors": 15}
	return {"name": "미상 구역", "base_level": 0, "floors": 10}


## 현재 층의 절대 고도(LV) 표기를 반환한다. 예: 침전 거주구 3층 → 409
static func absolute_level(section: String, floor_num: int) -> int:
	return int(section_info(section).base_level) + floor_num - 1


# ══════════════════════════════════════════════════
# 계층별 노드 명칭 테이블
# 레이아웃(노드 ID·연결 구조)은 구역 간 공유하되, 명칭·설명만 계층 테마로 교체한다.
# 형식: node_id -> [표시명, 설명]
# ⚠️ 표시명의 기능 접미사 (전투)(보급)(상점)(우회)(정비)(보스) 는 로직 분기에 쓰이므로 반드시 보존할 것.
# 설계 정본: docs/gdd/08_meta_progression.md §8.1-B
# ══════════════════════════════════════════════════

## 🟠 공역 — 부분 개조 노동자의 생산 계층
static func _names_b() -> Dictionary:
	return {
		101: ["하역장 (전투)", "화물이 밤낮없이 오르내리는 적재 구역"],
		102: ["폐열 배출구 (전투)", "공정에서 나온 열기가 뿜어져 나오는 통로"],
		201: ["컨베이어 홀 (전투)", "멈추지 않는 벨트가 가로지르는 홀"],
		301: ["공구 보관고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기용 탄약이 섞여 들어온 보관고"],
		302: ["주조 작업장 (전투)", "쇳물이 틀에 부어지는 구역"],
		401: ["용광로 작업장 (전투)", "열기로 시야가 일그러지는 노 앞"],
		501: ["크레인 갠트리 (전투)", "머리 위로 하중이 지나가는 좁은 통로"],
		601: ["부품 배급소 (상점)", "노동자에게 개조 부품을 배급하는 단말"],
		701: ["조립 라인 (전투)", "규격품이 끝없이 흘러가는 라인"],
		801: ["냉각 덕트 (우회)", "가동 중단된 냉각관을 통한 우회 통로"],
		802: ["압연 구역 (전투)", "금속을 눌러 펴는 기계들이 늘어선 구역"],
		901: ["가동 중단 구획 (전투)", "생산이 멈춘 채 방치된 구역"],
		1001: ["정밀 공작실 (정비)", "🔑 [약실 조율] 정밀 가공이 가능한 작업대"],
		1002: ["배기 통로 (전투)", "매연이 빠져나가는 좁은 관로"],
		1101: ["부품 배급소 (상점)", "공역 최상단의 마지막 배급 단말"],
		1201: ["공정 관리실 (보스)", "이 계층의 모든 생산을 통제하는 것"],
	}


## 🟢 정비 계층 — 인간이 사이보그가 되는 경계선
static func _names_c() -> Dictionary:
	return {
		101: ["시술 대기실 (전투)", "차례를 기다리던 자리들이 비어 있다"],
		102: ["검체 반입로 (전투)", "아래에서 올라온 것들이 들어오는 통로"],
		201: ["부품 선반 통로 (전투)", "규격별로 정렬된 이식용 부품들"],
		301: ["의료 물자고 (보급)", "🔑 [구경 보안 게이트] 대구경 화기용 탄약이 오분류된 물자고"],
		302: ["마취 구획 (전투)", "감각을 끊는 처치가 이루어지던 곳"],
		401: ["시술실 (전투)", "인간이 사이보그가 되는 자리"],
		501: ["배양조 구역 (전투)", "조직이 배양되는 수조들이 늘어선 구역"],
		601: ["이식 부품 상점 (상점)", "규격 미달품을 처분하는 단말"],
		701: ["회복실 (전투)", "시술 후 적응을 기다리는 구획"],
		801: ["검체 반출로 (우회)", "폐기 대상이 실려 나가는 우회 통로"],
		802: ["소각로 (전투)", "적합하지 않은 것들이 처리되는 곳"],
		901: ["폐기 시술대 (전투)", "쓰이지 않게 된 장비들이 방치된 구역"],
		1001: ["정밀 조정실 (정비)", "🔑 [약실 조율] 미세 조정용 장비가 남아 있는 방"],
		1002: ["봉인된 시술실 (전투)", "바깥에서 잠긴 채 오래 방치된 방"],
		1101: ["이식 부품 상점 (상점)", "정비 계층 최상단의 마지막 단말"],
		1201: ["적합성 심사실 (보스)", "누가 개조받을 자격이 있는지 판정하던 곳"],
	}


## 🔵 관리 계층 — 고도 개조체의 영역. 아름답지만 사람이 없다
static func _names_d() -> Dictionary:
	return {
		101: ["정온 회랑 (전투)", "온도와 습도가 일정하게 유지되는 복도"],
		102: ["여과 통로 (전투)", "공기가 몇 번이고 걸러지는 통로"],
		201: ["관측 아트리움 (전투)", "아래를 내려다볼 수 있게 뚫린 공간"],
		301: ["대기 정원 (전투)", "관리되지만 아무도 머물지 않는 정원"],
		302: ["규격 보관실 (보급)", "🔑 [구경 보안 게이트] 규격 외 물품이 보관된 방"],
		401: ["배급 단말 (상점)", "필요한 것이 자동으로 제공되는 단말"],
		501: ["데이터 열람실 (전투)", "기록을 열람하기 위한 정숙 구역"],
		502: ["무향실 (전투)", "소리가 반사되지 않는 방"],
		601: ["정온 회랑 상단 (전투)", "같은 복도가 위층에도 이어진다"],
		702: ["정비 통로 (우회)", "관리용으로만 열리는 협소한 통로"],
		801: ["인공 정원 (전투)", "빛과 물이 계산되어 공급되는 구역"],
		901: ["배급 단말 (상점)", "관리 계층 중단의 배급 단말"],
		1001: ["관측 회랑 (전투)", "도시 내부를 조망하도록 설계된 복도"],
		1002: ["정숙 구획 (전투)", "소음이 허용되지 않는 거주 구역"],
		1101: ["상위 열람실 (전투)", "접근 권한이 제한된 기록실"],
		1202: ["정밀 조정실 (정비)", "🔑 [약실 조율] 관리용 정밀 장비가 갖춰진 방"],
		1301: ["중추 접근로 (전투)", "관리 중추로 향하는 마지막 복도"],
		1401: ["배급 단말 (상점)", "관리 계층 최상단의 마지막 단말"],
		1501: ["관리 중추 (보스)", "이 계층의 모든 것을 조율하는 것"],
	}


## 🟣 정점 / 코어 — 인간을 상정하지 않은 공간
static func _names_e() -> Dictionary:
	return {
		101: ["연산 회랑 (전투)", "통로라기보다 배선에 가까운 공간"],
		102: ["신호 격자 (전투)", "빛으로 된 격자가 끊임없이 명멸한다"],
		201: ["냉각 심부 (전투)", "열을 빨아들이는 거대한 구조 안쪽"],
		301: ["비인간 규격 통로 (전투)", "사람이 지나갈 것을 상정하지 않은 통로"],
		302: ["예비 부품고 (보급)", "🔑 [구경 보안 게이트] 규격 외 잔여물이 남은 보관부"],
		401: ["배분 단말 (상점)", "자원을 재배분하는 접점"],
		501: ["연산 격자 (전투)", "계산이 물리적으로 배열된 구역"],
		502: ["침묵 구획 (전투)", "어떤 소리도 발생하지 않는 공간"],
		601: ["심부 회랑 (전투)", "더 깊은 곳으로 이어지는 통로"],
		702: ["우회 도선 (우회)", "신호가 돌아가도록 설계된 예비 경로"],
		801: ["열 교환부 (전투)", "막대한 열이 오가는 구조물 사이"],
		901: ["배분 단말 (상점)", "정점 중단의 재배분 접점"],
		1001: ["상위 연산부 (전투)", "판단이 이루어지는 층위"],
		1002: ["정지 구획 (전투)", "가동이 멈춘 채 남겨진 부분"],
		1101: ["코어 접근로 (전투)", "중심으로 향하는 마지막 구간"],
		1202: ["조정 단말 (정비)", "🔑 [약실 조율] 규격을 미세 조정하는 접점"],
		1301: ["최종 회랑 (전투)", "그 앞에 아무것도 없는 복도"],
		1401: ["배분 단말 (상점)", "마지막 재배분 접점"],
		1501: ["코어 (보스)", "이 도시가 그것을 중심으로 지어졌다"],
	}


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
		# 🟠 공역(b) / 🟢 정비 계층(c) — 동일 레이아웃, 계층별 명칭 테이블 적용 (12층 / 보스 12층)
		var nb := _names_b() if section == "section_b" else _names_c()
		add_node.call(1, 101, nb[101][0], nb[101][1], ["stairs", "air_duct"])
		add_node.call(1, 102, nb[102][0], nb[102][1], ["air_duct"])
		add_node.call(2, 201, nb[201][0], nb[201][1], ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(3, 301, nb[301][0], nb[301][1], ["stairs"], true, "caliber_762")
		add_node.call(3, 302, nb[302][0], nb[302][1], ["air_duct"])
		add_node.call(4, 401, nb[401][0], nb[401][1], ["stairs"])
		add_node.call(5, 501, nb[501][0], nb[501][1], ["stairs", "air_duct"])
		add_node.call(6, 601, nb[601][0], nb[601][1], ["stairs"])
		add_node.call(7, 701, nb[701][0], nb[701][1], ["stairs", "air_duct"])
		add_node.call(7, 702, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(8, 801, nb[801][0], nb[801][1], ["stairs"])
		add_node.call(8, 802, nb[802][0], nb[802][1], ["air_duct"])
		add_node.call(9, 901, nb[901][0], nb[901][1], ["stairs"])
		add_node.call(10, 1001, nb[1001][0], nb[1001][1], ["stairs"], true, "chamber_polish")
		add_node.call(10, 1002, nb[1002][0], nb[1002][1], ["air_duct"])
		add_node.call(11, 1101, nb[1101][0], nb[1101][1], ["stairs"])
		add_node.call(12, 1201, nb[1201][0], nb[1201][1], ["stairs"])

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
		# 🔵 관리 계층(d) / 🟣 정점(e) — 동일 레이아웃, 계층별 명칭 테이블 적용 (15층 / 보스 15층)
		var nd := _names_d() if section == "section_d" else _names_e()
		add_node.call(1, 101, nd[101][0], nd[101][1], ["stairs", "air_duct"])
		add_node.call(1, 102, nd[102][0], nd[102][1], ["air_duct"])
		add_node.call(2, 201, nd[201][0], nd[201][1], ["stairs", "air_duct"])
		add_node.call(2, 202, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(3, 301, nd[301][0], nd[301][1], ["stairs"])
		add_node.call(3, 302, nd[302][0], nd[302][1], ["air_duct"], true, "caliber_762")
		add_node.call(4, 401, nd[401][0], nd[401][1], ["stairs"])
		add_node.call(5, 501, nd[501][0], nd[501][1], ["stairs", "air_duct"])
		add_node.call(5, 502, nd[502][0], nd[502][1], ["air_duct"])
		add_node.call(6, 601, nd[601][0], nd[601][1], ["stairs", "air_duct"])
		add_node.call(6, 602, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(7, 701, "??? (미지)", "신호가 잡히지 않는 구획", ["stairs"])
		add_node.call(7, 702, nd[702][0], nd[702][1], ["air_duct"])
		add_node.call(8, 801, nd[801][0], nd[801][1], ["stairs", "air_duct"])
		add_node.call(8, 802, "??? (미지)", "신호가 잡히지 않는 구획", ["stairs", "air_duct"])
		add_node.call(9, 901, nd[901][0], nd[901][1], ["stairs"])
		add_node.call(10, 1001, nd[1001][0], nd[1001][1], ["stairs", "air_duct"])
		add_node.call(10, 1002, nd[1002][0], nd[1002][1], ["air_duct"])
		add_node.call(11, 1101, nd[1101][0], nd[1101][1], ["stairs", "air_duct"])
		add_node.call(11, 1102, "??? (미지)", "신호가 잡히지 않는 구획", ["air_duct"])
		add_node.call(12, 1201, "??? (미지)", "신호가 잡히지 않는 구획", ["stairs"])
		add_node.call(12, 1202, nd[1202][0], nd[1202][1], ["air_duct"], true, "chamber_polish")
		add_node.call(13, 1301, nd[1301][0], nd[1301][1], ["stairs", "air_duct"])
		add_node.call(13, 1302, "??? (미지)", "신호가 잡히지 않는 구획", ["stairs", "air_duct"])
		add_node.call(14, 1401, nd[1401][0], nd[1401][1], ["stairs"])
		add_node.call(15, 1501, nd[1501][0], nd[1501][1], ["stairs"])

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
