extends RefCounted
## Retired IDs remain readable in historical shot records; live ownership is canonical.
const IDS := {"thermal": "bore", "thermal_c": "bore_c", "thermal_f": "bore_f"}

static func canonical(id: String) -> String:
	return str(IDS.get(id, id))

static func definitions(base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for old_id in IDS:
		var spec: Dictionary = base[IDS[old_id]].duplicate(true)
		spec.source = "bore"
		spec.retired = true
		result[old_id] = spec
	return result

static func _array(state: Dictionary, key: String) -> void:
	if not state.get(key) is Array: return
	for i in range(state[key].size()):
		if state[key][i] is String: state[key][i] = canonical(state[key][i])

static func combat(state: Dictionary) -> void:
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan", "plan_load_order", "prepared"]:
		_array(state, key)
	if state.get("field_compression") is Dictionary:
		for key in ["source", "id"]:
			if state.field_compression.get(key) is String:
				state.field_compression[key] = canonical(state.field_compression[key])

static func campaign(state: Dictionary) -> void:
	_array(state, "supply_offers")
	if state.get("encounter") is Dictionary: _array(state.encounter, "offers")
	if state.get("offers") is Array:
		for offer in state.offers:
			if offer is Dictionary and offer.get("type") == "ammo" and offer.get("id") is String:
				offer.id = canonical(offer.id)
	if state.get("shop_seen_ammo") is Array:
		# Merge distinct old discovery entries; pre-existing invalid duplicates stay invalid.
		var seen: Array = []
		var original: Array = []
		for id in state.shop_seen_ammo:
			var next = canonical(id) if id is String else id
			if not seen.has(next) or original.has(id): seen.append(next)
			original.append(id)
		state.shop_seen_ammo = seen
