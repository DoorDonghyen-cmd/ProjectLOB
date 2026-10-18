extends RefCounted
## Chart notation, not miniature architecture. Atlas order follows the legend.
const ATLAS = preload("res://assets/art/map_chart_20261009/survey_symbols.png")
const GUARD_ATLAS = preload("res://assets/art/map_chart_20261009/survey_symbols_guard.png")
const ROLES := ["combat", "elite", "boss", "shop", "workshop", "supply", "event", "bypass"]
const BOUNDS := [Rect2(72, 80, 310, 320), Rect2(510, 35, 310, 385), Rect2(950, 24, 320, 390), Rect2(1360, 70, 390, 337), Rect2(59, 475, 338, 337), Rect2(490, 524, 352, 277), Rect2(945, 478, 330, 338), Rect2(1410, 480, 310, 330)]

static func role_texture(role: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	result.region = BOUNDS[ROLES.find(role)]
	if role == "elite":
		result.atlas = GUARD_ATLAS
		result.region = Rect2(488, 88, 356, 316)
	result.filter_clip = true
	return result
