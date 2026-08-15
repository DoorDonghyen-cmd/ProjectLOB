extends RefCounted
## 풀 런 통합 스캔 (A / B1) — 스케일에서만 드러나는 통합 구멍을 자동 탐지한다.
##   1) 맵 도달성: 맵을 여러 번 생성해 1층→최상층 전 층이 도달 가능한지(데드엔드 없음) BFS 검증.
##      (실측: 현재 generate_run_map은 10층 생성 — 문서의 "15층"과 불일치, task_tracker 등록)
##   2) 전투 크래시 스캔: 대표 적 + 보스 4종을 실제 CombatManager로 구동해 크래시/행(hang) 없이 종결되는지.
## 정본: run_manager.gd(맵), combat_manager.gd(전투)

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const GUN := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/cal_9mm.tres"
const B_KB := "res://resources/bullets/impact.tres"
const B_OPEN := "res://resources/bullets/marker.tres"
const B_STRONG := "res://resources/bullets/pierce.tres"   # ACC7 / PEN3 / DMG3 — 범용 강탄
const B_MAXACC := "res://resources/bullets/marker.tres"    # ACC8 — 일반탄 상한, EVA9 전용 카운터 아님


static func run(t) -> void:
	t.section("FullRun(integration)")
	RunManager.infiltration_risk_level = 1
	var gun: GunData = load(GUN)

	# ── 1) 맵 도달성 (랜덤 생성 5회) ──
	for iter in range(5):
		var rm := RunManager.new()
		rm.start_new_run("section_a", gun, load(B_BASIC), load(B_KB), load(B_OPEN))
		var report := _map_reachability(rm)
		t.check(report.all_reachable, "맵#%d: 1~%d층 전부 도달 가능(데드엔드 없음)%s" % [
			iter + 1, report.max_floor, report.detail])

	# ── 1-B) 전 구역 맵 생성 검증 ──
	# 계층별 명칭 테이블(_names_b/c/d/e)에 키가 누락되면 해당 구역 생성 시 즉시 실패한다.
	# section_a 외 구역은 플레이 경로가 길어 수동 확인이 어려우므로 여기서 강제 구동한다.
	for sec in ["section_a", "section_b", "section_c", "section_d", "section_e"]:
		var rm_s := RunManager.new()
		rm_s.start_new_run(sec, gun, load(B_BASIC), load(B_KB), load(B_OPEN))
		var rep := _map_reachability(rm_s)
		t.check(rep.all_reachable, "%s: 1~%d층 도달 가능%s" % [sec, rep.max_floor, rep.detail])

		# 노드 명칭이 비어 있지 않고, 기능 접미사(로직 분기용)가 보존되었는지 확인
		var has_major_gate := false
		var has_shop := false
		for nid in rm_s.map_nodes.keys():
			var tn: String = rm_s.map_nodes[nid].type_name
			t.check(tn.strip_edges() != "", "%s 노드 %d: 명칭 비어있지 않음" % [sec, nid])
			if CampaignContent.is_major_gate_type(tn):
				has_major_gate = true
			if tn.contains("상점"):
				has_shop = true
		t.check(has_major_gate, "%s: 주요 관문 노드 존재(전투 라우팅 보존)" % sec)
		t.check(has_shop, "%s: 상점 노드 존재(통로 배치 로직 보존)" % sec)

		# 구역 메타데이터 정합 (표시 고도)
		var info := MapGenerator.section_info(sec)
		t.eq(int(info.floors), rep.max_floor, "%s: section_info 층수와 실제 생성 층수 일치" % sec)

	# ── 2) 전투 크래시 스캔 ──
	# 승리 확인(약하고 명중 가능): 러셔
	t.eq(_encounter(gun, "res://resources/enemies/rusher.tres", B_BASIC).result, "won",
		"러셔 기본 전투 승리(전투 루프 정상)")

	# 9mm 고정 프로필은 고명중 전술탄 ACC8을 9로 올려 EVA9에 정확히 닿는다.
	# DMR은 전용 우회, 9mm는 탄환 선택을 요구하는 보조 카운터로 역할이 다르다.
	t.eq(_encounter(gun, "res://resources/enemies/nano_stalker.tres", B_MAXACC).result, "won",
		"광학 추적체 03 EVA9 — 9mm 고명중 프로필로 임계값 도달")

	# 크래시/행 없이 종결되는지 스캔 (일반 특수 적 + 보스 4종 = 보스 전용 코드 경로 구동)
	var scan := [
		"res://resources/enemies/sentry_drone.tres",
		"res://resources/enemies/dodger.tres",
		"res://resources/enemies/caster.tres",
		"res://resources/enemies/absorber_mech.tres",
		"res://resources/enemies/scrambler_drone.tres",
		"res://resources/enemies/neuro_caster.tres",
		"res://resources/enemies/boss_director.tres",
		"res://resources/enemies/boss_seraph.tres",
		"res://resources/enemies/boss_omega.tres",
		"res://resources/enemies/boss_lob_core.tres",
	]
	for path in scan:
		var r := _encounter(gun, path, B_STRONG)
		var name: String = path.get_file().get_basename()
		t.check(r.terminated, "%s 전투 크래시/행 없이 종결(%s)" % [name, r.result])


## 맵 BFS 도달성 분석 — 1층에서 시작해 도달 가능한 층 집합을 구한다.
static func _map_reachability(rm) -> Dictionary:
	var id_floor := {}
	var max_floor := 0
	for f in rm.floor_connections.keys():
		max_floor = maxi(max_floor, int(f))
		for nid in rm.floor_connections[f]:
			id_floor[nid] = int(f)

	var visited := {}
	var queue: Array = []
	for nid in rm.floor_connections.get(1, []):
		queue.append(nid)
		visited[nid] = true

	var reached_floors := {}
	while not queue.is_empty():
		var nid = queue.pop_front()
		reached_floors[id_floor.get(nid, 0)] = true
		var node = rm.map_nodes.get(nid, null)
		if node == null:
			continue
		for nxt in node.connected_node_ids:
			if not visited.has(nxt):
				visited[nxt] = true
				queue.append(nxt)

	var missing: Array = []
	for f in range(1, max_floor + 1):
		if not reached_floors.has(f):
			missing.append(f)

	return {
		"max_floor": max_floor,
		"all_reachable": missing.is_empty(),
		"detail": "" if missing.is_empty() else (" [끊긴 층: %s]" % str(missing)),
	}


## 단일 인카운터를 CombatManager로 구동한다. (탄창 1개 분량, 리로드 없음)
static func _encounter(gun: GunData, enemy_path: String, bullet_path: String) -> Dictionary:
	var cm = CombatManagerScript.new()
	var won := [false]
	var lost := [false]
	cm.encounter_won.connect(func(): won[0] = true)
	cm.player_died.connect(func(): lost[0] = true)

	var loadout: Array[BulletData] = []
	for i in range(8):
		loadout.append((load(bullet_path) as BulletData).duplicate())
	var enemies: Array[EnemyData] = [load(enemy_path) as EnemyData]
	var no_parts: Array[PartData] = []

	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)

	var guard := 0
	while not won[0] and not lost[0] and not cm.magazine.is_empty() and guard < 100:
		guard += 1
		cm.fire()

	var terminated: bool = won[0] or lost[0] or cm.magazine.is_empty()
	var result := "won" if won[0] else ("lost" if lost[0] else ("out_of_ammo" if cm.magazine.is_empty() else "hang"))
	cm.free()
	return {"result": result, "terminated": terminated, "guard": guard}
