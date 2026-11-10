extends RefCounted
## Real first-region earned decks, captured by foundry_campaign_runner seed 731042.
## The screen marks these as debug_session, so normal run/profile saves stay untouched.
static func campaign(gun: String = "single", encounter: String = "", current: bool = true, combat_revision: int = 0) -> RefCounted:
	if gun not in ["single","burst","scatter","heavy","amplifier"]: return null
	var arrival := current and encounter in ["elite","boss"]
	var path := "res://tests/fixtures/foundry_arrivals_20261023/%s_%s.json"%[gun,encounter] if arrival else "res://tests/fixtures/foundry_entry_%s.json" % gun
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not payload is Dictionary: return null
	var run = preload("res://redesign/campaign.gd").new()
	if not run.restore_state(payload): return null
	if current: run.s.roster_version = preload("res://redesign/foundry_workers.gd").VERSION
	if current and combat_revision>0:
		run.s.combat_revision=combat_revision;run.model.s.combat_revision=combat_revision
		run.model.s.weapon_version=1
		if not arrival and encounter.is_empty() and run.s.phase=="combat":run._begin_combat(run.node())
	if arrival:
		run._begin_combat(run.node())
		return run
	if encounter in ["elite","boss"]:
		var nodes: Array = run.current_nodes().filter(func(n): return n.kind=="boss" if encounter=="boss" else bool(n.get("elite",false)))
		if nodes.is_empty(): return null
		run.s.node=nodes[0].id;run.s.floor=nodes[0].floor
		run._begin_combat(nodes[0])
	return run
