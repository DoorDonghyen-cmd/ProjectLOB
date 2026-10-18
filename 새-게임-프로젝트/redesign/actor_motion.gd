extends RefCounted
## Presentation only: authored key poses and small, grounded secondary motion.
const HERO_ATLAS = preload("res://assets/art/actor_motion_20261005/reclaimer_actions_v1.png")
const PoseData = preload("res://redesign/hero_pose_data.gd")
const HERO_CELL = PoseData.CELL
const HERO_SCALE = PoseData.SCALE
const HERO_FRAMES = PoseData.FRAMES

static func hero_source(pose: String) -> Rect2:
	return Rect2(HERO_FRAMES[pose].cell * HERO_CELL, HERO_CELL)

static func hero_rect(pose: String, foot: Vector2, scale_value: float) -> Rect2:
	var factor := scale_value * HERO_SCALE
	return Rect2((foot - HERO_FRAMES[pose].anchor * factor).round(), (HERO_CELL * factor).round())

static func hero_muzzle(pose: String, foot: Vector2, scale_value: float) -> Vector2:
	return (foot + (HERO_FRAMES[pose].muzzle - HERO_FRAMES[pose].anchor) * scale_value * HERO_SCALE).round()

static func enemy_rect(rect: Rect2, kind: String, clock: float, stride: float, hit: float, death: float) -> Rect2:
	var result := rect
	var height_change := 0.0
	var width_change := 0.0
	var floating := kind in ["caster", "absorber", "stance"]
	if floating:
		result.position.y += roundf(sin(clock * 1.8) * 1.5)
	else:
		# Deform around planted feet, never lift the whole body off the floor.
		height_change = -roundf((sin(clock * 2.0) + 1.0) * 0.5)
	if stride != 0:
		var step := absf(sin(stride))
		height_change -= roundf(step * (2.0 if kind == "wall" else 4.0))
		width_change += roundf(step * (2.0 if kind == "wall" else 3.0))
		if floating: result.position.y -= roundf(step * 2.0)
	width_change += roundf(hit * 3.0)
	height_change -= roundf(hit * 3.0 + death * 14.0)
	result.position += Vector2(-width_change * 0.5, -height_change)
	result.size += Vector2(width_change, height_change)
	return Rect2(result.position.round(), result.size.round())
