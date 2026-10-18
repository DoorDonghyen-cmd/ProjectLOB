extends SceneTree
const Content = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Campaign = preload("res://redesign/campaign.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var args := OS.get_cmdline_user_args()
	check(not args.is_empty() and Model.VERSION == int(args[0]), "Packaged model version")
	check(Content.GUNS.size() == 5, "Five playable weapons")
	var campaign = Campaign.new()
	campaign.start("burst", 731042)
	check(campaign.s.discovery_version == Campaign.Content.Discovery.VERSION, "Current ammo discovery rules")
	check(campaign.model.s.deck.all(func(id): return Content.source_id(id) == "basic"), "Basic-only departure")
	check(campaign.model.s.deck.has("basic_p2"), "Current per-card starter profiles")
	var before: Array = campaign.model.s.deck.duplicate()
	var index: int = before.find("basic_p2")
	campaign.s.phase = "shop"
	campaign.s.credits = 30
	check(campaign.tune(index, "power"), "Per-copy shop tuning")
	check(campaign.s.credits == 18, "Tuning price")
	var changed := 0
	for card in range(before.size()):
		if before[card] != campaign.model.s.deck[card]: changed += 1
	check(changed == 1 and campaign.model.s.deck[index] == "basic_p2_power", "Only one owned copy changes")
	for gun in Content.GUNS:
		var model = Model.new()
		model.start(gun, 731042)
		check(model.s.hand.size() == mini(model.s.deck.size(), Content.hand_capacity(model.s)), "Opening hand: " + gun)
		model.s.hand = ["pierce", "charge"]
		check(model.load_round("pierce") and model.load_round("charge"), "Load: " + gun)
		check(model.s.plan == ["charge", "pierce"], "Last loaded fires first: " + gun)
		check(model.confirm(), "Confirm: " + gun)
		for enemy in model.s.enemies: enemy.distance = 1000
		model.s.heat = Content.heat_limit(model.s) - 1
		var expected_heat := Content.heat_after_reload(model.s)
		check(model.reload_magazine(), "Reload: " + gun)
		check(model.s.heat == expected_heat and model.s.phase == "plan", "Partial cooling: " + gun)
	var packed = load("res://redesign/main.tscn")
	check(packed is PackedScene, "Main scene resource")
	if packed is PackedScene:
		var scene = packed.instantiate()
		root.add_child(scene)
		for frame in range(30): await process_frame
		scene.queue_free()
		await process_frame
	if failures == 0: print("MOBILE_PACKAGE_PROBE_PASS model=", Model.VERSION)
	quit(0 if failures == 0 else 1)
