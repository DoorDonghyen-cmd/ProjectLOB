extends RefCounted
## Non-combat state and combat share one atomic save, including profile awards.
const Content = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Lore = preload("res://scripts/core/lore_catalog.gd")
const SAVE := "user://city_campaign_v1.json"
var model = Model.new()
var s: Dictionary = {}
var profile: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"cores": 0, "lore": [], "runs": 0, "wins": 0, "ascension": 0, "best_region": 0, "unlocks": ["balanced"]}

func start(gun: String, seed_value: int, difficulty: int = 0, loadout: String = "balanced") -> void:
	if not profile.unlocks.has(loadout): loadout = "balanced"
	s = {"version": 1, "seed": str(seed_value), "gun": gun, "difficulty": clampi(difficulty, 0, int(profile.ascension)), "loadout": loadout, "region": 0, "floor": 0, "node": 0, "phase": "map", "credits": 18, "pressure": 0, "slots": 0, "parts": [], "visited": [], "clears": 0, "shop_revision": 0, "shop_part_bought": false, "shop_refined": false, "offers": [], "resolved": false, "settled": false, "log": [], "message": "정점까지 35층. 다음 목적지를 선택하세요."}
	model.start(gun, seed_value)
	model.s.deck = Ammo.start_deck(gun) if loadout == "balanced" else Content.LOADOUTS[loadout].deck.duplicate()
	model.begin_encounter()

func current_nodes() -> Array:
	return Content.nodes(int(s.region), int(s.seed))

func node() -> Dictionary:
	for item in current_nodes():
		if int(item.id) == int(s.node): return item
	return {}

func choices() -> Array:
	var result: Array = []
	if s.phase != "map": return result
	var current := node()
	for item in current_nodes():
		if int(item.floor) != int(s.floor) + 1: continue
		# A right branch stays right until the path merges, so earlier choices matter.
		if not current.is_empty() and int(current.lane) == 1 and int(item.lane) == 0:
			var count := 0
			for other in current_nodes():
				if int(other.floor) == int(item.floor): count += 1
			if count > 1: continue
		result.append(item)
	return result

func enter(id: int) -> bool:
	var selected: Dictionary = {}
	for item in choices():
		if int(item.id) == id: selected = item
	if selected.is_empty(): return false
	s.floor = selected.floor
	s.node = id
	s.resolved = false
	if selected.route == "duct": s.pressure = 2
	s.visited.append(id)
	_log("enter", {"id": id, "route": selected.route})
	match str(selected.kind):
		"combat", "boss":
			model.s.floor = mini(5, int(s.region) + (1 if int(s.floor) >= 5 else 0))
			model.s.capacity_bonus = s.slots
			model.s.encounter_id = id
			# Each node has its own draw stream without resetting run statistics/history.
			model.s.seed = str(int(s.seed) + id * 101)
			model.begin_encounter()
			model.s.enemies = Content.encounter(selected, int(s.seed), str(s.gun), int(s.difficulty), int(s.pressure))
			model.s.encounter_name = selected.name
			s.pressure = 0
			s.phase = "combat"
		"shop":
			s.phase = "shop"
			s.shop_revision = 0
			s.shop_part_bought = false
			s.shop_refined = false
			s.offers = Content.offers(selected, int(s.seed), 0, str(s.gun), s.parts)
		"supply":
			s.phase = "supply"
			collect_lore(3 + int(s.region) * 4)
		"event": s.phase = "event"
		"bypass":
			s.phase = "bypass"
			collect_lore(1 + int(s.region) * 4)
			s.resolved = true
			s.message = "전투를 피해 이동했습니다. 남겨진 기록을 회수했습니다."
	return true

func sync_combat() -> void:
	if s.is_empty() or s.phase != "combat": return
	if model.s.phase == "lost":
		s.phase = "lost"
		s.message = model.s.message
		settle(false)
	elif model.s.phase in ["reward", "won"]:
		s.clears += 1
		s.phase = "reward"
		_log("clear", {"node": s.node, "shots": model.s.shots, "turns": model.s.turns})
		if node().kind == "boss": collect_lore(4 + int(s.region) * 4)

func credit_reward() -> int:
	var used := 0
	var elapsed := 0
	for i in range(model.s.history.size() - 1, -1, -1):
		var event: Dictionary = model.s.history[i]
		if event.action == "encounter": break
		if event.action == "fire":
			used += event.detail.results.size()
			elapsed += 1
		if event.action == "reload": elapsed += int(event.detail.cost)
	return maxi(8, 12 + int(s.region) - maxi(0, used - 6) - maxi(0, elapsed - 6) - int(s.difficulty))

