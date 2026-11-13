extends "res://tests/economy_roles_climb.gd"
## Growth structure v2 comparison (2026-11-10). The same full climb as economy_roles_climb
## (real combats by the solver, real rewards/shops/gates), with v2 on (QA_GROWTH=1, default)
## or off (QA_GROWTH=0, the flag removed at the start). With v2 the gate policy takes
## mastery whenever it is offered; otherwise the inherited gate policy applies.
var growth := true
## QA_GROWTH=late: start without v2, take the first growth core the old way, then switch
## v2 on (isolates the cost of removing the first-fight core).
var late := false

## Tag runs (QA_TAGS=1): the inherited equip order lists current-scheme parts only, so tag runs
## get their own preference per build, the same kind of hand order; 복제 기판 goes last.
const TAG_PREFERRED := {
	"fire": ["tag_fire_add", "tag_burning_mult", "tag_fire_burn", "tag_low_mult", "tag_fire_deck", "compression_sink", "radiator"],
	"control": ["third_striker", "resonator", "tag_multi_add", "tag_control_mult", "duplex", "tally"],
	"direct": ["third_striker", "opening", "tag_single_add", "tag_single_mult", "afterburner", "tag_low_mult"]}

## QA_NAIVE=fire (2026-11-11, user: "아무탄이나 막 발사해도 클리어 되는 문제"): combat without
## judgement. Every turn fire the full pulse; reload when the magazine is empty; emergency
## resupply when offered. No ejecting, no cooling by choice. Shop/gate choices stay as before.
## QA_NAIVE=careful (2026-11-12 launch pass): the play the user described — "과열 경고를 보고
## 확실히 발수를 제한하게 돼". Fire the largest volley that does not overheat; when even one
## round would overheat, cool first; swap an empty magazine. No ejecting, no look-ahead beyond
## the next volley. The solver minimises the player's own actions, so it walks into forced
## cooling (over half of its enemy actions); this policy is the one that pays for cooling.
func careful_path(c) -> Array:
	var m = solver.clone(c.model)
	var path: Array = []
	for step in range(400):
		if m.s.phase != "ready": break
		var item: Dictionary = {}
		if m.can_emergency_resupply(): item = {"action": "emergency"}
		elif m.s.magazine.is_empty(): item = {"action": "reload"}
		else:
			var most: int = mini(m.s.magazine.size(), int(m.MagazineTrial.WEAPON_PULSES[m.s.gun]) + int(m.Roles.pulse_bonus(m.s)))
			if m.s.gun == "amplifier": most = 1
			for amount in range(most, 0, -1):
				var trial = solver.clone(m)
				if trial.FireHeatTrial.enabled(trial.s): trial.s.fire_heat_trial.rounds = amount
				if not trial.fire(): continue
				if trial.s.phase == "lost": continue
				var detail: Dictionary = trial.s.history.back().get("detail", {})
				if trial.s.phase != "ready" or detail.get("forced_cooling", {}).is_empty():
					item = {"action": "fire", "rounds": amount}
					break
			if item.is_empty():
				var cooled = solver.clone(m)
				item = {"action": "cool"} if int(m.s.heat) > 0 and cooled.cool_magazine() and cooled.s.phase != "lost" else {"action": "fire", "rounds": 1}
		var ok := false
		match str(item.action):
			"emergency": ok = m.emergency_resupply()
			"reload": ok = m.reload_magazine()
			"cool": ok = m.cool_magazine()
			"fire":
				if m.FireHeatTrial.enabled(m.s): m.s.fire_heat_trial.rounds = int(item.rounds)
				ok = m.fire()
		if not ok:
			item = {"action": "cool"}
			if not m.cool_magazine(): break
		path.append(item)
	return path

