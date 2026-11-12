extends "res://tests/campaign_magazine_ui.gd"

const Cases = preload("res://tests/surface_fx_cases.gd")
const Data = preload("res://redesign/campaign_content.gd")

func warning_frame(label: String, expected: Dictionary) -> Color:
 var board = host.campaign_hud.board
 check(board.proximity_warning == expected, "warning uses the resolved state " + label)
 var rect: Rect2 = board.readout_layer.proximity_notice_rect()
 var immediate := int(expected.get("actions", 0)) == 1
 check(rect.has_area() == immediate, "text only when the very next enemy action can be fatal " + label)
 if immediate:
  check(Rect2(Vector2.ZERO, board.size).encloses(rect), "warning plate fits the field " + label)
  check(not rect.intersects(board.reinforcement_strip_rect()), "warning stays clear of reserve readout " + label)
  for index in board._alive_indices():
   check(not rect.intersects(board.enemy_plaque(index)), "warning leaves enemy HP clear " + label)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.save_png(output.path_join(label + ".png"))
 var point := Vector2i((board.get_global_transform_with_canvas() * Vector2(1, floorf(board.size.y * 0.5))).round())
 if immediate:
  var notice_pixel := Vector2i((board.get_global_transform_with_canvas() * (rect.position + Vector2(6, 4))).round())
  check(image.get_pixelv(notice_pixel).is_equal_approx(Color("251a19")), "opaque notice actually rendered " + label)
 return image.get_pixelv(point)

func contact_sequence(resolution: Vector2i) -> void:
 root.size = resolution
 var c = Cases.make("plain")
 c.model.s.enemies[0].merge({"hp": 2, "distance": 6, "speed": 3}, true)
 c.model.s.enemies[1].distance = 45
 c.model.s.heat = 1
 await mount(c)
 host.save_enabled = false
 var tag := str(resolution.x)
 var caution := await warning_frame("contact_early_" + tag, {"actions": 2, "kind": "contact"})
 await tap("Cool")
 check(c.model.s.phase == "ready" and int(c.model.s.enemies[0].distance) == 3, "cooling spends one actual approach action")
 var critical := await warning_frame("contact_immediate_" + tag, {"actions": 1, "kind": "contact"})
 check(critical.r - critical.g > caution.r - caution.g + 0.10, "immediate contact paints a stronger border than early approach " + tag)
 await tap("Fire")
 check(c.model.s.phase == "ready" and int(c.model.s.enemies[0].hp) == 0, "player can still fire to remove the threat")
 var clear := await warning_frame("contact_clear_" + tag, {})
 check(caution.r - caution.g > clear.r - clear.g + 0.06, "killing the near enemy clears the outer warning pixels " + tag)
 hud_bounds()

func projectile_sequence() -> void:
 var c = Cases.make("plain")
 c.model.s.enemies[0].distance = 36
 c.model.s.enemies[1] = Data._enemy(["spitter", 20, 0, 0, 45])
 c.model.s.enemies[1].ranged_phase = "waiting"
 c.model.s.enemies[1].ranged_left = 0
 c.model.s.projectile_serial = 1
 c.model.s.projectiles = [{"uid": 1, "source": 1, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": 6, "distance": 6, "burn": 0}]
 c.model.assign_opening_lanes()
 await mount(c)
 host.save_enabled = false
 host.campaign_hud.board.reduced_feedback = true
 await warning_frame("pressure_immediate_1008", {"actions": 1, "kind": "projectile"})
 await tap("Fire")
 check(c.model.s.phase == "ready", "interception avoids the forecast projectile loss")
 await warning_frame("pressure_clear_1008", {})

func run() -> void:
 output = OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/proximity_ui/"):
  quit(2)
  return
 Input.emulate_mouse_from_touch = true
 root.content_scale_size = Vector2i.ZERO
 root.content_scale_factor = 1
 for resolution in [Vector2i(1280, 800), Vector2i(1008, 454)]: await contact_sequence(resolution)
 await projectile_sequence()
 if is_instance_valid(host): host.free()
 FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
 print("PLAYTEST REVISION PROXIMITY UI COMPLETE checks=%d failures=%d" % [checks, failures.size()])
 quit(0 if failures.is_empty() else 1)