func encounter_report_state() -> Dictionary:
	var state: Dictionary = model.s.duplicate(true)
	for i in range(state.history.size() - 1, -1, -1):
		if state.history[i].action == "encounter":
			state.history = state.history.slice(i)
			break
	return state

func reward(choice: String, remove_id: String = "") -> bool:
	if s.phase != "reward" or s.resolved: return false
	if choice == "credits": s.credits += credit_reward()
	elif choice == "skip": pass
	elif choice == "remove" and model.s.deck.size() > 6 and model.s.deck.has(remove_id): model.s.deck.erase(remove_id)
	elif Content.rewards(node(), int(s.seed)).has(choice) and model.s.deck.size() < 14:
		model.s.deck.append(choice)
	else: return false
	s.resolved = true
	_log("reward", {"choice": choice, "removed": remove_id})
	if node().kind == "boss":
		if int(s.region) == 4:
			s.phase = "won"
			settle(true)
		else:
			s.phase = "gate"
			s.resolved = false
	else: s.phase = "map"
	return true

func gate(choice: String) -> bool:
	if s.phase != "gate" or s.resolved: return false
	if choice == "slot" and int(s.slots) < 2: s.slots += 1
	elif choice == "credits": s.credits += 24
	else: return false
	_log("gate", {"choice": choice})
	s.region += 1
	s.floor = 0
	s.node = 0
	s.phase = "map"
	s.resolved = true
	profile.best_region = maxi(int(profile.best_region), int(s.region))
	return true

func buy(index: int) -> bool:
	if s.phase != "shop" or index < 0 or index >= s.offers.size(): return false
	var offer: Dictionary = s.offers[index]
	if offer.sold or int(s.credits) < int(offer.price): return false
	if offer.type == "part":
		if s.shop_part_bought or s.parts.has(offer.id): return false
		if not Ammo.PARTS.has(offer.id) or offer.id in ["none", "supply"]: return false
	elif offer.type != "ammo" or not Ammo.AMMO.has(offer.id) or offer.id == "basic" or model.s.deck.size() >= 14: return false
	s.credits -= int(offer.price)
	offer.sold = true
	if offer.type == "part":
		s.parts.append(offer.id)
		model.s.part = offer.id
		s.shop_part_bought = true
	else: model.s.deck.append(offer.id)
	_log("purchase", {"id": offer.id, "price": offer.price})
	return true

func reroll() -> bool:
	if s.phase != "shop" or int(s.credits) < 3: return false
	s.credits -= 3
	s.shop_revision += 1
	s.offers = Content.offers(node(), int(s.seed), int(s.shop_revision), str(s.gun), s.parts)
	# Persistent visit-level lock deliberately survives offer replacement.
	_log("reroll", {"revision": s.shop_revision})
	return true

func shop_refine(id: String) -> bool:
	if s.phase != "shop" or s.get("shop_refined", false) or int(s.credits) < 12 or model.s.deck.size() <= 6 or not model.s.deck.has(id): return false
	model.s.deck.erase(id)
	s.credits -= 12
	s.shop_refined = true
	_log("shop_refine", {"id": id, "price": 12})
	return true

func equip(id: String) -> bool:
	if not s.phase in ["shop", "supply", "bypass"] or (id != "none" and not s.parts.has(id)): return false
	model.s.part = id
	_log("equip", {"id": id})
	return true

func dismantle(id: String) -> bool:
	if not s.phase in ["shop", "supply"] or not s.parts.has(id) or model.s.part == id: return false
	s.parts.erase(id)
	s.credits += 10
	_log("dismantle", {"id": id})
	return true

