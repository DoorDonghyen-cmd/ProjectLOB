extends "res://tests/fire_heat_rules.gd"
const Campaign = preload("res://redesign/campaign.gd")
const Focus = preload("res://redesign/focus_build.gd")

# Controlled combat contracts, deliberately separate from earned-climb evidence.
func fixture(rounds: Array, parts: Array, gun: String = "single", modern: bool = true):
	var c = Campaign.new(); c.start(gun,17,0,"balanced",3,"carrier",true)
	var m = c.model
	if not modern: m.s.erase("focus_build_version")
	m.s.equipped_parts = parts; m.s.part = "none"
	m.s.deck = rounds.duplicate()
	while m.s.deck.size() < 8: m.s.deck.append("basic_p2")
	m.begin_encounter()
	m.s.magazine = rounds.duplicate(); m.s.magazine_loaded = rounds.duplicate()
	m.s.hand = []; m.s.draw = m.s.deck.duplicate()
	for id in rounds: m.s.draw.erase(id)
	m.s.phase = "ready"; m.s.magazine_ejected = 0
	m.s.enemies = [m.s.enemies[0]]
	m.s.enemies[0].merge({"hp":10000,"max_hp":10000,"distance":1000,"def":0,"speed":1},true)
	m.s.encounter_total = 1; m.s.deployed = 1
	m._record("load", {"load_order":rounds.duplicate(),"whole_magazine":true})
	m.s.fire_heat_trial.rounds = 1
	restore_check(m)
	return m

