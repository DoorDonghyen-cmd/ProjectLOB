extends SceneTree
## Real renderer + public input; all saves are isolated by the launcher.
const Content = preload("res://redesign/content.gd")
const Pixel = preload("res://redesign/pixel_art.gd")
var screen: Control
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(id + ".png"))

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "available input " + key)
	if button == null or button.disabled: return
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	while screen.busy: await process_frame
	await settle()

func fixture() -> void:
	screen._debug_weapon("single")
	screen.model.s.course = false
	screen.model.s.floor = 5
	screen.model.s.phase = "plan"
	screen.model.s.plan = []
	screen.model.s.plan_load_order = []
	screen.model.s.magazine = []
	screen.model.s.turn = 0
	screen.model.s.hand = ["charge", "precise", "pierce", "bore", "arc"]
	screen.model.s.deck = screen.model.s.hand.duplicate()
	screen.model.s.draw = []
	screen.model.s.discard = []
	screen.model.s.reinforcements = []
	screen.model.s.enemies = []
	var kinds := ["runner", "wall", "evader", "absorber"]
	for i in range(4):
		var kind: String = kinds[i]
		var enemy := {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": 12 + i * 3, "max_hp": 12 + i * 3, "def": 3 if i == 1 else 0, "speed": 2, "distance": 12 + i * 5, "burn": 0, "lane": i}
		if kind == "evader": enemy.weakness = "electric"
		if kind == "absorber":
			enemy.barrier = 2
			enemy.barrier_max = 2
		screen.model.s.enemies.append(enemy)
	screen.redraw()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for id in ["reclaimer", "foundry", "runner", "wall", "evader", "caster", "absorber", "stance"]:
		check(Pixel.texture(id) != null, "pixel asset " + id)
	fixture()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		check(not screen.main_scroll.get_v_scroll_bar().visible, "no scroll " + str(resolution))
		for key in ["BattleView", "AmmoGrid", "QueuePanel", "confirm"]:
			var control := screen.find_child(key, true, false) as Control
			check(control != null and Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()), "bounds " + key)
		for i in range(4):
			check(Rect2(Vector2.ZERO, screen.battle_view.size).encloses(screen.battle_view.enemy_plaque(i)), "enemy plaque bounds")
			check(screen.battle_view.enemy_feet(i).y > screen.battle_view.ground_y(), "feet on foreground floor")
			for j in range(i): check(not screen.battle_view.enemy_plaque(i).intersects(screen.battle_view.enemy_plaque(j)), "nonoverlapping enemy stats")
		await capture("battle_%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1008, 630)
	await settle()
	var feet: Array = []
	for i in range(4): feet.append(screen.battle_view.enemy_feet(i))
	await tap("load_charge")
	await tap("load_precise")
	await tap("load_pierce")
	check(screen.model.s.plan == ["charge", "precise", "pierce"], "tap creates intended order")
	await capture("combo_planned")
	await tap("confirm")
	check(not screen.main_scroll.get_v_scroll_bar().visible, "ready fits without scrolling")
	await capture("combo_ready")
	screen.presentation_speed = 0.15
	await tap("fire")
	while screen.busy: await process_frame
	await capture("combo_resolved")
	check(not screen.last_presentation.is_empty() and screen.last_presentation.get("shown_enemies", []) == screen.last_presentation.get("after", {}).get("enemies", []), "display matches combat resolver")
	for i in range(4): check(screen.battle_view.enemy_feet(i).y == feet[i].y, "no vertical jump after movement or death")
	fixture()
	for enemy in screen.model.s.enemies: enemy.distance = 25
	screen.redraw()
	await capture("crowded_four")
	# Inspect actual hit area when all four actors share the same distance.
	await tap("enemy_info_2")
	var details := screen.find_child("EnemyDetails", true, false)
	check(details != null and int(details.get_meta("enemy_index", -1)) == 2, "enemy plaque opens touch details")
	for child in screen.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await settle()
	fixture()
	screen.model.s.enemies[0].kind = "caster"
	screen.model.s.enemies[0].name = Content.ENEMY_NAMES.caster
	screen.model.s.enemies[0].charge = 1
	screen.model.s.enemies[0].charge_max = 3
	screen.model.s.enemies[1].kind = "stance"
	screen.model.s.enemies[1].name = Content.ENEMY_NAMES.stance
	screen.model.s.enemies[1].stance = true
	screen.redraw()
	await capture("special_roles")
	print("PIXEL BATTLE COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