func resolve(choice: String, ammo_id: String = "") -> bool:
	if s.resolved or not s.phase in ["supply", "event"]: return false
	var current := node()
	if choice == "skip": s.message = "현재 구성을 유지했습니다."
	elif s.phase == "supply":
		if choice == "ammo" and Content.rewards(current, int(s.seed)).has(ammo_id) and model.s.deck.size() < 14:
			model.s.deck.append(ammo_id)
			s.message = Ammo.AMMO[ammo_id].name + " 1장을 보급받았습니다."
		elif choice == "remove" and model.s.deck.size() > 6 and model.s.deck.has(ammo_id):
			model.s.deck.erase(ammo_id)
			s.message = Ammo.AMMO[ammo_id].name + " 1장을 정제했습니다."
		else: return false
	else:
		match str(current.event):
			"siphon":
				if choice != "power": return false
				s.credits += 20
				s.pressure = 2
				s.message = "20Cr 회수 · 다음 전투 시작 거리 −2m."
			"archive":
				if choice == "lore":
					collect_lore(2 + int(s.region) * 4)
					s.message = "도시 기록을 회수했습니다."
				elif choice == "ammo" and model.s.deck.size() < 14:
					var id: String = Content.rewards(current, int(s.seed))[0]
					model.s.deck.append(id)
					s.message = Ammo.AMMO[id].name + " 1장을 회수했습니다."
				else: return false
			"salvage":
				if choice != "sell" or model.s.deck.size() <= 6 or not model.s.deck.has(ammo_id): return false
				model.s.deck.erase(ammo_id)
				s.credits += 16
				s.message = Ammo.AMMO[ammo_id].name + " 1장 분해 · +16Cr."
	s.resolved = true
	_log("resolve", {"choice": choice, "ammo": ammo_id})
	return true

func leave() -> bool:
	if not s.phase in ["shop", "supply", "event", "bypass"]: return false
	if s.phase in ["supply", "event"] and not s.resolved: return false
	s.phase = "map"
	return true

func collect_lore(id: int) -> void:
	if not profile.lore.has(id):
		profile.lore.append(id)
		profile.lore.sort()

func settle(won: bool) -> void:
	if s.settled: return
	s.settled = true
	var earned := int(s.clears) * 2 + (20 if won else 0)
	profile.cores += earned
	profile.runs += 1
	if won:
		profile.wins += 1
		if int(s.difficulty) == int(profile.ascension): profile.ascension = mini(10, int(profile.ascension) + 1)
	s.message = "전술 데이터 +%d · 기록은 다음 등반에 남습니다." % earned
	_log("settle", {"won": won, "cores": earned})

func unlock(id: String) -> bool:
	if not Content.LOADOUTS.has(id) or profile.unlocks.has(id) or int(profile.cores) < 30: return false
	profile.cores -= 30
	profile.unlocks.append(id)
	return true

func absolute_floor() -> int:
	var count := int(s.floor)
	for region in range(int(s.region)): count += int(Content.info(region).floors)
	return count

func _log(action: String, detail: Dictionary) -> void:
	s.log.append({"action": action, "region": s.region, "floor": s.floor, "detail": detail})

func save(path: String = SAVE) -> Error:
	# Outside combat, the next room owns the deck anew. Reconcile its zones after
	# rewards/services so every serialized nested combat state conserves ownership.
	if s.phase != "combat":
		model.s.capacity_bonus = s.slots
		model.s.hand = model.s.deck.slice(0, 5)
		model.s.draw = model.s.deck.slice(5)
		model.s.discard = []
		model.s.magazine = []
		model.s.plan = []
		model.s.buff = {}
		model.s.supply = model.capacity()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"campaign": s, "combat": model.s, "profile": profile}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func restore(path: String = SAVE) -> bool:
	if not FileAccess.file_exists(path): return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary: return false
	return restore_state(json.data)

