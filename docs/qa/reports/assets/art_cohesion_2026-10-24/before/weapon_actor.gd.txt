@tool
extends Node2D
## Body-family poses + registered weapon layers. No gameplay timing or RNG.
const OutfitArt = preload("res://redesign/outfit_art.gd")
var outfit_id := "work"
const CELL := Vector2(512, 512)
const FOOT := Vector2(240, 480)
const BODY_SCALE := 1065.0 / 447.0
const BODIES := {
	"pistol": preload("res://assets/art/weapon_motion_20261011/pistol_body_v2.png"),
	"long": preload("res://assets/art/weapon_motion_20261011/long_body_v2.png"),
}
const POSES := {
	"pistol": {
		"idle": {"cell":Vector2(0,0), "foot":Vector2(308,486), "grip":Vector2(344,226), "angle":20.0, "hands":[Rect2(328,210,38,34)]},
		"aim": {"cell":Vector2(1,0), "foot":Vector2(243,486), "grip":Vector2(314,205), "angle":0.0, "hands":[Rect2(299,189,32,34)]},
		"recoil": {"cell":Vector2(2,0), "foot":Vector2(212,486), "grip":Vector2(294,162), "angle":-8.0, "hands":[Rect2(279,146,33,34)]},
		"reload_open": {"cell":Vector2(0,1), "foot":Vector2(310,473), "grip":Vector2(351,205), "angle":8.0, "hands":[Rect2(335,190,33,34),Rect2(376,158,33,32)]},
		"reload_seat": {"cell":Vector2(1,1), "foot":Vector2(262,473), "grip":Vector2(293,198), "angle":8.0, "hands":[Rect2(277,181,34,36),Rect2(306,219,32,29)]},
		"cooling": {"cell":Vector2(2,1), "foot":Vector2(212,473), "grip":Vector2(240,212), "angle":18.0, "hands":[Rect2(223,196,34,34)]},
	},
	"long": {
		"idle": {"cell":Vector2(0,0), "foot":Vector2(308,484), "grip":Vector2(327,224), "support":Vector2(405,267), "hands":[Rect2(311,208,33,34),Rect2(390,250,33,34)]},
		"aim": {"cell":Vector2(1,0), "foot":Vector2(243,484), "grip":Vector2(260,194), "support":Vector2(350,160), "hands":[Rect2(244,179,33,33),Rect2(333,143,35,34)]},
		"recoil": {"cell":Vector2(2,0), "foot":Vector2(211,484), "grip":Vector2(232,189), "support":Vector2(300,160), "hands":[Rect2(216,173,33,34),Rect2(284,143,34,34)]},
		"reload_open": {"cell":Vector2(0,1), "foot":Vector2(308,472), "grip":Vector2(331,200), "angle":12.0, "hands":[Rect2(315,184,33,34),Rect2(403,252,35,35)]},
		"reload_seat": {"cell":Vector2(1,1), "foot":Vector2(260,472), "grip":Vector2(276,201), "angle":12.0, "hands":[Rect2(259,185,35,34),Rect2(287,210,34,34)]},
		"cooling": {"cell":Vector2(2,1), "foot":Vector2(211,472), "grip":Vector2(232,228), "support":Vector2(294,256), "hands":[Rect2(216,212,34,34),Rect2(278,239,34,34)]},
	},
}
const WEAPONS := {
	"single": {"family":"pistol", "image":preload("res://assets/art/weapons_mass_20261013/single_v3.png"), "grip":Vector2(290,610), "muzzle":Vector2(1438,302), "scale":0.15, "part":Rect2(654,256,196,240), "release":Vector2(0,200)},
	"amplifier": {"family":"pistol", "image":preload("res://assets/art/weapons_mass_20261013/amplifier_v3.png"), "grip":Vector2(240,613), "muzzle":Vector2(1496,396), "scale":0.17, "part":Rect2(686,260,850,255), "release":Vector2(25,55)},
	"burst": {"family":"long", "image":preload("res://assets/art/weapons_mass_20261013/burst_v4.png"), "grip":Vector2(495,631), "support":Vector2(1150,535), "muzzle":Vector2(1495,390), "part":Rect2(702,475,232,390), "release":Vector2(0,310)},
	"scatter": {"family":"long", "image":preload("res://assets/art/weapons_mass_20261013/scatter_v3.png"), "grip":Vector2(350,628), "support":Vector2(1060,472), "muzzle":Vector2(1497,351), "part":Rect2(734,474,204,240), "release":Vector2(0,240)},
	"heavy": {"family":"long", "image":preload("res://assets/art/weapons_mass_20261013/heavy_v3.png"), "grip":Vector2(270,681), "support":Vector2(1040,752), "muzzle":Vector2(1470,486), "part":Rect2(284,98,376,277), "release":Vector2(0,-150)},
}
var gun_id := "single"
var pose_id := "idle"
var recoil_amount := 0.0
var reload_amount := 0.0
var heat_amount := 0.0
# Only burst is being compared; the original image and attachment space stay intact.
@export var coarse_burst := true:
	set(value):
		if coarse_burst == value: return
		coarse_burst = value
		_refresh_weapon_layer()
		queue_redraw()
