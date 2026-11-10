extends SceneTree
const Content = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
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
	var comparison := args.size() > 2 and args[2] == "weapon-magazine"
	var journey_mode := args.size() > 2 and args[2] == "magazine-journey"
	check(args.size() <= 2 or args[2] in ["campaign", "weapon-magazine", "magazine-journey"], "Supported play mode")
	if not comparison and not journey_mode:
		var Campaign = load("res://redesign/campaign.gd")
		var campaign = Campaign.new()
		campaign.start("burst", 731042)
		check(campaign.s.discovery_version == Campaign.Content.Discovery.VERSION, "Current ammo discovery rules")
		check(campaign.model.s.deck.all(func(id): return Content.source_id(id) == "basic"), "Basic-only departure")
		check(campaign.model.s.deck.has("basic_p2"), "Current per-card starter profiles")
		var before: Array = campaign.model.s.deck.duplicate()
		var index: int = before.find("basic_p2")
		campaign.s.phase = "shop"
		campaign.s.credits = 30
		if campaign.modern_places():
			check(not campaign.tune(index, "power"), "Current campaign rejects retired shop tuning")
			check(campaign.s.credits == 30 and campaign.model.s.deck == before, "Rejected legacy tuning preserves the deck and wallet")
			var found_workshop := false
			for room in campaign.current_nodes():
				if not room.get("workshop", false): continue
				found_workshop = true
				campaign.s.node = room.id
				campaign.s.phase = "supply"
				campaign.s.resolved = false
				break
			check(found_workshop, "Current campaign contains a workshop")
			var pairs: Array = campaign.compressible_ids()
			check(not pairs.is_empty(), "Starter deck contains an upgradeable exact pair")
			if not pairs.is_empty():
				var source: String = str(pairs[0])
				var expected: Array = before.duplicate()
				expected.erase(source); expected.erase(source)
				expected.append(Content.compressed_id(source))
				check(campaign.resolve("compress", source), "Current workshop upgrades one exact pair")
				check(campaign.model.s.deck == expected and campaign.s.credits == 30 and campaign.s.resolved, "One pair becomes one enhanced round and consumes the workshop visit")
		else:
			check(campaign.tune(index, "power"), "Legacy per-copy shop tuning")
			check(campaign.s.credits == 18, "Legacy tuning price")
			var changed := 0
			for card in range(before.size()):
				if before[card] != campaign.model.s.deck[card]: changed += 1
			check(changed == 1 and campaign.model.s.deck[index] == "basic_p2_power", "Only one legacy owned copy changes")
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
	var entry: String = args[1] if args.size() > 1 else "res://redesign/main.tscn"
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == entry, "Packaged startup scene matches manifest")
	var packed = load(entry)
	check(packed is PackedScene, "Main scene resource")
	if packed is PackedScene:
		var scene = packed.instantiate()
		if journey_mode:
			var stage: String = args[3] if args.size() > 3 else ""
			var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
			if not (user_dir.contains("/qa_runtime/") or user_dir.contains("/package_probe/")) or stage not in ["write", "read"]:
				check(false, "Journey probe requires isolated storage and explicit stage");scene.free();quit(2);return
			scene.resume_saved = stage == "read"
		root.add_child(scene)
		for frame in range(30): await process_frame
		if journey_mode:
			await probe_journey(scene, args[3])
		if comparison:
			for gun_index in range(5):
				for case_index in range(4):
					scene.gun_index = gun_index; scene.case_index = case_index; scene.mount(false)
					check(scene.model.s.phase == "ready" and scene.model.s.magazine.size() >= 3, "Compiled comparison loads earned encounter")
					var before_ejection: Dictionary = scene.model.s.duplicate(true)
					scene.toggle_ejection(); scene.select_ejection(1)
					check(scene.model.s == before_ejection and scene.eject_selected == [1], "Packaged selection is reversible")
					scene.apply_ejection()
					check(scene.model.s.magazine == before_ejection.magazine.slice(0,1) + before_ejection.magazine.slice(2) and scene.model.ejection_remaining() == 1, "Packaged middle ejection")
					check(scene.model.s.heat == before_ejection.heat and scene.model.s.turns == before_ejection.turns, "Packaged ejection has no time or heat cost")
					check(scene.restore_comparison() and scene.model.ejection_remaining() == 1, "Packaged comparison save resumes quota")
					await scene.fire()
					check(not scene.busy, "Packaged firing finishes its real animation")
			print("MOBILE_COMPARISON_PROBE_PASS encounters=20 ejection=middle resume=1 fire=20")
		scene.queue_free()
		await process_frame
	if failures == 0: print("MOBILE_PACKAGE_PROBE_PASS model=", Model.VERSION)
	quit(0 if failures == 0 else 1)

func canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func journey_roundtrip(scene) -> void:
	var restored = scene.Journey.new()
	check(restored.restore(), "Packaged journey save loads")
	check(canonical(restored.data()) == canonical(scene.journey.data()), "Packaged journey preserves complete state/RNG")
	check(canonical(restored.results) == canonical(scene.journey.results) and canonical(restored.acquisitions) == canonical(scene.journey.acquisitions), "Rewards and battle records survive restore")

func probe_journey(scene, stage: String) -> void:
	scene.board.speed_scale = 0.01
	var campaign_save: String = scene.Journey.Campaign.SAVE
	var comparison_save: String = scene.COMPARISON_SAVE
	var marker := "mobile journey probe: preserve other modes"
	var expected_path := "user://mobile_journey_probe_expected.json"
	if stage == "write":
		for path in [campaign_save, comparison_save]:
			FileAccess.open(path, FileAccess.WRITE).store_string(marker)
		# New-run choices, real ejection and firing for every weapon, ending with
		# the default gun so the second process can replay a known earned route.
		for index in [1, 2, 3, 4, 0]:
			scene.open_panel("new");scene.node("JourneyGun").select(index)
			await scene.confirm_panel()
			check(scene.model.s.gun == scene.GUNS[index] and scene.journey.phase() == "combat", "Packaged journey starts chosen gun")
			var before: Dictionary = canonical(scene.journey.data())
			scene.select_ejection(1)
			check(canonical(scene.journey.data()) == before, "Packaged HUD selection does not spend ammo")
			scene.toggle_ejection()
			check(scene.model.ejection_remaining() == 1, "Packaged HUD removes selected round directly")
			await scene.fire()
			check(scene.model.s.shots > 0 and not scene.busy, "Packaged journey fires actual weapon")
			journey_roundtrip(scene)
		FileAccess.open(expected_path, FileAccess.WRITE).store_string(JSON.stringify(scene.journey.data()))
	else:
		check(scene.resumed, "New process resumes packaged journey")
		check(canonical(scene.journey.data()) == JSON.parse_string(FileAccess.get_file_as_string(expected_path)), "New process preserves partial magazine, spent quota, heat and RNG")
		scene.mount(false)
		check(scene.model.ejection_remaining() == 2 and scene.journey.phase() == "combat", "Packaged retry restores encounter entry")
		# Verified inputs for seed731042, siege core and first offered ammo.
		# Feasibility regression only: this is not a player policy or win rate.
		var paths := {101:["fire","fire","fire"],201:["fire","fire"],401:["fire","swap","fire","fire"],602:["fire","fire"],802:["fire","cool","fire","fire","swap","fire","fire","fire"]}
		var workshops := 0
		for step in range(40):
			journey_roundtrip(scene)
			var phase: String = scene.journey.phase()
			if phase == "complete":break
			if phase == "combat":
				for action in paths.get(int(scene.journey.campaign.s.node), []):
					match action:
						"fire":await scene.fire()
						"cool":await scene.cool()
						"swap":await scene.reload_magazine()
				check(scene.journey.phase() == "reward", "Packaged actual combat opens rewards")
			elif phase in ["reward", "supply"]:
				if phase == "supply":workshops += 1
				var index: int = scene.reward_ids.find("siege_drive") if scene.journey.campaign.engine_reward() else 0
				scene.select_reward(index)
				check(not scene.flow.projected.is_empty(), "Packaged reward preview loads and applies real command")
				await scene.confirm_panel()
			elif phase == "map":await scene.confirm_panel()
			else:check(false, "Unexpected packaged journey phase: " + phase);break
		check(scene.journey.phase() == "complete" and scene.journey.results.size() == 5 and workshops == 2, "Packaged five battles and two workshops reach the gate")
		check(int(scene.model.s.engine.levels.get("siege_drive", 0)) == 3, "Packaged earned core actually grows")
	for path in [campaign_save, comparison_save]:
		check(FileAccess.get_file_as_string(path) == marker, "Other play-mode save remains byte-identical")
	if failures == 0:print("MOBILE_JOURNEY_PROBE_PASS stage=", stage)
