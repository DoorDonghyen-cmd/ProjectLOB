extends RefCounted
## Hazards are separate from enemies, slots and rewards. IDs survive deployments.
const TARGET_BASE := 10000
const PREPARE_TURNS := 2
const PROJECTILE_SPEED := 6

static func is_gatekeeper(enemy: Dictionary) -> bool:
	return str(enemy.get("species", "")) == "closure_watch"

static func is_projectile(target: int) -> bool:
	return target >= TARGET_BASE

static func target_id(projectile: Dictionary) -> int:
	return TARGET_BASE + int(projectile.uid)

static func entity(state: Dictionary, target: int) -> Dictionary:
	if is_projectile(target):
		for projectile in state.get("projectiles", []):
			if target_id(projectile) == target: return projectile
		return {}
	return state.enemies[target] if target >= 0 and target < state.enemies.size() else {}

static func active(state: Dictionary) -> Array:
	return state.get("projectiles", []).filter(func(p): return int(p.hp) > 0)

static func arrival(projectile: Dictionary) -> int:
	return ceili(float(projectile.distance) / PROJECTILE_SPEED)

static func intent(enemy: Dictionary) -> String:
	if int(enemy.get("jammed", 0)) > 0: return "차단 %d턴 · 준비 정지" % int(enemy.jammed)
	if is_gatekeeper(enemy):
		match str(enemy.ranged_phase):
			"guard": return "개방까지 %d턴" % int(enemy.ranged_left)
			"waiting": return "압력탄 비행 · 개방"
			"recover": return "개방 유지 %d턴" % int(enemy.ranged_left)
		return "압력탄 발사 %d턴" % int(enemy.ranged_left)
	match str(enemy.get("ranged_phase", "prepare")):
		"waiting": return "탄 비행 중"
		"recover": return "회복 1턴"
	return "발사까지 %d턴" % int(enemy.get("ranged_left", PREPARE_TURNS))

static func advance(state: Dictionary, tick: int, record_events: bool = true) -> Array:
	var events: Array = []
	# Existing projectiles move before launches: no movement on the birth tick.
	for projectile in active(state):
		var from := int(projectile.distance)
		projectile.distance = maxi(0, from - PROJECTILE_SPEED)
		if record_events: events.append({"kind": "projectile_move", "turn": tick, "target": target_id(projectile), "from": from, "to": projectile.distance})
		if int(projectile.distance) == 0:
			state.phase = "lost"
			state.loss_reason = "projectile"
	if state.phase == "lost": return events
	for i in range(state.enemies.size()):
		var enemy: Dictionary = state.enemies[i]
		if int(enemy.hp) <= 0 or str(enemy.kind) != "spitter": continue
		if int(enemy.get("jammed", 0)) > 0: continue
		if is_gatekeeper(enemy):
			events.append_array(_advance_gatekeeper(state, i, tick, record_events))
			continue
		var phase := str(enemy.ranged_phase)
		if phase == "waiting":
			if not active(state).is_empty(): continue
			phase = "recover"
			enemy.ranged_left = 1
		if phase == "recover":
			enemy.ranged_phase = "prepare"
			enemy.ranged_left = PREPARE_TURNS
			if record_events: events.append({"kind": "ranged_recover", "turn": tick, "target": i, "phase": "prepare", "left": PREPARE_TURNS})
			continue
		if not active(state).is_empty(): continue
		enemy.ranged_left = maxi(0, int(enemy.ranged_left) - 1)
		if int(enemy.ranged_left) > 0:
			if record_events: events.append({"kind": "ranged_prepare", "turn": tick, "target": i, "phase": "prepare", "left": enemy.ranged_left})
			continue
		var launch := _launch(state, i, tick)
		if record_events: events.append(launch)
	return events