func shot(m) -> Dictionary:
	return verify_fire(m).results[0]

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/focus_build_20261103/"): quit(2); return
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var m = fixture(["basic_p2","charge","precise_p2","basic_p2"],["third_striker"],gun)
		shot(m); shot(m)
		check(m.cool_magazine(),"cool before the third shot")
		var restored = Model.new();check(restored.restore_state(canonical(m.s)),"third-shot timing survives JSON resume")
		var r := shot(restored)
		check(int(r.get("part_factor",1)) == 3 and int(r.magazine_ordinal) == 3,"third actual round multiplies, after partial inputs/cooling/resume "+gun)
		check(int(r.math.raw) == int(r.math.subtotal)*3,"third shot exact raw formula")
		check(r.part_effects.any(func(p):return p.id == "third_striker"),"actual positional activation is visible")
		check(r.hits == 2,"multi-hit round is one ordinal")
		var fourth := shot(restored)
		check(fourth.part_factor == 1 and fourth.magazine_ordinal == 4,"fourth round never repeats third proc")
		check(restored.reload_magazine(),"real replacement reloads")
		var next := shot(restored)
		check(next.magazine_ordinal == 1 and next.part_factor == 1,"reload starts a fresh ordinal")
	var support = fixture(["basic_p2","basic_p2","charge","precise_p2"],["third_striker"])
	shot(support);shot(support)
	var grant := shot(support)
	check(grant.damage == 0 and grant.part_factor == 1 and grant.magazine_ordinal == 3,"support consumes third position without false damage")
	check(shot(support).part_factor == 1,"third support cannot bank multiplier for later")
	var aligned = fixture(["basic_p2","charge","basic_p2","precise_p2"],["third_striker"])
	var unaligned = fixture(["basic_p2","charge","basic_p2","precise_p2"],["third_striker"])
	check(aligned.eject_magazine_rounds([2]),"legal middle ejection aligns the payoff")
	shot(aligned);shot(aligned);var payoff := shot(aligned)
	shot(unaligned);shot(unaligned);shot(unaligned)
	if unaligned.s.phase == "ready":unaligned.cool_magazine()
	var plain := shot(unaligned)
	check(payoff.damage > plain.damage and payoff.part_factor == 3 and plain.part_factor == 1,"same deck: ejection saves boost for the multiplied main round")
	records.append({"case":"align_main","aligned":payoff,"unchanged":plain})
	var stacked = fixture(["basic_p2","charge","pierce_p2"],["third_striker","afterburner","siege_drive"])
	shot(stacked);shot(stacked);var hit := shot(stacked)
	check(hit.part_factor == 9 and hit.engine_percent == 200,"third and prepared final single stack with core")
	check(hit.math.raw == hit.math.subtotal*18,"addition before positional and core multiplication")
	records.append({"case":"stacked_finish","shot":hit})
	var fake = fixture(["charge","basic_p2","pierce_p2"],["afterburner"])
	shot(fake);shot(fake)
	check(shot(fake).part_factor == 1,"spent support in the magazine does not grant final multiplier")
	var old = fixture(["charge","basic_p2","pierce_p2"],["afterburner"],"single",false)
	shot(old);shot(old)
	check(shot(old).part_factor == 2,"historical magazine retains old afterburner condition")
	for modern in [true,false]:
		var first = fixture(["precise_p2","basic_p2"],["opening"],"single",modern)
		var r := shot(first)
		check(r.part_factor == (2 if modern else 1),"opening rule is versioned")
	var old_scatter = fixture(["pierce_p3","basic_p2"],["opening"],"scatter",false)
	var old_preview := Forecast.analyze(old_scatter.s,true)
	old_scatter.s.focus_build_version = 1
	var new_preview := Forecast.analyze(old_scatter.s,true)
	check(new_preview.shots[0].damage_max != old_preview.shots[0].damage_max,"scatter cache separates rule versions")
	var c = Campaign.new();c.start("single",17,0,"balanced",3,"carrier",true)
	var before: Dictionary = canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
	for invalid in [0.5,2,"1"]:
		var bad := before.duplicate(true);bad.campaign.focus_build_version = invalid
		check(not c.restore_state(bad),"malformed focus version rejected")
	var mismatch := before.duplicate(true);mismatch.combat.erase("focus_build_version")
	check(not c.restore_state(mismatch),"campaign/model version mismatch rejected")
	check(canonical(c.s) == before.campaign,"invalid restore is atomic")
	for core in ["volley_drive","siege_drive","thermal_drive"]:
		c.s.equipped_parts = [core];c.model.s.equipped_parts = [core]
		var id: String = Focus.opening_options(c.model.s)[0]
		var deck := Focus.replace_opening(c.model.s.deck,id)
		check(deck.size() == c.model.s.deck.size() and deck.count(id) == 2,"starter package replaces basics without inflation")
		var state: Dictionary = c.model.s.duplicate(true);state.deck = deck
		check(Focus.main_round(state) == id,"chosen core's main round remains the focus")
		for n in range(20):
			var offer := Focus.rewards(state,{"id":n},["arc","bore"])
			check(offer.size() == 3 and offer[0] == id,"rewards repeat exact profile alongside support/discovery")
	check(not Campaign.Content.eligible_parts("single",3).has("third_striker"),"old shops exclude new module")
	check(Campaign.Content.eligible_parts("single",3,1).has("third_striker"),"new shops include new module")
	for id in ["precise_p2", "pierce_p2", "vent"]:
		var state: Dictionary = c.model.s.duplicate(true); state.deck = Focus.replace_opening(c.model.s.deck,id)
		var before_deck: Array = state.deck.duplicate()
		var upgrade := Focus.upgrade(id)
		var offers := Focus.rewards(state,{"id":402,"floor":4,"region":0},["arc","bore"])
		check(offers[0] == id and offers[2] == upgrade,"same-profile copy and upgraded copy are separate choices")
		check(state.deck == before_deck and Content.AMMO.has(upgrade),"offering improvement never mutates owned cards")
		check(Content.is_compressed(upgrade) or Content.AMMO[upgrade].dmg > Content.AMMO[id].dmg,"upgrade uses real power/compression profile")
	var relay = fixture(["basic_p2","charge","precise_p2"],["third_striker","volley_drive"])
	shot(relay);shot(relay)
	relay.s.enemies[0].hp = 1
	var second: Dictionary = relay.s.enemies[0].duplicate(true);second.hp=1000;second.max_hp=1000;second.distance+=10
	relay.s.enemies.append(second);relay.s.encounter_total=2;relay.s.deployed=2
	var relayed := shot(relay)
	check(relayed.relay_hits == 1 and relayed.relay_damage == relayed.math.raw,"unused multi-hit retains positional multiplier on next enemy")
	records.append({"case":"multiplied_relay","shot":relayed})
	var scattered = fixture(["basic_p2","charge","precise_p2"],["third_striker"],"scatter")
	for armor in [2,4]:
		var target: Dictionary = scattered.s.enemies[0].duplicate(true);target.def=armor;target.distance+=armor
		scattered.s.enemies.append(target)
	scattered.s.encounter_total=3;scattered.s.deployed=3
	shot(scattered);shot(scattered);shot(scattered)
	var package_save := ProjectSettings.globalize_path("res://../qa_runtime/focus_build_20261103/ui_final/after_package.json")
	if FileAccess.file_exists(package_save):
		var resumed = Campaign.new()
		check(resumed.restore_state(JSON.parse_string(FileAccess.get_file_as_string(package_save))),"fresh process restores actual UI starter choice")
		check(Focus.enabled(resumed.model.s) and resumed.model.s.deck.count("pierce_p2") == 2,"UI package and new rules persist together")
		check(resumed.enter(int(resumed.choices()[0].id)),"fresh-process package continues to next real room")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("FOCUS BUILD COMPLETE checks=%d failures=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
