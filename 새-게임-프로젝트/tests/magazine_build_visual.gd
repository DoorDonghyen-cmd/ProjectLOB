extends SceneTree
## Magazine combo readout on the real campaign HUD (magazine_build.gd, 2026-11-01).
## Uses earned encounters saved by `run_campaign_magazine.ps1 -Mode rules -RunTag build_density`.
const Campaign = preload("res://redesign/campaign.gd")
const Build = preload("res://redesign/magazine_build.gd")
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
	for i in range(6): await process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func mount(c) -> void:
	if is_instance_valid(host): host.free()
	host = load("res://redesign/main.tscn").instantiate()
	root.add_child(host)
	host.campaign = c; host.model = c.model; host.page = "run"; host.redraw()
	await settle()

## First earned encounter (in save order) whose opening magazine forms a combo.
func earned_with_combo(gun: String) -> String:
	var rules := OS.get_environment("QA_RULES_DIR")
	var files: Array = Array(DirAccess.get_files_at(rules)).filter(func(f): return f.begins_with("combat_%s_731042_r" % gun))
	files.sort_custom(func(a, b): return int(a.get_slice("_n", 1).to_int()) < int(b.get_slice("_n", 1).to_int()))
	for file in files:
		var c = Campaign.new()
		if c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(rules.path_join(file)))) and not Build.combo_line(c.model.s).is_empty():
			return rules.path_join(file)
	return ""

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	var covered := 0
	for gun in ["single", "heavy"]:
		# A rules folder may hold one gun only (per-gun runs); skip guns it lacks.
		if not Array(DirAccess.get_files_at(OS.get_environment("QA_RULES_DIR"))).any(func(f): return f.begins_with("combat_%s_" % gun)): continue
		var file := earned_with_combo(gun)
		if not check(not file.is_empty(), "earned encounter with a combo exists for " + gun): continue
		covered += 1
		print("COMBO FIXTURE ", file)
		for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
			var c = Campaign.new()
			check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(file))), "restore earned encounter")
			root.size = extent; await mount(c)
			var hud: Control = host.campaign_hud
			if not check(is_instance_valid(hud), "campaign HUD mounted"): continue
			var label: Label = hud.find_child("ComboLine", true, false)
			check(label != null and label.is_visible_in_tree(), "combo line visible %s %dx%d" % [gun, extent.x, extent.y])
			if label != null:
				check(label.text == Build.combo_line(c.model.s), "combo line matches rules: " + label.text)
				check(hud.get_global_rect().encloses(label.get_global_rect()), "combo line inside HUD")
				for id in ["MagazineTitle", "SelectedDetail", "EjectToggle", "HeatLabel"]:
					var other: Control = hud.node(id)
					check(not other.is_visible_in_tree() or not other.get_global_rect().intersects(label.get_global_rect().grow(-1)), "combo line does not cover " + id)
			await capture("combo_%s_%dx%d" % [gun, extent.x, extent.y])
			hud.select_ejection(0); await settle()
			check(label == null or not label.is_visible_in_tree(), "combo line hidden while choosing rounds to eject")
			await capture("combo_%s_%dx%d_eject" % [gun, extent.x, extent.y])
	check(covered > 0, "at least one gun's earned encounters were checked")
	# A legacy-rule run never shows the readout.
	var legacy = Campaign.new(); legacy.start("single", 731042, 0, "balanced", 3, "carrier", true)
	legacy.s.erase("magazine_build_version"); legacy.model.s.erase("magazine_build_version"); legacy.model.s.erase("magazine_loaded")
	legacy.enter(int(legacy.choices()[0].id))
	root.size = Vector2i(1280, 800); await mount(legacy)
	var none: Label = host.campaign_hud.find_child("ComboLine", true, false)
	check(none == null or not none.is_visible_in_tree(), "no readout without the build version")
	print("MAGAZINE BUILD VISUAL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
