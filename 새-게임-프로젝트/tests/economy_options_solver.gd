extends "res://tests/central_combat_solver.gd"
## Respect an already inserted field-compressed card while enumerating additions.
func enumerate(model, stack: Array = []) -> void:
	if candidate_limit > 0 and candidates.size() >= candidate_limit:return
	if not stack.is_empty() or not model.s.plan.is_empty():candidates.append(stack.duplicate())
	var plan: Array = model.s.plan.duplicate()
	for id in stack:plan.insert(Content.insertion_index(plan,str(id)),id)
	if Content.slots_used(plan) >= model.capacity():return
	var ids: Array = []
	for id in ["charge_c","precise_c","pierce_c","bore_c","arc_c","push_c","charge","precise","pierce","bore","arc","push","basic"] + model.s.hand:
		if not ids.has(id) and model.available(id) > 0:ids.append(id)
	for id in ids:
		if candidate_limit > 0 and candidates.size() >= candidate_limit:break
		if stack.count(id) >= model.available(id) or not Content.can_insert(plan,str(id),model.capacity()):continue
		stack.append(id);enumerate(model,stack);stack.pop_back()
