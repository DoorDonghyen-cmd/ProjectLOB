extends RefCounted
## Non-combat state and combat share one atomic save, including profile awards.
const Content = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const Encounters = preload("res://redesign/encounter_scenes.gd")
const Economy = preload("res://redesign/run_economy.gd")
const Lore = preload("res://redesign/city_story.gd")
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

func start(gun: String, seed_value: int, difficulty: int = 0, loadout: String = "balanced", map_version: int = Content.RouteMap.VERSION, outfit: String = "work", magazine_mode: bool = false) -> void:
	if gun in Model.WeaponRoles.KINDS:
		magazine_mode=true
		map_version=maxi(4,map_version)
	if not profile.unlocks.has(loadout): loadout = "balanced"
	if not Ammo.OUTFITS.has(outfit): outfit = "work"
	s = {"version": 4, "seed": str(seed_value), "gun": gun, "difficulty": clampi(difficulty, 0, int(profile.ascension)), "loadout": loadout, "region": 0, "floor": 0, "node": 0, "phase": "map", "credits": Content.START_CREDITS, "pressure": 0, "slots": 0, "parts": [], "equipped_parts": [], "shop_seen_parts": [], "shop_seen_ammo": [], "visited": [], "clears": 0, "compressor_charges": 1, "shop_revision": 0, "shop_part_bought": false, "shop_compressor_bought": false, "shop_refined": false, "shop_tuned": false, "offers": [], "resolved": false, "settled": false, "log": [], "message": "다음 목적지를 선택하세요."}
	s.build_version = 1
	s.combat_revision = Ammo.COMBAT_REVISION
	s.sustained_version = Ammo.Sustained.VERSION
	s.growth_version = Model.Engines.Growth.VERSION
	s.inventory_version = Model.Reserve.INVENTORY_VERSION
	s.emergency_version = Model.Reserve.EMERGENCY_VERSION
	s.gate_version = Gates.VERSION
	s.boss_loot_paid = false
	s.discovery_version = Content.Discovery.VERSION
	s.opening_reward_step = 0
	s.roster_version = Content.Residential.VERSION
	s.outfit = outfit
	s.bag_version = Ammo.BAG_VERSION
	s.bag_upgrades = 0
	model.start(gun, seed_value, false, outfit)
	model.s.combat_revision = int(s.combat_revision)
	model.s.sustained_version = int(s.sustained_version)
	model.s.growth_version = int(s.growth_version)
	model.s.gate_mods = {}
	s.map_version = map_version
	s.place_version = 1 if map_version >= 3 else 0
	s.encounter = {}
	s.supply_offers = []
	s.departure_step = 0
	s.restoration_done = false
	s.message = Lore.OBJECTIVE
	model.s.equipped_parts = []
	model.s.reserve_version = Model.Reserve.VERSION
	model.s.inventory_version = s.inventory_version
	model.s.emergency_version = s.emergency_version
	model.s.deck = Model.Reserve.start_deck()
	# The production new-run entry opts in; historical fixtures and loaded saves
	# retain their original rules. No migration of a partly loaded magazine.
	if magazine_mode:
		s.magazine_campaign_version = 1
		model.s.magazine_trial_version = Model.MagazineTrial.VERSION
		model.s.weapon_magazine_version = Model.MagazineTrial.WEAPON_VERSION
		# Deck-building revision (2026-11-01): leaner start deck and magazine-composition parts.
		s.magazine_build_version = Model.MagazineBuild.VERSION
		model.s.magazine_build_version = Model.MagazineBuild.VERSION
		model.s.deck = Model.MagazineBuild.start_deck(gun)
		s.fire_control_version = Model.FireHeatTrial.CAMPAIGN_VERSION
		Model.FireHeatTrial.activate_campaign(model.s)
		s.focus_build_version = Model.FocusBuild.VERSION
		model.s.focus_build_version = Model.FocusBuild.VERSION
		# Build engine trial (2026-11-08): 연타 공명기·타격 기록기 for new runs.
		model.s.build_engine_version = Model.BuildEngine.VERSION
		# Growth structure v2 (2026-11-10): special-first magazine, no forced first core, mastery.
		model.s.growth_structure_version = Model.GrowthV2.VERSION
		# Overheat cost (2026-11-11): forced cooling costs more enemy actions (overheat_cost.gd).
		model.s.overheat_version = Model.Overheat.VERSION
		# Normal-fight reward row "remove one round" (2026-11-11, reward_trim.gd).
		model.s.reward_trim_version = Model.RewardTrim.VERSION
		# Mixed round rewards (2026-11-11, reward_mix.gd): main / another attack / support.
		model.s.reward_mix_version = Model.RewardMix.VERSION
		# 교차 사격 (2026-11-11, mix_combo.gd): switching attack families grows per-hit damage.
		model.s.mix_combo_version = Model.MixCombo.VERSION
		# Salvaged rounds (2026-11-11, salvage.gd): the last enemy killed drops its answer round.
		model.s.salvage_version = Model.Salvage.VERSION
		# 연계탄·예약탄 rework (2026-11-12, ammo_revision.gd).
		model.s.ammo_revision_version = Model.AmmoRevision.VERSION
		# Launch balance (2026-11-12, launch_balance.gd): 리와인더 되감기 사격.
		model.s.launch_balance_version = Model.LaunchBalance.VERSION
	if magazine_mode and map_version>=4:
		s.combat_roles_version=Model.Roles.VERSION;model.s.combat_roles_version=Model.Roles.VERSION
		s.specialist_core_version=Model.Roles.SPECIALIST_VERSION;model.s.specialist_core_version=Model.Roles.SPECIALIST_VERSION
		s.economy_version=Economy.VERSION;s.intro_part_bought=false;s.gate_bag_used=false;s.gate_ammo_used=false
		s.balance_version=Model.Balance.VERSION;model.s.balance_version=Model.Balance.VERSION
		s.enemy_pattern_version=Model.Patterns.VERSION;model.s.enemy_pattern_version=Model.Patterns.VERSION
		s.boss_skills_version=Model.BossSkills.VERSION;model.s.boss_skills_version=Model.BossSkills.VERSION
	model.begin_encounter(int(s.compressor_charges))

func magazine_enabled() -> bool:
	return int(s.get("magazine_campaign_version",0)) == 1

func current_nodes() -> Array:
	var nodes := Content.nodes(int(s.region), int(s.seed), int(s.get("map_version", 1)))
	if int(s.region)==0 and int(s.get("roster_version",1)) >= Content.Rhythm.VERSION: nodes = Content.Rhythm.decorate(nodes)
	if int(s.region)==2 and int(s.get("roster_version",1))>=9:
		nodes=nodes.duplicate(true)
		for room in nodes:
			if room.kind=="boss": room.name="수로의 어미"
			elif room.get("elite",false): room.name="긴발 숨접이"
	if int(s.region)==3 and int(s.get("roster_version",1))>=10:
		nodes=nodes.duplicate(true)
		for room in nodes:
			if room.kind=="boss": room.name="백동 후작"
			elif room.get("elite",false): room.name="수석 시종"
	if int(s.region)==4 and int(s.get("roster_version",1))>=11:
		nodes=nodes.duplicate(true)
		for room in nodes:
			if room.kind=="boss": room.name="탑의 지배자"
			elif room.get("elite",false): room.name="친위대장"
	return nodes