func checked_previous_path(c) -> Array:
	if OS.get_environment("QA_NAIVE") == "careful": return careful_path(c)
	if OS.get_environment("QA_NAIVE") != "fire": return super.checked_previous_path(c)
	var m = solver.clone(c.model)
	var path: Array = []
	for step in range(300):
		if m.s.phase != "ready": break
		var item: Dictionary
		if m.can_emergency_resupply(): item = {"action": "emergency"}
		elif m.s.magazine.is_empty(): item = {"action": "reload"}
		else: item = {"action": "fire", "rounds": 0}
		var ok := false
		match str(item.action):
			"emergency": ok = m.emergency_resupply()
			"reload": ok = m.reload_magazine()
			"fire":
				if m.FireHeatTrial.enabled(m.s): m.s.fire_heat_trial.rounds = 0
				ok = m.fire()
		if not ok:
			# Nothing legal by the naive rule (e.g. reload refused): cool once, the only other key.
			item = {"action": "cool"}
			if not m.cool_magazine(): break
		path.append(item)
	return path

func choose_parts(c) -> bool:
	if not preload("res://redesign/tag_build.gd").enabled(c.model.s): return super.choose_parts(c)
	var copy: bool = c.s.parts.has("tag_copy")
	var chosen: Array = []
	for id in TAG_PREFERRED[build_kind] + c.s.parts:
		if chosen.size() >= (4 if copy else 5): break
		if id != "tag_copy" and not chosen.has(id) and c.s.parts.has(id) and Ammo.valid_part_set(run_gun, chosen + [id], c.model.s): chosen.append(id)
	if copy and Ammo.valid_part_set(run_gun, chosen + ["tag_copy"], c.model.s): chosen.append("tag_copy")
	if chosen == c.s.equipped_parts: return true
	if not c.s.equipped_parts.is_empty() and not command(c, {"action": "equip", "id": "none"}): return false
	for id in chosen:
		if not command(c, {"action": "equip", "id": id}): return false
	return true

## Reward cards seen at normal fights and depots (2026-11-11 mixed rewards): [region, cards, main].
var offer_log: Array = []
## QA_AMMO=variety: take another attack round when one is offered (else the inherited choice).
func choose_ammo(c, options: Array) -> String:
	var main: String = c.model.FocusBuild.main_round(c.model.s)
	offer_log.append([int(c.s.region) + 1, options.duplicate(), main, c.salvage_card()])
	if OS.get_environment("QA_AMMO") == "variety" and not main.is_empty():
		for id in options:
			var family: String = c.model.Content.source_id(str(id))
			if c.model.Content.is_attack(str(id)) and family != "basic" and family != c.model.Content.source_id(main): return str(id)
	return super.choose_ammo(c, options)

