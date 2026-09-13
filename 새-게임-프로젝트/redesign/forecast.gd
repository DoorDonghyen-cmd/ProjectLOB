extends RefCounted
## Conditional forecast: keep firing this magazine, with no reload in between.
## Execute real commands on an isolated copy, including single-shot movement.
const Model = preload("res://redesign/model.gd")

static func analyze(state: Dictionary) -> Dictionary:
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var shots: Array = []
	var initial_turns: int = copy.s.turns
	if copy.s.phase == "plan": copy.confirm()
	for action in range(copy.capacity()):
		if not copy.fire(): break
		for result in copy.s.history.back().detail.results:
			var shot: Dictionary = result.duplicate(true)
			shot.action = action
			shots.append(shot)
	return {"shots": shots, "phase": copy.s.phase, "remaining": copy.s.magazine.duplicate(), "turns": int(copy.s.turns) - initial_turns, "enemies": copy.s.enemies.duplicate(true)}

static func tag(index: int) -> String:
	return String.chr(65 + index)

static func outcome(shot: Dictionary) -> String:
	if not shot.hit: return "빗나감"
	if int(shot.damage) == 0: return "도탄"
	return "−%d%s" % [shot.damage, " 처치" if int(shot.hp) == 0 else (" 스침" if shot.get("graze", false) else "")]
