extends RefCounted
## Presentation preview from a recorded, legitimately earned second-gate deck.
## Later rooms are direct jumps for visual review, not balance/route evidence.
static func campaign(stage: int = -1, encounter: String = "", roster_version: int = 9) -> RefCounted:
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/garden_gate_single.json"))
	if not payload is Dictionary: return null
	var run = preload("res://redesign/campaign.gd").new()
	if not run.restore_state(payload): return null
	if not run.gate("bag" if run.can_grow_bag() else "credits"): return null
	run.s.roster_version = roster_version
	return preload("res://redesign/ascent_preview.gd").select_stage(run, stage, encounter)
