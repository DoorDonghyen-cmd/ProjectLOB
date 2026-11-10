extends "res://tests/economy_campaign_runner.gd"
## The same earned route with one public workshop preference changed.
func command(c, item: Dictionary) -> bool:
	var step := item.duplicate(true)
	if step.action == "resolve" and c.s.phase == "supply" and c.node().get("workshop",false) and not c.s.resolved:
		var preference := OS.get_environment("QA_WORKSHOP")
		if preference == "bag" and c.can_grow_bag():
			step = {"action":"resolve","id":"bag"}
		elif preference == "compress":
			var candidates: Array = c.compressible_ids()
			if not candidates.is_empty():
				var selected := str(candidates[0])
				var priorities: Array = ["pierce","precise","bore","arc","charge","cool"]
				if run_gun == "heavy":priorities = ["vent","bore","charge_heat","charge_hot","arc","pierce","precise"]
				for family in priorities:
					var matches: Array = candidates.filter(func(id):return Ammo.source_id(str(id)) == family)
					if not matches.is_empty():selected = str(matches[0]);break
				step = {"action":"resolve","id":"compress","ammo":selected}
	return super.command(c,step)

func write_report() -> void:
	for row in battles:row.workshop_policy = OS.get_environment("QA_WORKSHOP")
	for row in endpoints:row.workshop_policy = OS.get_environment("QA_WORKSHOP")
	super.write_report()
