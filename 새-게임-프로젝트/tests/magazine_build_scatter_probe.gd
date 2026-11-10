extends SceneTree
## Wider bounded search on the saved scatter final-boss entry (diagnostic only).
const Campaign = preload("res://redesign/campaign.gd")
func _initialize() -> void:
	var file := OS.get_environment("QA_STATE_FILE")
	var c = Campaign.new()
	if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(file))): print("restore failed"); quit(1); return
	var s: Dictionary = c.model.s
	print("deck=", s.deck.size(), " parts=", s.equipped_parts, " enemies=", s.enemies.map(func(e): return [e.name, e.hp, e.distance]), " reserve=", s.reinforcements.size())
	var solver = preload("res://tests/campaign_magazine_solver.gd").new()
	for pair in [[24, 40], [48, 60]]:
		var started := Time.get_ticks_msec()
		var path: Array = solver.solve(c.model, pair[0], pair[1])
		print("width=", pair[0], " depth=", pair[1], " solved=", not path.is_empty(), " steps=", path.size(), " ms=", Time.get_ticks_msec() - started)
		if not path.is_empty():
			print("PATH ", JSON.stringify(path)); break
	quit(0)
