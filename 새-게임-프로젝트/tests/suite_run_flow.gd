extends RefCounted
## 플레이 흐름 통합 검증 (Level A) — 무기 선택 → 맵 → 노드 → 실제 전투 → 클리어 → 정산.
## RunManager(런 로직) + CombatManager(전투 루프)를 UI 없이 헤드리스로 한 판 구동한다.
## 개별 부품이 아니라 "연결된 게임 루프"가 정상 전이하는지 본다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const GUN_PISTOL := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/cal_9mm.tres"
const B_KB := "res://resources/bullets/impact.tres"
const B_OPEN := "res://resources/bullets/marker.tres"
const E_RUSHER := "res://resources/enemies/rusher.tres"


static func run(t) -> void:
	t.section("RunFlow(integration)")

	# 결정론 확보를 위해 메타 정적 상태 리셋
	RunManager.infiltration_risk_level = 1
	RunManager.meta_hp_armor_lvl = 0
	RunManager.meta_backpack_lvl = 0

	# ── 1) 무기 선택 → 런 시작 ──
	var gun: GunData = load(GUN_PISTOL)
	t.check(gun != null, "총기 리소스(revolver) 로드")
	var rm := RunManager.new()
	rm.start_new_run("section_a", gun, load(B_BASIC), load(B_KB), load(B_OPEN))
	t.eq(rm.current_gun, gun, "런에 총기 고정")
	t.eq(rm.current_floor, 1, "런 시작 층 = 1")
	t.eq(rm.hp_buffer, 1, "HP 버퍼 = 1 (아머 Lv0)")
	t.eq(rm.deck.size(), 8, "권총 기본 덱 8발(5+2+1)")

	# ── 2) 스테이지/맵 생성 ──
	t.check(rm.map_nodes.size() > 0, "맵 노드 생성됨 (%d개)" % rm.map_nodes.size())
	t.check(rm.floor_connections.has(1), "1층 연결 존재")
	var floor1 := rm.get_nodes_for_floor(1)
	t.check(floor1.size() >= 1, "1층 노드 %d개 배치" % floor1.size())

	# ── 3) 노드 선택 (1층은 모두 도달 가능) + 환기구 비용 ──
	t.check(rm.is_node_reachable(floor1[0].id), "1층 노드 도달 가능")
	rm.select_route("air_duct")
	t.eq(rm.consume_pending_combat_distance_modifier(), -2, "환기구 경로 → 다음 교전 시작거리 -2m")
	t.eq(rm.consume_pending_combat_distance_modifier(), 0, "거리 비용은 1회 소비 후 소멸")

	# ── 4) 실제 전투를 CombatManager로 완주 ──
	var cm = CombatManagerScript.new()
	var won := [false]
	var lost := [false]
	cm.encounter_won.connect(func(): won[0] = true)
	cm.player_died.connect(func(): lost[0] = true)

	var loadout: Array[BulletData] = []
	for i in range(5):
		loadout.append((load(B_BASIC) as BulletData).duplicate())
	var enemies: Array[EnemyData] = [load(E_RUSHER) as EnemyData]
	var no_parts: Array[PartData] = []

	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)

	var guard := 0
	while not won[0] and not lost[0] and guard < 50:
		guard += 1
		cm.fire()

	t.check(won[0], "전투 완주 → 승리(encounter_won 발신)")
	t.check(not lost[0], "플레이어 생존(거리 0 도달 없음)")

	# ── 5) 보상: 드래프트로 덱에 추가 ──
	var before := rm.deck.size()
	rm.add_to_deck(load(B_KB))
	t.eq(rm.deck.size(), before + 1, "전투 보상 탄환이 덱에 추가")

	# ── 6) 다음 진행: 노드 클리어 TDC 지급 + 층 상승 ──
	var boss_node = RunManager.RunNode.new(999, "보스 (Boss)", "최종 보스", ["stairs"] as Array[String])
	t.eq(rm.record_node_clear(boss_node), 2, "보스 노드 클리어 → 전술 데이터 코어 +2")
	rm.current_floor = 5

	# ── 7) 런 정산 ──
	var meta_before := RunManager.meta_credits
	var earned := rm.end_run(true)
	t.eq(earned, 5 * 15 + 50, "런 클리어 정산 = 층(5)*15 + 승리보너스 50")
	t.eq(RunManager.meta_credits, meta_before + earned, "메타 크레딧에 정산액 누적")

	cm.free()
