extends "res://tests/supply_live_ui.gd"
## Tag-based rounds and parts prototype on screen (2026-11-10): the 등반 설정 scheme toggle
## starts a tag run, a tag part in the shop opens its details, and equipped tag parts show
## in the combat header with their own details. Shop/combat come from earned 2026-11-06 states.
const Tags = preload("res://redesign/tag_build.gd")

func find(id: String) -> Control:
	for name in ["ShopTerminal", "WorkspaceOverlay"]:
		var scene: Node = host.find_child(name, true, false)
		if scene != null and id != name:
			var inside: Node = scene.find_child(id, true, false)
			if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func earned(file: String, edit: Callable):
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))
	data.combat.tag_build_version = Tags.VERSION
	edit.call(data)
	var c = Campaign.new()
	check(c.restore_state(data), "tag state restores " + file)
	# Tag runs start with growth structure v2 like every new run (as overhaul_ui).
	c.model.s.growth_structure_version = preload("res://redesign/growth_structure.gd").VERSION
	return c

func on_screen(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(control.get_global_rect())

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# 등반 설정: choose the tag scheme, then start a new run.
		if is_instance_valid(host): host.free()
		host = load("res://redesign/main.tscn").instantiate(); host.save_enabled = false
		root.add_child(host); await settle()
		host.selected_tag_build = false
		# Launch build (2026-11-12): the comparison toggle is a developer tool.
		host.preferences.data.dev_tools = false
		host._open_preparation(false); await settle()
		await tap("preparation_options")
		check(find("part_scheme_current") == null and find("CityDifficulty") != null, "launch 등반 설정 has no scheme toggle " + suffix)
		await capture("options_launch_" + suffix)
		await tap("DialogClose")
		host.preferences.data.dev_tools = true
		host._open_preparation(false); await settle()
		await tap("preparation_options")
		check(on_screen(find("part_scheme_current")) or find("part_scheme_current") != null, "scheme row in 등반 설정 " + suffix)
		await tap("part_scheme_tags")
		check(host.selected_tag_build, "태그 시험판 selected " + suffix)
		await capture("options_tags_" + suffix)
		await tap("DialogClose")
		check(find("preparation_options").text.contains("태그"), "등반 설정 button marks the tag scheme " + suffix)
		host._start(host.selected_weapon_id, false); await settle()
		check(Tags.enabled(host.campaign.model.s), "new run from the tag scheme carries the tag flag " + suffix)
		var copy = Campaign.new()
		check(copy.restore_state(JSON.parse_string(JSON.stringify({"campaign": host.campaign.s, "combat": JSON.parse_string(host.campaign.model.serialized_state()), "profile": host.campaign.profile}))) and Tags.enabled(copy.model.s), "tag flag survives save")
		host._start(host.campaign.s.gun, true); await settle()
		check(Tags.enabled(host.campaign.model.s), "restart with the same seed keeps the tag scheme")
		host.selected_tag_build = false
		host._start(host.selected_weapon_id, false); await settle()
		check(not Tags.enabled(host.campaign.model.s), "현재 구성 starts without the tag flag")
		# Shop: a tag part on sale opens its details.
		var shop = earned("shop_burst_17_r5_n40401.json", func(data):
			data.campaign.offers[2] = {"id": "tag_multi_add", "new": true, "price": 30, "sold": false, "type": "part"})
		await mount(shop)
		host.city_ui.shop_selection = 2; host.redraw(); await settle()
		await tap("Details")
		var window := find("PartDetails")
		check(on_screen(window) and window.get_meta("dialog").find_child("Title", true, false).text.contains("다회 가속기"), "shop part details for 다회 가속기 " + suffix)
		var text := ""
		for label in window.get_meta("dialog").find_children("*", "Label", true, false): text += label.text + "\n"
		print("DETAILS ", text.replace("\n", " | "))
		check(text.contains("다회 태그 공격탄") and not text.contains("특정 탄종 없이"), "details name the deck rounds that carry the tag " + suffix)
		check(not text.contains("코어는 별도 장착 제한"), "v2 details drop the one-core note " + suffix)
		await capture("shop_tag_part_" + suffix)
		# Combat: equipped tag parts in the HUD build panel.
		var combat = earned("combat_heavy_17_r3_n20101.json", func(data):
			data.campaign.parts = data.campaign.parts + ["tag_fire_add", "tag_copy"]
			data.campaign.equipped_parts = ["tag_fire_add", "tag_copy"]
			data.combat.equipped_parts = ["tag_fire_add", "tag_copy"])
		await mount(combat)
		# The live combat HUD lists the build behind its Parts button.
		var hud: Control = host.campaign_hud
		check(hud != null and on_screen(hud.node("Parts")), "combat HUD Parts button " + suffix)
		await capture("combat_tag_" + suffix)
		# Card chips (2026-11-11): tagged rounds show chips on screen, 화염 filled by 화염 점화기.
		var magazine: Array = combat.model.s.magazine
		var tagged := 0
		for i in range(magazine.size()):
			var own := Tags.tags(combat.model.s, str(magazine[i]))
			var chips: Control = hud.node("Face%d" % i).get_node_or_null("Tags") if hud != null else null
			if own.is_empty():
				check(chips == null or not chips.visible, "no chips on untagged %s %s" % [magazine[i], suffix])
				continue
			tagged += 1
			check(on_screen(chips) and chips.tags == own, "chips %s on %s %s" % [own, magazine[i], suffix])
			check(chips.lit.has("화염") == own.has("화염"), "화염 chip filled only on 화염 rounds " + str(magazine[i]))
			# Boosted number (11-11): green on rounds the equipped tag parts already raise.
			var boosted: bool = hud.node("Value%d" % i).get_theme_color("font_color") == Tags.BOOSTED
			var expected_boost: bool = own.has("화염") and preload("res://redesign/content.gd").is_attack(str(magazine[i]))
			check(boosted == expected_boost, "card number green only when boosted: %s %s" % [magazine[i], suffix])
		check(tagged > 0, "the earned magazine has tagged rounds " + suffix)
		if hud != null and not magazine.is_empty():
			hud.hud.inspect_round(0); await settle()
			check(hud.node("DetailBody").text.contains("태그 · ") or hud.node("DetailBody").text.contains("태그 없음"), "round details open with the tag line " + suffix)
			await capture("combat_tag_round_" + suffix)
			hud.close_detail(); await settle()
		if hud != null:
			hud.node("Parts").pressed.emit(); await settle()
			var body: String = hud.node("DetailBody").text
			check(hud.node("Detail").is_visible_in_tree() and body.contains("태그 시험판") and body.contains("화염 점화기") and body.contains("복제 기판"), "build panel lists the tag scheme and both parts " + suffix)
			check(not body.contains(" · \n") and not body.contains("\n\n"), "no empty value lines for plain parts")
			await capture("combat_tag_build_" + suffix)
	print("TAG BUILD UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
