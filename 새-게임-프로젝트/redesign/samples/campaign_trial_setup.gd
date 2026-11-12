extends RefCounted
## Build a legal visited prefix for an isolated campaign trial.

static func path_to(rooms: Array, matches: Callable) -> Array:
	var ordered := rooms.duplicate()
	ordered.sort_custom(func(a, b): return int(a.floor) < int(b.floor))
	var routes := {}
	for room in ordered:
		if int(room.floor) == 1: routes[room.id] = [room.id]
		if not routes.has(room.id): continue
		if matches.call(room): return routes[room.id]
		for next in room.next:
			if not routes.has(next): routes[next] = routes[room.id] + [next]
	return []

static func load_magazine(model, rounds: Array) -> void:
	model.s.deck = rounds.duplicate()
	while model.s.deck.size() < 14: model.s.deck.append("basic_p2")
	model.s.magazine = rounds.duplicate()
	model.s.magazine_loaded = rounds.duplicate()
	model.s.hand = []
	model.s.draw = model.s.deck.duplicate()
	for id in rounds: model.s.draw.erase(id)
	model.s.fire_heat_trial.rounds = 1
	model._record("load", {"load_order": rounds.duplicate(), "whole_magazine": true})
