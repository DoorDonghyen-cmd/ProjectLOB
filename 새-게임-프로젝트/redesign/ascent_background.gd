extends RefCounted
## Presentation-only height bands. No visited counts, random draws or save fields.
const STAGE_COUNT := 3
const FALLBACK := {"path": "res://assets/art/tower_sample_20261003/residential_tower.png", "floor_y": 720.0}
# Every region uses the same band rule; register its three paintings here.
# Unproduced regions retain the existing battle art instead of borrowing a
# residential upper stage and claiming it is a different district.
const REGION_ART := {
	0: [FALLBACK,
		{"path": "res://assets/art/residential_ascent_20261011/middle_v1.png", "floor_y": 728.0},
		{"path": "res://assets/art/residential_ascent_20261011/upper_v1.png", "floor_y": 772.0}],
}
static var textures: Dictionary = {}

static func stage_index(depth: int, length: int) -> int:
	var count := maxi(1, length)
	var position := clampi(depth, 1, count) - 1
	return mini(STAGE_COUNT - 1, floori(float(position * STAGE_COUNT) / count))

static func profile(region: int, depth: int, length: int) -> Dictionary:
	var stage := stage_index(depth, length)
	var entries: Array = REGION_ART.get(region, [])
	var ready := entries.size() == STAGE_COUNT
	var result: Dictionary = (entries[stage] if ready else FALLBACK).duplicate()
	result.stage = stage
	result.region = region
	result.ready = ready
	return result

static func texture(profile_data: Dictionary) -> Texture2D:
	var path := str(profile_data.path)
	if not textures.has(path): textures[path] = load(path)
	return textures[path] as Texture2D