func region_info(region: int = -1) -> Dictionary:
	return Content.info(int(s.region) if region < 0 else region, int(s.get("map_version", 1)))

func total_floors() -> int:
	var total := 0
	for region in range(5): total += int(region_info(region).floors)
	return total

func route_outlook(id: int) -> String:
	var pending: Array = [id]
	var seen: Array = []
	var facilities: Dictionary = {}
	var rooms := current_nodes()
	while not pending.is_empty():
		var next_id: int = int(pending.pop_front())
		if seen.has(next_id): continue
		seen.append(next_id)
		for room in rooms:
			if int(room.id) != next_id: continue
			if next_id != id and Content.room_kind(room) in ["shop", "workshop", "elite"]:
				var label := Content.kind_name(Content.room_kind(room))
				facilities[label] = true
			pending.append_array(room.next)
	var lines: PackedStringArray = []
	for label in facilities: lines.append(label)
	return "이후 도달 가능 · " + " / ".join(lines) if not lines.is_empty() else "이후 경로 · 관문으로 연결"

func departure_pending() -> bool:
	return s.get("phase", "") == "map" and int(s.get("region", -1)) == 0 and int(s.get("floor", -1)) == 0 and int(s.get("departure_step", 3)) < 3

func advance_departure(skip: bool = false) -> bool:
	if not departure_pending(): return false
	s.departure_step = 3 if skip else int(s.departure_step) + 1
	return true

func restoration_pending() -> bool:
	return s.get("phase", "") == "won" and not bool(s.get("restoration_done", true))

func restore_supply() -> bool:
	if not restoration_pending(): return false
	s.restoration_done = true
	_log("restore_supply", {})
	return true

func node() -> Dictionary:
	for item in current_nodes():
		if int(item.id) == int(s.node): return item
	return {}

func modern_places() -> bool:
	return int(s.get("place_version", 0)) == 1

func is_shortcut(id: int) -> bool:
	return node().get("shortcuts", []).has(id)

func choices() -> Array:
	var result: Array = []
	if s.phase != "map": return result
	var current := node()
	for item in current_nodes():
		if current.is_empty() and int(item.floor) != 1: continue
		if not current.is_empty() and not current.next.has(item.id): continue
		result.append(item)
	return result

func enter(id: int) -> bool:
	var selected: Dictionary = {}
	for item in choices():
		if int(item.id) == id: selected = item
	if selected.is_empty(): return false
	s.departure_step = 3
	s.floor = selected.floor
	s.node = id
	s.resolved = false
	s.boss_loot_paid = false
	s.encounter = {}
	s.supply_offers = []
	if selected.route == "duct": s.pressure = 2
	s.visited.append(id)
	_log("enter", {"id": id, "route": selected.route})
	match str(selected.kind):
		"combat", "boss":
			_begin_combat(selected)
		"shop":
			s.phase = "shop"
			s.shop_revision = 0
			s.shop_part_bought = false
			s.shop_compressor_bought = false
			s.shop_refined = false
			s.shop_tuned = false
			_stock_shop(selected)
		"supply":
			s.phase = "supply"
			if modern_places() and not selected.get("workshop", false): s.supply_offers = _supply_options()
			collect_lore(3 + int(s.region) * 4)
		"event": s.phase = "event"
		"bypass":
			s.phase = "bypass"
			collect_lore(1 + int(s.region) * 4)
			s.resolved = true
			s.message = "전투를 피해 이동했습니다. 남겨진 기록을 회수했습니다."
	return true

func _begin_combat(selected: Dictionary) -> void:
	if magazine_enabled():
		model.s.erase("approach_trial_version")
		model.s.erase("approach_trial_role")
	_sync_equipped_parts()
	model.s.floor = mini(5, int(s.region) + (1 if int(s.floor) >= 5 else 0))
	model.s.capacity_bonus = s.slots
	model.s.encounter_id = int(selected.id)
	# Each node has its own draw stream without resetting run statistics/history.
	model.s.seed = str(int(s.seed) + int(selected.id) * 101)
	model.begin_encounter(int(s.compressor_charges))
	if int(s.region) == 0 and int(s.floor) == 1: Content.prepare_opening_hand(model)
	var formation := Content.encounter_pack(selected, int(s.seed), str(s.gun), int(s.difficulty), int(s.pressure), int(s.get("roster_version", 1)), int(s.get("combat_revision",0)))
	model.s.enemies = formation.active
	model.s.reinforcements = formation.reserve
	model.assign_opening_lanes()
	model.s.encounter_total = int(formation.total)
	model.s.deployed = model.s.enemies.size()
	model.s.wave = 1
	model.s.encounter_name = selected.name
	s.pressure = 0
	s.phase = "combat"
	if magazine_enabled():
		# Keep the already played first-region approach profiles. Later regions
		# retain their authored patterns and distances, rather than scaling blindly.
		var approach = preload("res://redesign/combat_approach_trial.gd")
		for role in approach.NODES:
			if int(selected.id) == int(approach.NODES[role]): approach.apply_opening(model.s,role)
		# Deck-building revision v2: tougher enemies so a fight spans several magazines.
		Model.MagazineBuild.strengthen(model.s, "boss" if str(selected.get("kind", "")) == "boss" else "elite" if selected.get("elite", false) else "normal")
		# Launch balance (launch_balance.gd): 난도마다 적 체력 증가, 후반 구역일수록 크게. 난도 0은 그대로.
		Model.LaunchBalance.harden(model.s, int(s.difficulty), int(s.region))
		Model.Balance.approach(model.s,selected)
		Model.Patterns.prepare(model.s,selected)
		Model.BossSkills.prepare(model.s,selected)
		_load_opening_magazine()

func _load_opening_magazine() -> void:
	model.trial_load_magazine()

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
		if modern_places() and s.get("encounter", {}).get("stage", "") == "combat":
			var found := Encounters.outcome(str(node().event), str(s.encounter.choice), int(s.seed), int(s.node))
			s.credits += int(found.bonus)
			s.encounter.stage = "cleared"
			s.message = "현장 물자 확보 · +%dCr" % int(found.bonus)
		s.clears += 1
		# v2: the first win skips the growth-core pick and offers the main-round package.
		if Model.GrowthV2.enabled(model.s) and int(s.clears) == 1 and int(s.get("opening_reward_step", 2)) == 0: s.opening_reward_step = 1
		s.phase = "reward"
		_log("clear", {"node": s.node, "shots": model.s.shots, "turns": model.s.turns})
		if node().kind == "boss":
			collect_lore(4 + int(s.region) * 4)
			if modern_gates():
				s.credits += boss_credits()
				s.boss_loot_paid = true
				_log("boss_loot", {"credits":boss_credits()})

func modern_gates() -> bool:
	return int(s.get("gate_version",0)) == Gates.VERSION

func boss_credits() -> int:
	return 30 + 5 * int(s.region)

func boss_loot() -> bool:
	return modern_gates() and node().get("kind","")=="boss" and s.phase=="reward"

func gate_options() -> Array:
	var late_growth: bool = int(s.region)>=1 and (s.parts.any(func(id): return Model.Engines.IDS.has(id)) or not Ammo.innate_engine(model.s).is_empty())
	return Gates.options(model.s,late_growth) if modern_gates() and s.phase=="gate" and not s.resolved else []

func gate_ready() -> bool:
	return modern_gates() and s.phase == "gate" and s.resolved and int(s.region) < 4

