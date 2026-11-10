extends RefCounted
## One source for equipment art, held weapons and effect attachment coordinates.
const PROFILES := {
	"single": {"family":"pistol", "image":preload("res://assets/art/weapon_redesign_20261024/single_latch_v1.png"), "grip":Vector2(340,590), "muzzle":Vector2(1450,310), "scale":0.10, "part":Rect2(713,265,200,273), "release":Vector2(0,200), "heat":Rect2(1105,220,350,225), "bounds":Rect2(91,149,1367,804)},
	"burst": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/burst_ratchet_v1.png"), "grip":Vector2(570,570), "support":Vector2(1350,505), "muzzle":Vector2(1730,378), "part":Rect2(882,480,144,215), "release":Vector2(0,240), "heat":Rect2(1140,310,590,135), "bounds":Rect2(42,216,1692,512)},
	"scatter": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/scatter_splinter_v4.png"), "grip":Vector2(665,515), "support":Vector2(1640,470), "muzzle":Vector2(2035,292), "part":Rect2(1052,405,150,158), "release":Vector2(0,205), "heat":Rect2(1560,160,480,245), "bounds":Rect2(110,100,1935,556)},
	"heavy": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/heavy_reactor_v1.png"), "grip":Vector2(665,520), "support":Vector2(1660,485), "muzzle":Vector2(2110,310), "part":Rect2(952,448,240,167), "release":Vector2(0,205), "heat":Rect2(1230,215,775,205), "bounds":Rect2(35,98,2092,571)},
	"amplifier": {"family":"pistol", "image":preload("res://assets/art/weapon_redesign_20261024/amplifier_spike_v1.png"), "grip":Vector2(340,475), "muzzle":Vector2(2025,310), "scale":0.10, "part":Rect2(860,184,1173,240), "release":Vector2.ZERO, "heat":Rect2(1140,240,890,140), "bounds":Rect2(88,113,1943,553)},
}

static func atlas(gun: String) -> AtlasTexture:
	var profile: Dictionary = PROFILES.get(gun, PROFILES.single)
	var texture := AtlasTexture.new()
	texture.atlas = profile.image
	texture.region = profile.bounds
	texture.filter_clip = true
	return texture
