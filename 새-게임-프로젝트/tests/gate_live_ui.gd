extends SceneTree
## Approved gate scene in the main game (2026-11-07). A real run reaches the gate
## through actual boss loot; every input is a touch on the real screen.
const Campaign = preload("res://redesign/campaign.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const GateView = preload("res://redesign/samples/gate_review/preview.gd")
var host
var checks := 0
var failures: Array = []
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func find(id: String) -> Control:
	# Search the gate scene first: names like Menu/Apply/Build are generic.
	var gate: Node = host.find_child("GateScreen", true, false)
	if gate != null and id != "GateScreen":
		var inside: Node = gate.find_child(id, true, false)
		if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func tap(id: String) -> void:
	var button := find(id) as Button
	if not check(button != null and button.is_visible_in_tree() and not button.disabled, "available " + id): return
	var scroll: Node = button.get_parent()
	while scroll != null:
		if scroll is ScrollContainer: scroll.ensure_control_visible(button)
		scroll = scroll.get_parent()
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = point; event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

## Earned gate states saved by the full-climb check (`QA_GATE_DIR`, files gate_<gun>_<seed>_r<n>.json).
## These pass save validation, so autosave can be checked. Region 1..4 gates.
func earned_gate(region: int = 1):
	var c = Campaign.new()
	var file: String = OS.get_environment("QA_GATE_DIR").path_join(OS.get_environment("QA_GATE_PREFIX") + "_r%d.json" % region)
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(file))) and c.s.phase == "gate" and c.modern_gates(), "earned gate restores " + file.get_file())
	return c

## The review fixture's staging (not save-valid): used only for the outfit pose check.
func gate_run(outfit: String = "carrier", gun: String = "burst"):
	var c = Campaign.new()
	c.start(gun, 251025, 0, "balanced", Campaign.Content.RouteMap.VERSION, outfit, true)
	c.s.region = 1; c.s.departure_step = 3; c.s.clears = 2; c.s.opening_reward_step = 2; c.s.credits = 43
	c.s.parts = ["volley_drive"]; c.s.equipped_parts = ["volley_drive"]
	c.model.s.deck = c.Model.FocusBuild.replace_opening(c.model.s.deck, "precise")
	var nodes: Array = c.current_nodes()
	var boss: Dictionary = nodes.filter(func(node): return node.kind == "boss")[0]
	var prior: Dictionary = nodes.filter(func(node): return node.next.has(boss.id))[0]
	c.s.node = prior.id; c.s.floor = prior.floor
	check(c.enter(int(boss.id)), "enter boss")
	c.model.s.phase = "won"
	c.sync_combat()
	check(c.reward("skip") and c.s.phase == "gate" and c.modern_gates(), "boss loot leads to the modern gate")
	return c

func mount(c) -> void:
	if is_instance_valid(host): host.free()
	host = load("res://redesign/main.tscn").instantiate()
	root.add_child(host)
	host.campaign = c; host.model = c.model; host.page = "run"; host.redraw()
	await settle()

