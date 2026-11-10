extends "res://tests/weapon_magazine_probe.gd"
const Solver = preload("res://tests/weapon_magazine_solver.gd")
var checks := 0
var failures: Array = []
var audit: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("FAIL: " + message)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func conserved(m) -> void:
	var all: Array = m.s.hand + m.s.draw + m.s.discard + m.s.magazine
	var deck: Array = m.s.deck.duplicate()
	for i in range(Model.Reserve.generated_count(m.s)): deck.append(Model.Reserve.EMERGENCY_ROUND)
	all.sort(); deck.sort(); check(all == deck, "Owned ammo is conserved")
	var restored = Model.new()
	check(restored.restore_state(normalized(m.s)), "Weapon trial save restores")
	check(normalized(restored.s) == normalized(m.s), "Save retains exact magazine, target RNG and pressure")
	if m.s.phase == "ready" and not m.s.magazine.is_empty():
		var copy = Model.new(); copy.s = m.s.duplicate(true)
		copy.fire(); restored.fire()
		check(normalized(copy.s) == normalized(restored.s), "Restored next action is identical")

func forecast_action(m) -> void:
	var before := JSON.stringify(m.s)
	var prediction := Forecast.analyze(m.s, true)
	check(JSON.stringify(m.s) == before, "Forecast preserves live state and RNG")
	check(prediction.scope == "next_action", "Weapon trial forecast describes one decision")
	var copy = Model.new(); copy.s = Model.simulation_state(m.s)
	check(copy.fire(), "Actual fire available")
	var detail: Dictionary = copy.s.history.back().detail
	if m.s.gun != "scatter":
		check(prediction.enemies == copy.s.enemies and prediction.projectiles == copy.s.projectiles, "Exact enemies and projectiles")
		check(prediction.phase == copy.s.phase and prediction.remaining == copy.s.magazine, "Exact phase and remaining magazine")
		check(prediction.turns == copy.s.turns-m.s.turns, "Exact action and forced cooling cost")
		check(prediction.heat.forced_cost_max == detail.get("forced_cooling",{}).get("cost",0), "Overdrive cooling surcharge forecast")
	else:
		for i in range(prediction.enemies.size()):
			check(copy.s.enemies[i].hp >= prediction.enemies[i].hp_min and copy.s.enemies[i].hp <= prediction.enemies[i].hp_max, "Random actual HP lies in displayed range")
		check(detail.results.size() >= prediction.heat.fired_min and detail.results.size() <= prediction.heat.fired_max, "Random fired count range")
		check(copy.s.turns-m.s.turns >= prediction.heat.turns_min and copy.s.turns-m.s.turns <= prediction.heat.turns_max, "Random forced cooling turns range")
		if copy.s.phase == "lost": check(prediction.lost_probability > 0, "No hidden lethal random branch")

# Independent exhaustive paths (no cache/branch merging) for a single random
# decision, using actual shot and end-turn calculations for each target choice.
func enumerate_random(m, depth: int, probability: float, leaves: Array) -> void:
	if depth >= Model.MagazineTrial.pulse(m.s) or m.s.magazine.is_empty() or m.target_index() < 0 or (depth > 0 and int(m.s.heat) >= Content.heat_limit(m.s)):
		var detail: Dictionary = m.finish_fire()
		leaves.append({"p":probability,"state":m.s,"cost":detail.get("forced_cooling",{}).get("cost",0)})
		return
	var id: String = m.s.magazine[0]
	var targets: Array = m.scatter_targets(id)
	for target in targets:
		var copy = Model.new(); copy.s = Model.simulation_state(m.s)
		var recent: Array = copy._recent_part_sources()
		var rounds: Array = copy._recent_part_rounds()
		copy.s.magazine.pop_front()
		var source_id := Content.source_id(id)
		var context := {"first":recent.is_empty(),"last":copy.s.magazine.is_empty(),"last_attack":not copy.s.magazine.any(func(r): return Content.is_attack(str(r))),"previous_round":str(rounds.back()) if not rounds.is_empty() else "","fired_count":recent.size(),"sequence_count":Content.prior_kind_count(recent,id),"triad":recent.size()>=2 and recent[-1]!=recent[-2] and source_id!=recent[-1] and source_id!=recent[-2]}
		var shot: Dictionary = copy._shot(id,int(target),context)
		copy._discard_fired_round(id); copy.s.shots += 1
		copy._record("fire", {"results":[shot]})
		enumerate_random(copy,depth+1,probability/targets.size(),leaves)