func boss_ammo_options() -> Array:
	var result := Content.rewards(node(),int(s.seed),model.s.deck,s.equipped_parts,int(s.discovery_version))
	if Model.FocusBuild.enabled(s): result = Model.FocusBuild.rewards(model.s, node(), result).slice(0, 2)
	var pool := Content.shuffle(Content.ammo_pool(node(),int(s.discovery_version)),Content.rng(int(s.seed),int(s.node)+9713))
	var fitting := Content.Discovery.fitting(pool,s.equipped_parts,int(s.discovery_version))
	for id in fitting + pool:
		if not Ammo.COMPRESSIONS.has(id): continue
		var advanced := Ammo.compressed_id(id)
		if not result.has(advanced):
			result.append(advanced)
			break
	return result

func credit_reward() -> int:
	if node().get("elite", false): return 22 + int(s.region)
	var used := 0
	var elapsed := 0
	for i in range(model.s.history.size() - 1, -1, -1):
		var event: Dictionary = model.s.history[i]
		if event.action == "encounter": break
		if event.action == "fire":
			used += event.detail.results.size()
			elapsed += 1
		if event.action == "reload": elapsed += int(event.detail.cost)
	var base := 10 if int(s.get("map_version", 1)) >= 2 else 12
	return maxi(8, base + int(s.region) - maxi(0, used - 6) - maxi(0, elapsed - 6) - int(s.difficulty)) + (Content.ROUTE_REWARD_BONUS if str(node().get("route", "stairs")) == "duct" else 0)

func encounter_report_state() -> Dictionary:
	var state: Dictionary = model.s.duplicate(true)
	for i in range(state.history.size() - 1, -1, -1):
		if state.history[i].action == "encounter":
			state.history = state.history.slice(i)
			break
	return state

func reward(choice: String, remove_id: String = "") -> bool:
	if s.phase != "reward" or s.resolved: return false
	if boss_loot() and choice=="credits": return false
	var opening_core := engine_reward() and int(s.get("discovery_version",0)) >= 3
	var opening_ammo := first_ammo_reward()
	if not remove_id.is_empty() and choice != "trim" and not reward_options().has(choice): return false
	if choice == "credits": s.credits += credit_reward()
	elif choice == "trim":
		if not can_trim_reward() or not model.s.deck.has(remove_id): return false
		model.s.deck.erase(remove_id)
		s.message = Ammo.AMMO[remove_id].name + " 1장을 덱에서 뺐습니다."
	elif choice == "skip": pass
	elif part_rewards().has(choice):
		s.parts.append(choice)
		if can_equip(choice): s.equipped_parts.append(choice)
		_sync_equipped_parts()
	elif reward_options().has(choice) and can_acquire_ammo(choice, remove_id):
		if opening_ammo and Model.FocusBuild.enabled(s):
			if not remove_id.is_empty(): return false
			var replacement := Model.FocusBuild.replace_opening(model.s.deck, choice)
			if replacement.is_empty(): return false
			model.s.deck = replacement
			s.message = Model.FocusBuild.package_text(choice) + " · 기본탄 3장 교체"
		else: _acquire_ammo(choice, remove_id)
	else: return false
	if opening_core:
		s.opening_reward_step = 1
		s.message = "첫 특수탄을 선택하세요. 한 장을 추가하거나 보유 탄과 교체할 수 있습니다."
		_log("opening_core", {"choice":choice})
		return true
	if opening_ammo: s.opening_reward_step = 2
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

func reward_options() -> Array:
	if modern_places() and s.phase == "event": return s.get("encounter", {}).get("offers", []).duplicate()
	if modern_places() and s.phase == "supply" and not node().get("workshop", false):
		return s.supply_offers.duplicate() if not s.get("supply_offers", []).is_empty() else _supply_options()
	if engine_reward(): return []
	if first_ammo_reward(): return Model.FocusBuild.opening_options(model.s) if Model.FocusBuild.enabled(s) else Content.Acquisition.first_options(int(s.seed), str(s.gun), s.parts, str(s.loadout))
	if boss_loot(): return boss_ammo_options()
	if node().get("elite", false):
		# Elites: the upgraded salvage round next to the part choices (salvage.gd).
		var elite_card := salvage_card()
		return [elite_card.id] if not elite_card.is_empty() else []
	var options := Content.rewards(node(), int(s.seed), model.s.deck, s.equipped_parts if int(s.get("roster_version",1))>=3 else [], int(s.get("discovery_version",0)))
	if Model.FocusBuild.enabled(s): return _with_salvage(_mixed_rewards(Model.FocusBuild.rewards(model.s, node(), options)))
	return Content.Rhythm.rewards(node(), model.s.deck, options) if int(s.get("roster_version",1)) >= Content.Rhythm.VERSION else options

## Mixed round rewards (reward_mix.gd, new runs): one main card (upgrade if offered, else a copy),
## another attack round (the family held least), one support round; the old cards fill gaps.
func _mixed_rewards(options: Array) -> Array:
	if not Model.RewardMix.enabled(model.s): return options
	var main := Model.FocusBuild.main_round(model.s)
	if main.is_empty(): return options
	var family := Ammo.source_id(main)
	var improved := Model.FocusBuild.upgrade(main)
	var result: Array = [improved if options.has(improved) else main]
	var other := Model.RewardMix.other_attack(Content.ammo_pool(node(), int(s.get("discovery_version", 0))), model.s.deck, family, int(s.seed) + int(node().id))
	if not other.is_empty() and int(s.get("discovery_version", 0)) >= 2:
		other = Ammo.Variants.offer(other, Ammo.AMMO, Content.rng(int(s.seed), int(node().id) + 5300), node())
	if not other.is_empty() and not result.has(other): result.append(other)
	for id in options:
		if Model.FocusBuild.supports_for(model.s, family).has(Ammo.source_id(str(id))) and not result.has(id):
			result.append(id)
			break
	for id in options:
		if result.size() >= 3: break
		if not result.has(id): result.append(id)
	return result.slice(0, 3)

## The salvage card of the fight just won (salvage.gd): {id, kind, name}, or {}.
func salvage_card() -> Dictionary:
	if s.phase != "reward" or s.resolved or engine_reward() or first_ammo_reward(): return {}
	return Model.Salvage.card(model.s, bool(node().get("elite", false)), str(node().get("kind", "")) == "boss")

## Normal fights: the salvage card takes the "another attack" slot, so there are still three
## cards, the main card (and its upgrade) stays, and the player still chooses.
func _with_salvage(options: Array) -> Array:
	var salvage := salvage_card()
	if salvage.is_empty() or options.has(salvage.id): return options
	var result := options.duplicate()
	var slot := 1
	if result.size() <= slot: result.append(salvage.id)
	else: result[slot] = salvage.id
	return result

func _supply_options() -> Array:
	var found := Content.rewards(node(), int(s.seed), model.s.deck, s.equipped_parts, int(s.discovery_version))
	if Model.FocusBuild.enabled(s): return _mixed_rewards(Model.FocusBuild.rewards(model.s, node(), found))
	var eligible: Array = []
	for id in model.s.deck:
		if Ammo.COMPRESSIONS.has(id) and Ammo.grade(id) <= 0 and not eligible.has(id): eligible.append(id)
	var single: Array = eligible.filter(func(id): return model.s.deck.count(id) == 1)
	if not single.is_empty(): eligible = single
	var special: Array = eligible.filter(func(id): return Ammo.source_id(id) != "basic")
	if not special.is_empty(): eligible = special
	if not eligible.is_empty():
		var random := Content.rng(int(s.seed), int(s.node) + 7193)
		var matching: String = eligible[random.randi_range(0, eligible.size() - 1)]
		found.erase(matching)
		found.push_front(matching)
	return found.slice(0, 3)