var weapon_pixel_step := 4.0
var weapon_layer_viewport: SubViewport
var weapon_layer: Node2D

func _ready() -> void:
	weapon_layer_viewport = SubViewport.new()
	weapon_layer_viewport.name = "CoarseWeapon"
	weapon_layer_viewport.transparent_bg = true
	weapon_layer_viewport.handle_input_locally = false
	weapon_layer_viewport.size = Vector2i(ceil(768.0 / weapon_pixel_step), ceil(512.0 / weapon_pixel_step))
	add_child(weapon_layer_viewport)
	weapon_layer = preload("res://redesign/weapon_pixel_layer.gd").new()
	weapon_layer.actor = self
	weapon_layer.pixel_step = weapon_pixel_step
	weapon_layer.material = material
	weapon_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_layer_viewport.add_child(weapon_layer)
	_refresh_weapon_layer()

func _refresh_weapon_layer() -> void:
	if not is_instance_valid(weapon_layer): return
	weapon_layer_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if coarse_burst and gun_id == "burst" else SubViewport.UPDATE_DISABLED
	weapon_layer.queue_redraw()

# Source-space metal surfaces; tint follows the very same transformed texture.
const HEAT_REGIONS := {
	"single": Rect2(1000,215,455,182), "amplifier": Rect2(900,320,630,150),
	"burst": Rect2(1080,330,432,124), "scatter": Rect2(1200,170,330,420),
	"heavy": Rect2(1080,375,410,230),
}
const KICK_ANGLE := {"single": -7.0, "amplifier": -11.0, "burst": -4.0, "scatter": -7.0, "heavy": -5.0}

static func family(gun: String) -> String:
	return str(WEAPONS.get(gun, WEAPONS.single).family)

static func pose(gun: String, action: String) -> Dictionary:
	return POSES[family(gun)].get(action, POSES[family(gun)].idle)

static func weapon_transform(gun: String, action: String, recoil: float = 0.0) -> Transform2D:
	var weapon: Dictionary = WEAPONS.get(gun, WEAPONS.single)
	var frame := pose(gun, action)
	var factor := float(weapon.get("scale", 0.24))
	var angle := deg_to_rad(float(frame.get("angle", 0.0)))
	if weapon.family == "long":
		# Keep each long gun's scale fixed; support hand poses are registered below.
		var aim: Dictionary = POSES.long.aim
		var span: Vector2 = aim.support - aim.grip
		var source_span: Vector2 = weapon.support - weapon.grip
		factor = span.length() / source_span.length()
		if frame.has("support"):
			var target_span: Vector2 = frame.support - frame.grip
			angle = target_span.angle() - source_span.angle()
		if gun == "heavy" and action in ["aim", "recoil"]: angle = 0.0
	angle += deg_to_rad(float(KICK_ANGLE.get(gun, -5.0)) * clampf(recoil, 0.0, 1.0))
	var transform := Transform2D(angle, Vector2.ONE * factor, 0.0, FOOT - frame.foot + frame.grip)
	transform.origin -= transform.basis_xform(weapon.grip)
	return transform

static func muzzle(gun: String, action: String, foot: Vector2, scale_value: float, recoil: float = 0.0) -> Vector2:
	var weapon: Dictionary = WEAPONS.get(gun, WEAPONS.single)
	return (foot + (weapon_transform(gun, action, recoil) * weapon.muzzle - FOOT) * BODY_SCALE * scale_value).round()

static func opening(progress: float) -> float:
	# Extract, hold clear of the receiver, then visibly seat the part.
	if progress < 0.25: return smoothstep(0.0, 0.25, progress)
	if progress < 0.55: return 1.0
	return 1.0 - smoothstep(0.55, 0.90, progress)

func configure(gun: String, action: String, recoil: float = 0.0, reload_phase: float = -1.0, heat: float = 0.0) -> bool:
	var next_gun := gun if WEAPONS.has(gun) else "single"
	var next_recoil := snappedf(clampf(recoil, 0.0, 1.0), 0.025)
	var next_reload := 1.0 if action == "cooling" else (opening(reload_phase) if reload_phase >= 0.0 else (1.0 if action == "reload_open" else 0.35))
	next_reload = snappedf(next_reload, 0.025)
	var next_heat := snappedf(clampf(heat, 0.0, 1.0), 0.025)
	if gun_id == next_gun and pose_id == action and recoil_amount == next_recoil and reload_amount == next_reload and heat_amount == next_heat: return false
	gun_id = next_gun
	pose_id = action
	recoil_amount = next_recoil
	reload_amount = next_reload
	heat_amount = next_heat
	_refresh_weapon_layer()
	queue_redraw()
	return true

func body_texture() -> Texture2D:
	return OutfitArt.BODIES.get(outfit_id, BODIES)[family(gun_id)]

