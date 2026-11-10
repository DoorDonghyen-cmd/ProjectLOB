extends RefCounted
## Current preview uses a recorded, earned fourth-region arrival.
## Later rooms are direct visual jumps, not additional earned growth.
## Legacy roster previews retain the previous visual-only route synthesis.
static func campaign(stage: int = -1, encounter: String = "", roster_version: int = 10) -> RefCounted:
	var preview = preload("res://redesign/ascent_preview.gd")
	if roster_version >= 10:
		var payload = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/noble_arrivals_20261025/single.json"))
		if not payload is Dictionary: return null
		var current = preload("res://redesign/campaign.gd").new()
		if not current.restore_state(payload): return null
		current.s.roster_version = roster_version
		current.s.message = "귀족 거주구 전투 미리보기 · 저장되지 않습니다"
		return preview.select_stage(current, stage, encounter)
	var run = preload("res://redesign/garden_preview.gd").campaign(-1, "", roster_version)
	if run == null: return null
	if not preview.advance_region(run): return null
	run.s.message = "귀족 거주구 전투 미리보기 · 저장되지 않습니다"
	return preview.select_stage(run, stage, encounter)
