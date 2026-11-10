extends RefCounted
## Roster 11 uses a fresh, actually earned fifth-region arrival.
## Later room jumps are for visual inspection, without fabricated extra growth.
static func campaign(stage: int = -1, encounter: String = "", roster_version: int = 11, combat_revision: int = 0) -> RefCounted:
	if roster_version>=11:
		var payload=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/central_arrivals_20261026/single.json"))
		if not payload is Dictionary:return null
		var current=preload("res://redesign/campaign.gd").new()
		if not current.restore_state(payload):return null
		if combat_revision>0:
			current.s.combat_revision=combat_revision;current.model.s.combat_revision=combat_revision
			current.model.s.weapon_version=1
			if stage<0 and current.s.phase=="combat":current._begin_combat(current.node())
		current.s.message="중앙 통제구 전투 미리보기 · 저장되지 않습니다"
		return preload("res://redesign/ascent_preview.gd").select_stage(current,stage,encounter)
	var run = preload("res://redesign/noble_preview.gd").campaign(-1, "", roster_version)
	if run == null: return null
	var preview = preload("res://redesign/ascent_preview.gd")
	if not preview.advance_region(run): return null
	run.s.message = "중앙 통제구 배경 미리보기"
	return preview.select_stage(run, stage, encounter)
