extends RefCounted
## Non-combat state and combat share one atomic save, including profile awards.
const Content = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Lore = preload("res://scripts/core/lore_catalog.gd")
const SAVE := "user://city_campaign_v1.json"
const MIN_DECK := 8
const MAX_COMPRESSOR_CHARGES := 2
const COMPRESSOR_PRICE := 18
const MAX_EQUIPPED_PARTS := 5
var model = Model.new()
var s: Dictionary = {}
var profile: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"cores": 0, "lore": [], "runs": 0, "wins": 0, "ascension": 0, "best_region": 0, "unlocks": ["balanced"]}

func start(gun: String, seed_value: int, difficulty: int = 0, loadout: String = "balanced") -> void:
	if not profile.unlocks.has(loadout): loadout = "balanced"
	s = {"version": 4, "seed": str(seed_value), "gun": gun, "difficulty": clampi(difficulty, 0, int(profile.ascension)), "loadout": loadout, "region": 0, "floor": 0, "node": 0, "phase": "map", "credits": Content.START_CREDITS, "pressure": 0, "slots": 0, "parts": [], "equipped_parts": [], "shop_seen_parts": [], "visited": [], "clears": 0, "compressor_charges": 1, "shop_revision": 0, "shop_part_bought": false, "shop_compressor_bought": false, "shop_refined": false, "offers": [], "resolved": false, "settled": false, "log": [], "message": "정점까지 35층. 다음 목적지를 선택하세요."}
	model.start(gun, seed_value)
	model.s.equipped_parts = []
	model.s.deck = Ammo.start_deck(gun) if loadout == "balanced" else Content.LOADOUTS[loadout].deck.duplicate()
	model.begin_encounter(int(s.compressor_charges))

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
			_sync_equipped_parts()
			model.s.floor = mini(5, int(s.region) + (1 if int(s.floor) >= 5 else 0))
			model.s.capacity_bonus = s.slots
			model.s.encounter_id = id
			# Each node has its own draw stream without resetting run statistics/history.
			model.s.seed = str(int(s.seed) + id * 101)
			model.begin_encounter(int(s.compressor_charges))
			if int(s.region) == 0 and int(s.floor) == 1: Content.prepare_opening_hand(model)
			var formation := Content.encounter_pack(selected, int(s.seed), str(s.gun), int(s.difficulty), int(s.pressure))
			model.s.enemies = formation.active
			model.s.reinforcements = formation.reserve
			model.assign_opening_lanes()
			model.s.encounter_total = int(formation.total)
			model.s.deployed = model.s.enemies.size()
			model.s.wave = 1
			model.s.encounter_name = selected.name
			s.pressure = 0
			s.phase = "combat"
		"shop":
			s.phase = "shop"
			s.shop_revision = 0
			s.shop_part_bought = false
			s.shop_compressor_bought = false
			s.shop_refined = false
			_stock_shop(selected)
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
	# The field press contributes a free encounter charge. Consume that temporary
	# charge before reducing the run-owned shop stock.
	s.compressor_charges = mini(int(s.compressor_charges), int(model.s.field_compression_left))
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
	return maxi(8, 12 + int(s.region) - maxi(0, used - 6) - maxi(0, elapsed - 6) - int(s.difficulty)) + (Content.ROUTE_REWARD_BONUS if str(node().get("route", "stairs")) == "duct" else 0)

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

func compressible_ids() -> Array:
	var result: Array = []
	if model.s.deck.size() <= MIN_DECK: return result
	for source in Ammo.COMPRESSIONS:
		if model.s.deck.count(source) >= 2: result.append(source)
	return result

func gate(choice: String, ammo_id: String = "") -> bool:
	if s.phase != "gate" or s.resolved: return false
	if choice == "slot" and int(s.slots) < 2: s.slots += 1
	elif choice == "credits": s.credits += 24
	elif choice == "compress" and compressible_ids().has(ammo_id):
		model.s.deck.erase(ammo_id)
		model.s.deck.erase(ammo_id)
		model.s.deck.append(Ammo.compressed_id(ammo_id))
	else: return false
	_log("gate", {"choice": choice, "ammo": ammo_id})
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
		if s.parts.has(offer.id): return false
		if not Ammo.PARTS.has(offer.id) or offer.id == "none": return false
	elif offer.type != "ammo" or not Ammo.AMMO.has(offer.id) or offer.id == "basic" or model.s.deck.size() >= 14: return false
	s.credits -= int(offer.price)
	offer.sold = true
	if offer.type == "part":
		s.parts.append(offer.id)
		if can_equip(str(offer.id)):
			s.equipped_parts.append(str(offer.id))
			_sync_equipped_parts()
			s.message = "%s 구매 · 빈 슬롯에 장착했습니다." % Ammo.PARTS[offer.id].name
		else:
			s.message = "%s 구매 · 장착 조건이 맞지 않아 보관함으로 이동했습니다." % Ammo.PARTS[offer.id].name
	else: model.s.deck.append(offer.id)
	_log("purchase", {"id": offer.id, "price": offer.price})
	return true

