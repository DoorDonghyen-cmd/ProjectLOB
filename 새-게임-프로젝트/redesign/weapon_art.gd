extends RefCounted
## One source for equipment art, held weapons and effect attachment coordinates.
const PROFILES := {
	"single": {"family":"long", "image":preload("res://assets/art/rivet_twohand_20261106/rivet_carbine_v1_pixel.png"), "grip":Vector2(640,445), "support":Vector2(1550,430), "muzzle":Vector2(2080,285), "part":Rect2(865,150,350,270), "release":Vector2(0,145), "heat":Rect2(1335,175,750,180), "bounds":Rect2(134,49,1950,629)},
	"burst": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/burst_ratchet_v1.png"), "grip":Vector2(570,570), "support":Vector2(1350,505), "muzzle":Vector2(1730,378), "part":Rect2(882,480,144,215), "release":Vector2(0,240), "heat":Rect2(1140,310,590,135), "bounds":Rect2(42,216,1692,512)},
	"scatter": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/scatter_splinter_v4.png"), "grip":Vector2(665,515), "support":Vector2(1640,470), "muzzle":Vector2(2035,292), "part":Rect2(1052,405,150,158), "release":Vector2(0,205), "heat":Rect2(1560,160,480,245), "bounds":Rect2(110,100,1935,556)},
	"heavy": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/heavy_reactor_v1.png"), "grip":Vector2(665,520), "support":Vector2(1660,485), "muzzle":Vector2(2110,310), "part":Rect2(952,448,240,167), "release":Vector2(0,205), "heat":Rect2(1230,215,775,205), "bounds":Rect2(35,98,2092,571)},
	"amplifier": {"family":"pistol", "image":preload("res://assets/art/weapon_redesign_20261024/amplifier_spike_v1.png"), "grip":Vector2(340,475), "muzzle":Vector2(2025,310), "scale":0.10, "part":Rect2(860,184,1173,240), "release":Vector2.ZERO, "heat":Rect2(1140,240,890,140), "bounds":Rect2(88,113,1943,553)},
	"rewinder": {"family":"long","image":preload("res://assets/art/weapon_expansion_20261106/rewinder_v1.png"),"grip":Vector2(565,465),"support":Vector2(1545,455),"muzzle":Vector2(2060,294),"part":Rect2(805,305,535,275),"release":Vector2(0,205),"heat":Rect2(1645,240,410,80),"bounds":Rect2(115,182,1957,420)},
	"deadbolt": {"family":"long","image":preload("res://assets/art/weapon_expansion_20261106/deadbolt_break_v4.png"),"grip":Vector2(740,430),"support":Vector2(1500,435),"muzzle":Vector2(2080,296),"part":Rect2(1110,180,985,305),"hinge":Vector2(1110,385),"release":Vector2.ZERO,"heat":Rect2(1360,235,700,100),"bounds":Rect2(85,180,2010,440)},
}

static func atlas(gun: String) -> AtlasTexture:
	var profile: Dictionary = PROFILES.get(gun, PROFILES.single)
	var texture := AtlasTexture.new()
	texture.atlas = profile.image
	texture.region = profile.bounds
	texture.filter_clip = true
	return texture
