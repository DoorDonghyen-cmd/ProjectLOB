extends SceneTree

const Campaign = preload("res://redesign/campaign.gd")
const PartsCampaign = preload("res://redesign/samples/opening_build/parts_campaign.gd")
const Solver = preload("res://tests/fire_control_solver.gd")
const Commands = preload("res://tests/weapon_magazine_solver.gd")
const Content = preload("res://redesign/content.gd")
const Focus = preload("res://redesign/focus_build.gd")
const BRANCHES := [["volley_drive", "precise_p2"], ["sequencer", "precise_p2"], ["chain_sink", "precise_p2"], ["thermal_drive", "bore"], ["rammer", "bore"]]

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
	return ok

static func win_battle(campaign: Campaign) -> Array:
	var path := Solver.new().solve(campaign.model)
	for step in path:
		var action := str(step.action)
		if action == "fire": campaign.model.s.fire_heat_trial.rounds = int(step.get("rounds", 0))
		var accepted: bool = campaign.model.eject_magazine_rounds(step.indices) if action == "eject" else Commands.command(campaign.model, "swap" if action == "reload" else action)
		if not accepted: return []
		campaign.sync_combat()
	return path if campaign.s.phase == "reward" else []

static func first_choice(campaign: Campaign) -> int:
	for node in campaign.choices():
		if node.kind == "combat" and not node.get("elite", false): return int(node.id)
	return -1

func branch(checkpoint: Dictionary, pair: Array, mode: int = PartsCampaign.VariantMode.PARTS) -> Dictionary:
	var id := str(pair[0])
	var package := str(pair[1])
	var core := str(Content.PARTS[id].kind) == "core"
	var candidate: Campaign = Campaign.new() if core else PartsCampaign.new()
	if candidate is PartsCampaign: candidate.mode = mode
	if not check(candidate.restore_state(checkpoint.duplicate(true)), "same earned first win restores " + id): return {}
	var starting_deck: Array = candidate.model.s.deck.duplicate()
	var rewards := candidate.part_rewards()
	if not check(rewards.size() == 3 and rewards.all(func(part): return str(Content.PARTS[part].kind) == ("core" if core else "module")), "first offer kind " + id): return {}
	if not check(candidate.reward(id) and candidate.first_ammo_reward(), "first claim leads to ammo package " + id): return {}
	check(candidate.equipped_parts() == [id] and candidate.model.s.equipped_parts == [id], "real module ownership and equip " + id)
	check(candidate.model.s.deck == starting_deck, "first part changes only loadout " + id)
	check(not candidate.reward(id), "first part cannot be claimed twice " + id)
	if not check(candidate.reward(package) and candidate.s.phase == "map", "same existing package rule " + id): return {}
	check(candidate.model.s.deck.size() == starting_deck.size(), "package preserves ammo count " + id)
	var deck: Array = candidate.model.s.deck.duplicate()
	var next := first_choice(candidate)
	if not check(candidate.enter(next), "enters real next encounter " + id): return {}
	var start: Dictionary = candidate.model.s
	var first_magazine: Array = start.magazine.duplicate()
	var initial_rng := str(start.rng_state)
	var support := str(Focus.package(package)[2])
	if mode != PartsCampaign.VariantMode.PARTS:
		check(first_magazine.has(package) and first_magazine.count(support) == 1, "both owned rounds loaded once " + id)
		check(Content.valid_stack(first_magazine, candidate.model.capacity()), "capacity and anchors respected " + id)
		var rounds: Array = first_magazine + start.draw + start.hand + start.discard
		var owned := deck.duplicate()
		rounds.sort()
		owned.sort()
		check(rounds == owned, "opening load preserves every owned round " + id)
	var from_history := int(start.history.size())
	var from_turns := int(start.turns)
	var from_shots := int(start.shots)
	var path := win_battle(candidate)
	if not check(not path.is_empty(), "solver reaches next earned reward " + id): return {}
	var events: Array = candidate.model.s.history.slice(from_history)
	var shots: Array = []
	for event in events:
		if event.action == "fire": shots.append_array(event.detail.results)
	var useful: Array = shots.filter(func(shot):
		if id == "sequencer": return int(shot.get("damage", 0)) > 0 and int(shot.get("math", {}).get("boost", 0)) > 3
		return shot.get("part_effects", []).any(func(effect): return effect.id == id)
	)
	var next_rewards := candidate.reward_options()
	var next_parts := candidate.part_rewards()
	if mode == PartsCampaign.VariantMode.FOLLOW_UP:
		check(next_rewards.size() == 2 and next_parts.size() == 1, "one existing reward slot becomes a part " + id)
		if next_parts.size() == 1:
			var part := str(next_parts[0])
			check(not candidate.s.parts.has(part) and int(Content.PARTS[part].grade) == 0, "follow-up is new and common " + id)
			check(candidate.reward(part) and candidate.equipped_parts().has(part) and not candidate.reward(part), "follow-up is claimed once through campaign " + id)
	var combo_available := first_magazine.has(support) and first_magazine.find(support) < first_magazine.rfind(package)
	return {"seed":int(candidate.s.seed), "mode":mode, "part":id, "package":package, "next_node":next, "turns":int(candidate.model.s.turns)-from_turns, "rounds":int(candidate.model.s.shots)-from_shots, "first_magazine":first_magazine, "combo_available":combo_available, "activations":useful.size(), "next_rewards":next_rewards, "next_parts":next_parts, "deck":deck, "rng":initial_rng, "path":path}

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/opening_build_20261108/"): quit(2); return
	var rows := []
	for seed in [731042, 17, 23, 31]:
		var campaign := Campaign.new()
		campaign.start("single", seed, 0, "balanced", 4, "carrier", true)
		if not check(campaign.enter(first_choice(campaign)), "first actual encounter %d" % seed): continue
		if not check(not win_battle(campaign).is_empty() and campaign.engine_reward(), "first reward earned %d" % seed): continue
		var checkpoint := {"campaign":campaign.s, "combat":campaign.model.s, "profile":campaign.profile}
		var compared := []
		for pair in BRANCHES:
			var row := branch(checkpoint, pair)
			if not row.is_empty(): compared.append(row)
		if compared.size() == BRANCHES.size():
			check(compared.all(func(row): return row.next_node == compared[0].next_node), "same second node across rewards")
			check(compared[0].deck == compared[1].deck and compared[1].deck == compared[2].deck and compared[3].deck == compared[4].deck, "matched decks compare only starter equipment")
		rows.append_array(compared)
		for i in [1, 2, 4]:
			var support := branch(checkpoint, BRANCHES[i], PartsCampaign.VariantMode.SUPPORT)
			var follow_up := branch(checkpoint, BRANCHES[i], PartsCampaign.VariantMode.FOLLOW_UP)
			if support.is_empty() or follow_up.is_empty(): continue
			rows.append_array([support, follow_up])
			check(support.path == follow_up.path and support.first_magazine == follow_up.first_magazine, "C and D share the same second fight")
			check(support.next_parts.is_empty() and follow_up.next_rewards == support.next_rewards.slice(0, -1), "D replaces exactly the last ammo offer")
			if compared.size() == BRANCHES.size():
				check(compared[i].rng == support.rng and compared[i].deck == support.deck, "B and C share deck and random state")
		if seed == 731042:
			for package in ["pierce_p2", "vent", "arc"]:
				var row := branch(checkpoint, ["chain_sink", package], PartsCampaign.VariantMode.SUPPORT)
				if not row.is_empty(): rows.append(row)
	FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("FOCUS BUILD COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