func buy_compressor_charge() -> bool:
	if s.phase != "shop" or bool(s.shop_compressor_bought) or int(s.compressor_charges) >= MAX_COMPRESSOR_CHARGES or int(s.credits) < COMPRESSOR_PRICE: return false
	s.credits -= COMPRESSOR_PRICE
	s.compressor_charges += 1
	s.shop_compressor_bought = true
	s.message = "압축 코어를 충전했습니다. 다음 전투에서도 남은 수량이 유지됩니다."
	_log("purchase_compressor", {"price": COMPRESSOR_PRICE, "charges": s.compressor_charges})
	return true

func reroll_cost() -> int:
	return mini(9, 3 + int(s.get("shop_revision", 0)) * 2)

func reroll() -> bool:
	var cost := reroll_cost()
	if s.phase != "shop" or int(s.credits) < cost: return false
	s.credits -= cost
	s.shop_revision += 1
	_stock_shop(node())
	# Persistent visit-level lock deliberately survives offer replacement.
	_log("reroll", {"revision": s.shop_revision, "cost": cost})
	return true

func _stock_shop(shop_node: Dictionary) -> void:
	s.offers = Content.offers(shop_node, int(s.seed), int(s.shop_revision), str(s.gun), s.parts, s.get("shop_seen_parts", []))
	for offer in s.offers:
		if offer.type == "part" and not s.shop_seen_parts.has(offer.id): s.shop_seen_parts.append(offer.id)

func shop_refine(id: String) -> bool:
	# Kept as a rejected legacy command so old automation cannot silently mutate
	# the new deck. Compression is a visible gate decision instead.
	return false

func equipped_parts() -> Array:
	return s.get("equipped_parts", []).duplicate()

func is_equipped(id: String) -> bool:
	return s.get("equipped_parts", []).has(id)

func can_equip(id: String) -> bool:
	if not s.parts.has(id) or is_equipped(id): return false
	var proposed: Array = equipped_parts()
	proposed.append(id)
	return Ammo.valid_part_set(str(s.gun), proposed)

func can_manage_parts() -> bool:
	return not str(s.get("phase", "")) in ["combat", "won", "lost"]

func equip(id: String) -> bool:
	if not can_manage_parts(): return false
	if id == "none":
		if s.equipped_parts.is_empty(): return false
		s.equipped_parts = []
	elif not s.parts.has(id): return false
	elif is_equipped(id): s.equipped_parts.erase(id)
	elif can_equip(id): s.equipped_parts.append(id)
	else: return false
	_sync_equipped_parts()
	_log("equip", {"id": id, "equipped": s.equipped_parts.duplicate()})
	return true

func replace_part(outgoing: String, incoming: String) -> bool:
	if not can_manage_parts() or not s.parts.has(incoming) or is_equipped(incoming): return false
	var index: int = s.equipped_parts.find(outgoing)
	if index < 0: return false
	var proposed: Array = s.equipped_parts.duplicate()
	proposed[index] = incoming
	if not Ammo.valid_part_set(str(s.gun), proposed): return false
	s.equipped_parts = proposed
	_sync_equipped_parts()
	_log("replace_part", {"outgoing": outgoing, "incoming": incoming, "equipped": proposed.duplicate()})
	return true

func _sync_equipped_parts() -> void:
	model.s.equipped_parts = s.get("equipped_parts", []).duplicate()
	model.s.part = "none"
	model.s.push_left = Ammo.push_budget(model.s)
	model.s.supply = model.supply_capacity()
	model.s.exchange_left = mini(int(model.s.exchange_left), Ammo.exchange_capacity(model.s))

