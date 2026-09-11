extends SceneTree
const Model = preload("res://redesign/model.gd")
var screen: Control
var passed := 0
var failed := 0
var evidence: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL: " + label)

func settle() -> void:
	for i in range(4): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func click(id: String) -> void:
	var button := screen.find_child(id, true, false) as Button
	check(button != null and not button.disabled, "enabled " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await settle()

func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://" + id + ".png")
	evidence.append(id)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.seed_input.text = "731042"
	await click("start_single")
	# Real loading animation and lock; no model fixture yet.
	screen.find_child("load_basic", true, false).pressed.emit()
	for i in range(3): await process_frame
	check(screen.busy and not screen.magazine_view.incoming.is_empty(), "round travels into visible magazine")
	var before: Dictionary = screen.model.s.duplicate(true)
	screen._load("basic")
	screen._confirm()
	check(screen.model.s == before, "loading animation rejects duplicate commands")
	await capture("01_loading_flight")
	await settle()
	await click("load_charge")
	check(screen.magazine_view.stack == ["basic", "charge"], "visual magazine keeps LIFO loading order")
	await capture("02_setup_link")
	await click("confirm")
	screen.find_child("fire", true, false).pressed.emit()
	for i in range(3): await process_frame
	check(screen.busy and not screen.battle_view.bullet.is_empty(), "projectile visible while resolving presentation")
	before = screen.model.s.duplicate(true)
	screen._fire()
	screen._reload()
	screen._to_menu()
	check(screen.model.s == before and screen.page == "run", "fire/reload/menu locked during shot")
	await capture("03_projectile")
	await click("skip_animation")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "shown result equals authoritative model")
	await click("fire")
	check(screen.model.s.phase == "reward", "setup followed by strengthened basic actually wins")
	# Explicit visual QA fixtures: do not count these as campaign wins.
	for kind in ["push", "blocked", "miss", "burst"]:
		screen.model.start("burst" if kind == "burst" else "single", 731042)
		screen.model.s.enemies = [{"kind":"runner","name":"검증 사족체","hp":20,"max_hp":20,"def":0,"eva":4,"speed":2,"distance":16,"slow":0}]
		screen.model.s.hand = ["push", "charge", "bore", "precise", "mark"]
		if kind == "blocked": screen.model.s.enemies[0].def = 4
		if kind == "miss": screen.model.s.enemies[0].eva = 9
		if kind == "burst":
			screen.model.s.enemies[0].hp = 4
			screen.model.s.enemies.append({"kind":"wall","name":"검증 장갑벽","hp":12,"max_hp":12,"def":0,"eva":4,"speed":1,"distance":20,"slow":0})
		screen.page = "run"
		screen.redraw()
		await settle()
		if kind == "burst":
			for id in ["basic", "basic", "basic", "charge"]: await click("load_" + id)
		else: await click("load_" + ("push" if kind == "push" else "basic"))
		await click("confirm")
		var authoritative = Model.new()
		authoritative.s = screen.model.s.duplicate(true)
		authoritative.fire()
		screen.find_child("fire", true, false).pressed.emit()
		await create_timer(0.28).timeout
		check(screen.battle_view.float_target >= 0, kind + " impact phase visible")
		await capture("04_" + kind + "_impact")
		await settle()
		check(screen.model.s == authoritative.s, kind + " animation does not change combat rules")
		check(screen.last_presentation.shown_enemies == authoritative.s.enemies, kind + " final distances and HP match")
		if kind == "burst":
			var events: Array = screen.last_presentation.events
			var targets: Array = []
			for event in events:
				if event.kind == "shot": targets.append(event.target)
			check(targets == [0, 0, 1, 1], "burst retargets visually after killing front enemy")
			check(events.back().kind == "advance" and screen.model.s.turns == 1, "advance once after entire burst")
	await click("reload")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "reload movement matches final state")
	var output := FileAccess.open("user://motion_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":passed,"failed":failed,"captures":evidence,"scope":"real first encounter; explicit impact/burst fixtures; animation/model invariants"}, "\t"))
	print("REDESIGN MOTION: %d passed / %d failed" % [passed, failed])
	quit(1 if failed else 0)
