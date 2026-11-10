extends RefCounted
## Developer-only route synthesis; never clears encounters or awards rewards.
static func advance_region(run: RefCounted) -> bool:
	var rooms: Array = run.current_nodes()
	var entry: Array = rooms.filter(func(room): return int(room.floor) == 1)
	if entry.is_empty(): return false
	var room: Dictionary = entry[0]
	for step in range(rooms.size()):
		run.s.visited.append(int(room.id))
		if room.kind == "boss": break
		if room.next.is_empty(): return false
		var next_id := int(room.next[0])
		var next_rooms := rooms.filter(func(candidate): return int(candidate.id) == next_id)
		if next_rooms.is_empty(): return false
		room = next_rooms[0]
	if room.kind != "boss": return false
	run.s.region += 1
	run.s.floor = 0
	run.s.node = 0
	run.s.phase = "map"
	run.set_meta("visual_only_route", true)
	return true

static func select_stage(run: RefCounted, stage: int, encounter: String) -> RefCounted:
	if stage < 0: return run
	var band := clampi(stage, 0, 2)
	var length := int(run.region_info().floors)
	var candidates: Array = run.current_nodes().filter(func(candidate):
		if encounter == "boss": return candidate.kind == "boss"
		if encounter == "elite": return bool(candidate.get("elite", false))
		return candidate.kind == "combat" and not candidate.get("elite", false) and preload("res://redesign/ascent_background.gd").stage_index(int(candidate.floor), length) == band
	)
	if candidates.is_empty(): return null
	var selected: Dictionary = candidates[0]
	run.s.floor = selected.floor
	run.s.node = selected.id
	# Match the room-entry flags that direct visual jumps otherwise bypass.
	run.s.resolved = false
	run.s.boss_loot_paid = false
	run.s.encounter = {}
	run.s.supply_offers = []
	run._begin_combat(selected)
	return run