func encounter_scene() -> Dictionary:
	return Encounters.scene(str(node().get("event", "siphon")))

func _resolve_encounter(choice: String, value: String, replacement: String) -> bool:
	var stage: String = s.get("encounter", {}).get("stage", "")
	if choice == "skip" and stage in ["", "loot"]:
		s.encounter = {"choice":"skip", "stage":"finished", "offers":[]}
		s.resolved = true
		s.message = "흔적을 뒤로하고 길을 이어갑니다."
	elif choice == "encounter" and stage.is_empty():
		var option := Encounters.choice(str(node().event), value)
		if option.is_empty() or int(s.credits) < int(option.cost): return false
		var result := Encounters.outcome(str(node().event), value, int(s.seed), int(s.node))
		s.credits -= int(option.cost)
		s.encounter = {"choice":value, "stage":"finished", "offers":[]}
		s.message = result.text
		collect_lore(2 + int(s.region) * 4)
		match str(result.type):
			"combat": s.encounter.stage = "ambush"
			"ammo":
				s.encounter.stage = "loot"
				s.encounter.offers = Content.rewards(node(), int(s.seed), model.s.deck, s.equipped_parts, int(s.discovery_version))
				s.credits += int(result.amount)
			"credits": s.credits += int(result.amount)
		s.resolved = s.encounter.stage == "finished"
	elif choice == "fight" and stage == "ambush":
		var battle: Dictionary = node().duplicate(true)
		battle.kind = "combat"
		battle.name = str(encounter_scene().title)
		battle.route = "stairs"
		s.encounter.stage = "combat"
		_begin_combat(battle)
	elif choice == "ammo" and stage == "loot" and reward_options().has(value) and can_acquire_ammo(value, replacement):
		_acquire_ammo(value, replacement)
		s.encounter.stage = "finished"
		s.resolved = true
	else: return false
	_log("encounter", {"choice":choice,"value":value,"stage":s.encounter.stage})
	return true

func engine_reward() -> bool:
	return s.get("phase", "") == "reward" and int(s.get("build_version",0))==1 and int(s.clears)==1 and (int(s.get("discovery_version",0)) < 3 or int(s.get("opening_reward_step",2)) == 0) and not Model.GrowthV2.enabled(model.s)

func first_ammo_reward() -> bool:
	return s.get("phase", "") == "reward" and int(s.get("discovery_version",0)) >= 3 and int(s.clears)==1 and int(s.get("opening_reward_step",2)) == 1

func replaceable_basics() -> Array:
	return Content.Acquisition.replaceable(model.s.deck) if int(s.get("discovery_version",0)) >= 3 else []

func replaceable_ammo() -> Array:
	return Content.Acquisition.replaceable_owned(model.s.deck) if Model.Reserve.inventory_enabled(s) else replaceable_basics()

func workshop_ammo_options() -> Array:
	if not Model.Reserve.inventory_enabled(s) or s.phase != "supply" or s.resolved or not node().get("workshop", false): return []
	var offered := Content.rewards(node(), int(s.seed), model.s.deck, s.equipped_parts, int(s.discovery_version))
	if Model.FocusBuild.enabled(s): return Model.FocusBuild.rewards(model.s, node(), offered)
	var families: Array = offered.map(func(id): return Ammo.source_id(str(id)))
	var random := Content.rng(int(s.seed), int(s.node) + 8711)
	for id in Content.shuffle(Content.ammo_pool(node(), int(s.discovery_version)), random):
		if not families.has(Ammo.source_id(str(id))):
			offered.append(Ammo.Variants.offer(id, Ammo.AMMO, random, node()))
			break
	return offered

func can_acquire_ammo(id: String, replace_id: String = "") -> bool:
	if not Ammo.AMMO.has(id) or Ammo.is_temporary(id): return false
	if replace_id.is_empty(): return model.s.deck.size() < model.deck_limit()
	return replaceable_ammo().has(replace_id) and replace_id != id

func _acquire_ammo(id: String, replace_id: String) -> void:
	if replace_id.is_empty(): model.s.deck.append(id)
	else: model.s.deck[model.s.deck.find(replace_id)] = id
	s.message = "%s 1장 %s" % [Ammo.AMMO[id].name, "획득 · %s 1장 교체" % Ammo.AMMO[replace_id].name if not replace_id.is_empty() else "추가"]

func _offer_owned() -> Array:
	return s.parts + ["field_press", "reserve"] if magazine_enabled() else s.parts

func part_rewards() -> Array:
	if engine_reward(): return Ammo.PARTS.keys().filter(func(id): return Model.Engines.IDS.has(id) and not s.parts.has(id))
	if first_ammo_reward(): return []
	if not node().get("elite", false): return []
	var options: Array = []
	for offer in Content.offers(node(), int(s.seed), 0, str(s.gun), _offer_owned(), s.get("shop_seen_parts", []), [], [], int(s.get("discovery_version",0)), int(s.get("focus_build_version",0)),model.s):
		if offer.type == "part" and not s.parts.has(offer.id): options.append(offer.id)
	return options.slice(0, 2)

## Normal-fight reward row "remove one round" (reward_trim.gd): new runs, normal fights only,
## never below the deck minimum.
func can_trim_reward() -> bool:
	if not Model.RewardTrim.enabled(model.s) or s.phase != "reward" or s.resolved: return false
	if engine_reward() or first_ammo_reward() or boss_loot() or node().get("elite", false) or node().kind == "boss": return false
	return model.s.deck.size() > minimum_deck()

func trim_reward_options() -> Array:
	return Model.RewardTrim.options(model.s.deck) if can_trim_reward() else []

func can_equip_reward(id: String) -> bool:
	var proposed: Array = equipped_parts()
	proposed.append(id)
	return Ammo.valid_part_set(str(s.gun), proposed, model.s)

func compressible_ids() -> Array:
	var result: Array = []
	if model.s.deck.size() <= minimum_deck(): return result
	for source in Ammo.COMPRESSIONS:
		if model.s.deck.count(source) >= 2: result.append(source)
	return result

func minimum_deck() -> int:
	return Model.Roles.minimum(model.s)

func bag_growth_limit() -> int:
	if Model.Roles.enabled(model.s):return mini(Model.Roles.BAG_STEPS,1+int(s.region)+(1 if s.phase=="gate" else 0))
	# Gates invest toward the next region; workbenches use the current region's cap.
	return mini(Ammo.MAX_BAG_CAPACITY, 6 + int(s.region) + (1 if s.phase == "gate" else 0))

func can_grow_bag() -> bool:
	if Model.Roles.enabled(model.s):return int(s.bag_upgrades)<bag_growth_limit()
	return int(s.get("bag_version", 0)) == Ammo.BAG_VERSION and Ammo.hand_capacity(model.s) < bag_growth_limit()