func random_distribution(m) -> void:
	var prediction := Forecast.analyze(m.s,true)
	var leaves: Array = []
	var copy = Model.new(); copy.s = Model.simulation_state(m.s)
	enumerate_random(copy,0,1.0,leaves)
	var win := 0.0; var lost := 0.0; var forced := 0.0; var mass := 0.0
	for leaf in leaves:
		mass += float(leaf.p)
		if leaf.state.phase in ["won","reward"]: win += float(leaf.p)
		if leaf.state.phase == "lost": lost += float(leaf.p)
		if int(leaf.cost)>0: forced += float(leaf.p)
	check(is_equal_approx(mass,1.0), "All random target paths accounted for")
	check(is_equal_approx(win,float(prediction.win_probability)) and is_equal_approx(lost,float(prediction.lost_probability)), "Exact random win/loss probability")
	check(is_equal_approx(forced,float(prediction.heat.forced_probability)), "Exact random forced cooling probability")
	for i in range(m.s.enemies.size()):
		var hp_min := 999999; var hp_max := 0; var killed := 0.0
		for leaf in leaves:
			var hp := int(leaf.state.enemies[i].hp)
			hp_min = mini(hp_min,hp); hp_max = maxi(hp_max,hp)
			if hp<=0: killed += float(leaf.p)
		check(hp_min == prediction.enemies[i].hp_min and hp_max == prediction.enemies[i].hp_max and is_equal_approx(killed,float(prediction.enemies[i].kill_probability)), "Exact per-enemy random range and kill probability")

func identity_cases() -> void:
	# Purpose-built calculation boundaries; separate from earned play evidence.
	var m = weapon("heavy","breach")
	m.s.equipped_parts=[]; m.s.enemies=m.s.enemies.slice(0,1); m.s.enemies[0].hp=1000; m.s.enemies[0].distance=100; m.s.reinforcements=[]
	m.s.magazine=["basic","basic","basic","basic","basic"]; m.s.heat=11; m.s.sustained_version=0
	forecast_action(m); m.fire()
	var d: Dictionary = m.s.history.back().detail
	check(d.results.size()==4 and d.results[3].overdrive, "Reactor receives one extra round at pulse boundary")
	check(d.forced_cooling.get("cost",0)==4 and m.s.magazine==["basic"], "Reactor surcharge and retained ammo")
	m=weapon("heavy","breach"); m.s.equipped_parts=[]; m.s.enemies=m.s.enemies.slice(0,1); m.s.enemies[0].hp=1000; m.s.enemies[0].distance=100; m.s.reinforcements=[]
	m.s.magazine=["basic","cool","basic"]; m.s.heat=13; m.s.sustained_version=0
	forecast_action(m); m.fire(); d=m.s.history.back().detail
	check(d.results.size()==2 and d.results[1].overdrive and d.forced_cooling.is_empty() and m.s.magazine==["basic"], "Overdrive cooling round avoids forced cooling")
	m=weapon("amplifier","sweep"); m.s.heat=0; m.s.sustained_version=0; m.s.equipped_parts=[]; m.s.magazine=["basic","basic","basic","basic","basic"]
	for enemy in m.s.enemies: enemy.hp=1; enemy.def=0
	m.fire(); check(m.s.history.back().detail.results.size()==4 and m.s.phase in ["won","reward"], "Spike continues across more than two kills")
	m=weapon("amplifier","breach"); m.s.magazine=["basic","basic","basic"]; m.s.enemies[0].hp=1000; m.fire()
	check(m.s.history.back().detail.results.size()==1, "Spike stops on survivor")
	m=weapon("burst","breach"); m.s.equipped_parts=[]; m.s.sustained_version=0; m.s.magazine=["basic","basic","basic","basic"]; m.s.enemies[0].hp=1000; m.s.enemies[0].def=0; m.s.enemies[0].stance_def=0
	forecast_action(m); m.fire(); d=m.s.history.back().detail
	check(d.results.size()==3 and int(d.results[2].damage) == int(d.results[0].damage)+4, "Ratchet third primary hit bonus survives pulse")
	for invalid in [true, -1, 2, 1.5, "1"]:
		m=weapon("single","breach"); m.s.weapon_magazine_version=invalid
		check(not Model.new().restore_state(m.s), "Invalid weapon trial version rejected")
	m=weapon("burst","breach"); m.s.erase("magazine_trial_version")
	check(not Model.new().restore_state(m.s), "Weapon opt-in requires magazine rule")
	var campaign = preload("res://redesign/campaign.gd").new(); campaign.start("burst",731042)
	check(not Model.MagazineTrial.enabled(campaign.model.s) and not Model.MagazineTrial.weapons_enabled(campaign.model.s), "Production campaigns remain unchanged")

