@tool
extends RefCounted
## Map-only authored marks. Native sizes are exact 2x pixel exports.
const ROOT := "res://assets/ui/pipe_map_art_20261101/"
const REGIONS := ["residential", "foundry", "garden", "noble", "central"]
static var cache: Dictionary = {}

static func texture(mark: String) -> Texture2D:
	if not cache.has(mark): cache[mark] = load(ROOT + mark + ".png")
	return cache[mark]

static func symbol(role: String, detail: bool = false) -> Texture2D:
	if role == "boss": return texture("gate_detail_closed")
	if role == "elite" and detail: return texture("elite_detail")
	return texture(role)

static func region_mark(region: int, state: String) -> Texture2D:
	return texture("region_" + REGIONS[clampi(region, 0, 4)] + "_" + state)