func bag_growth_hint() -> String:
	if Model.Roles.enabled(model.s):
		if int(s.bag_upgrades)>=Model.Roles.BAG_STEPS:return "가방 확장 완료 · 탄약 상한 %d발"%model.deck_limit()
		return "탄약 상한 %d → %d발"%[model.deck_limit(),model.deck_limit()+2] if can_grow_bag() else "현재 구역 한도 · 다음 구역에서 확장"
	if int(s.get("bag_version", 0)) != Ammo.BAG_VERSION: return "새 등반에서 가방 성장 가능"
	if Ammo.hand_capacity(model.s) >= Ammo.MAX_BAG_CAPACITY: return "최대 10장 도달"
	if not can_grow_bag(): return "현재 구역 한도 · 다음 구역에서 확장"
	if magazine_enabled(): return "탄약 상한 %d → %d발" % [model.deck_limit(), mini(40, model.deck_limit()+2)]
	if Model.Reserve.inventory_enabled(s): return "손패 +1 · 휴대 상한 %d → %d장 · 탄약 지급 없음" % [model.deck_limit(), mini(40, model.deck_limit()+2)]
	return "구역 한도 %d장 · 최종 10장" % bag_growth_limit()

func _grow_bag() -> void:
	s.bag_upgrades += 1
	model.s.bag_upgrades = s.bag_upgrades
	s.message = "가방 확장 · 다음 교전부터 손패 %d장" % Ammo.hand_capacity(model.s)
	if magazine_enabled():
		s.message = "가방 확장 · 탄약 상한 %d발" % model.deck_limit()
		return
	if Model.Reserve.inventory_enabled(s): s.message += " · 휴대 상한 %d장 · 탄약 지급 없음" % model.deck_limit()

func gate(choice: String, ammo_id: String = "", sources: Array = []) -> bool:
	if s.phase != "gate" or s.resolved: return false
	if modern_gates():
		if choice=="skip": pass
		elif not gate_options().has(choice): return false
		elif choice=="mastery":
			if not Model.GrowthV2.add_mastery(model.s): return false
		elif choice=="drive":
			if not Gates.grow_drive(model.s): return false
		elif choice=="mastery_support":
			if not Model.GrowthV2.add_mastery(model.s, true): return false
		elif choice=="production":
			if not Gates.can_produce(model.s,ammo_id,sources): return false
			for id in sources: model.s.deck.erase(id)
			for i in range(3): model.s.deck.append(ammo_id)
		else:
			model.s.gate_mods[choice] = Gates.level(model.s,choice)+1
		_log("gate_upgrade", {"choice":choice,"ammo":ammo_id,"sources":sources.duplicate()})
	elif choice == "slot" and int(s.slots) < 2: s.slots += 1
	elif choice == "bag" and can_grow_bag(): _grow_bag()
	elif choice == "credits": s.credits += 24
	elif choice == "compress" and compressible_ids().has(ammo_id):
		model.s.deck.erase(ammo_id)
		model.s.deck.erase(ammo_id)
		model.s.deck.append(Ammo.compressed_id(ammo_id))
	else: return false
	_log("gate", {"choice": choice, "ammo": ammo_id})
	s.resolved = true
	if modern_gates():
		s.message = "개조를 건너뛰었습니다. 재정비를 마치면 출발하세요." if choice == "skip" else "관문 개조를 적용했습니다. 재정비를 마치면 출발하세요."
		if choice == "growth": s.message = Gates.summary(choice,model.s)+" · 다음 전투부터 조건 달성 후 추가 성장"
		return true
	_advance_region()
	return true

## Drive tune (2026-11-10, growth structure v2): the shop's former compressor slot raises the
## gun's built-in drive by 2 levels for credits (12, 18, 24 ... Cr), up to 12. With the gate's
## 구동 강화 (+4) it replaces the automatic per-win growth. Credits were left unspent (110+)
## in every v2 climb, so this is also their main late use.
func drive_level() -> int:
	return int(model.s.get("engine", {}).get("levels", {}).get(Ammo.innate_engine(model.s), 0))

func drive_tune_price() -> int:
	return 12 + 6 * (drive_level() / 2)

func can_tune_drive() -> bool:
	return s.phase == "shop" and Model.GrowthV2.enabled(model.s) and not Ammo.innate_engine(model.s).is_empty() and model.s.has("engine") and drive_level() < Model.Engines.Growth.V2_LIMIT and int(s.credits) >= drive_tune_price()

func tune_drive() -> bool:
	if not can_tune_drive(): return false
	var price := drive_tune_price()
	s.credits -= price
	model.s.engine.levels[Ammo.innate_engine(model.s)] = mini(Model.Engines.Growth.V2_LIMIT, drive_level() + 2)
	_log("drive_tune", {"price": price, "level": drive_level()})
	return true

func can_buy_gate_bag() -> bool:
	return Economy.enabled(s) and gate_ready() and not s.gate_bag_used and not s.get("gate_ammo_used",false) and can_grow_bag() and int(s.credits)>=Economy.BAG_PRICE

func buy_gate_bag() -> bool:
	if not can_buy_gate_bag():return false
	s.credits-=Economy.BAG_PRICE
	_grow_bag()
	s.gate_bag_used=true
	s.message="가방 확장 · 탄약 상한 +2발 · %dCr 사용"%Economy.BAG_PRICE
	_log("gate_bag",{"price":Economy.BAG_PRICE,"limit":model.deck_limit()})
	return true

func gate_copy_options() -> Array:
	if not Economy.enabled(s) or not gate_ready():return []
	var result: Array=[]
	for id in model.s.deck:
		if Ammo.source_id(id)!="basic" and not Ammo.is_temporary(id) and not result.has(id):result.append(id)
	return result

func gate_copy_price(id: String) -> int:
	return 24 if Ammo.grade(id)==1 else 12

func can_buy_gate_copy(id: String) -> bool:
	return gate_copy_options().has(id) and not s.gate_bag_used and not s.get("gate_ammo_used",false) and int(s.credits)>=gate_copy_price(id) and can_acquire_ammo(id)

func buy_gate_copy(id: String) -> bool:
	if not can_buy_gate_copy(id):return false
	var price:=gate_copy_price(id)
	s.credits-=price
	_acquire_ammo(id,"")
	s.gate_ammo_used=true
	s.message="%s 1장 복제 · %dCr 사용"%[Ammo.AMMO[id].name,price]
	_log("gate_copy",{"id":id,"price":price})
	return true

func depart_gate() -> bool:
	if not gate_ready(): return false
	_log("gate_depart", {"region": int(s.region) + 1})
	_advance_region()
	return true

func _advance_region() -> void:
	if Economy.enabled(s):s.gate_bag_used=false;s.gate_ammo_used=false
	s.region += 1
	s.floor = 0
	s.node = 0
	s.phase = "map"
	s.resolved = true
	profile.best_region = maxi(int(profile.best_region), int(s.region))
	s.message = "다음 목적지를 선택하세요."

func buy(index: int, replace_id: String = "") -> bool:
	if s.phase != "shop" or index < 0 or index >= s.offers.size(): return false
	var offer: Dictionary = s.offers[index]
	if offer.sold or int(s.credits) < int(offer.price): return false
	if offer.type == "part":
		if not replace_id.is_empty(): return false
		if s.parts.has(offer.id): return false
		if not Ammo.PARTS.has(offer.id) or offer.id == "none": return false
	elif offer.type != "ammo" or offer.id == "basic" or not can_acquire_ammo(str(offer.id), replace_id): return false
	s.credits -= int(offer.price)
	offer.sold = true
	if Economy.enabled(s) and offer.get("intro_discount",false):s.intro_part_bought=true
	if offer.type == "part":
		s.parts.append(offer.id)
		if can_equip(str(offer.id)):
			s.equipped_parts.append(str(offer.id))
			_sync_equipped_parts()
			s.message = "%s 구매 · 빈 슬롯에 장착했습니다." % Ammo.PARTS[offer.id].name
		else:
			s.message = "%s 구매 · 장착 조건이 맞지 않아 보관함으로 이동했습니다." % Ammo.PARTS[offer.id].name
	else: _acquire_ammo(str(offer.id), replace_id)
	_log("purchase", {"id": offer.id, "price": offer.price, "removed":replace_id})
	return true

