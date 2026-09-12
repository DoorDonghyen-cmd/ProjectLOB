extends SceneTree
const Model = preload("res://redesign/model.gd")
const Forecast = preload("res://redesign/forecast.gd")
var screen: Control
var passed := 0
var failed := 0
var captures: Array = []

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL: " + label)

func enemy(distance: int, speed: int = 1, hp: int = 20, armor: int = 0, evasion: int = 4) -> Dictionary:
	return {"kind":"runner", "name":"검증 적", "distance":distance, "speed":speed, "hp":hp, "max_hp":hp, "def":armor, "eva":evasion, "slow":0}

func fixture(gun: String, enemies: Array, order: Array):
	var game = Model.new()
	game.start(gun, 731042)
	game.s.enemies = enemies.duplicate(true)
	game.s.hand = []
	for id in order:
		if id != "basic": game.s.hand.append(id)
	var loading := order.duplicate()
	loading.reverse()
	for id in loading: check(game.load_round(id), "legal fixture round " + id)
	return game

func verify(label: String, game, targets: Array) -> Dictionary:
	var before: Dictionary = game.s.duplicate(true)
	var forecast := Forecast.analyze(game.s)
	check(game.s == before, label + " source state and RNG unchanged")
	check(forecast == Forecast.analyze(game.s), label + " repeated preview stable")
	var actual_targets: Array = []
	for shot in forecast.shots: actual_targets.append(shot.target)
	check(actual_targets == targets, label + " independently expected target order")
	game.confirm()
	check(Forecast.analyze(game.s) == forecast, label + " plan and confirmed predictions agree")
	var actual: Array = []
	while game.fire():
		for shot in game.s.history.back().detail.results: actual.append(shot)
	check(game.s.enemies == forecast.enemies and game.s.phase == forecast.phase and game.s.magazine == forecast.remaining, label + " real final command state matches")
	check(actual.size() == forecast.shots.size(), label + " actual shot count matches")
	for i in range(actual.size()):
		var predicted: Dictionary = forecast.shots[i].duplicate(true)
		predicted.erase("action")
		check(actual[i] == predicted, label + " actual shot " + str(i))
	return forecast

func settle() -> void:
	for i in range(5): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func click(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "enabled " + key)
	if button != null and not button.disabled: button.pressed.emit()
	await settle()

func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("user://" + name + ".png")
	captures.append(name)
	for key in ["confirm", "fire", "reload"]:
		var button := screen.find_child(key, true, false) as Button
		if button: check(button.get_global_rect().end.y <= 800, "onscreen " + name + key)

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog: child.get_ok_button().pressed.emit()
	await settle()

