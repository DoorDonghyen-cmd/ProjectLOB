extends RefCounted
## Roster 11 provisional full-run pass. Saved rosters 1..10 retain old values.
static func rows(node: Dictionary, fallback: Array) -> Array:
	if int(node.region)!=0 or str(node.kind)!="boss":return fallback
	var result:=fallback.duplicate(true)
	# Short first-region routes can reach this gate with only two core levels.
	# Keep the armor/opening lesson and escorts; reduce finite-ammo demand.
	result[0][1]=32
	return result