func dismantle(id: String) -> bool:
	if not s.phase in ["shop", "supply"] or not s.parts.has(id) or is_equipped(id): return false
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
				if choice != "sell" or model.s.deck.size() <= MIN_DECK or not model.s.deck.has(ammo_id): return false
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
		_sync_equipped_parts()
		model.s.capacity_bonus = s.slots
		model.s.hand = model.s.deck.slice(0, 5)
		model.s.draw = model.s.deck.slice(5)
		model.s.discard = []
		model.s.magazine = []
		model.s.plan = []
		model.s.plan_load_order = []
		model.s.field_compression = {}
		model.s.field_compression_left = 0
		model.s.buff = {}
		# A newly equipped distance-control part changes this per-magazine limit.
		# Rebuild all encounter-scoped budgets together before serializing.
		model.s.push_left = Ammo.push_budget(model.s)
		model.s.supply = model.supply_capacity()
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
	var legacy_v1: bool = int(state.get("version", -1)) == 1
	if legacy_v1:
		state.compressor_charges = 1
		state.shop_compressor_bought = false
	if int(state.get("version", -1)) in [1, 2]:
		state.shop_seen_parts = []
	if int(state.get("version", -1)) in [1, 2, 3]:
		var legacy_part := str(data.combat.get("part", "none"))
		state.equipped_parts = [legacy_part] if state.get("parts", []).has(legacy_part) else []
		state.version = 4
	if not state.has("shop_refined"): state.shop_refined = false
	var progress: Dictionary = data.profile
	for key in ["version", "seed", "gun", "difficulty", "loadout", "region", "floor", "node", "phase", "credits", "pressure", "slots", "parts", "equipped_parts", "shop_seen_parts", "visited", "clears", "compressor_charges", "shop_revision", "shop_part_bought", "shop_compressor_bought", "offers", "resolved", "settled", "log", "message"]:
		if not state.has(key): return false
	if not _whole(state.version, 4, 4) or not state.seed is String or not state.seed.is_valid_int() or str(int(state.seed)) != state.seed: return false
	if not Ammo.GUNS.has(state.gun) or not Content.LOADOUTS.has(state.loadout): return false
	for key in ["region", "floor", "node", "difficulty", "credits", "pressure", "slots", "clears", "shop_revision"]:
		if not _whole(state[key], 0, 1000000): return false
	if state.region > 4 or state.floor > int(Content.info(int(state.region)).floors) or state.difficulty > 10 or not int(state.pressure) in [0, 2] or state.slots > 2: return false
	if not _whole(state.compressor_charges, 0, MAX_COMPRESSOR_CHARGES): return false
	if not state.phase in ["map", "combat", "reward", "gate", "shop", "supply", "event", "bypass", "won", "lost"]: return false
	for key in ["resolved", "settled", "shop_part_bought", "shop_compressor_bought", "shop_refined"]:
		if not state[key] is bool: return false
	for key in ["parts", "equipped_parts", "shop_seen_parts", "visited", "offers", "log"]:
		if not state[key] is Array: return false
	if not state.message is String: return false
	var unique := []
	for id in state.parts:
		if id == "none" or not Ammo.PARTS.has(id) or unique.has(id) or not Ammo.accepts_part(str(state.gun), str(id)): return false
		unique.append(id)
	if not Ammo.valid_part_set(str(state.gun), state.equipped_parts): return false
	for id in state.equipped_parts:
		if not state.parts.has(id): return false
	unique = []
	for id in state.shop_seen_parts:
		if id == "none" or not Ammo.PARTS.has(id) or unique.has(id) or not Ammo.accepts_part(str(state.gun), str(id)): return false
		unique.append(id)
	for offer in state.offers:
		if not offer is Dictionary: return false
		for key in ["id", "type", "price", "sold"]:
			if not offer.has(key): return false
		if not offer.sold is bool or not _whole(offer.price, 1, 100): return false
		if offer.type == "ammo":
			if not Ammo.AMMO.has(offer.id) or offer.id == "basic" or int(offer.price) != 12: return false
		elif offer.type != "part" or offer.id == "none" or not Ammo.PARTS.has(offer.id) or int(offer.price) != 30 or not Ammo.accepts_part(str(state.gun), str(offer.id)): return false
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
	if legacy_v1 and state.phase == "combat": state.compressor_charges = int(combat.s.field_compression_left)
	if combat.s.gun != state.gun or combat.s.get("capacity_bonus", 0) > state.slots: return false
	var combat_parts: Array = Ammo.equipped_parts(combat.s)
	var campaign_parts: Array = state.equipped_parts.duplicate()
	combat_parts.sort()
	campaign_parts.sort()
	if combat_parts != campaign_parts: return false
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
	if state.phase == "combat":
		var compression_bonus := Ammo.field_compression_bonus(combat.s)
		if int(combat.s.field_compression_left) < int(state.compressor_charges) or int(combat.s.field_compression_left) > int(state.compressor_charges) + compression_bonus: return false
	if state.phase in ["reward", "gate", "won"] and not combat.s.phase in ["reward", "won"]: return false
	if state.phase == "lost" and combat.s.phase != "lost": return false
	if (state.phase in ["won", "lost"]) != state.settled: return false
	s = state.duplicate(true)
	profile = progress.duplicate(true)
	model = combat
	return true

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
