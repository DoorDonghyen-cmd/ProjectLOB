extends RefCounted
## Conditional forecast: keep firing this magazine, with no reload in between.
## Execute real commands on an isolated copy, including single-shot movement.
const Model = preload("res://redesign/model.gd")

static func analyze(state: Dictionary) -> Dictionary:
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var shots: Array = []
	var advance_events: Array = []
	var initial_turns: int = copy.s.turns
	if copy.s.phase == "plan": copy.confirm()
	for action in range(copy.capacity()):
		if not copy.fire(): break
		for result in copy.s.history.back().detail.results:
			var shot: Dictionary = result.duplicate(true)
			shot.action = action
			shots.append(shot)
		for event_value in copy.s.history.back().detail.get("advance_events", []):
			var event: Dictionary = event_value.duplicate(true)
			event.action = action
			advance_events.append(event)
	return {"shots": shots, "advance_events": advance_events, "phase": copy.s.phase, "remaining": copy.s.magazine.duplicate(), "turns": int(copy.s.turns) - initial_turns, "enemies": copy.s.enemies.duplicate(true)}

static func tag(index: int) -> String:
	return String.chr(65 + index)

static func outcome(shot: Dictionary) -> String:
	if not shot.hit: return "빗나감"
	if int(shot.damage) == 0: return "도탄"
	if int(shot.hp) == 0: return "처치"
	return "−%d · HP %d" % [shot.damage, shot.hp]

static func burn_ticks_for_shot(forecast: Dictionary, shot_index: int) -> int:
	if shot_index < 0 or shot_index >= forecast.get("shots", []).size(): return 0
	var shot: Dictionary = forecast.shots[shot_index]
	if int(shot.get("burn_added", 0)) <= 0: return 0
	var ticks := 0
	for event in forecast.get("advance_events", []):
		if str(event.get("kind", "")) == "burn" and int(event.get("target", -1)) == int(shot.target) and int(event.get("action", -1)) >= int(shot.action):
			ticks += 1
	return ticks

static func note(forecast: Dictionary, shot_index: int) -> String:
	if shot_index < 0 or shot_index >= forecast.get("shots", []).size(): return ""
	var shot: Dictionary = forecast.shots[shot_index]
	var boosted := int(shot.get("math", {}).get("boost", 0)) > 0
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var impacts: PackedStringArray = []
		for other in secondary:
			impacts.append("%s %s −%d" % [tag(other.target), "확산" if other.get("kind", "arc") == "spread" else "전이", other.damage])
		return ("증폭 · " if boosted else "") + " / ".join(impacts)
	if int(shot.get("math", {}).get("overflow", 0)) > 0:
		return ("증폭 · 2타 · " if boosted and int(shot.hits) > 1 else ("증폭 · " if boosted else "")) + "초과 관통 +%d" % shot.math.overflow
	if int(shot.get("burn_added", 0)) > 0:
		var ticks := burn_ticks_for_shot(forecast, shot_index)
		return "화상 %d회 예상" % ticks if ticks > 0 else "화상 +%d" % shot.burn_added
	if int(shot.get("push", 0)) > 0:
		return "거리 +%dm" % shot.push
	if boosted and int(shot.get("hits", 1)) > 1:
		return "증폭 · 2타"
	if boosted:
		return "증폭 적용"
	if int(shot.get("hits", 1)) > 1:
		return "2회 타격"
	if str(shot.get("id", "")) == "charge":
		return "다음 2발 +2"
	return ""

static func is_combo_link(forecast: Dictionary, shot_index: int) -> bool:
	if shot_index <= 0 or shot_index >= forecast.get("shots", []).size(): return false
	return int(forecast.shots[shot_index].get("math", {}).get("boost", 0)) > 0

static func summary(forecast: Dictionary) -> String:
	if forecast.is_empty(): return "탄환을 눌러 장전하세요"
	var parts: PackedStringArray = []
	var nearest := 99999
	for i in range(forecast.get("enemies", []).size()):
		var enemy: Dictionary = forecast.enemies[i]
		if int(enemy.hp) <= 0:
			parts.append("%s 처치" % tag(i))
		else:
			parts.append("%s HP %d" % [tag(i), enemy.hp])
			nearest = mini(nearest, int(enemy.distance))
	if str(forecast.get("phase", "")) == "lost":
		parts.append("접촉 위험")
	elif nearest < 99999:
		parts.append("안전 %dm" % nearest)
	else:
		parts.append("전투 종료")
	return " · ".join(parts)
