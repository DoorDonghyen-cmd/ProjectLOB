extends "res://tests/campaign_magazine_ui.gd"

const Cases = preload("res://tests/surface_fx_cases.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const CROP := Rect2i(67, 126, 616, 150)
const TITLES := ["현재", "A  예광선", "B  불씨와 파편", "C  겹잔광"]

var recording := false
var frames: Array[Image] = []
var flight_still: Image
var impact_still: Image
var last_still: Image

func title_for(option: int) -> void:
	var title := Label.new()
	title.text = TITLES[option]
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e6e1c7"))
	title.add_theme_color_override("font_outline_color", Color("1b252c"))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(CROP.position) + Vector2(12, 5)
	title.z_index = 50
	host.add_child(title)

func post_draw() -> void:
	if not recording or not is_instance_valid(host.campaign_hud): return
	var board = host.campaign_hud.board
	if board.bullet.is_empty() and board.float_target < 0: return
	var full := root.get_texture().get_image()
	var cropped := full.get_region(CROP)
	frames.append(cropped)
	if flight_still == null and not board.bullet.is_empty() and board.bullet_progress >= 0.58:
		flight_still = cropped
	if impact_still == null and board.float_target >= 0 and board.pulse >= 0.08:
		impact_still = cropped
		last_still = full

func exercise(kind: String, option: int) -> Dictionary:
	var campaign = Cases.make(kind)
	campaign.model.s.enemies.resize(1)
	campaign.model.s.enemies[0].distance = 23
	campaign.model.s.encounter_total = 1
	campaign.model.s.deployed = 1
	await mount(campaign)
	host.save_enabled = false
	var board = host.campaign_hud.board
	board.speed_scale = 1.0
	host.campaign_hud.select_budget(1, false)
	# The historical comparison deliberately forces each candidate on the same shot.
	board.feedback_changed.connect(func(event: Dictionary):
		if event.kind == "plain_shot" or event.kind == "powered_shot":
			board.firing_profile.tier = option
			if option > 0 and int(board.firing_profile.rank) == 0:
				board.firing_profile.color = Color("eccb94")
	)
	title_for(option)
	var oracle = Model.new()
	oracle.s = campaign.model.s.duplicate(true)
	check(oracle.fire(), "reference accepts shot %s %d" % [kind, option])
	frames = []
	flight_still = null
	impact_still = null
	last_still = null
	recording = true
	await tap("Fire")
	recording = false
	check(canonical(campaign.model.s) == canonical(oracle.s), "preview preserves outcome and RNG %s %d" % [kind, option])
	check(flight_still != null and impact_still != null and frames.size() >= 24, "flight and contact rendered %s %d" % [kind, option])
	return {"frames": frames, "flight": flight_still, "impact": impact_still, "full": last_still}

func combine(entries: Array, kind: String) -> void:
	var size := CROP.size
	var gap := 4
	var cell := size + Vector2i(gap, gap)
	var format: Image.Format = entries[0].flight.get_format()
	var poster := Image.create_empty(cell.x * 2 - gap, cell.y * entries.size() - gap, false, format)
	poster.fill(Color("172125"))
	for i in range(entries.size()):
		poster.blit_rect(entries[i].flight, Rect2i(Vector2i.ZERO, size), Vector2i(0, i * cell.y))
		poster.blit_rect(entries[i].impact, Rect2i(Vector2i.ZERO, size), Vector2i(cell.x, i * cell.y))
	check(poster.save_png(output.path_join(kind + ".png")) == OK, "comparison saved " + kind)
	var folder := output.path_join(kind)
	DirAccess.make_dir_recursive_absolute(folder)
	var count: int = entries[0].frames.size()
	for entry in entries:
		check(absi(entry.frames.size() - count) <= 1, "preview does not extend shot playback " + kind)
	for frame_index in range(count):
		var board_image := Image.create_empty(cell.x * 2 - gap, cell.y * 2 - gap, false, format)
		board_image.fill(Color("172125"))
		for i in range(entries.size()):
			var source: Array = entries[i].frames
			var panel: Image = source[mini(frame_index, source.size() - 1)]
			board_image.blit_rect(panel, Rect2i(Vector2i.ZERO, size), Vector2i(i % 2, i / 2) * cell)
		board_image.save_png(folder.path_join("%03d.png" % frame_index))
	entries[2].full.save_png(output.path_join(kind + "_B_full.png"))

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/firing_fx_20261106/"):
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	root.size = Vector2i(1008, 454)
	RenderingServer.frame_post_draw.connect(post_draw)
	for kind in ["plain", "multiply"]:
		var entries := []
		for option in range(TITLES.size()):
			entries.append(await exercise(kind, option))
		if not failures.is_empty(): break
		combine(entries, kind)
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host): host.free()
	print("FIRING FX CONCEPTS COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
