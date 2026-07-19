extends RefCounted
## 풀 런 통합 스캔 (A / B1) — 스케일에서만 드러나는 통합 구멍을 자동 탐지한다.
##   1) 맵 도달성: 맵을 여러 번 생성해 1층→최상층 전 층이 도달 가능한지(데드엔드 없음) BFS 검증.
##      (실측: 현재 generate_run_map은 10층 생성 — 문서의 "15층"과 불일치, task_tracker 등록)
##   2) 전투 크래시 스캔: 대표 적 + 보스 4종을 실제 CombatManager로 구동해 크래시/행(hang) 없이 종결되는지.
## 정본: run_manager.gd(맵), combat_manager.gd(전투)

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const GUN := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/basic_pistol.tres"
const B_KB := "res://resources/bullets/knockback_pistol.tres"
const B_OPEN := "res://resources/bullets/opening_pistol.tres"
const B_STRONG := "res://resources/bullets/pierce_dmr.tres"   # ACC7 / PEN3 / DMG4 — 범용 강탄
const B_MAXACC := "res://resources/bullets/slow_pistol.tres"  # ACC8 — 최대 명중


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

	# ── 2) 전투 크래시 스캔 ──
	# 승리 확인(약하고 명중 가능): 러셔
	t.eq(_encounter(gun, "res://resources/enemies/rusher.tres", B_BASIC).result, "won",
		"러셔 기본 전투 승리(전투 루프 정상)")

	# nano_stalker: EVA 9 > 탄환 ACC 상한(8) → 일반 총기로는 원천 명중 불가(의도된 스텔스 설계).
	# 전용 카운터(DMR 저격 시그니처 등)는 suite_gun_signatures에서 검증한다.
	t.eq(_encounter(gun, "res://resources/enemies/nano_stalker.tres", B_MAXACC).result, "out_of_ammo",
		"나노 스토커 EVA9 — 일반 총기 최대 ACC(8)로는 명중 불가(카운터 필수 설계)")

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
