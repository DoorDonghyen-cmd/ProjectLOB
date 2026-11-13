extends "res://tests/supply_live_ui.gd"
## Launch tour (2026-11-12, user: "런칭 직전 수준까지 전체 작업"). One real new run from the
## title to the ending, with the current rules of a new run. Every kind of screen is captured
## the first time it appears, in the order a player meets it. Combats are won by the solver;
## rewards, shops and gates use real campaign calls. QA_TOUR_SIZE=1170x540 (phone, default),
## QA_GUN, QA_SEED. Captures: QA_OUTPUT_DIR/NN_label.png, list in tour.json.
const FireSolver = preload("res://tests/fire_control_solver.gd")
const WideSolver = preload("res://tests/central_combat_solver.gd")
var seen: Dictionary = {}
var order: Array = []
var gun := "single"
var tour_seed := 17
var visited_kinds: Dictionary = {}
var log_lines: PackedStringArray = []

func snap(label: String) -> void:
	if seen.has(label): return
	seen[label] = true
	var file := "%03d_%s" % [order.size() + 1, label]
	order.append(file)
	await capture(file)

func note(text: String) -> void:
	log_lines.append(text)
	print("TOUR " + text)

func remount(c) -> void:
	await mount(c)
	await settle()

func solve_and_win(c) -> bool:
	var solver = FireSolver.new()
	var path: Array = solver.solve(c.model)
	if path.is_empty():
		solver.candidate_limit = 1800
		path = solver.solve(c.model, 12, 26)
	if path.is_empty():
		var wide = WideSolver.new()
		wide.candidate_limit = 4000
		path = wide.solve(c.model, 24, 40)
	if path.is_empty(): return false
	for item in path:
		match str(item.action):
			"fire":
				c.model.s.fire_heat_trial.rounds = int(item.get("rounds", 0)); c.model.fire()
			"reload": c.model.reload_magazine()
			"cool": c.model.cool_magazine()
			"eject": c.model.eject_magazine_rounds(item.indices)
			"emergency": c.model.emergency_resupply()
		c.sync_combat()
	return c.s.phase != "combat"

func place_key(node: Dictionary) -> String:
	var key := str(node.get("kind", ""))
	if node.get("workshop", false): key += "_workshop"
	if node.get("elite", false): key += "_elite"
	return key

func choose_node(c) -> Dictionary:
	var choices: Array = c.choices()
	for wanted in ["shop", "supply_workshop", "supply", "event", "combat_elite"]:
		for option in choices:
			if place_key(option) == wanted and not visited_kinds.has(wanted): return option
	for wanted in ["shop", "supply_workshop", "supply", "event", "combat", "combat_elite"]:
		for option in choices:
			if place_key(option) == wanted: return option
	return choices[0]

func combat_overlays(c, tag: String) -> void:
	var hud = host.campaign_hud
	if not is_instance_valid(hud): return
	for entry in [["Help", "help"], ["Parts", "build"]]:
		var button: Button = hud.node(entry[0])
		if button != null and button.is_visible_in_tree():
			button.pressed.emit(); await settle()
			await snap("combat_%s_%s" % [entry[1], tag])
			hud.close_detail(); await settle()
	if not c.model.s.magazine.is_empty():
		hud.hud.inspect_round(0); await settle()
		await snap("combat_round_detail_" + tag)
		hud.close_detail(); await settle()
	hud.inspect_enemy(0); await settle()
	await snap("combat_enemy_detail_" + tag)
	hud.close_detail(); await settle()
	hud.hud.open_menu(); await settle()
	await snap("combat_menu_" + tag)
	hud.node("Help").pressed.emit(); await settle()
	await snap("combat_help_" + tag)
	hud.close_detail(); await settle()
	hud.hud.close_menu(); await settle()

## Press the visible button with this caption, capture what opens, then return to the screen.
func press_and_snap(c, caption: String, label: String) -> void:
	if seen.has(label): return
	for button in host.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or button.disabled or str(button.text).strip_edges() != caption: continue
		button.pressed.emit(); await settle(); await settle()
		await snap(label)
		for key in ["workspace_close", "DialogClose"]:
			var close := host.find_child(key, true, false) as Button
			if close != null and close.is_visible_in_tree(): close.pressed.emit()
		await settle()
		await remount(c)
		return

