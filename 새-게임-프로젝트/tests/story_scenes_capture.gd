extends SceneTree
## Captures the story scenes (출발 3장면, 공급 복구, 귀환) at three sizes. Used before and
## after the story scene rework (2026-11-08). States are set directly for viewing only.
const Campaign = preload("res://redesign/campaign.gd")
var host
var output: String

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func mount(c) -> void:
	if is_instance_valid(host): host.free()
	host = load("res://redesign/main.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.campaign = c; host.model = c.model; host.page = "run"; host.redraw()
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = Campaign.new()
		c.start("single", 251107, 0, "balanced", Campaign.Content.RouteMap.VERSION, "work", true)
		for step in range(3):
			await mount(c)
			await capture("departure%d_%s" % [step + 1, suffix])
			c.advance_departure()
		c.s.phase = "won"
		c.s.restoration_done = false
		await mount(c)
		await capture("restoration_" + suffix)
		c.restore_supply()
		await mount(c)
		await capture("homecoming_" + suffix)
	print("STORY SCENES CAPTURED")
	quit(0)
