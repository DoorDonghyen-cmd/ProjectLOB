extends "res://art_source/rivet_twohand_20261106/legacy_weapon_actor.gd"
## Art-only prototype. Production registrations and save IDs remain untouched.
const CONCEPTS := {
	"single": {"family":"pistol", "image":preload("res://assets/art/weapon_redesign_20261024/single_latch_v1.png"), "grip":Vector2(340,590), "muzzle":Vector2(1450,310), "scale":0.10, "catalog_scale":0.82, "part":Rect2(713,265,200,273), "release":Vector2(0,200), "heat":Rect2(1105,220,350,225), "bounds":Rect2(91,149,1367,804)},
	"burst": {"family":"long", "image":preload("res://assets/art/weapon_redesign_20261024/burst_ratchet_v1.png"), "grip":Vector2(570,570), "support":Vector2(1350,505), "muzzle":Vector2(1730,378), "part":Rect2(882,480,144,215), "release":Vector2(0,240), "heat":Rect2(1140,310,590,135), "bounds":Rect2(42,216,1692,512)},
}

func registered_transform() -> Transform2D:
	var weapon: Dictionary = CONCEPTS[gun_id]
	var frame := pose(gun_id, pose_id)
	var factor := float(weapon.get("scale", 0.24))
	var angle := deg_to_rad(float(frame.get("angle", 0.0)))
	if weapon.family == "long":
		var aim: Dictionary = POSES.long.aim
		var span: Vector2 = aim.support - aim.grip
		var source_span: Vector2 = weapon.support - weapon.grip
		factor = span.length() / source_span.length()
		if frame.has("support"):
			var target_span: Vector2 = frame.support - frame.grip
			angle = target_span.angle() - source_span.angle()
	angle += deg_to_rad(float(KICK_ANGLE[gun_id]) * recoil_amount)
	var result := Transform2D(angle, Vector2.ONE * factor, 0.0, FOOT - frame.foot + frame.grip)
	result.origin -= result.basis_xform(weapon.grip)
	if outfit_id == "expedition" and family(gun_id) == "pistol" and pose_id == "aim": result.origin.x += 28.0
	return result

func draw_weapon_layers(painter: CanvasItem, pixel_step: float = 1.0) -> void:
	var weapon: Dictionary = CONCEPTS[gun_id]
	var raster := Transform2D(0.0, Vector2.ONE / pixel_step, 0.0, Vector2.ZERO)
	painter.draw_set_transform_matrix(raster * registered_transform())
	if pose_id in ["reload_open", "reload_seat", "cooling"]:
		_draw_open_weapon(painter, weapon, reload_amount, raster)
	else:
		_draw_weapon_region(painter, weapon.image, Rect2(Vector2.ZERO, weapon.image.get_size()))
	painter.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_weapon_region(painter: CanvasItem, source: Texture2D, region: Rect2, offset: Vector2 = Vector2.ZERO) -> void:
	painter.draw_texture_rect_region(source, Rect2(region.position + offset, region.size), region)
	if heat_amount <= 0.0: return
	var metal := region.intersection(CONCEPTS[gun_id].heat)
	if metal.has_area():
		painter.draw_texture_rect_region(source, Rect2(metal.position + offset, metal.size), metal, Color(1.8, 0.80, 0.50, heat_amount * 0.65))

func registered_muzzle(foot: Vector2, scale_value: float) -> Vector2:
	return (foot + (registered_transform() * CONCEPTS[gun_id].muzzle - FOOT) * BODY_SCALE * scale_value).round()
