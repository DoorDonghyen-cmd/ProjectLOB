extends SceneTree

const Actor = preload("res://redesign/weapon_actor.gd")
const Content = preload("res://redesign/content.gd")
const ACTIONS = ["idle", "aim", "recoil", "reload_open", "reload_seat", "cooling"]

func _initialize() -> void:
	var output := OS.get_environment("OUTFIT_STYLE_MANIFEST")
	var file := FileAccess.open(output, FileAccess.WRITE) if not output.is_empty() else null
	if file == null:
		quit(2)
		return
	var rows: Array[Dictionary] = []
	var actor := Actor.new()
	for outfit: String in Content.OUTFITS:
		for gun in ["amplifier", "deadbolt"]:
			for action: String in ACTIONS:
				if Actor.body_action(gun, action) != action:
					continue
				var frame := Actor.frame_for(outfit, gun, action)
				var hands: Array = []
				for hand: Rect2 in frame.hands:
					hands.append(rect_values(hand))
				var front: Array = []
				actor.outfit_id = outfit
				actor.gun_id = gun
				actor.pose_id = action
				for hand: Rect2 in actor.registered_hands():
					front.append([hand.position.x, hand.position.y, hand.size.x, hand.size.y])
				rows.append({
					"outfit": outfit,
					"family": Actor.family(gun),
					"action": action,
					"asset": Actor.body_for(outfit, gun, action).resource_path.get_file(),
					"source": rect_values(frame.source),
					"bounds": rect_values(frame.bounds),
					"hands": hands,
					"front_hands": front,
					"foot": [frame.foot.x, frame.foot.y],
					"scale": frame.scale,
				})
	file.store_string(JSON.stringify(rows, "\t"))
	actor.free()
	print("OUTFIT STYLE MANIFEST poses=", rows.size())
	quit()

func rect_values(rect: Rect2) -> Array[int]:
	return [floori(rect.position.x), floori(rect.position.y), ceili(rect.size.x), ceili(rect.size.y)]
