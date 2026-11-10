extends "res://tests/economy_options_solver.gd"
## Fallback only: spend legal exchanges/field compression at encounter entry.
func solve(model, width: int = 4, max_depth: int = 18) -> Array:
	var path: Array = super.solve(model,width,max_depth)
	if not path.is_empty() or model.s.phase != "plan":return path
	var choices: Array = [{"model":clone(model),"path":[]}]
	var frontier: Array = choices.duplicate()
	for count in range(mini(2,int(model.s.exchange_left))):
		var next: Array = []
		for branch in frontier:
			var ids: Array = []
			for id in branch.model.s.hand:
				if ids.has(id):continue
				ids.append(id)
				var copy = clone(branch.model)
				if copy.exchange(id):next.append({"model":copy,"path":branch.path+[{"action":"exchange","id":id}]})
		choices.append_array(next);frontier = next
	for branch in choices.duplicate():
		for id in branch.model.field_compressible_ids():
			var copy = clone(branch.model)
			if copy.field_compress(id):choices.append({"model":copy,"path":branch.path+[{"action":"field_compress","id":id}]})
	for choice in choices.slice(1):
		path = super.solve(choice.model,mini(width,8),max_depth)
		if not path.is_empty():return choice.path + path
	return []
