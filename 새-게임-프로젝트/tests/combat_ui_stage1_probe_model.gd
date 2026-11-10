extends "res://redesign/model.gd"
## Read-only diagnostic subclass: count actual resolver calls, never change rules.
var advance_calls: Array = []

func _advance(turn_count: int, count_turns: bool = false) -> Array:
	advance_calls.append({"requested_turns": turn_count, "counts_turns": count_turns})
	return super._advance(turn_count, count_turns)
