extends "res://tests/workshop_standard_ui.gd"
const UpgradePlan = preload("res://redesign/ammo_upgrade.gd")

func dialog(): return view().upgrade_dialog()

func click(button: Button) -> void:
	if not check(button.is_visible_in_tree() and not button.disabled, "available input " + str(button.name)): return
	var parent := button.get_parent()
	while parent != null and not parent is CanvasLayer:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await stable()
	check(root.get_visible_rect().encloses(button.get_global_rect()), "modal action in viewport " + str(button.name))
	var at: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = at; event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await stable()

func key(action: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action = action; event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await stable()

func source(c) -> String:
	for id in c.compressible_ids():
		if Model.Content.source_id(id) == "basic": return id
	return str(c.compressible_ids()[0])

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/ammo_upgrade_single_20261106/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	var authored = load("res://redesign/workbench/screen.tscn").instantiate()
	check(authored.get_node("Tabs").get_child_count() == 4, "four operations are serialized")
	check(not authored.has_node("Tabs/Tab2") and not authored.has_node("Options/TuneModes"), "old permanent tune controls are removed")
	check(authored.get_node("Tabs/Tab1").text == "탄환 강화", "single growth entry is authored")
	check(authored.get_node("UpgradeLayer/Upgrade/Center/Panel/Body/Review/Rows/Comparison/After/Content/Count").text == "고급 · 1발", "formal overlay is editor visible before binding")
	authored.free()
	for extent in [Vector2i(1280,800), Vector2i(1008,630), Vector2i(844,390), Vector2i(2340,1080), Vector2i(2160,1032)]:
		var c = modern_place()
		await mount_at(c,extent); await stable()
		geometry(extent)
		var id := source(c)
		await tap("Owned_" + id)
		var before = canonical([c.s,c.model.s,c.profile])
		await tap("Apply")
		var d = dialog()
		check(d.visible and not d.body.has_node("Methods"), "one comparison has no method selector")
		check(d.proposal.valid and d.proposal.target == Model.Content.compressed_id(id), "exact owned pair has actual upgraded result")
		check(d.body.get_node("Review/Rows/Comparison/Stats/Cell02").text == "→ " + str(Model.Content.damage(d.proposal.target,c.model.s) * Model.Content.hit_count(d.proposal.target,c.model.s)), "result direct damage uses actual weapon")
		check(d.body.get_node("Review/Rows/Comparison/Stats/Cell01").text == str(2 * Model.Content.damage(id,c.model.s) * Model.Content.hit_count(id,c.model.s)), "input damage compares both rounds")
		check(d.body.get_node("Review/Rows/Comparison/Stats/Cell21").text == "%d칸" % (2*Model.Content.slot_cost(id)), "input space counts both materials")
		check(canonical([c.s,c.model.s,c.profile]) == before, "opening and preview have no model side effects")
		scan("upgrade_%dx%d" % [extent.x,extent.y]); await capture("upgrade_%dx%d" % [extent.x,extent.y])
		for i in range(18):
			await key("ui_focus_next")
			check(d.is_ancestor_of(root.gui_get_focus_owner()), "keyboard focus stays inside modal")
		await click(d.body.get_node("Actions/Cancel"))
		check(not d.visible and canonical([c.s,c.model.s,c.profile]) == before, "cancel preserves pair/free work")
		await tap("Apply"); await key("ui_cancel")
		check(not dialog().visible and canonical([c.s,c.model.s,c.profile]) == before, "ESC preserves state")
		check(root.gui_get_focus_owner() == view().get_node("Inspector/Inset/Actions/Apply"), "ESC restores focus")
		await tap("Apply")
		check(c.save() == OK, "save unresolved baseline before UI commit")
		var oracle = UpgradePlan.copy(c)
		check(UpgradePlan.execute(oracle,id), "oracle uses the same public command")
		oracle.sync_combat()
		oracle.normalize_for_save()
		var expected = canonical(oracle.model.s)
		await click(dialog().body.get_node("Actions/Confirm"))
		check(c.s.resolved and canonical(c.model.s) == expected, "native touch commits actual preview exactly")
		save_matches(c)
		var restored = Campaign.new(); check(restored.restore(),"new upgrade restores")
		await mount_at(restored,extent); await stable()
		check(view() != null and not dialog().visible and restored.s.resolved, "resume shows completed workshop")
		var once = canonical([restored.s,restored.model.s])
		check(not restored.resolve("compress",id) and canonical([restored.s,restored.model.s]) == once, "visit cannot upgrade twice")
	# Resizing changes the authored size variant and retains the selected pair.
	var c = modern_place(); await mount_at(c,Vector2i(1280,800)); await stable()
	var id := source(c); await tap("Owned_"+id); await tap("Apply")
	var before = canonical([c.s,c.model.s,c.profile])
	root.size = Vector2i(844,390); await stable()
	check(dialog().visible and dialog().selected == id, "open overlay/selection survive resize")
	await capture("resized_844x390")
	check(canonical([c.s,c.model.s,c.profile]) == before, "resize is free")
	await click(dialog().body.get_node("Actions/Cancel"))
	# Current domain commands reject both retired tune options atomically.
	for method in ["power","cool"]:
		check(not c.tune(c.model.s.deck.find(id),method), "modern workshop rejects retired " + method)
		check(canonical([c.s,c.model.s,c.profile]) == before, "rejected tune preserves run")
	# Ownership may change after opening. Confirmation must re-read live state.
	await tap("Apply")
	while c.model.s.deck.count(id)>1: c.model.s.deck.erase(id)
	var changed = canonical([c.s,c.model.s])
	dialog().confirm()
	check(canonical([c.s,c.model.s]) == changed and not c.s.resolved, "stale pair rejects without consuming work")
	check(dialog().body.get_node("Actions/Confirm").disabled, "stale pair explains restriction")
	await capture("insufficient_844x390")
	# Existing tuned copies retain their identity and use exact matching materials.
	for method in ["power","cool"]:
		c = modern_place(); await mount_at(c,Vector2i(1280,800)); await stable()
		id = source(c)
		var tuned := Model.Content.Variants.tuned(id,Model.Content.AMMO,method)
		check(not tuned.is_empty(), "historical tune exists " + method)
		c.model.s.deck[c.model.s.deck.find(id)] = tuned
		check(not UpgradePlan.inspect(c,tuned).valid, "unequal profiles cannot be mixed")
		c.model.s.deck[c.model.s.deck.find(id)] = tuned
		host.redraw(); await stable(); await tap("Owned_"+tuned); await tap("Apply")
		var target := Model.Content.compressed_id(tuned)
		check(dialog().sources.get_node("Material_"+tuned).text.contains("화력" if method=="power" else "방열"), "legacy identity is readable on touch")
		await click(dialog().body.get_node("Actions/Confirm"))
		check(c.s.resolved and c.model.s.deck.has(target), "tuned pair preserves its old tuning")
		save_matches(c)
		check(not UpgradePlan.inspect(c,target).valid, "completed visit rejects repeat")
	c = modern_place()
	c.model.s.deck = []
	for i in range(c.minimum_deck()): c.model.s.deck.append("basic_p2")
	check(not UpgradePlan.inspect(c,"basic_p2").valid, "minimum inventory blocks two-to-one")
	# Representative art/values from an actually earned workshop, not an injected build.
	var earned_path := "res://../docs/qa/reports/ammo_upgrade_single_2026-11-06/states/fire_workshop.json"
	check(FileAccess.file_exists(earned_path), "earned fire workshop snapshot exists")
	if FileAccess.file_exists(earned_path):
		for extent in [Vector2i(1280,800),Vector2i(2340,1080)]:
			c = Campaign.new()
			check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(earned_path))), "earned fire workshop restores")
			await mount_at(c,extent); await stable(); await tap("Owned_bore"); await tap("Apply")
			check(dialog().proposal.valid and dialog().body.get_node("Review/Rows/Comparison/Stats/Cell00").text == "화상 지속 / 발", "fire upgrade shows duration without adding nonstacking burns")
			check(dialog().body.get_node("Review/Rows/Details/SourceText").visible,"special effects compare original and upgraded descriptions")
			scan("earned_fire_%dx%d" % [extent.x,extent.y]); await capture("earned_fire_%dx%d" % [extent.x,extent.y])
			await click(dialog().body.get_node("Actions/Cancel"))
	FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("AMMO UPGRADE LIVE COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	host.free(); await settle(); quit(0 if failures.is_empty() else 1)
