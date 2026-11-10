extends SceneTree
const Actor = preload("res://redesign/weapon_actor.gd")
const Content = preload("res://redesign/content.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: " + label)

func _initialize() -> void:
	# The recoil path must rotate the barrel without teleporting the wrist,
	# changing costume/scale, or leaving the muzzle behind on the aiming pose.
	for outfit in Content.OUTFITS:
		var actor = Actor.new()
		actor.set_outfit(outfit)
		actor.configure("amplifier", "aim")
		var aim := Actor.frame_for(outfit, "amplifier", "aim")
		var anchor: Vector2 = actor.registered_transform() * Actor.WEAPONS.amplifier.grip
		var source: String = actor.body_texture().resource_path
		var scale_before: Vector2 = actor.registered_transform().get_scale()
		var angle_before: float = actor.registered_transform().get_rotation()
		var muzzle_before: Vector2 = actor.registered_muzzle(Vector2(140, 300), 0.3)
		for step in range(21):
			var kick := step / 20.0
			actor.configure("amplifier", "recoil", kick)
			var transform: Transform2D = actor.registered_transform()
			check((transform * Actor.WEAPONS.amplifier.grip).distance_to(anchor) < 0.01, "stationary wrist %s/%d" % [outfit, step])
			check(actor.body_texture().resource_path == source, "costume retained %s/%d" % [outfit, step])
			check(transform.get_scale().is_equal_approx(scale_before), "weapon scale retained %s/%d" % [outfit, step])
			var projected: Vector2 = (Vector2(140, 300) + (transform * Actor.WEAPONS.amplifier.muzzle - Actor.FOOT) * Actor.BODY_SCALE * 0.3).round()
			check(projected == actor.registered_muzzle(Vector2(140, 300), 0.3), "effect muzzle follows rendered barrel %s/%d" % [outfit, step])
		check(actor.registered_transform().get_rotation() < angle_before, "barrel still kicks " + outfit)
		check(actor.registered_muzzle(Vector2(140, 300), 0.3).distance_to(muzzle_before) > 1, "muzzle actually moves " + outfit)
		actor.configure("amplifier", "recoil", 0)
		check(actor.registered_muzzle(Vector2(140, 300), 0.3) == muzzle_before, "recoil returns to aim without jump " + outfit)
		actor.configure("amplifier", "reload_open", 0, 0.4)
		check(actor.reload_amount > 0.9, "breech still opens " + outfit)
		check(Actor.frame_for(outfit, "amplifier", "reload_open").source != aim.source, "reload keeps its own body pose " + outfit)
		actor.free()
	print("SPIKE MOTION RULES COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