func buy_compressor_charge() -> bool:
	if magazine_enabled(): return false
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
	s.offers = Content.offers(shop_node, int(s.seed), int(s.shop_revision), str(s.gun), _offer_owned(), s.get("shop_seen_parts", []), s.get("shop_seen_ammo", []), s.equipped_parts if int(s.get("roster_version",1))>=3 else [], int(s.get("discovery_version",0)), int(s.get("focus_build_version",0)),model.s)
	if Model.FocusBuild.enabled(s):
		var main := Model.FocusBuild.main_round(model.s)
		if Model.Roles.builds(model.s):main=preload("res://redesign/build_choices.gd").shop_ammo(model.s,shop_node,int(s.shop_revision))
		if not main.is_empty():
			s.offers[0].id = main
			s.offers[0].price = 24 if Ammo.grade(main) == 1 else 12
	Economy.stock(s,model.s,s.offers)
	for offer in s.offers:
		if offer.type == "ammo" and not s.get("shop_seen_ammo", []).has(offer.id):
			if not s.has("shop_seen_ammo"): s.shop_seen_ammo = []
			s.shop_seen_ammo.append(offer.id)
		if offer.type == "part" and not s.shop_seen_parts.has(offer.id): s.shop_seen_parts.append(offer.id)

func shop_refine(id: String) -> bool:
	# Kept as a rejected legacy command so old automation cannot silently mutate
	# the new deck. Use the priced shop_compress or the gate decision instead.
	return false

const COMPRESSION_PRICE := 18
const TUNE_PRICE := 12

func tune(index: int, mode: String) -> bool:
	# Modern permanent growth is one exact pair -> one enhanced round.
	# Keep the old paid-shop command for legacy saves, and all already-owned IDs.
	if modern_places(): return false
	if s.phase != "shop" or int(s.get("discovery_version",0)) < 2 or bool(s.get("shop_tuned",false)) or int(s.credits) < TUNE_PRICE: return false
	if index < 0 or index >= model.s.deck.size(): return false
	var source := str(model.s.deck[index])
	var result := Ammo.Variants.tuned(source, Ammo.AMMO, mode)
	if result.is_empty(): return false
	model.s.deck[index] = result
	s.credits -= TUNE_PRICE
	s.shop_tuned = true
	s.message = "%s 1장 · %s. 같은 탄의 다른 사본은 유지됩니다." % [Ammo.AMMO[source].name, "화력 +1" if mode == "power" else "발열 −1"]
	_log("tune", {"source":source,"id":result,"price":TUNE_PRICE})
	return true


func shop_compress(id: String) -> bool:
	if modern_places(): return false
	if s.phase != "shop" or bool(s.get("shop_refined", false)) or int(s.credits) < COMPRESSION_PRICE or not compressible_ids().has(id): return false
	model.s.deck.erase(id)
	model.s.deck.erase(id)
	model.s.deck.append(Ammo.compressed_id(id))
	s.credits -= COMPRESSION_PRICE
	s.shop_refined = true
	s.message = "%s 일반 2장 → 고급 1장 · 덱에 영구 적용했습니다." % Ammo.AMMO[id].name
	_log("shop_compress", {"id": id, "price": COMPRESSION_PRICE})
	return true

func equipped_parts() -> Array:
	return s.get("equipped_parts", []).duplicate()

func is_equipped(id: String) -> bool:
	return s.get("equipped_parts", []).has(id)

func can_equip(id: String) -> bool:
	if not s.parts.has(id) or is_equipped(id): return false
	var proposed: Array = equipped_parts()
	proposed.append(id)
	return Ammo.valid_part_set(str(s.gun), proposed, model.s)

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
	if not Ammo.valid_part_set(str(s.gun), proposed, model.s): return false
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
	Model.BuildEngine.forget(model.s, id)
	if model.s.has("tag_growth"): model.s.tag_growth.erase(id)
	_log("dismantle", {"id": id})
	return true

func resolve(choice: String, ammo_id: String = "", replace_id: String = "") -> bool:
	if s.resolved or not s.phase in ["supply", "event"]: return false
	var current := node()
	if modern_places() and s.phase == "event": return _resolve_encounter(choice, ammo_id, replace_id)
	if not replace_id.is_empty() and not (choice == "refit" and current.get("workshop", false) or choice == "ammo" and not current.get("workshop", false)): return false
	if choice == "skip": s.message = "현재 구성을 유지했습니다."
	elif current.get("workshop", false):
		if choice == "refit" and not replace_id.is_empty() and workshop_ammo_options().has(ammo_id) and can_acquire_ammo(ammo_id, replace_id):
			_acquire_ammo(ammo_id, replace_id)
			s.message += " · 이번 무료 정비 사용"
		elif choice == "bag" and can_grow_bag():
			_grow_bag()
		elif choice == "compress" and compressible_ids().has(ammo_id):
			model.s.deck.erase(ammo_id)
			model.s.deck.erase(ammo_id)
			model.s.deck.append(Ammo.compressed_id(ammo_id))
			s.message = Ammo.AMMO[ammo_id].name + " 2발 → 강화 탄환 1발 · 이번 정비를 사용했습니다."
		elif choice == "remove" and model.s.deck.size() > minimum_deck() and model.s.deck.has(ammo_id):
			model.s.deck.erase(ammo_id)
			s.message = Ammo.AMMO[ammo_id].name + " 1장을 덱에서 제거했습니다. 이번 정비를 사용했습니다."
		elif choice == "core" and not modern_places() and int(s.compressor_charges) < MAX_COMPRESSOR_CHARGES:
			s.compressor_charges += 1
			s.message = "압축 코어 +1. 이번 정비를 사용했습니다."
		else: return false
	elif s.phase == "supply":
		if choice == "ammo" and reward_options().has(ammo_id) and can_acquire_ammo(ammo_id, replace_id):
			_acquire_ammo(ammo_id, replace_id)
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
				elif choice == "ammo" and can_acquire_ammo(str(reward_options()[0]), replace_id):
					var id: String = reward_options()[0]
					_acquire_ammo(id, replace_id)
				else: return false
			"salvage":
				if choice != "sell" or model.s.deck.size() <= minimum_deck() or not model.s.deck.has(ammo_id): return false
				model.s.deck.erase(ammo_id)
				s.credits += 16
				s.message = Ammo.AMMO[ammo_id].name + " 1장 분해 · +16Cr."
	s.resolved = true
	_log("resolve", {"choice": choice, "ammo": ammo_id, "removed":replace_id})
	return true

func leave() -> bool:
	if not s.phase in ["shop", "supply", "event", "bypass"]: return false
	if s.phase in ["supply", "event"] and not s.resolved: return false
	s.phase = "map"
	return true

func collect_lore(id: int) -> void:
	if not profile.lore.any(func(known): return int(known) == id):
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
	for region in range(int(s.region)): count += int(region_info(region).floors)
	return count