func restore_state(data: Dictionary) -> bool:
	if not data.get("campaign") is Dictionary or not data.get("combat") is Dictionary or not data.get("profile") is Dictionary: return false
	var state: Dictionary = data.campaign
	state = state.duplicate(true)
	if not state.has("shop_refined"): state.shop_refined = false
	var progress: Dictionary = data.profile
	for key in ["version", "seed", "gun", "difficulty", "loadout", "region", "floor", "node", "phase", "credits", "pressure", "slots", "parts", "visited", "clears", "shop_revision", "shop_part_bought", "offers", "resolved", "settled", "log", "message"]:
		if not state.has(key): return false
	if not _whole(state.version, 1, 1) or not state.seed is String or not state.seed.is_valid_int() or str(int(state.seed)) != state.seed: return false
	if not Ammo.GUNS.has(state.gun) or not Content.LOADOUTS.has(state.loadout): return false
	for key in ["region", "floor", "node", "difficulty", "credits", "pressure", "slots", "clears", "shop_revision"]:
		if not _whole(state[key], 0, 1000000): return false
	if state.region > 4 or state.floor > int(Content.info(int(state.region)).floors) or state.difficulty > 10 or not int(state.pressure) in [0, 2] or state.slots > 2: return false
	if not state.phase in ["map", "combat", "reward", "gate", "shop", "supply", "event", "bypass", "won", "lost"]: return false
	for key in ["resolved", "settled", "shop_part_bought", "shop_refined"]:
		if not state[key] is bool: return false
	for key in ["parts", "visited", "offers", "log"]:
		if not state[key] is Array: return false
	if not state.message is String: return false
	var unique := []
	for id in state.parts:
		if not id in ["lens", "coil", "loader"] or unique.has(id) or not Ammo.accepts_part(str(state.gun), str(id)): return false
		unique.append(id)
	for offer in state.offers:
		if not offer is Dictionary: return false
		for key in ["id", "type", "price", "sold"]:
			if not offer.has(key): return false
		if not offer.sold is bool or not _whole(offer.price, 1, 100): return false
		if offer.type == "ammo":
			if not Ammo.AMMO.has(offer.id) or offer.id == "basic" or int(offer.price) != 12: return false
		elif offer.type != "part" or not offer.id in ["lens", "coil", "loader"] or int(offer.price) != 30 or not Ammo.accepts_part(str(state.gun), str(offer.id)): return false
	for key in defaults():
		if not progress.has(key): return false
	for key in ["cores", "runs", "wins", "ascension", "best_region"]:
		if not _whole(progress[key], 0, 1000000): return false
	if progress.ascension > 10 or progress.best_region > 4 or progress.wins > progress.runs or not progress.lore is Array or not progress.unlocks is Array: return false
	unique = []
	for id in progress.lore:
		if not _whole(id, 1, 20) or unique.has(id): return false
		unique.append(id)
	unique = []
	for id in progress.unlocks:
		if not Content.LOADOUTS.has(id) or unique.has(id): return false
		unique.append(id)
	if not progress.unlocks.has("balanced") or not progress.unlocks.has(state.loadout) or state.difficulty > progress.ascension: return false
	var combat = Model.new()
	if not combat.restore_state(data.combat): return false
	if combat.s.gun != state.gun or combat.s.get("capacity_bonus", 0) > state.slots: return false
	if combat.s.part != "none" and not state.parts.has(combat.s.part): return false
	var candidate = get_script().new()
	candidate.s = state
	var current: Dictionary = candidate.node()
	var seen_nodes: Array = []
	var previous: Dictionary = {}
	for id in state.visited:
		if not _whole(id, 101, 40801) or seen_nodes.has(int(id)): return false
		var region := int(id) / 10000
		if region > int(state.region): return false
		var found: Dictionary = {}
		for item in Content.nodes(region, int(state.seed)):
			if int(item.id) == int(id): found = item
		if found.is_empty(): return false
		if previous.is_empty():
			if found.region != 0 or found.floor != 1: return false
		elif found.region == previous.region:
			if int(found.floor) != int(previous.floor) + 1: return false
			var next_nodes := Content.nodes(region, int(state.seed)).filter(func(item): return int(item.floor) == int(found.floor))
			if int(previous.lane) == 1 and int(found.lane) == 0 and next_nodes.size() > 1: return false
		elif int(found.region) != int(previous.region) + 1 or found.floor != 1 or previous.kind != "boss": return false
		previous = found
		seen_nodes.append(int(id))
	if state.floor == 0:
		if state.node != 0 or state.phase != "map": return false
		if int(state.region) > 0 and (previous.is_empty() or int(previous.region) != int(state.region) - 1 or previous.kind != "boss"): return false
	elif current.is_empty() or current.floor != state.floor: return false
	elif previous.is_empty() or int(previous.id) != int(state.node): return false
	if state.phase in ["combat", "reward", "gate", "won", "lost"] and not current.get("kind", "") in ["combat", "boss"]: return false
	if state.phase in ["shop", "supply", "event", "bypass"] and current.get("kind", "") != state.phase: return false
	if state.phase == "gate" and (current.kind != "boss" or int(state.region) == 4): return false
	if state.phase == "won" and (int(state.region) != 4 or int(state.floor) != 8): return false
	if state.phase == "combat" and not combat.s.phase in ["plan", "ready"]: return false
	if state.phase in ["reward", "gate", "won"] and not combat.s.phase in ["reward", "won"]: return false
	if state.phase == "lost" and combat.s.phase != "lost": return false
	if (state.phase in ["won", "lost"]) != state.settled: return false
	s = state.duplicate(true)
	profile = progress.duplicate(true)
	model = combat
	return true

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