func command(c, item: Dictionary) -> bool:
	if late and not c.model.GrowthV2.enabled(c.model.s) and int(c.s.get("opening_reward_step", 0)) >= 1:
		c.model.s.growth_structure_version = c.model.GrowthV2.VERSION
	# QA_MASTERY=mix: mastery at the region-1 and region-3 gates only, the inherited policy elsewhere.
	var mix := OS.get_environment("QA_MASTERY") == "mix"
	# QA_MASTERY=shop: tune the drive at every shop before leaving; main mastery at the region-3 gate.
	if growth and OS.get_environment("QA_MASTERY") == "shop":
		if item.action == "leave" and c.s.phase == "shop":
			while c.can_tune_drive():
				if not super.command(c, {"action": "drive_tune"}): return false
		if item.action == "gate" and int(c.s.region) == 2 and c.gate_options().has("mastery"):
			item = item.duplicate(true)
			item.id = "mastery"
			item.keep = true
		return super.command(c, item)
	# QA_MASTERY=plan: drive at the first two gates, main mastery at the third, default after.
	if growth and OS.get_environment("QA_MASTERY") == "plan" and item.action == "gate":
		var wanted := "drive" if int(c.s.region) <= 1 else ("mastery" if int(c.s.region) == 2 else "")
		if not wanted.is_empty() and c.gate_options().has(wanted):
			item = item.duplicate(true)
			item.id = wanted
			item.keep = true
		return super.command(c, item)
	# QA_MASTERY=support: main mastery at the region-1 gate, support mastery at the region-3 gate.
	var support := OS.get_environment("QA_MASTERY") == "support"
	if growth and support and item.action == "gate" and int(c.s.region) == 2 and c.gate_options().has("mastery_support"):
		item = item.duplicate(true)
		item.id = "mastery_support"
		item.keep = true
	elif growth and item.action == "gate" and c.gate_options().has("mastery") and (not (mix or support) or int(c.s.region) in ([0] if support else [0, 2])):
		item = item.duplicate(true)
		item.id = "mastery"
		item.keep = true
	return super.command(c, item)

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/growth_v2_20261110/"): quit(2); return
	solver = preload("res://tests/fire_control_solver.gd").new(); route_policy = "safe"; acquisition_policy = "refit"; rule_version = 3
	run_gun = OS.get_environment("QA_GUN"); run_seed = int(OS.get_environment("QA_SEED")); outfit_id = OS.get_environment("QA_OUTFIT")
	if run_gun.is_empty(): run_gun = "burst"
	if outfit_id.is_empty(): outfit_id = "carrier"
	if run_seed == 0: run_seed = 17
	growth = OS.get_environment("QA_GROWTH") != "0"
	late = OS.get_environment("QA_GROWTH") == "late"
	economy_version = 1
	# 2026-11-12 launch pass: all seven guns. The four later guns follow the build of their
	# built-in drive (스플린터 연쇄, 스파이크·데드볼트·리와인더 돌파).
	build_kind = {"heavy": "fire", "burst": "control", "single": "direct", "scatter": "control", "amplifier": "direct", "rewinder": "direct", "deadbolt": "direct"}[run_gun]; role_build = build_kind == "fire"
	preferred_core = Ammo.gun_engine(run_gun, true)
	# QA_BUILD=direct|control|fire: another build for the same gun (is it the gun or the build?).
	if OS.get_environment("QA_BUILD") in ["direct", "control", "fire"]:
		build_kind = OS.get_environment("QA_BUILD"); role_build = build_kind == "fire"
	# QA_DIFFICULTY=n (2026-11-12): climb at 난도 n (the profile is given that ascension).
	var difficulty := int(OS.get_environment("QA_DIFFICULTY"))
	var c = Campaign.new()
	if difficulty > 0: c.profile.ascension = difficulty
	c.start(run_gun, run_seed, difficulty, "balanced", 4, outfit_id, true)
	if not growth or late: c.model.s.erase("growth_structure_version")
	# QA_TAGS=1: tag-based rounds and parts prototype (tag_build.gd), as chosen in 등반 설정.
	var tags := OS.get_environment("QA_TAGS") == "1"
	# QA_OVERHEAT=0: without the 11-11 overheat cost. QA_OVERHEAT_EXTRA=n: try another size.
	if OS.get_environment("QA_OVERHEAT") == "0": c.model.s.erase("overheat_version")
	# QA_MIX=0: the old main-heavy reward cards (before 2026-11-11 mixed rewards).
	if OS.get_environment("QA_MIX") == "0": c.model.s.erase("reward_mix_version")
	if not OS.get_environment("QA_OVERHEAT_EXTRA").is_empty(): c.model.Overheat.extra_override = int(OS.get_environment("QA_OVERHEAT_EXTRA"))
	if tags: c.model.s.tag_build_version = preload("res://redesign/tag_build.gd").VERSION
	roundtrip(c)
	var won: bool = await play_run(c)
	endpoints.append({"gun": run_gun, "seed": run_seed, "outfit": outfit_id, "growth": "late" if late else growth, "tags": tags, "tag_growth": c.model.s.get("tag_growth", {}), "offers": offer_log, "won": won, "region": int(c.s.region) + 1, "phase": c.s.phase, "deck": c.model.s.deck, "parts": c.s.equipped_parts, "gate_mods": c.model.s.get("gate_mods", {}), "mastery": c.model.s.get("mastery", {}), "credits": int(c.s.credits)})
	check(won, "growth comparison climb " + run_gun + " growth=" + str(growth) + " tags=" + str(tags))
	write_report()
	print("GROWTH V2 CLIMB COMPLETE won=%s checks=%d failures=%d" % [won, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
