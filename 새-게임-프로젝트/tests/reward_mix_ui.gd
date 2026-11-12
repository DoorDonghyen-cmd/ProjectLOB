extends "res://tests/reward_trim_ui.gd"
## Mixed round rewards (2026-11-11, reward_mix.gd): main card / another attack round / support,
## on earned fights won into the real reward screen. Old saves keep the main-heavy cards.
const RewardMix = preload("res://redesign/reward_mix.gd")
const Ammo = preload("res://redesign/content.gd")
const Focus = preload("res://redesign/focus_build.gd")

func mixed(c) -> void:
	c.model.s.reward_mix_version = RewardMix.VERSION

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	# Picking the other attack round.
	check(RewardMix.other_attack(["precise", "pierce", "bore", "charge"], ["precise", "precise", "bore"], "precise", 0) == "pierce", "least-held other attack family (pierce, none held)")
	check(RewardMix.other_attack(["precise", "charge", "cool"], ["precise"], "precise", 3) == "", "no other attack in the pool → none")
	var fresh = Campaign.new(); fresh.start("burst", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(RewardMix.enabled(fresh.model.s), "new runs carry mixed rewards")
	for file in ["combat_burst_17_r2_n10101.json", "combat_single_17_r2_n10101.json", "combat_heavy_17_r2_n10101.json"]:
		var old = won_fight(file, false)
		var old_cards: Array = old.reward_options()
		var c = won_fight(file, false)
		mixed(c)
		var cards: Array = c.reward_options()
		var main: String = Focus.main_round(c.model.s)
		var family: String = Ammo.source_id(main)
		print("CARDS %s main %s old %s new %s" % [file, main, old_cards, cards])
		check(cards.size() == 3, "three cards " + file)
		check(Ammo.source_id(str(cards[0])) == family, "first card is the main round (copy or upgrade) " + file)
		check(Ammo.is_attack(str(cards[1])) and Ammo.source_id(str(cards[1])) not in ["basic", family], "second card is another attack round " + file)
		check(Focus.supports_for(c.model.s, family).has(Ammo.source_id(str(cards[2]))), "third card supports the main round " + file)
		check(cards.filter(func(id): return Ammo.source_id(str(id)) == family).size() == 1, "only one main card (was %d) %s" % [old_cards.filter(func(id): return Ammo.source_id(str(id)) == family).size(), file])
		var before: int = c.model.s.deck.size()
		check(c.reward(str(cards[1]), "") and c.model.s.deck.has(str(cards[1])) and c.model.s.deck.size() == before + 1, "taking the other attack round adds it " + file)
	var broken: Dictionary = JSON.parse_string(fresh.model.serialized_state())
	broken.reward_mix_version = 3
	check(not Campaign.Model.new().restore_state(broken), "unknown mix version rejected")
	# Screen: the three cards (plus 탄 1장 빼기) on the real reward screen.
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = won_fight("combat_burst_17_r2_n10101.json")
		mixed(c)
		await mount(c)
		var cards: Array = c.reward_options()
		for id in cards:
			var card := find("city_reward_" + str(id)) as Control
			check(card != null and card.is_visible_in_tree(), "card shown: %s %s" % [id, suffix])
		await capture("reward_mix_" + suffix)
	print("REWARD MIX UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