func saved():
	var copy = Campaign.new()
	check(copy.restore(), "autosave restores")
	return copy

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = earned_gate([1, 2, 3][[Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)].find(extent)])
		await mount(c)
		var gate := find("GateScreen")
		check(gate != null and gate.is_visible_in_tree(), "gate scene replaces the old gate screen " + suffix)
		check(find("GateUpgradeGrid") == null and find("CampaignShellHeader") == null, "old gate grid and shell header are gone")
		check(gate != null and root.get_visible_rect().grow(1).encloses(gate.get_global_rect()), "gate scene fits the screen " + suffix)
		check(gate != null and gate.get_node("%Region").text == c.region_info().name and gate.get_node("%Destination").text == c.region_info(int(c.s.region) + 1).name, "real region names")
		var options: Array = c.gate_options()
		var upgrade: String = str(options.filter(func(id): return id != "production")[0])
		for id in options: check(find("Option_" + str(id)) != null, "real gate option shown " + str(id))
		await capture("upgrade_" + suffix)
		# Highlight is free; apply commits through the main handler and autosaves.
		var mods_before: Dictionary = c.model.s.gate_mods.duplicate()
		await tap("Option_" + upgrade)
		check(c.model.s.gate_mods == mods_before and not c.gate_ready(), "highlight alone changes nothing")
		await tap("Apply")
		check(c.gate_ready() and find("GateScreen") == gate, "upgrade applied once and the scene stays")
		check(saved().gate_ready(), "upgrade is autosaved")
		await capture("service_" + suffix)
		# Utility menu: the old gate's parts/ammo access lives here now.
		await tap("Menu")
		check(find("UtilityMenu").is_visible_in_tree(), "utility menu opens")
		await capture("menu_" + suffix)
		await tap("Build")
		check(find("WorkspaceOverlay") != null, "build workspace opens over the gate")
		host._close_workspace(); await settle()
		check(find("GateScreen") == gate and not find("UtilityMenu").visible, "gate remains after closing build")
		# Paid service: storage expansion with real price.
		var limit: int = c.model.deck_limit()
		var credits: int = c.s.credits
		await tap("Option_bag")
		await tap("Apply")
		check(c.model.deck_limit() == limit + 2 and c.s.credits == credits - c.Economy.BAG_PRICE, "storage expansion uses real rules %s (limit %d->%d, Cr %d->%d, can_grow %s)" % [suffix, limit, c.model.deck_limit(), credits, c.s.credits, c.can_grow_bag()])
		check(saved().model.deck_limit() == limit + 2, "service is autosaved")
		# Departure sits on the door plaque; the map follows the blackout.
		var region: int = c.s.region
		var exit := find("GateExit")
		check(exit != null and find("DoorPlaque").get_global_rect().encloses(exit.get_global_rect()), "departure on the destination plate")
		await tap("GateExit")
		var started := Time.get_ticks_msec()
		while c.s.phase != "map" and Time.get_ticks_msec() - started < 5000: await process_frame
		await settle()
		check(c.s.phase == "map" and int(c.s.region) == region + 1, "departure enters the next region " + suffix)
		await capture("after_depart_" + suffix)
		check(find("PipeMapScreen") != null and find("GateScreen") == null, "map replaces the gate after blackout (map=%s gate=%s phase=%s)" % [find("PipeMapScreen") != null, find("GateScreen") != null, c.s.phase])
		check(int(saved().s.region) == region + 1, "departure is autosaved")
	root.size = Vector2i(1280, 800)
	# Resume after the upgrade opens straight at the paid service step.
	var resume = earned_gate(4)
	check(resume.gate(str(resume.gate_options().filter(func(id): return id != "production")[0])), "fixture upgrade")
	check(resume.save() == OK, "save for resume")
	var loaded = Campaign.new(); check(loaded.restore(), "resume restores")
	await mount(loaded)
	check(find("GateScreen").mode == GateView.Mode.SERVICE and find("GateExit").is_visible_in_tree(), "resume opens at service with departure ready")
	# Dedicated ammunition production: specimen, three basics, exact swap.
	var prod = earned_gate(2)
	await mount(prod)
	var deck_before: Array = prod.model.s.deck.duplicate()
	await tap("Option_production"); await tap("Apply")
	var screen := find("GateScreen")
	check(screen.mode == GateView.Mode.SPECIMENS, "production asks for a specimen")
	var specimen: String = str(screen.buttons.keys()[0])
	await tap("Option_" + specimen); await tap("Apply")
	var source: String = str(screen.buttons.keys()[0])
	for i in range(3): await tap("Option_" + source)
	await capture("production_1280x800")
	await tap("Apply")
	check(prod.gate_ready() and prod.model.s.deck.size() == deck_before.size() and prod.model.s.deck.count(specimen) == deck_before.count(specimen) + 3, "production swaps exactly three rounds")
	# The console operator wears the run's outfit.
	var scout = gate_run("scout", "single")
	await mount(scout)
	check(find("GateScreen").get_node("%Gate").work_profile == Actors.resolve("scout", "workshop").profile, "operator uses the run's outfit pose")
	await capture("scout_1280x800")
	# An older map-3 run (no run economy) reaches the new gate without paid service.
	var old = Campaign.new()
	var old_file: String = OS.get_environment("QA_LEGACY_GATE")
	check(old.restore_state(JSON.parse_string(FileAccess.get_file_as_string(old_file))) and old.s.phase == "gate" and not old.Economy.enabled(old.s), "pre-economy gate save restores")
	await mount(old)
	var old_upgrade: String = str(old.gate_options().filter(func(id): return id != "production")[0])
	await tap("Option_" + old_upgrade); await tap("Apply")
	check(old.gate_ready() and find("Option_bag") == null and find("Apply").disabled, "no paid service offered without the run economy")
	await capture("legacy_service_1280x800")
	await tap("GateExit")
	var wait_from := Time.get_ticks_msec()
	while old.s.phase != "map" and Time.get_ticks_msec() - wait_from < 5000: await process_frame
	check(old.s.phase == "map" and int(old.s.region) == 1, "pre-economy run departs normally")
	print("GATE LIVE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
