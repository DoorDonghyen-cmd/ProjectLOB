extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
var screen
var report: Dictionary = {"earned_gate_choices": [], "reward_pool_comparisons": [], "outfit_gate_availability": []}
var out: String

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw

func snap(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(out.path_join(label+".png"))

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/gate_review/"):
		quit(1); return
	out = OS.get_environment("QA_OUTPUT_DIR")
	var base: String = OS.get_environment("QA_GATE_BASE")
	for gun in ["single", "burst", "scatter", "heavy", "amplifier"]:
		var c = Campaign.new()
		if not c.restore(base.path_join("endpoint_"+gun+".json")):
			push_error("Cannot restore earned gate "+gun); quit(1); return
		var state: Dictionary = {"campaign": c.s.duplicate(true), "combat": c.model.s.duplicate(true), "profile": c.profile.duplicate(true)}
		for choice in ["slot", "bag", "credits", "compress"]:
			c.restore_state(state)
			var before: Dictionary = {"deck": c.model.s.deck.size(), "credits": c.s.credits, "slots": c.s.slots, "capacity": c.model.capacity(), "hand": Ammo.hand_capacity(c.model.s)}
			var ids: Array = c.compressible_ids()
			var id: String = str(ids[0]) if choice=="compress" and not ids.is_empty() else ""
			var ok: bool = c.gate(choice,id)
			var saved: bool = c.save("user://gate_probe.json")==OK
			var restored = Campaign.new()
			var loaded: bool = restored.restore("user://gate_probe.json")
			report.earned_gate_choices.append({"gun":gun,"choice":choice,"source":id,"ok":ok,"saved":saved,"restored":loaded,"before":before,"after":{"deck":c.model.s.deck.size(),"credits":c.s.credits,"slots":c.s.slots,"capacity":c.model.capacity(),"hand":Ammo.hand_capacity(c.model.s)},"compressible":ids})
	for region in range(4):
		for seed_value in range(10):
			var c = Campaign.new(); c.start("single", 731042+seed_value, 0, "balanced", 3, "carrier")
			c.s.region=region
			var boss: Dictionary = c.current_nodes().filter(func(n): return n.kind=="boss")[0]
			var plain: Dictionary = boss.duplicate(true); plain.kind="combat"
			var b: Array = Data.rewards(boss,int(c.s.seed),c.model.s.deck,["siege_drive"],int(c.s.discovery_version))
			var p: Array = Data.rewards(plain,int(c.s.seed),c.model.s.deck,["siege_drive"],int(c.s.discovery_version))
			report.reward_pool_comparisons.append({"region":region,"seed":c.s.seed,"equal":b==p,"boss":b})
		for outfit in Ammo.OUTFITS:
			var c = Campaign.new(); c.start("single",731042,0,"balanced",3,outfit)
			c.s.region=region;c.s.phase="gate"
			report.outfit_gate_availability.append({"region":region,"outfit":outfit,"hand":Ammo.hand_capacity(c.model.s),"limit":c.bag_growth_limit(),"bag":c.can_grow_bag()})
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	root.add_child(screen);await settle()
	screen.campaign=Campaign.new()
	screen.campaign.restore(base.path_join("endpoint_single.json"))
	screen.model=screen.campaign.model
	screen.page="run";screen.debug_session=true
	for resolution in [Vector2i(1280,800),Vector2i(1008,630)]:
		root.size=resolution;screen.redraw()
		await snap("earned_gate_%d"%resolution.x)
		screen.campaign.s.phase="reward";screen.campaign.s.resolved=false;screen.redraw()
		await snap("boss_regular_reward_%d"%resolution.x)
		screen.campaign.s.phase="gate";screen.campaign.s.resolved=false
	# Explicit availability fixture: capped magazine and test-open 10-card outfit.
	screen.campaign.s.slots=2;screen.model.s.capacity_bonus=2
	screen.campaign.s.outfit="expedition";screen.model.s.outfit="expedition"
	screen.campaign.s.bag_upgrades=0;screen.model.s.bag_upgrades=0
	screen.redraw();await snap("capped_gate_1008")
	var file=FileAccess.open(out.path_join("audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("GATE REVIEW COMPLETE choices=",report.earned_gate_choices.size()," pool_pairs=",report.reward_pool_comparisons.size()," outfit_states=",report.outfit_gate_availability.size())
	screen.queue_free();await process_frame;quit(0)
