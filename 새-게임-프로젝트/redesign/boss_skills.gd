extends RefCounted
## Finite, public boss actions. New campaigns opt in; old saves keep their clocks.
const VERSION := 1
const GATE := "closure_watch"
const MOTHER := "waterway_mother"
const CALL_TURNS := 3
const CALL_COUNT := 2

static func enabled(state: Dictionary) -> bool:
	return int(state.get("boss_skills_version", 0)) == VERSION

static func salvo(enemy: Dictionary) -> bool:
	return str(enemy.get("species", "")) == GATE and int(enemy.get("salvo_total", 0)) == 2

static func caller(enemy: Dictionary) -> bool:
	return str(enemy.get("species", "")) == MOTHER and enemy.has("summon_left")

static func prepare(state: Dictionary, node: Dictionary) -> void:
	if not enabled(state) or str(node.kind) != "boss": return
	for enemy in state.enemies:
		if int(node.region) == 0 and str(enemy.get("species", "")) == GATE:
			enemy.salvo_total = 2; enemy.salvo_left = 2
		elif int(node.region) == 2 and str(enemy.get("species", "")) == MOTHER:
			var selected: Array = []
			for reserve in state.reinforcements:
				if str(reserve.kind) == "runner" and selected.size() < CALL_COUNT: selected.append(reserve)
			if selected.size() != CALL_COUNT: continue
			enemy.summon_left = CALL_TURNS; enemy.summon_done = false
			for reserve in selected: reserve.brood_reserve = true

static func can_deploy(state: Dictionary, enemy: Dictionary) -> bool:
	if not enabled(state) or not enemy.get("brood_reserve", false): return true
	for source in state.enemies:
		if caller(source) and int(source.hp) > 0: return bool(source.summon_done)
	return true

static func called_waiting(state: Dictionary) -> bool:
	if not enabled(state): return false
	for enemy in state.reinforcements:
		if enemy.get("brood_reserve", false) and can_deploy(state, enemy): return true
	return false

static func advance(state: Dictionary, tick: int, record: bool) -> Array:
	var events: Array = []
	if not enabled(state): return events
	for i in range(state.enemies.size()):
		var enemy: Dictionary = state.enemies[i]
		if not caller(enemy) or int(enemy.hp) <= 0 or enemy.summon_done or int(enemy.get("jammed",0)) > 0: continue
		enemy.summon_left -= 1
		if int(enemy.summon_left) == 0: enemy.summon_done = true
		if record: events.append({"kind":"brood_call", "turn":tick, "target":i, "left":int(enemy.summon_left), "released":bool(enemy.summon_done)})
	return events

static func call_intent(enemy: Dictionary) -> String:
	return " · 증원 %d턴" % int(enemy.summon_left) if caller(enemy) and not enemy.summon_done else ""

static func whole(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= lo and value <= hi

static func valid(state: Dictionary) -> bool:
	if not whole(state.get("boss_skills_version",0),0,VERSION): return false
	if enabled(state) and (int(state.get("fire_control_version",0)) != 1 or int(state.get("enemy_pattern_version",0)) != 1): return false
	var mothers := 0; var brood := 0
	for enemy in state.enemies + state.reinforcements:
		if enemy.has("salvo_total") or enemy.has("salvo_left"):
			if not enabled(state) or not salvo(enemy) or not whole(enemy.get("salvo_total"),2,2): return false
			var phase: String = enemy.get("ranged_phase", "")
			var left := 1 if phase == "burst" else 2 if phase in ["guard","prepare"] else 0
			if not whole(enemy.get("salvo_left",-1),left,left): return false
		if enemy.has("summon_left") or enemy.has("summon_done"):
			if not enabled(state) or not caller(enemy) or int(enemy.get("garden_version",0)) != 1: return false
			if not whole(enemy.summon_left,0,CALL_TURNS) or not enemy.get("summon_done") is bool: return false
			if bool(enemy.summon_done) != (int(enemy.summon_left) == 0): return false
			mothers += 1
		if enemy.has("brood_reserve"):
			if not enabled(state) or not enemy.brood_reserve is bool or not enemy.brood_reserve or str(enemy.kind) != "runner": return false
			brood += 1
	return mothers <= 1 and (brood == CALL_COUNT if mothers == 1 else brood == 0)
