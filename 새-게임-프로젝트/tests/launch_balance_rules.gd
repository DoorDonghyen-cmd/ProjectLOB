extends SceneTree
## Launch balance (2026-11-12, redesign/launch_balance.gd). 리와인더 되감기 사격: the first attack
## round fired right after the rewind (manual cool that reversed the magazine) deals ×3.
## New runs only; earlier saves, other guns and the second round of the volley are unchanged.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Launch = preload("res://redesign/launch_balance.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

## A real first fight of a new run, with sturdy enemies and a known magazine.
func fight(gun: String, rounds: Array, launch := true):
	var c = Campaign.new()
	c.start(gun, 17, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(c.advance_departure(true) and c.enter(int(c.choices()[0].id)), "first fight opens " + gun)
	c.sync_combat()
	var m = c.model
	if not launch: m.s.erase("launch_balance_version")
	for e in m.s.enemies:
		e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0
	m.s.magazine = rounds.duplicate()
	if m.s.has("weapon_role_trial"):
		m.s.weapon_role_trial.mark = -1
		m.s.weapon_role_trial.rewound = false
	m.s.heat = 6
	return m

## HP of every enemy (opening line, then reserve) in a late first-region fight at a 난도.
func first_hp(gun: String, difficulty: int, launch: bool) -> Array:
	var c = Campaign.new()
	c.profile.ascension = 10
	c.start(gun, 17, difficulty, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	if not launch: c.model.s.erase("launch_balance_version")
	check(int(c.s.difficulty) == difficulty and c.advance_departure(true) and c.enter(int(c.choices()[0].id)), "fight opens at 난도 %d" % difficulty)
	var result: Array = []
	for e in c.model.s.enemies: result.append(int(e.hp))
	for e in c.model.s.reinforcements: result.append(int(e.hp))
	for e in c.model.s.enemies + c.model.s.reinforcements:
		check(int(e.max_hp) >= int(e.hp), "max HP covers HP")
	return result

func volley(m, count: int) -> Array:
	m.s.fire_heat_trial.rounds = count
	check(m.fire(), "volley fires")
	return m.s.history.back().detail.get("results", [])

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	# New runs carry the flag; saves keep it; unknown versions are rejected.
	var fresh = Campaign.new()
	fresh.start("rewinder", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(Launch.enabled(fresh.model.s), "new runs: launch balance on")
	var saved: Dictionary = JSON.parse_string(fresh.model.serialized_state())
	check(Model.new().restore_state(saved.duplicate(true)), "flag survives save")
	saved.launch_balance_version = Launch.VERSION + 1
	check(not Model.new().restore_state(saved), "unknown launch balance version rejected")
	# 리와인더 carries 돌파 in these runs; earlier saves keep 열압; other guns keep their drive.
	check(Content.innate_engine(fresh.model.s) == "siege_drive" and Content.gun_engine("rewinder", false) == "thermal_drive", "리와인더: 돌파 in new runs, 열압 before")
	var earlier: Dictionary = fresh.model.s.duplicate(true)
	earlier.erase("launch_balance_version")
	check(Content.innate_engine(earlier) == "thermal_drive", "a save without the flag keeps 열압")
	for gun in Content.GUNS:
		if str(gun) != "rewinder": check(Content.gun_engine(str(gun), true) == str(Content.GUN_ENGINES[gun]), "drive unchanged: " + str(gun))
	# 되감기 사격.
	var m = fight("rewinder", ["basic_p2", "basic_p2", "pierce_p2"])
	check(m.cool_magazine() and bool(m.s.history.back().detail.get("reversed", false)), "manual cool reverses the magazine")
	check(m.s.magazine == ["pierce_p2", "basic_p2", "basic_p2"], "the last round is now first (%s)" % [m.s.magazine])
	check(Launch.rewind_ready(m.s), "rewind shot is ready after the reversing cool")
	var shots := volley(m, 2)
	# The same two rounds from a cold magazine in the same run rules, without a rewind.
	var same = fight("rewinder", ["pierce_p2", "basic_p2", "basic_p2"])
	same.s.heat = 0
	var same_shots := volley(same, 2)
	var plain = fight("rewinder", ["basic_p2", "basic_p2", "pierce_p2"], false)
	check(plain.cool_magazine() and plain.s.magazine == ["pierce_p2", "basic_p2", "basic_p2"], "earlier saves still rewind")
	var plain_shots := volley(plain, 2)
	print("REWIND ", int(shots[0].damage), " vs ", int(same_shots[0].damage), " / second ", int(shots[1].damage), " vs ", int(same_shots[1].damage), " / earlier save ", int(plain_shots[0].damage))
	check(int(shots[0].math.get("weapon_factor", 1)) == Launch.REWIND_FACTOR and int(shots[0].damage) == Launch.REWIND_FACTOR * int(same_shots[0].damage), "first attack round after the rewind hits ×3")
	check(int(shots[1].math.get("weapon_factor", 1)) == 1 and int(shots[1].damage) == int(same_shots[1].damage), "the second round of the volley is not multiplied")
	check(int(plain_shots[0].math.get("weapon_factor", 1)) == 1, "earlier saves: no rewind shot")
	check(not Launch.rewind_ready(m.s), "a volley uses the rewind shot up")
	# A support round first: the bonus waits for the first attack round of that volley.
	var support = fight("rewinder", ["basic_p2", "charge", "pierce_p2"])
	check(support.cool_magazine() and support.s.magazine == ["pierce_p2", "charge", "basic_p2"], "reversal with a support round")
	var lead = fight("rewinder", ["basic_p2", "pierce_p2", "charge"])
	check(lead.cool_magazine() and lead.s.magazine == ["charge", "pierce_p2", "basic_p2"], "support round first after the rewind")
	var lead_shots := volley(lead, 2)
	check(int(lead_shots[0].math.get("weapon_factor", 1)) == 1 and int(lead_shots[1].math.get("weapon_factor", 1)) == Launch.REWIND_FACTOR, "support first: the attack round behind it takes ×3")
	# No rewind, no bonus: firing without cooling, and a cool that cannot reverse (already rewound).
	var cold = fight("rewinder", ["basic_p2", "basic_p2", "pierce_p2"])
	check(int(volley(cold, 1)[0].math.get("weapon_factor", 1)) == 1, "no cool: no bonus")
	var twice = fight("rewinder", ["basic_p2", "basic_p2", "pierce_p2", "basic_p2"])
	twice.cool_magazine(); volley(twice, 1)
	twice.s.heat = 6
	check(twice.cool_magazine() and not bool(twice.s.history.back().detail.get("reversed", false)), "second cool of the magazine does not reverse")
	check(int(volley(twice, 1)[0].math.get("weapon_factor", 1)) == 1, "second cool: no bonus")
	# Other guns are untouched.
	var rivet = fight("single", ["basic_p2", "basic_p2", "pierce_p2"])
	check(rivet.cool_magazine() and int(volley(rivet, 1)[0].math.get("weapon_factor", 1)) == 1, "리벳: cooling gives no ×3")
	# Forecast agrees with the real shot.
	var seen = fight("rewinder", ["basic_p2", "basic_p2", "pierce_p2"])
	seen.cool_magazine()
	seen.s.fire_heat_trial.rounds = 1
	var forecast: Dictionary = preload("res://redesign/forecast.gd").analyze(seen.s, true)
	var real := volley(seen, 1)
	check(not forecast.get("shots", []).is_empty() and int(forecast.shots[0].get("damage", -1)) == int(real[0].damage), "forecast shows the ×3 shot (%s vs %s)" % [forecast.get("shots", [{}])[0].get("damage"), real[0].damage])
	# 난도 · 적 체력: more HP per level, more in later regions, on the opening line and the reserve;
	# 난도 0 and earlier saves unchanged.
	var base_hp: Array = first_hp("single", 0, true)
	var hard_hp: Array = first_hp("single", 5, true)
	var old_hp: Array = first_hp("single", 5, false)
	print("HARDEN ", base_hp, " -> ", hard_hp, " / without flag ", old_hp)
	check(Launch.harden_percent(0, 4) == 100 and Launch.harden_percent(5, 0) == 116 and Launch.harden_percent(5, 3) == 140 and Launch.harden_percent(10, 0) == 132 and Launch.harden_percent(10, 4) == 196 and Launch.harden_percent(99, 9) == 196, "난도 percent by region: 난도 5 +16%~, 난도 10 +32%~+96%, capped")
	check(base_hp.size() == hard_hp.size() and not base_hp.is_empty(), "same formation at any 난도")
	var scaled := true
	for i in range(mini(base_hp.size(), hard_hp.size())):
		if int(hard_hp[i]) != ceili(int(base_hp[i]) * 1.16): scaled = false
	check(scaled, "난도 5, first region: every enemy, reserve included, has +16% HP (rounded up)")
	check(old_hp == base_hp, "runs without the flag keep enemy HP at any 난도")
	print("LAUNCH BALANCE RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
