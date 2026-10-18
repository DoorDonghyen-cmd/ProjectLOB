extends RefCounted
## Developer-only fixtures. All rules and simulation come from the live resolver.
const Data = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Forecast = preload("res://redesign/forecast.gd")
var gun := "single"
var encounter := 1
var run_seed := 42
var start_heat := 0
var parts: Array = []
var loaded: Array = []

func fixture() -> RefCounted:
	var m = Model.new()
	m.start(gun, run_seed)
	m.s.floor = encounter
	m.s.equipped_parts = parts.duplicate()
	m.begin_encounter(0)
	m.s.heat = start_heat
	# A prepared test hand, not a normal run's draw/ownership operation.
	m.s.hand = loaded.duplicate()
	m.s.deck = loaded.duplicate()
	m.s.draw = []
	for id in loaded:
		if not m.load_round(str(id)): return null
	return m

func configure(next_gun: String, next_encounter: int, next_seed: int, next_heat: int) -> String:
	if next_encounter < 0 or next_encounter >= Data.ENCOUNTERS.size() or next_seed < 0 or next_heat < 0:
		return "시험 조건 범위를 확인하세요."
	if not Data.GUNS.has(next_gun) or not Data.valid_part_set(next_gun, parts):
		return "이 총기에 장착할 수 없는 파츠가 있습니다. 먼저 해제하세요."
	var previous := [gun, encounter, run_seed, start_heat]
	gun = next_gun; encounter = next_encounter; run_seed = next_seed; start_heat = next_heat
	if fixture() == null:
		gun = previous[0]; encounter = previous[1]; run_seed = previous[2]; start_heat = previous[3]
		return "현재 탄창을 유지할 수 없습니다. 탄환을 회수한 뒤 변경하세요."
	return ""

func add_round(id: String) -> String:
	if not Data.AMMO.has(id) or Data.is_temporary(id): return "임시 압축탄은 직접 장전할 수 없습니다."
	var m = fixture()
	var reason: String = Data.insertion_block_reason(m.s.plan, id, m.capacity())
	if not reason.is_empty(): return reason
	loaded.append(id)
	return ""

func toggle_part(id: String) -> String:
	var prior := parts.duplicate()
	if parts.has(id): parts.erase(id)
	else: parts.append(id)
	if not Data.valid_part_set(gun, parts):
		parts = prior
		return "장착 불가 · 총기 호환 / 최대 5개 / 코어 최대 1개를 확인하세요."
	if fixture() == null:
		parts = prior
		return "탄창 용량이 부족해집니다. 탄환을 먼저 회수하세요."
	return ""

func run_trial() -> Dictionary:
	var m = fixture()
	if m == null or loaded.is_empty(): return {}
	var before: Dictionary = m.s.duplicate(true)
	var prediction: Dictionary = Forecast.analyze(before)
	m.confirm()
	for _i in range(m.capacity()):
		if not m.fire(): break
	var damage := 0
	var kills := 0
	for i in range(before.enemies.size()):
		damage += maxi(0, int(before.enemies[i].hp) - maxi(0, int(m.s.enemies[i].hp)))
		if int(m.s.enemies[i].hp) <= 0: kills += 1
	var peak := start_heat
	var forced := 0
	for event in m.s.history:
		peak = maxi(peak, int(event.get("detail", {}).get("heat_peak", 0)))
		forced += int(event.get("detail", {}).get("forced_reload", {}).get("cost", 0))
	return {"before": before, "after": m.s.duplicate(true), "forecast": prediction,
		"damage": damage, "kills": kills, "peak": peak, "forced": forced,
		"turns": int(m.s.turns) - int(before.turns), "end_heat": int(m.s.heat)}

static func catalog(kind: int, query: String) -> Array:
	var source: Dictionary = Data.AMMO if kind == 0 else Data.PARTS
	var found: Array = []
	for id in source:
		if id == "none" or (kind == 0 and Data.is_temporary(id)): continue
		if query.strip_edges().is_empty() or (str(id) + " " + str(source[id])).to_lower().contains(query.strip_edges().to_lower()):
			found.append(str(id))
	return found
