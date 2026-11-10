extends SceneTree
## Depot (탄약고) scene in the main game (2026-11-08). A fresh run walks to the first
## depot through real combats (solved by the magazine solver) and real rewards, so
## every state is save-valid; all depot inputs are touches on the real screen.
const Campaign = preload("res://redesign/campaign.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const DepotView = preload("res://redesign/samples/supply_review/preview.gd")
const Solver = preload("res://tests/campaign_magazine_solver.gd")
const SEED := 251107
var host
var checks := 0
var failures: Array = []
var output: String
var solver = Solver.new()

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

## Names like Menu/Primary are generic: search the depot scene first.
func find(id: String) -> Control:
	var depot: Node = host.find_child("DepotScreen", true, false)
	if depot != null and id != "DepotScreen":
		var inside: Node = depot.find_child(id, true, false)
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

func reaches(nodes: Array, from_id: int, target: int) -> bool:
	var queue: Array = [from_id]
	var seen: Dictionary = {}
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if id == target: return true
		if seen.has(id): continue
		seen[id] = true
		for node in nodes:
			if int(node.id) == id: queue.append_array(node.next)
	return false

## Walk to the first depot of region 1 with real entries, combats and rewards.
func reach_depot(outfit: String = "carrier"):
	var c = Campaign.new()
	c.start("single", SEED, 0, "balanced", Campaign.Content.RouteMap.VERSION, outfit, true)
	while c.departure_pending(): c.advance_departure(true)
	var nodes: Array = c.current_nodes()
	var target: int = int(nodes.filter(func(n): return n.kind == "supply" and not n.get("workshop", false))[0].id)
	for step in range(60):
		if c.s.phase == "supply" and int(c.s.node) == target: return c
		match str(c.s.phase):
			"map":
				var next: Array = c.choices().filter(func(n): return reaches(nodes, int(n.id), target))
				if not check(not next.is_empty() and c.enter(int(next[0].id)), "walk toward the depot"): return null
			"combat":
				var path: Array = solver.solve(c.model, 4, 18)
				if not check(not path.is_empty(), "combat on the way is winnable"): return null
				for item in path:
					match str(item.action):
						"fire": c.model.fire()
						"reload": c.model.reload_magazine()
						"cool": c.model.cool_magazine()
						"eject": c.model.eject_magazine_rounds(item.indices)
						"emergency": c.model.emergency_resupply()
					c.sync_combat()
			"reward":
				var parts: Array = c.part_rewards()
				var ammo: Array = c.reward_options()
				var taken := false
				if not parts.is_empty(): taken = c.reward(str(parts[0]), "")
				elif not ammo.is_empty() and c.first_ammo_reward(): taken = c.reward(str(ammo[0]), "")
				if not taken: taken = c.reward("credits", "")
				if not check(taken, "reward on the way"): return null
			_:
				if not check(c.leave(), "leave a place on the way"): return null
	check(false, "depot reached")
	return null

func snapshot(c) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"campaign": c.s, "combat": JSON.parse_string(c.model.serialized_state()), "profile": c.profile}))

func restored(data: Dictionary):
	var c = Campaign.new()
	check(c.restore_state(data.duplicate(true)), "depot state restores")
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
	var base = reach_depot()
	if base == null:
		print("SUPPLY LIVE UI checks=%d failures=%d" % [checks, failures.size()]); quit(1); return
	var data := snapshot(base)
	check(Campaign.new().restore_state(data.duplicate(true)), "walked depot state is save-valid")
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# Take the first offer as an extra round.
		var c = restored(data)
		await mount(c)
		var depot := find("DepotScreen")
		check(depot != null and depot.is_visible_in_tree(), "depot scene replaces the old supply screen " + suffix)
		check(find("CampaignShellHeader") == null, "old shell header is gone")
		check(depot != null and root.get_visible_rect().grow(1).encloses(depot.get_global_rect()), "depot fits the screen " + suffix)
		var offers: Array = c.reward_options()
		for id in offers: check(find("Offer_" + str(id)) != null, "real offer shown " + str(id))
		await capture("pick_" + suffix)
		var size_before: int = c.model.s.deck.size()
		var first: String = str(offers[0])
		var owned: int = c.model.s.deck.count(first)
		await tap("Offer_" + first)
		check(c.model.s.deck.size() == size_before and not c.s.resolved, "picking only previews")
		await tap("Primary")
		check(c.s.resolved and c.model.s.deck.size() == size_before + 1 and c.model.s.deck.count(first) == owned + 1, "take adds one real round")
		check(saved().model.s.deck.size() == size_before + 1, "taking is autosaved")
		check(find("Offer_" + first).get_node("Content/Count").text.ends_with("보유 %d" % (owned + 1)), "offer count updates after taking")
		await capture("done_" + suffix)
		await tap("Primary")
		check(c.s.phase == "map" and find("PipeMapScreen") != null and find("DepotScreen") == null, "leaving returns to the map " + suffix)
		check(saved().s.phase == "map", "leaving is autosaved")
	root.size = Vector2i(1280, 800)
	# Swap: the shelf turns into owned stacks and the total stays.
	var swap = restored(data)
	await mount(swap)
	var offer: String = str(swap.reward_options()[1] if swap.reward_options().size() > 1 else swap.reward_options()[0])
	var total: int = swap.model.s.deck.size()
	var basics: int = swap.model.s.deck.count("basic_p2")
	await tap("Offer_" + offer)
	await tap("Secondary")
	check(find("StacksScroll").is_visible_in_tree() and not find("OffersScroll").is_visible_in_tree(), "swap switches the shelf to owned stacks")
	await tap("Stack_basic_p2")
	await capture("replace_1280x800")
	await tap("Primary")
	check(swap.s.resolved and swap.model.s.deck.size() == total and swap.model.s.deck.count("basic_p2") == basics - 1, "swap keeps the total and removes the chosen round")
	# Resume after taking: the result opens with the way out.
	check(swap.save() == OK, "save for resume")
	var resumed = Campaign.new(); check(resumed.restore(), "resume restores")
	await mount(resumed)
	check(find("DepotScreen").mode == DepotView.Mode.DONE and find("Primary").text == "지도로 계속", "resume opens on the result")
	# Skip.
	var skip = restored(data)
	await mount(skip)
	var before: int = skip.model.s.deck.size()
	await tap("Leave")
	check(skip.s.resolved and skip.model.s.deck.size() == before, "skip keeps the bag")
	# Utility menu.
	var menu = restored(data)
	await mount(menu)
	await tap("Menu")
	check(find("UtilityMenu").is_visible_in_tree(), "utility menu opens")
	await capture("menu_1280x800")
	await tap("Build")
	check(find("WorkspaceOverlay") != null, "build workspace opens over the depot")
	host._close_workspace(); await settle()
	check(find("DepotScreen") != null, "depot stays after closing build")
	# Full bag: adding is off, swapping is the main action.
	var filler = restored(data)
	while filler.model.s.deck.size() < filler.model.deck_limit(): filler.model.s.deck.append("basic_p2")
	filler.normalize_for_save()
	var full = Campaign.new()
	if check(full.restore_state(snapshot(filler)), "full-bag depot restores"):
		await mount(full)
		check(find("Primary").disabled and find("Secondary").text == "교체해서 확보", "full bag offers swap only")
		await capture("full_1280x800")
	print("SUPPLY LIVE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