func _run() -> void:
	verify("burst push and kill", fixture("burst", [enemy(16), enemy(17, 1, 4)], ["push", "charge", "basic", "basic"]), [0, 1, 1, 0])
	var f := verify("single moving target", fixture("single", [enemy(10, 0), enemy(11, 3)], ["basic", "basic", "basic"]), [0, 1, 1])
	check(f.turns == 3 and f.enemies[1].distance == 2, "single advances after every shot")
	f = verify("burst same distance", fixture("burst", [enemy(16), enemy(16)], ["basic", "basic", "basic"]), [0, 0, 0])
	check(f.turns == 1 and f.enemies[0].distance == 15, "burst advances only once")
	f = verify("early clear", fixture("burst", [enemy(16, 1, 1)], ["basic", "basic", "basic"]), [0])
	check(f.phase == "reward" and f.remaining.size() == 2, "unfired rounds survive early clear")
	f = verify("lethal single", fixture("single", [enemy(1)], ["basic", "basic", "basic"]), [0])
	check(f.phase == "lost" and f.remaining.size() == 2 and f.turns == 1, "lethal movement interrupts later rounds")
	f = verify("missed setup", fixture("burst", [enemy(16, 1, 20, 0, 9)], ["charge", "precise"]), [0, 0])
	check(not f.shots[0].hit and f.shots[1].damage == 7, "setup persists despite miss and buffs next round")
	f = verify("blocked push", fixture("burst", [enemy(16, 1, 20, 4), enemy(17)], ["push", "basic"]), [0, 1])
	check(f.shots[0].damage == 0 and f.shots[0].push == 2, "blocked hit still changes distance")
	# Both are at 7m after the first advance, so the stable A tie-break wins.
	f = verify("slow consumed between single shots", fixture("single", [enemy(8, 3), enemy(9, 2)], ["slow", "basic"]), [0, 0])
	check(f.enemies[0].distance == 4 and f.enemies[1].distance == 5, "slow affects one advance only")
	var limited = fixture("burst", [enemy(16), enemy(17)], ["push", "push", "basic"])
	limited.s.push_left = 0
	f = verify("spent push budget", limited, [0, 0, 0])
	check(f.shots[0].push == 0 and f.shots[1].push == 0, "forecast honors remaining magazine push budget")
	var empty = Model.new()
	empty.start("single", 731042)
	f = Forecast.analyze(empty.s)
	check(f.shots.is_empty() and f.turns == 0, "empty plan has no predicted command")
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.05
	root.add_child(screen)
	await settle()
	await click("dev")
	await click("debug_multi_target")
	check(screen.debug_session and screen.magazine_view.forecast.shots.size() == 4, "developer shortcut gives isolated full magazine forecast")
	await capture("01_multi_plan")
	var before: Dictionary = screen.model.s.duplicate(true)
	var target: int = screen.model.target_index()
	# Actual viewport pointer events on enemy B's silhouette, not its signal.
	var point: Vector2 = screen.battle_view.global_position + screen.battle_view.enemy_position(1)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await settle()
	var detail := screen.find_child("EnemyDetails", true, false)
	check(detail != null and detail.get_meta("enemy_index") == 1, "click enemy B opens its own detail")
	check(screen.model.s == before and screen.model.target_index() == target and screen.battle_view.target == target, "inspection does not select combat target or change state")
	await capture("02_enemy_detail")
	await close_dialogs()
	screen.find_child("enemy_info_0", true, false).grab_focus()
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key)
	await settle()
	detail = screen.find_child("EnemyDetails", true, false)
	check(detail != null and detail.get_meta("enemy_index") == 0, "keyboard opens individual enemy details")
	await close_dialogs()
	await click("undo")
	check(screen.combat_forecast.shots[0].id == "charge", "undo recalculates first predicted round")
	await click("load_push")
	await click("confirm")
	await capture("03_multi_ready")
	var predicted: Array = screen.combat_forecast.shots.duplicate(true)
	await click("fire")
	var shown: Array = []
	for event in screen.last_presentation.events:
		if event.kind == "shot": shown.append(event.target)
	var predicted_targets: Array = []
	for shot in predicted: predicted_targets.append(shot.target)
	check(shown == predicted_targets, "actual visual burst follows forecast targets")
	await capture("04_multi_after")
	# Same/near-distance three-enemy display fixture, retaining real load commands.
	screen.model.start("burst", 731042)
	screen.model.s.floor = 6
	screen.model.begin_encounter()
	screen.model.s.hand = ["push", "charge", "precise", "bore", "mark"]
	for i in range(3): screen.model.s.enemies[i].distance = 16
	for id in ["basic", "basic", "charge", "push"]: screen.model.load_round(id)
	screen.redraw()
	await capture("05_three_same_distance")
	root.size = Vector2i(960, 600)
	await capture("06_three_small_window")
	var file := FileAccess.open("user://multi_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"captures":captures,"scope":"deterministic fixtures and actual viewport pointer/keyboard inspection; not campaign wins"}, "\t"))
	print("REDESIGN MULTI: %d passed / %d failed" % [passed, failed])
	quit(1 if failed else 0)
