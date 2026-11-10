extends "res://tests/economy_recovery_runner.gd"

func command(c, item: Dictionary) -> bool:
	var step := item.duplicate(true)
	if step.action=="gate" and c.gate_options().has("growth"):step={"action":"gate","id":"growth"}
	return super.command(c,step)

func write_report() -> void:
	if not battles.is_empty() and not battles.back().has("growth_limit"):
		battles.back().growth_limit=preload("res://redesign/core_growth.gd").limit(initial_state)
	super.write_report()