## The ending story has one button to the results; the results page has its own tabs/buttons.
func open_results(phase: String) -> void:
	var to_results := host.find_child("story_results", true, false) as Button
	if to_results != null and to_results.is_visible_in_tree():
		to_results.pressed.emit(); await settle()
		await snap("results_page_" + phase)
	for button in host.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or button.disabled: continue
		if str(button.text).contains("기록") or str(button.text).contains("상세"):
			button.pressed.emit(); await settle()
			await snap("results_%s_%s" % [phase, str(button.name)])
			var close := host.find_child("workspace_close", true, false) as Button
			if close == null: close = host.find_child("DialogClose", true, false) as Button
			if close != null and close.is_visible_in_tree(): close.pressed.emit()
			await settle()
			break

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	var size_text := OS.get_environment("QA_TOUR_SIZE")
	if size_text.is_empty(): size_text = "1170x540"
	root.size = Vector2i(int(size_text.get_slice("x", 0)), int(size_text.get_slice("x", 1)))
	if not OS.get_environment("QA_GUN").is_empty(): gun = OS.get_environment("QA_GUN")
	if not OS.get_environment("QA_SEED").is_empty(): tour_seed = int(OS.get_environment("QA_SEED"))
	# Title and the windows a player can open before the first run.
	host = load("res://redesign/main.tscn").instantiate()
	root.add_child(host); await settle()
	await snap("title_first")
	for entry in [["_guide", "title_guide"], ["_rules", "title_rules"], ["_settings", "title_settings"], ["_city_archive", "title_archive"]]:
		host.call(entry[0]); await settle()
		await snap(entry[1])
		var close := host.find_child("DialogClose", true, false) as Button
		if close != null and close.is_visible_in_tree(): close.pressed.emit()
		else: host._to_menu()
		await settle()
	host._to_menu(); await settle()
	# Preparation.
	host._open_preparation(false); await settle()
	await snap("prepare")
	for entry in [["weapon_info", "prepare_weapon_info"], ["starting_deck", "prepare_deck"], ["preparation_options", "prepare_options"]]:
		var button := host.find_child(entry[0], true, false) as Button
		if button != null and button.is_visible_in_tree():
			button.pressed.emit(); await settle()
			await snap(entry[1])
			var close := host.find_child("DialogClose", true, false) as Button
			if close != null: close.pressed.emit()
			await settle()
	# The run.
	var c = Campaign.new()
	c.start(gun, tour_seed, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	var steps := 0
	var first_combat := true
	while steps < 400:
		steps += 1
		if c.departure_pending():
			await remount(c)
			await snap("departure_%d" % steps)
			c.advance_departure(false)
			continue
		if c.restoration_pending():
			await remount(c)
			await snap("restoration")
			c.restore_supply()
			continue
		var phase := str(c.s.phase)
		var region := int(c.s.region) + 1
		match phase:
			"map":
				await remount(c)
				await snap("map_r%d" % region)
				if not seen.has("map_legend"):
					for entry in [["범례", "map_legend"], ["자세히", "map_place"], ["빌드", "map_build"], ["기록", "map_archive"], ["메뉴", "map_menu"]]:
						await press_and_snap(c, str(entry[0]), str(entry[1]))
				var node := choose_node(c)
				visited_kinds[place_key(node)] = true
				note("enter r%d f%d %s" % [region, int(node.get("floor", 0)), place_key(node)])
				if not c.enter(int(node.id)): note("enter refused"); break
				c.sync_combat()
			"combat":
				var node: Dictionary = c.node()
				var tag := "r%d%s" % [region, "_boss" if str(node.get("kind", "")) == "boss" else "_elite" if node.get("elite", false) else ""]
				await remount(c)
				await snap("combat_" + tag)
				if first_combat:
					first_combat = false
					await combat_overlays(c, tag)
					# One real volley on screen, then the state after it.
					var fire: Button = host.campaign_hud.node("Fire")
					if fire != null and not fire.disabled:
						fire.pressed.emit()
						for i in range(40): await process_frame
						await snap("combat_firing_" + tag)
						var waited := Time.get_ticks_msec()
						while host.busy and Time.get_ticks_msec() - waited < 20000: await process_frame
						await settle()
						await snap("combat_after_fire_" + tag)
				if c.s.phase == "combat" and not await solve_and_win(c):
					note("solver could not win r%d f%d" % [region, int(c.s.floor)])
					await remount(c)
					await snap("combat_unsolved_" + tag)
					break
			"reward":
				var node: Dictionary = c.node()
				var kind := "package" if c.first_ammo_reward() else "boss" if c.boss_loot() else "elite" if node.get("elite", false) else "normal"
				await remount(c)
				await snap("reward_%s_r%d" % [kind, region])
				if kind != "package" and not seen.has("reward_detail_" + kind):
					for entry in [["상세", "reward_detail_" + kind], ["교전 기록", "reward_record"], ["메뉴", "reward_menu"]]:
						await press_and_snap(c, str(entry[0]), str(entry[1]))
				if kind == "normal" and c.can_trim_reward() and not seen.has("reward_trim_pick"):
					var trim := host.find_child("city_reward_trim", true, false) as Button
					if trim != null:
						trim.pressed.emit(); await settle()
						var confirm := host.find_child("Confirm", true, false) as Button
						confirm.pressed.emit(); await settle()
						await snap("reward_trim_pick")
						await remount(c)
				var parts: Array = c.part_rewards()
				var options: Array = c.reward_options()
				var taken := false
				if not parts.is_empty(): taken = c.reward(str(parts[0]), "")
				if not taken:
					for id in options:
						if c.can_acquire_ammo(str(id)) or c.first_ammo_reward():
							taken = c.reward(str(id), "")
							if taken: break
				if not taken: taken = c.reward("credits", "") or c.reward("skip", "")
				if not taken: note("reward refused"); break
			"shop":
				await remount(c)
				await snap("shop_r%d" % region)
				if not seen.has("shop_parts"):
					var parts_button := host.find_child("PartsButton", true, false) as Button
					if parts_button != null and parts_button.is_visible_in_tree() and not parts_button.disabled:
						parts_button.pressed.emit(); await settle()
						await snap("shop_parts")
						await remount(c)
					var tools := host.find_child("Tools", true, false) as Button
					if tools != null and tools.is_visible_in_tree():
						tools.pressed.emit(); await settle()
						await snap("shop_menu")
						await remount(c)
					var details := host.find_child("Details", true, false) as Button
					if details != null and details.is_visible_in_tree():
						details.pressed.emit(); await settle()
						await snap("shop_details")
						await remount(c)
				for i in range(c.s.offers.size()):
					var offer: Dictionary = c.s.offers[i]
					if offer.type == "part" and not offer.sold and int(c.s.credits) >= int(offer.price): c.buy(i)
				while c.can_tune_drive(): c.tune_drive()
				await remount(c)
				await snap("shop_after_buy_r%d" % region)
				c.leave()
			"supply":
				var workshop: bool = c.node().get("workshop", false)
				await remount(c)
				await snap(("workshop_r%d" if workshop else "depot_r%d") % region)
				if not workshop:
					var options: Array = c.reward_options()
					if not options.is_empty() and c.can_acquire_ammo(str(options[0])): c.resolve("ammo", str(options[0]))
					else: c.resolve("skip")
				else: c.resolve("skip")
				if c.s.phase == "supply":
					await remount(c)
					await snap(("workshop_done_r%d" if workshop else "depot_done_r%d") % region)
					c.leave()
			"event":
				var event := str(c.node().get("event", ""))
				await remount(c)
				await snap("event_%s" % event)
				c.resolve("skip")
				if c.s.phase == "event":
					await remount(c)
					await snap("event_%s_done" % event)
					c.leave()
			"bypass":
				await remount(c)
				await snap("bypass")
				c.leave()
			"gate":
				await remount(c)
				await snap("gate_r%d" % region)
				var options: Array = c.gate_options()
				var pick := ""
				for wanted in ["mastery", "drive", "mastery_support"]:
					if options.has(wanted) and pick.is_empty(): pick = wanted
				if pick.is_empty() and not options.is_empty(): pick = str(options[0])
				if not pick.is_empty(): c.gate(pick)
				await remount(c)
				await snap("gate_after_r%d" % region)
				if not c.depart_gate(): note("gate depart refused"); break
			"won", "lost":
				await remount(c)
				await snap("results_" + phase)
				await open_results(phase)
				break
			_:
				note("unknown phase " + phase)
				break
	note("ended phase=%s region=%d floor=%d steps=%d deck=%d parts=%s" % [c.s.phase, int(c.s.region) + 1, int(c.s.floor), steps, c.model.s.deck.size(), str(c.s.equipped_parts)])
	# A defeat: a second run whose first fight is lost by waiting (magazine swaps only).
	var lost = Campaign.new()
	lost.start(gun, tour_seed + 1, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	lost.advance_departure(true)
	var first: Array = lost.choices()
	if not first.is_empty() and lost.enter(int(first[0].id)):
		lost.sync_combat()
		var waits := 0
		while lost.s.phase == "combat" and waits < 60:
			waits += 1
			if not lost.model.reload_magazine(): lost.model.cool_magazine()
			lost.sync_combat()
		note("defeat run phase=%s waits=%d" % [lost.s.phase, waits])
		if lost.s.phase == "lost":
			await remount(lost)
			await snap("results_lost")
			await open_results("lost")
	# After the run: the title with the finished run.
	c.save()
	if is_instance_valid(host): host.free()
	host = load("res://redesign/main.tscn").instantiate()
	root.add_child(host); await settle()
	await snap("title_after_run")
	FileAccess.open(output.path_join("tour.json"), FileAccess.WRITE).store_string(JSON.stringify({"size": size_text, "gun": gun, "seed": tour_seed, "captures": order, "log": log_lines}, "  "))
	print("LAUNCH TOUR captures=%d" % order.size())
	quit(0)