func _log(action: String, detail: Dictionary) -> void:
	s.log.append({"action": action, "region": s.region, "floor": s.floor, "detail": detail})

func normalize_for_save() -> void:
	# Outside combat, the next room owns the deck anew. Reconcile its zones after
	# rewards/services so every serialized nested combat state conserves ownership.
	# Exhaustion is validated against empty usable zones. Preserve that terminal
	# snapshot instead of repopulating ammunition while saving the defeat.
	var preserve_loss: bool = s.phase == "lost" and (model.s.get("loss_reason", "") == "ammo" or Model.Reserve.emergency_enabled(model.s))
	if s.phase != "combat" and not preserve_loss:
		if Model.Reserve.emergency_enabled(model.s): model.s.emergency_uses = 0
		_sync_equipped_parts()
		model.s.capacity_bonus = s.slots
		model.s.hand = model.s.deck.slice(0, Ammo.hand_capacity(model.s))
		model.s.draw = model.s.deck.slice(Ammo.hand_capacity(model.s))
		model.s.discard = []
		model.s.magazine = []
		if Model.MagazineBuild.enabled(model.s): model.s.magazine_loaded = []
		model.s.plan = []
		model.s.plan_load_order = []
		model.s.prepared = []
		model.s.field_compression = {}
		model.s.field_compression_left = 0
		model.s.buff = {}
		# A newly equipped distance-control part changes this per-magazine limit.
		# Rebuild all encounter-scoped budgets together before serializing.
		model.s.push_left = Ammo.push_budget(model.s)
		model.s.supply = model.supply_capacity()
func save(path: String = SAVE) -> Error:
	normalize_for_save()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string("{\"campaign\":" + JSON.stringify(s) + ",\"combat\":" + model.serialized_state() + ",\"profile\":" + JSON.stringify(profile) + "}")
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
	Ammo.Merge.campaign(state)
	if not Economy.valid(state):return false
	if not Ammo.valid_bag_state(state): return false
	if state.has("outfit") and (not state.outfit is String or not Ammo.OUTFITS.has(state.outfit)): return false
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
	if not state.has("shop_tuned"): state.shop_tuned = false
	if not _whole(state.get("gate_version",0),0,Gates.VERSION): return false
	if int(state.get("gate_version",0))==Gates.VERSION and not state.get("boss_loot_paid") is bool: return false
	if state.has("build_version") and not _whole(state.build_version,1,1): return false
	if not _whole(state.get("combat_revision",0),0,Ammo.COMBAT_REVISION): return false
	if not _whole(state.get("sustained_version",0),0,Ammo.Sustained.VERSION): return false
	if not _whole(state.get("growth_version",0),0,Model.Engines.Growth.VERSION): return false
	if not _whole(state.get("balance_version",0),0,Model.Balance.VERSION): return false
	if not _whole(state.get("enemy_pattern_version",0),0,Model.Patterns.VERSION): return false
	if not _whole(state.get("boss_skills_version",0),0,Model.BossSkills.VERSION): return false
	if Model.Patterns.enabled(state) and (int(state.get("map_version",0))<4 or int(state.get("magazine_campaign_version",0))!=1): return false
	if not _whole(state.get("magazine_campaign_version",0),0,1): return false
	if not _whole(state.get("fire_control_version",0),0,Model.FireHeatTrial.CAMPAIGN_VERSION): return false
	if not _whole(state.get("focus_build_version",0),0,Model.FocusBuild.VERSION): return false
	if Model.FocusBuild.enabled(state) and int(state.get("fire_control_version",0)) != Model.FireHeatTrial.CAMPAIGN_VERSION: return false
	if int(state.get("fire_control_version",0))>0 and int(state.get("magazine_campaign_version",0))!=1:return false
	if not _whole(state.get("magazine_build_version",0),0,Model.MagazineBuild.VERSION): return false
	if int(state.get("magazine_build_version",0))>0 and int(state.get("magazine_campaign_version",0))!=1: return false
	if not _whole(state.get("inventory_version",0),0,Model.Reserve.INVENTORY_VERSION): return false
	if not _whole(state.get("emergency_version",0),0,Model.Reserve.EMERGENCY_VERSION): return false
	if not state.has("discovery_version"): state.discovery_version = 0
	if not _whole(state.discovery_version, 0, Content.Discovery.VERSION): return false
	if not state.has("opening_reward_step"):
		if int(state.discovery_version) >= 3: return false
		state.opening_reward_step = 2
	if not _whole(state.opening_reward_step,0,2): return false
	if int(state.discovery_version) >= 3 and int(state.opening_reward_step) == 1 and (state.get("phase","") != "reward" or int(state.get("clears",0)) != 1 or state.get("resolved",true)): return false
	if not state.has("roster_version"): state.roster_version = 1
	if not _whole(state.roster_version, 1, Content.Residential.VERSION): return false
	if not state.has("map_version"): state.map_version = 1
	if not _whole(state.map_version, 1, Content.RouteMap.VERSION): return false
	if not state.has("place_version"): state.place_version = 0
	if not _whole(state.place_version, 0, 1) or (int(state.map_version) >= 3) != (int(state.place_version) == 1): return false
	if not state.has("encounter"): state.encounter = {}
	if not state.has("supply_offers"): state.supply_offers = []
	if not state.encounter is Dictionary or not state.supply_offers is Array: return false
	# Existing saves keep their place; completed older runs do not gain a pending ending.
	if not state.has("departure_step"): state.departure_step = 3
	if not state.has("restoration_done"): state.restoration_done = state.get("phase", "") == "won"
	if not _whole(state.departure_step, 0, 3) or not state.restoration_done is bool: return false
	if state.restoration_done and state.get("phase", "") != "won": return false
	if not state.has("shop_seen_ammo"): state.shop_seen_ammo = []
	if not state.shop_seen_ammo is Array: return false
	var ammo_seen: Array = []
	for id in state.shop_seen_ammo:
		if not id is String or not Ammo.AMMO.has(id) or Ammo.is_temporary(id) or id == "basic" or ammo_seen.has(id): return false
		ammo_seen.append(id)
	var progress: Dictionary = data.profile
	for key in ["version", "seed", "gun", "difficulty", "loadout", "region", "floor", "node", "phase", "credits", "pressure", "slots", "parts", "equipped_parts", "shop_seen_parts", "visited", "clears", "compressor_charges", "shop_revision", "shop_part_bought", "shop_compressor_bought", "offers", "resolved", "settled", "log", "message"]:
		if not state.has(key): return false
	if not _whole(state.version, 4, 4) or not state.seed is String or not state.seed.is_valid_int() or str(int(state.seed)) != state.seed: return false
	if not Ammo.GUNS.has(state.gun) or not Content.LOADOUTS.has(state.loadout): return false
	for key in ["region", "floor", "node", "difficulty", "credits", "pressure", "slots", "clears", "shop_revision"]:
		if not _whole(state[key], 0, 1000000): return false
	if state.region > 4 or state.floor > int(Content.info(int(state.region), int(state.map_version)).floors) or state.difficulty > 10 or not int(state.pressure) in [0, 2] or state.slots > 2: return false
	if not _whole(state.compressor_charges, 0, MAX_COMPRESSOR_CHARGES): return false
	if not state.phase in ["map", "combat", "reward", "gate", "shop", "supply", "event", "bypass", "won", "lost"]: return false
	for key in ["resolved", "settled", "shop_part_bought", "shop_compressor_bought", "shop_refined", "shop_tuned"]:
		if not state[key] is bool: return false
	for key in ["parts", "equipped_parts", "shop_seen_parts", "visited", "offers", "log"]:
		if not state[key] is Array: return false
	if not state.message is String: return false
	var unique := []
	for id in state.parts:
		if id == "none" or not Ammo.PARTS.has(id) or unique.has(id) or not Ammo.accepts_part(str(state.gun), str(id)): return false
		unique.append(id)
	if not Ammo.valid_part_set(str(state.gun), state.equipped_parts, data.get("combat", {})): return false
	for id in state.equipped_parts:
		if not state.parts.has(id): return false
	unique = []
	for id in state.shop_seen_parts:
		if id == "none" or not Ammo.PARTS.has(id) or unique.has(id) or not Ammo.accepts_part(str(state.gun), str(id)): return false
		unique.append(id)
	for offer_index in range(state.offers.size()):
		var offer: Variant=state.offers[offer_index]
		if not offer is Dictionary: return false
		for key in ["id", "type", "price", "sold"]:
			if not offer.has(key): return false
		if not offer.sold is bool or not _whole(offer.price, 1, 100): return false
		if offer.type == "ammo":
			if offer.has("intro_discount"):return false
			if not Ammo.AMMO.has(offer.id) or offer.id == "basic" or Ammo.is_temporary(str(offer.id)): return false
			# Preserve already stocked legacy offers, including the old 12Cr high-output round.
			if int(offer.price) != 12 and not (Ammo.grade(str(offer.id)) == 1 and int(offer.price) == 24): return false
		elif offer.type != "part" or offer.id == "none" or not Ammo.PARTS.has(offer.id) or not Economy.valid_price(state,offer,offer_index) or not Ammo.accepts_part(str(state.gun), str(offer.id)): return false
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
	if int(state.get("magazine_campaign_version",0))==1 and not Model.MagazineTrial.weapons_enabled(combat.s): return false
	if state.get("magazine_build_version",0) != combat.s.get("magazine_build_version",0): return false
	if state.get("fire_control_version",0) != combat.s.get("fire_control_version",0): return false
	if state.get("focus_build_version",0) != combat.s.get("focus_build_version",0): return false
	if state.get("combat_roles_version",0)!=combat.s.get("combat_roles_version",0):return false
	if state.get("balance_version",0)!=combat.s.get("balance_version",0):return false
	if state.get("enemy_pattern_version",0)!=combat.s.get("enemy_pattern_version",0):return false
	if state.get("boss_skills_version",0)!=combat.s.get("boss_skills_version",0):return false
	if not _whole(state.get("specialist_core_version",0),0,Model.Roles.SPECIALIST_VERSION) or state.get("specialist_core_version",0)!=combat.s.get("specialist_core_version",0):return false
	if Model.Roles.enabled(combat.s) and (int(state.map_version)<4 or combat.s.deck.size()<Model.Roles.minimum(combat.s)):return false
	if state.get("combat_revision",0) != combat.s.get("combat_revision",0): return false
	if state.get("sustained_version",0) != combat.s.get("sustained_version",0): return false
	if state.get("growth_version",0) != combat.s.get("growth_version",0): return false
	if Gates.level(combat.s,"growth") > mini(Model.Engines.Growth.MAX_UPGRADES,int(state.region)): return false
	if state.get("inventory_version",0) != combat.s.get("inventory_version",0): return false
	if state.get("emergency_version",0) != combat.s.get("emergency_version",0): return false
	if int(state.get("gate_version",0))==0 and not combat.s.get("gate_mods",{}).is_empty(): return false
	if int(state.get("gate_version",0))==Gates.VERSION and not combat.s.has("gate_mods"): return false
	if state.get("outfit", "") != combat.s.get("outfit", ""): return false
	for key in ["bag_version", "bag_upgrades"]:
		if state.get(key, 0) != combat.s.get(key, 0): return false
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
		if not _whole(id, 101, 41004) or seen_nodes.has(int(id)): return false
		var region := int(id) / 10000
		if region > int(state.region): return false
		var found: Dictionary = {}
		for item in Content.nodes(region, int(state.seed), int(state.map_version)):
			if int(item.id) == int(id): found = item
		if found.is_empty(): return false
		if previous.is_empty():
			if found.region != 0 or found.floor != 1: return false
		elif found.region == previous.region:
			if int(found.floor) <= int(previous.floor): return false
			if not previous.next.has(found.id): return false
		elif int(found.region) != int(previous.region) + 1 or found.floor != 1 or previous.kind != "boss": return false
		previous = found
		seen_nodes.append(int(id))
	if state.floor == 0:
		if state.node != 0 or state.phase != "map": return false
		if int(state.region) > 0 and (previous.is_empty() or int(previous.region) != int(state.region) - 1 or previous.kind != "boss"): return false
	elif current.is_empty() or current.floor != state.floor: return false
	elif previous.is_empty() or int(previous.id) != int(state.node): return false
	if not _valid_places(state, current): return false
	var event_combat: bool = int(state.place_version) == 1 and current.get("kind", "") == "event" and state.encounter.get("stage", "") in ["combat", "cleared"]
	if state.phase in ["combat", "reward", "gate", "won", "lost"] and not current.get("kind", "") in ["combat", "boss"] and not (event_combat and state.phase in ["combat", "reward", "lost"]): return false
	if state.phase in ["shop", "supply", "event", "bypass"] and current.get("kind", "") != state.phase: return false
	if state.phase == "gate" and (current.kind != "boss" or int(state.region) == 4): return false
	if state.phase == "gate" and state.resolved and int(state.get("gate_version",0)) != Gates.VERSION: return false
	if state.phase == "won" and (int(state.region) != 4 or int(state.floor) != int(Content.info(4, int(state.map_version)).floors)): return false
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