func run() -> void:
	var out := OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapon_magazine_20261031/"): quit(2); return
	identity_cases()
	for gun in GUNS:
		for role in ROLES:
			for seed_value in [0,17,1042,731042,900001,1200411]:
				var m = weapon(gun,role,seed_value)
				var start: Dictionary = m.s.duplicate(true)
				var min_margin := margin(m); var path: Array = []
				for step in range(48):
					if m.s.phase not in ["plan","ready"]: break
					conserved(m); min_margin=mini(min_margin,margin(m))
					if not m.s.magazine.is_empty(): forecast_action(m)
					var action := policy(m,true); path.append(action)
					check(command(m,action), "Legal comparison action")
				conserved(m)
				var alternate: Array = []
				if m.s.phase not in ["won","reward"]:
					alternate=Solver.solve(start)
					if alternate.is_empty(): alternate=Solver.solve(start,192,40)
					var replay=Model.new(); replay.s=Model.simulation_state(start)
					for action in alternate: check(command(replay,action), "Solver path replays legally")
					if not alternate.is_empty(): check(replay.s.phase in ["won","reward"], "Solver path reaches actual victory")
				audit.append({"gun":gun,"role":role,"seed":seed_value,"phase":m.s.phase,"turns":int(m.s.turns)-int(start.turns),"margin":min_margin,"path":path,"alternate":alternate})
	for role in ROLES:
		var m=weapon("scatter",role)
		random_distribution(m)
		m.fire(); if m.s.phase == "ready": random_distribution(m)
		m=weapon("scatter",role); m.s.heat=Content.heat_limit(m.s)-1; random_distribution(m)
	# A pulse boundary must not masquerade as the magazine's last attack.
	for suffix in ["cool","basic"]:
		var m=weapon("scatter","breach")
		m.s.equipped_parts=["afterburner"]; m.s.magazine=["basic","charge","basic",suffix]
		random_distribution(m); forecast_action(m)
		var trial:=Forecast.analyze(m.s,true)
		var legacy: Dictionary=m.s.duplicate(true)
		legacy.erase("weapon_magazine_version");legacy.erase("magazine_trial_version")
		Forecast.analyze(legacy,true)
		check(trial == Forecast.analyze(m.s,true),"Legacy full-salvo cache cannot replace trial action forecast")
	FileAccess.open(out.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audit":audit},"  "))
	print("WEAPON RULES COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)