static func _launch(state: Dictionary, index: int, tick: int) -> Dictionary:
	var enemy: Dictionary = state.enemies[index]
	state.projectile_serial = int(state.get("projectile_serial", 0)) + 1
	var projectile := {"uid": state.projectile_serial, "source": index, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": PROJECTILE_SPEED, "distance": int(enemy.distance), "burn": 0}
	state.projectiles = [projectile]
	enemy.ranged_phase = "waiting"
	enemy.ranged_left = 0
	return {"kind":"projectile_launch","turn":tick,"target":target_id(projectile),"source":index,"projectile":projectile.duplicate(true)}

static func _advance_gatekeeper(state: Dictionary, index: int, tick: int, record_events: bool) -> Array:
	var enemy: Dictionary = state.enemies[index]
	var events: Array = []
	var phase := str(enemy.ranged_phase)
	if phase == "waiting":
		if not active(state).is_empty(): return events
		enemy.ranged_phase = "recover"
		enemy.ranged_left = 2
	else:
		enemy.ranged_left = maxi(0, int(enemy.ranged_left) - 1)
		if int(enemy.ranged_left) == 0:
			match phase:
				"guard":
					enemy.ranged_phase = "prepare"
					enemy.ranged_left = 2
					enemy.def = 0
				"recover":
					enemy.ranged_phase = "guard"
					enemy.ranged_left = 2
					enemy.def = int(enemy.guard_armor)
				"prepare":
					if active(state).is_empty():
						var launch := _launch(state,index,tick)
						if record_events: events.append(launch)
					else: enemy.ranged_left = 1
	if record_events:
		events.append({"kind":"gatekeeper_state","turn":tick,"target":index,"phase":enemy.ranged_phase,"left":enemy.ranged_left,"def":enemy.def})
	return events

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func valid_state(state: Dictionary) -> bool:
	if not state.get("projectiles", []) is Array or state.get("projectiles", []).size() > 1: return false
	if not _integer(state.get("projectile_serial", 0), 0, 1000000): return false
	if state.has("loss_reason") and state.loss_reason not in ["", "projectile"]: return false
	var shooters := 0
	for enemy in state.enemies + state.get("reinforcements", []):
		if str(enemy.kind) != "spitter": continue
		shooters += 1
		if is_gatekeeper(enemy):
			if enemy.speed != 0 or enemy.get("ranged_phase", "") not in ["guard","prepare","waiting","recover"]: return false
			var gate_phase := str(enemy.ranged_phase)
			if not _integer(enemy.get("guard_armor", -1),0,9): return false
			if not _integer(enemy.get("ranged_left", -1),0 if gate_phase == "waiting" else 1,0 if gate_phase == "waiting" else 2): return false
			if int(enemy.def) != (int(enemy.guard_armor) if gate_phase == "guard" else 0): return false
			continue
		if enemy.speed != 0 or enemy.get("ranged_phase", "") not in ["prepare", "waiting", "recover"]: return false
		var phase := str(enemy.ranged_phase)
		if not _integer(enemy.get("ranged_left", -1), 0 if phase == "waiting" else 1, 2 if phase == "prepare" else (0 if phase == "waiting" else 1)): return false
	if shooters > 1: return false
	for projectile in state.get("projectiles", []):
		if not projectile is Dictionary: return false
		for key in ["uid", "source", "hp", "max_hp", "def", "speed", "distance", "burn"]:
			if not _integer(projectile.get(key, null), 0, 1000000): return false
		if projectile.uid < 1 or projectile.uid != state.get("projectile_serial", 0): return false
		if projectile.source >= state.enemies.size() or str(state.enemies[int(projectile.source)].kind) != "spitter": return false
		if projectile.hp > 1 or projectile.max_hp != 1 or projectile.def != 0 or projectile.speed != PROJECTILE_SPEED or projectile.burn != 0: return false
		if projectile.get("kind", "") != "pressure" or not projectile.get("name") is String: return false
		if not _integer(projectile.get("focus_hits", 0), 0, 2): return false
		if int(projectile.hp) > 0 and (state.phase in ["reward", "won"] or (int(projectile.distance) == 0 and state.phase != "lost")): return false
	return true
