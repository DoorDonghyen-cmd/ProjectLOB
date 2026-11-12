extends "res://tests/supply_live_ui.gd"
## Build workshop (빌드 작업실) rework in the main game (2026-11-08). Uses earned,
## save-valid states from the 2026-11-06 full-climb check (QA_BUILD_DIR):
## entry_single_17_r5.json (map, 5 equipped + 4 stored) and a region-5 combat entry.
const Workshop = preload("res://redesign/build/workshop.gd")

func find(id: String) -> Control:
	var overlay: Node = host.find_child("WorkspaceOverlay", true, false)
	if overlay != null and id != "WorkspaceOverlay":
		var inside: Node = overlay.find_child(id, true, false)
		if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func earned(file: String):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned state restores " + file)
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454), Vector2i(2340, 1080)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = earned("entry_single_17_r5.json")
		await mount(c)
		await tap("city_deck")
		var overlay := find("WorkspaceOverlay")
		check(overlay != null and overlay.get_script() == Workshop, "map build opens the new workshop " + suffix)
		check(find("EquippedPartGrid") == null and find("DeckGrid") == null, "old deck loadout is gone")
		check(overlay != null and root.get_visible_rect().grow(1).encloses(find("PartsPane").get_global_rect()), "parts pane fits " + suffix)
		check(root.get_visible_rect().grow(1).encloses(find("Apply").get_global_rect()), "apply button on screen " + suffix)
		var shelf := find("StorageScroll") as ScrollContainer
		var slots_rect := find("Slots").get_global_rect()
		var apply_rect := find("Apply").get_global_rect()
		shelf.scroll_vertical = 10000
		await settle()
		if extent != Vector2i(1280, 800):
			check(shelf.scroll_vertical > 0, "short workbench scrolls the storage list " + suffix)
		check(find("Slots").get_global_rect() == slots_rect and find("Apply").get_global_rect() == apply_rect, "storage scroll keeps slots and apply fixed " + suffix)
		shelf.scroll_vertical = 0
		await settle()
		await capture("parts_" + suffix)
		# Swap: a stored part needs a slot; choosing the slot enables the swap.
		var equipped: Array = c.equipped_parts()
		var stored: Array = c.s.parts.filter(func(id): return not equipped.has(id))
		var incoming := ""
		var outgoing := ""
		for candidate in stored:
			for slot_id in equipped:
				var test: Array = equipped.duplicate()
				test[test.find(slot_id)] = candidate
				if c.model.Content.valid_part_set(str(c.s.gun), test, c.model.s):
					incoming = str(candidate); outgoing = str(slot_id); break
			if not incoming.is_empty(): break
		if check(not incoming.is_empty(), "a valid swap exists"):
			await tap("Stored_" + incoming)
			check(find("Apply").disabled and find("Instruction").text.contains("교체할 장착 슬롯"), "full loadout asks for a slot")
			await tap("Slot%d" % (equipped.find(outgoing) + 1))
			check(not find("Apply").disabled and find("Apply").text == "교체 장착", "choosing the slot enables the swap")
			if extent in [Vector2i(1280, 800), Vector2i(2340, 1080)]: await capture("swap_" + suffix)
			await tap("Apply")
			check(c.is_equipped(incoming) and not c.is_equipped(outgoing) and c.s.parts.has(outgoing), "swap installs and stores the old part")
			check(saved().is_equipped(incoming), "swap is autosaved")
			check(find("WorkspaceOverlay") == overlay and find("BuildFeedback").text.contains("구성을 적용"), "workshop stays open with feedback")
			# Unequip then equip again.
			await tap("Slot%d" % (c.equipped_parts().find(incoming) + 1))
			check(find("Apply").text == "장착 해제", "equipped part offers unequip")
			await tap("Apply")
			check(not c.is_equipped(incoming) and c.equipped_parts().size() == 4, "unequip frees a slot")
			await tap("Stored_" + incoming)
			check(find("Apply").text == "장착", "free slot offers equip")
			await tap("Apply")
			check(c.is_equipped(incoming) and c.equipped_parts().size() == 5, "equip fills the slot")
		# Rules dialog sits above the workshop.
		await tap("PartRules")
		var rules := host.find_child("PartDetails", true, false) as Control
		check(rules != null and rules.is_visible_in_tree(), "rules dialog opens over the workshop")
		if extent == Vector2i(1280, 800): await capture("rules_" + suffix)
		if rules != null:
			var dialog: Node = rules.get_meta("dialog") if rules.has_meta("dialog") else rules.get_parent()
			while dialog != null and not dialog.has_method("close") and dialog.get_parent() != host: dialog = dialog.get_parent()
			if dialog != null: dialog.queue_free()
			await settle()
		check(not find("PartDismantle").is_visible_in_tree(), "no dismantle outside shop or depot")
		# Ammo tab.
		await tap("AmmoTab")
		var distinct: Dictionary = {}
		for id in c.model.s.deck: distinct[id] = true
		check(find("AmmoPage").is_visible_in_tree() and find("Stacks").get_child_count() == distinct.size(), "ammo tab lists every owned round once")
		var pick: String = str(distinct.keys()[distinct.size() - 1])
		await tap("Stack_" + pick)
		check(find("AmmoName").text == str(c.model.Content.AMMO[pick].name), "stack shows its detail")
		check(root.get_visible_rect().grow(1).encloses(find("AmmoDetail").get_global_rect()), "ammo detail on screen " + suffix)
		await capture("ammo_" + suffix)
		await tap("workspace_close")
		check(find("WorkspaceOverlay") == null and find("PipeMapScreen") != null, "close returns to the map " + suffix)
	# Combat: read-only.
	root.size = Vector2i(1280, 800)
	var battle = earned("combat_single_17_r5_n40101.json")
	await mount(battle)
	check(is_instance_valid(host.campaign_hud), "combat HUD mounted")
	# The live UI never opens the workshop during combat (the HUD 빌드 shows its own
	# detail); bind the presenter as render() would, then check the read-only state.
	host.city_ui.ui = host; host.city_ui.campaign = battle
	host.city_ui.deck()
	await settle()
	check(find("Apply").disabled and find("Instruction").text == "교전 중 · 열람만 가능", "combat opens read-only")
	await capture("combat_readonly_1280x800")
	print("BUILD LIVE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
