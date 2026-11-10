extends RefCounted
## Original source PNGs, alpha bounds and planted foot anchors.
const REGISTRATION := {"guard_rusher": {"source": [145, 61, 1056, 1084], "feet": [827.5, 1145], "height": 112, "file": "res://assets/art/central_guard_alt_20261025/guard_rusher_b.png"}, "guard_heavy": {"source": [57, 162, 1317, 866], "feet": [765.5, 1028], "height": 132, "file": "res://assets/art/central_guard_alt_20261025/guard_heavy_b.png"}, "guard_shield": {"source": [188, 56, 861, 1231], "feet": [643.5, 1287], "height": 116, "file": "res://assets/art/central_guard_alt_20261025/guard_shield_b.png"}, "guard_artillery": {"source": [55, 141, 1223, 1000], "feet": [881.5, 1141], "height": 108, "file": "res://assets/art/central_guard_alt_20261025/guard_artillery_b.png"}, "guard_captain": {"file": "res://assets/art/central_leaders_20261026/captain_v1.png", "height": 148, "source": [39, 65, 968, 1385], "feet": [575.5, 1450]}, "tower_ruler": {"file": "res://assets/art/central_leaders_20261026/ruler_v1.png", "height": 148, "source": [39, 66, 914, 1458], "feet": [494.0, 1524]}}
const TEXTURES := {
	"res://assets/art/central_guard_alt_20261025/guard_artillery_b.png":preload("res://assets/art/central_guard_alt_20261025/guard_artillery_b.png"),
	"res://assets/art/central_guard_alt_20261025/guard_heavy_b.png":preload("res://assets/art/central_guard_alt_20261025/guard_heavy_b.png"),
	"res://assets/art/central_guard_alt_20261025/guard_rusher_b.png":preload("res://assets/art/central_guard_alt_20261025/guard_rusher_b.png"),
	"res://assets/art/central_guard_alt_20261025/guard_shield_b.png":preload("res://assets/art/central_guard_alt_20261025/guard_shield_b.png"),
	"res://assets/art/central_leaders_20261026/captain_v1.png":preload("res://assets/art/central_leaders_20261026/captain_v1.png"),
	"res://assets/art/central_leaders_20261026/ruler_v1.png":preload("res://assets/art/central_leaders_20261026/ruler_v1.png"),
}

static func data() -> Dictionary:
	return REGISTRATION

static func pose(species: String) -> Dictionary:
	var entry:Dictionary=REGISTRATION[species]
	var source:=Rect2(entry.source[0],entry.source[1],entry.source[2],entry.source[3])
	return {"texture":TEXTURES[entry.file],"source":source,"anchor":Vector2(entry.feet[0],entry.feet[1]),"scale":float(entry.height)/source.size.y,"height":float(entry.height)}

static func radius(species: String) -> float:
	var entry:=pose(species)
	return ceilf(maxf(entry.anchor.x-entry.source.position.x,entry.source.end.x-entry.anchor.x)*entry.scale)