static func _valid_places(state: Dictionary, current: Dictionary) -> bool:
	if state.supply_offers.size() > 3: return false
	for id in state.supply_offers:
		if not id is String or not Ammo.AMMO.has(id) or Ammo.is_temporary(id): return false
	if state.encounter.is_empty():
		return not (current.get("kind", "") == "event" and int(state.place_version) == 1 and state.phase in ["combat", "reward", "lost"])
	if int(state.place_version) != 1 or current.get("kind", "") != "event": return false
	var event: Dictionary = state.encounter
	if not event.get("choice") is String or not event.get("stage") is String or not event.get("offers") is Array: return false
	if event.offers.size() > 2: return false
	for id in event.offers:
		if not id is String or not Ammo.AMMO.has(id) or Ammo.is_temporary(id): return false
	if event.choice == "skip": return event.stage == "finished" and state.resolved and state.phase in ["event", "map"] and event.offers.is_empty()
	var result := Encounters.outcome(str(current.event), event.choice, int(state.seed), int(state.node))
	if result.is_empty(): return false
	if result.type == "combat":
		if not event.offers.is_empty(): return false
		match str(event.stage):
			"ambush": return state.phase == "event" and not state.resolved
			"combat": return state.phase in ["combat", "lost"] and not state.resolved
			"cleared": return (state.phase == "reward" and not state.resolved) or (state.phase == "map" and state.resolved)
		return false
	if event.stage == "loot": return result.type == "ammo" and not event.offers.is_empty() and state.phase == "event" and not state.resolved
	return event.stage == "finished" and state.resolved and state.phase in ["event", "map"]