func registered_hands() -> Array[Rect2]:
	var result := foreground_hands(gun_id, pose_id)
	if outfit_id == "expedition" and family(gun_id) == "pistol" and pose_id == "aim": result[0] = Rect2(326, 189, 36, 34)
	return result

func registered_transform() -> Transform2D:
	var result := weapon_transform(gun_id, pose_id, recoil_amount)
	if outfit_id == "expedition" and family(gun_id) == "pistol" and pose_id == "aim": result.origin.x += 28.0
	return result

func _draw() -> void:
	var frame := pose(gun_id, pose_id)
	var body := body_texture()
	var body_position: Vector2 = FOOT - frame.foot
	var cell_position: Vector2 = frame.cell * CELL
	draw_texture_rect_region(body, Rect2(body_position, CELL), Rect2(cell_position, CELL))
	if coarse_burst and gun_id == "burst" and is_instance_valid(weapon_layer_viewport):
		draw_texture_rect(weapon_layer_viewport.get_texture(), Rect2(Vector2.ZERO, Vector2(weapon_layer_viewport.size) * weapon_pixel_step), false)
	else:
		draw_weapon_layers(self)
	# Redraw only the registered fingers, not the whole fist across the barrel.
	for hand: Rect2 in registered_hands():
		draw_texture_rect_region(body, Rect2(body_position + hand.position, hand.size), Rect2(cell_position + hand.position, hand.size))

static func foreground_hands(gun: String, action: String) -> Array[Rect2]:
	var frame := pose(gun, action)
	var regions: Array[Rect2] = []
	for index in range(frame.hands.size()):
		var hand: Rect2 = frame.hands[index]
		# Supporting fingers wrap under the fore-end. The upper knuckles stay
		# behind the gun so its continuous silhouette survives combat downscaling.
		if family(gun) == "long" and index == 1 and frame.has("support"):
			var top := maxf(hand.position.y, frame.support.y + 1.0)
			hand = Rect2(hand.position.x, top, hand.size.x, maxf(0.0, hand.end.y - top))
		regions.append(hand)
	return regions

func draw_weapon_layers(painter: CanvasItem, pixel_step: float = 1.0) -> void:
	var weapon: Dictionary = WEAPONS[gun_id]
	var raster := Transform2D(0.0, Vector2.ONE / pixel_step, 0.0, Vector2.ZERO)
	painter.draw_set_transform_matrix(raster * registered_transform())
	if pose_id in ["reload_open", "reload_seat", "cooling"]:
		_draw_open_weapon(painter, weapon, reload_amount, raster)
	else:
		_draw_weapon_region(painter, weapon.image, Rect2(Vector2.ZERO, weapon.image.get_size()))
	painter.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_open_weapon(painter: CanvasItem, weapon: Dictionary, progress: float, raster: Transform2D) -> void:
	var image: Texture2D = weapon.image
	var cut: Rect2 = weapon.part
	var extent := image.get_size()
	var pieces := [Rect2(0,0,extent.x,cut.position.y), Rect2(0,cut.end.y,extent.x,extent.y-cut.end.y), Rect2(0,cut.position.y,cut.position.x,cut.size.y), Rect2(cut.end.x,cut.position.y,extent.x-cut.end.x,cut.size.y)]
	for region: Rect2 in pieces:
		_draw_weapon_region(painter, image, region)
	if gun_id == "amplifier":
		# Break-action barrel pivots around the breech instead of floating away.
		var hinge := Vector2(cut.position.x, cut.end.y)
		var rotation := Transform2D(deg_to_rad(36.0 * progress), hinge)
		rotation.origin -= rotation.basis_xform(hinge)
		painter.draw_set_transform_matrix(raster * registered_transform() * rotation)
		_draw_weapon_region(painter, image, cut)
	else:
		_draw_weapon_region(painter, image, cut, weapon.release * progress)

func _draw_weapon_region(painter: CanvasItem, image: Texture2D, region: Rect2, offset: Vector2 = Vector2.ZERO) -> void:
	painter.draw_texture_rect_region(image, Rect2(region.position + offset, region.size), region)
	if heat_amount <= 0.0: return
	var metal := region.intersection(HEAT_REGIONS[gun_id])
	if not metal.has_area(): return
	# Alpha cutout also applies to this overlay. Empty pixels remain empty,
	# including while the break-action barrel rotates during cooling/reload.
	painter.draw_texture_rect_region(image, Rect2(metal.position + offset, metal.size), metal, Color(1.8, 0.80, 0.50, heat_amount * 0.65))

func set_outfit(id: String) -> bool:
	if outfit_id == id: return false
	outfit_id = id
	_refresh_weapon_layer()
	queue_redraw()
	return true

func registered_muzzle(foot: Vector2, scale_value: float) -> Vector2:
	return (foot + (registered_transform() * WEAPONS[gun_id].muzzle - FOOT) * BODY_SCALE * scale_value).round()
