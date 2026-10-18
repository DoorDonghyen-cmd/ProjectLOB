extends SceneTree
const Ammo = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
func conserved(m) -> void:
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))), "save validates ownership " + str(m.s.gun) + " / " + str(m.s.phase))
	if not restored.s.is_empty(): check(JSON.stringify(restored.s.hand) == JSON.stringify(m.s.hand), "restore hand unchanged")
func durable(m) -> void:
	m.s.enemies = [Data._enemy(["wall", 9999, 0, 0, 30])]
	m.s.encounter_total = 1
	m.s.deployed = 1
	m.assign_opening_lanes()
func fixture(ids: Array, gun: String = "single"):
	var m = Model.new()
	m.start(gun, 718)
	m.s.deck = ids.duplicate()
	while m.s.deck.size() < 10: m.s.deck.append("pierce")
	m.begin_encounter()
	m.s.hand = ids.duplicate()
	m.s.draw = m.s.deck.duplicate()
	for id in ids: m.s.draw.erase(id)
	durable(m)
	return m
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_cycle/rules"):
		quit(1)
		return
	var opening_counts: Array = []
	for gun in Ammo.GUNS:
		for outfit in Ammo.OUTFITS:
			for seed_value in range(24):
				var m = Model.new()
				m.start(gun, seed_value, false, outfit)
				check(m.s.deck.size() == 10 and m.s.deck.count("basic") == 3, "three finite basics in ten-card starter")
				check(m.s.supply == 0 and m.available("basic") == m.s.hand.count("basic"), "no separate supply")
				check(m.s.hand.size() == Ammo.hand_capacity(m.s), "basics count toward outfit bag")
				if not opening_counts.has(m.s.hand.count("basic")): opening_counts.append(m.s.hand.count("basic"))
				durable(m)
				for cycle in range(3):
					conserved(m)
					var next_hand: Array = m.s.draw.duplicate()
					var before_turns: int = m.s.turns
					check(m.reload_magazine(), "unloaded reload available")
					check(m.s.turns - before_turns == m.base_reload_cost(), "reload pays enemy time")
					check(m.s.hand.slice(0, mini(next_hand.size(), m.s.hand.size())) == next_hand.slice(0, m.s.hand.size()), "remaining draw consumed before reshuffle")
					for id in m.s.hand.duplicate():
						if m.can_load(id): m.load_round(id)
					if not m.s.plan.is_empty():
						var before := JSON.stringify(m.s)
						var prediction := Forecast.analyze(m.s, true, true)
						check(JSON.stringify(m.s) == before, "forecast does not consume cards or RNG")
						check(m.confirm() and m.fire(), "mixed-card volley")
						if gun != "scatter": check(prediction.enemies == m.s.enemies, "forecast and actual enemies match")
						conserved(m)
						if m.s.phase == "ready": m.reload_magazine()
	check(opening_counts.size() >= 3, "basic count varies between seeded hands")
	var m = fixture(["basic", "basic", "charge", "pierce", "push"])
	check(m.load_round("basic") and m.load_round("basic") and not m.load_round("basic"), "one card permits exactly one bullet")
	check(m.undo() and m.available("basic") == 1, "undo returns one basic")
	check(m.exchange("basic") and m.s.discard.count("basic") == 1, "unplanned basic exchanges")
	conserved(m)
	check(m.confirm() and m.fire() and m.s.discard.count("basic") == 2, "fired basic goes to discard")
	conserved(m)
	m = fixture(["basic", "basic", "basic", "pierce", "charge"])
	m.load_round("basic")
	m.load_round("charge")
	check(m.s.plan == ["charge", "basic"], "last loaded fires first")
	var deck: Array = m.s.deck.duplicate()
	check(m.reload_magazine() and m.s.plan.is_empty(), "reload abandons editable stack")
	check(m.s.deck == deck, "reload creates no new cards")
	conserved(m)
	m = fixture(["pierce", "pierce", "basic", "charge", "push"])
	check(m.field_compress("pierce"), "temporary compression legal")
	check(m.reload_magazine() and m.s.field_compression.is_empty(), "plan reload restores temporary originals")
	check(m.s.field_compression_left == 0, "reload does not refund spent compression charge")
	conserved(m)
	m = fixture(["prepare", "basic", "basic", "pierce", "charge"])
	for id in ["basic", "prepare"]: m.load_round(id)
	check(m.confirm() and m.fire() and m.s.prepared.has("basic"), "basic can be reserved without duplication")
	conserved(m)
	m.reload_magazine()
	check(m.s.hand.has("basic"), "reservation moves owned basic into next hand")
	conserved(m)
	m = fixture(["charge_hot", "basic", "basic", "pierce", "charge"])
	m.s.heat = 10
	m.load_round("basic")
	m.load_round("charge_hot")
	m.confirm()
	m.fire()
	check(m.s.phase == "plan" and m.s.reloads == 1 and m.s.heat == 0, "overheat interrupts and refills")
	check(not Forecast.reload_now(m.s).required, "post-shot forecast does not charge a second reload after overheat")
	check(Forecast.reload_now(m.s, true).required, "explicit plan reload forecast is available")
	conserved(m)
	var invalid: Dictionary = m.s.duplicate(true)
	invalid.supply = 1
	check(not Model.new().restore_state(invalid), "reject fabricated supply in card mode")
	invalid = m.s.duplicate(true)
	invalid.hand.append("basic")
	check(not Model.new().restore_state(invalid), "reject duplicated basic card")
	invalid = m.s.duplicate(true)
	invalid.ammo_cycle = 2
	check(not Model.new().restore_state(invalid), "reject unknown cycle version")
	for loadout in Data.LOADOUTS:
		var c = Campaign.new()
		if not c.profile.unlocks.has(loadout): c.profile.unlocks.append(loadout)
		c.start("single", 71, 0, loadout)
		check(c.model.s.deck.size() == 10 and c.model.s.deck.count("basic") == 3, "alternate loadout has finite basics")
		check(c.save("user://campaign.json") == OK, "campaign save")
		check(Campaign.new().restore("user://campaign.json"), "campaign roundtrip")
		var room: Dictionary = c.current_nodes().filter(func(n): return n.get("workshop", false))[0]
		c.s.phase = "supply"
		c.s.node = room.id
		c.s.floor = room.floor
		check(c.resolve("remove", "basic") and c.model.s.deck.count("basic") == 2, "workshop removes one basic permanently for this run")
	m = Model.new()
	m.start("single", 71, true)
	check(m.s.deck.size() == 5 and m.s.hand.count("basic") == 3, "training has actual basic cards")
	conserved(m)
	m = Model.new()
	m.start("single", 718)
	m.s.erase("ammo_cycle")
	m.s.deck = Ammo.START_DECK.duplicate()
	m.begin_encounter()
	check(m.available("basic") == m.capacity() and not m.s.deck.has("basic"), "legacy separate supply retained")
	check(not m.reload_magazine(), "legacy plan rule retained")
	m.load_round("basic")
	m.confirm()
	conserved(m)
	check(m.fire(), "legacy fire")
	conserved(m)
	m.reload_magazine()
	check(m.s.supply == m.capacity() and not m.s.discard.has("basic"), "legacy reload retained")
	for part in ["supply", "reserve"]:
		m = fixture(["basic", "pierce", "charge", "precise", "push"])
		m.s.equipped_parts = [part]
		m.begin_encounter()
		check(m.s.supply == 0 and m.s.deck.count("basic") == 1, "part creates no basic supply")
		check(m.capacity() == (5 if part == "supply" else 4), "expansion affects only magazine")
		check(m.s.exchange_left == (2 if part == "reserve" else 1), "reserve retains exchange identity")
	for gun in Ammo.GUNS:
		for seed_value in [71, 731042]:
			var c = Campaign.new()
			c.start(gun, seed_value)
			c.enter(int(c.choices()[0].id))
			var solver = preload("res://tests/city_combat_solver.gd").new()
			solver.candidate_limit = 300
			var path: Array = solver.solve(c.model, 3, 8)
			check(not path.is_empty(), "opening combat reachable " + gun + " seed " + str(seed_value))
			for command in path:
				match command.action:
					"load": check(c.model.load_round(command.id), "opening replay load")
					"confirm": check(c.model.confirm(), "opening replay confirm")
					"fire": check(c.model.fire(), "opening replay fire")
					"reload": check(c.model.reload_magazine(), "opening replay reload")
			check(c.model.s.phase in ["reward", "won"], "opening actual replay clears")
			conserved(c.model)
	print("AMMO CYCLE RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
