extends SceneTree
## Deck-building revision (magazine_build.gd, 2026-11-01): start deck, magazine-
## composition parts, combo readout, save compatibility. Runs on isolated user://.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Build = preload("res://redesign/magazine_build.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)
	return ok

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"):
		print("refusing to run outside qa_runtime user://"); quit(2); return
	start_deck_checks()
	part_checks()
	save_checks()
	print("MAGAZINE BUILD RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func new_run(magazine: bool):
	var c = Campaign.new()
	c.start("single", 731042, 0, "balanced", 3, "carrier", magazine)
	return c

func start_deck_checks() -> void:
	var c = new_run(true)
	check(Build.enabled(c.s) and Build.enabled(c.model.s), "new climb records build version on campaign and combat")
	check(c.model.s.deck.size() == 14 and c.model.s.deck.count("basic_p2") == 8 and c.model.s.deck.count("basic_p3") == 6, "new climb starts with 14 basics (p2 x8, p3 x6)")
	for gun in ["burst", "scatter", "heavy"]:
		var pulse = Campaign.new(); pulse.start(gun, 731042, 0, "balanced", 3, "carrier", true)
		check(pulse.model.s.deck.size() == 20 and pulse.model.s.deck.count("basic_p2") == 12 and pulse.model.s.deck.count("basic_p3") == 8, gun + " starts with 20 basics")
	for gun in ["amplifier"]:
		var other = Campaign.new(); other.start(gun, 731042, 0, "balanced", 3, "carrier", true)
		check(other.model.s.deck.size() == 14, gun + " starts with 14 basics")
	var legacy = new_run(false)
	check(not Build.enabled(legacy.s) and not Build.enabled(legacy.model.s), "legacy fixture has no build version")
	check(legacy.model.s.deck == Model.Reserve.start_deck() and legacy.model.s.deck.size() == 20, "legacy fixture keeps the 20-card deck")
	check(c.enter(int(c.choices()[0].id)), "first combat entry")
	check(c.model.s.phase == "ready" and c.model.s.magazine_loaded == c.model.s.magazine, "auto-loaded magazine is recorded")
	var before: Array = c.model.s.magazine.duplicate()
	check(c.model.eject_magazine_rounds([0]), "eject one round")
	var expected: Array = before.duplicate(); expected.erase(before[0])
	check(c.model.s.magazine_loaded == expected, "ejected round leaves the loaded record")
	vitality_checks()

## Version 2: enemy HP scaled once at combat entry; version 1 runs keep authored HP.
func vitality_checks() -> void:
	var tough = new_run(true)
	check(int(tough.s.magazine_build_version) == Build.VERSION and Build.vitality(tough.model.s), "new climb records vitality version")
	var plain = new_run(true)
	plain.s.magazine_build_version = 1; plain.model.s.magazine_build_version = 1
	var node_id := int(tough.choices()[0].id)
	tough.enter(node_id); plain.enter(node_id)
	var scale: float = Build.HP_SCALE.normal
	var pairs: Array = []
	for group in ["enemies", "reinforcements"]:
		for i in range(plain.model.s[group].size()):
			pairs.append([plain.model.s[group][i], tough.model.s[group][i]])
	check(not pairs.is_empty(), "encounter has enemies")
	for pair in pairs:
		var hp_factor: float = Build.hp_scale(pair[0], scale)
		check(int(pair[1].max_hp) == ceili(int(pair[0].max_hp) * hp_factor) and int(pair[1].hp) == int(pair[1].max_hp), "normal enemy HP x%.2f: %d -> %d" % [hp_factor, pair[0].max_hp, pair[1].max_hp])
		var far: int = ceili(int(pair[0].distance) * (1.0 + (scale - 1.0) * Build.DISTANCE_SHARE)) if int(pair[0].speed) > 0 else int(pair[0].distance)
		check(int(pair[1].distance) == far and int(pair[1].speed) == int(pair[0].speed), "moving enemy starts farther, speed unchanged: %d -> %d" % [pair[0].distance, pair[1].distance])
	check(not Build.vitality(plain.model.s), "version 1 run keeps authored HP")
	check(is_equal_approx(Build.hp_scale({"def": 6}, 2.0), 1.5) and is_equal_approx(Build.hp_scale({"def": 0, "guard_armor": 5}, 1.4), 1.2) and is_equal_approx(Build.hp_scale({"def": 0}, 2.0), 2.0), "armoured enemies get half the HP increase")
	var data: Dictionary = JSON.parse_string(JSON.stringify({"campaign": tough.s, "combat": JSON.parse_string(tough.model.serialized_state()), "profile": tough.profile}))
	var copy = Campaign.new()
	check(copy.restore_state(data) and JSON.stringify(copy.model.s.enemies) == JSON.stringify(JSON.parse_string(JSON.stringify(tough.model.s.enemies))), "scaled HP survives save without rescaling")

## A combat model in the new mode with a crafted magazine and sturdy, distant enemies.
func rig(parts: Array, magazine: Array, build: bool = true):
	var c = new_run(true)
	c.enter(int(c.choices()[0].id))
	var m = Model.new()
	m.s = c.model.s.duplicate(true)
	if not build:
		# Same automatic magazine, original order-based part rules.
		m.s.erase("magazine_build_version")
		m.s.erase("magazine_loaded")
	m.s.equipped_parts = parts.duplicate()
	m.s.part = "none"
	m.s.heat = 0
	m.s.buff = {}
	for e in m.s.enemies:
		e.hp = 999; e.max_hp = 999; e.distance = 99
	m.s.reinforcements = []
	m.s.magazine = magazine.duplicate()
	Build.on_load(m.s)
	m.s.history.append({"action": "load", "detail": {}})
	return m

## Part effects of the most recent fire action. Fails loudly if none was recorded.
func effects(m) -> Array:
	var result: Array = []
	for i in range(m.s.history.size() - 1, -1, -1):
		var event: Dictionary = m.s.history[i]
		if str(event.get("action", "")) != "fire": continue
		check(event.get("detail", {}).has("results"), "fire record has shot results")
		for shot in event.detail.get("results", []):
			for effect in shot.get("part_effects", []): result.append({"id": str(shot.id), "part": str(effect.id)})
		check(not event.detail.get("results", []).is_empty(), "fire record is not empty")
		return result
	check(false, "a fire action was recorded %s phase=%s mag=%s" % [m.s.equipped_parts, m.s.phase, m.s.magazine])
	return result

func has_effect(list: Array, part: String, id: String = "") -> bool:
	return list.any(func(e): return e.part == part and (id.is_empty() or e.id == id))

func part_checks() -> void:
	var pierce := "pierce_p3"; var precise := "precise_p2"; var arc := "arc"
	for id in [pierce, precise, arc, "charge", "basic_p2"]: check(Content.AMMO.has(id), "fixture round exists " + id)
	# Triad: three special kinds anywhere in the magazine. Basic sits between them.
	var m = rig(["triad"], [pierce, "basic_p2", precise, arc])
	check(Build.special_kinds(m.s) == 3, "three special kinds counted")
	m.fire()
	var first: Array = effects(m)
	check(has_effect(first, "triad", pierce), "triad pays the first special attack regardless of order")
	check(not has_effect(first, "triad", "basic_p2"), "triad never pays basic rounds")
	var legacy = rig(["triad"], [pierce, "basic_p2", precise, arc], false)
	legacy.fire()
	check(not has_effect(effects(legacy), "triad"), "legacy order rule needs three different consecutive rounds")
	var two = rig(["triad"], [pierce, "basic_p2", precise, "basic_p3"])
	two.fire()
	check(not has_effect(effects(two), "triad"), "two special kinds do not form the triad")
	var ejected = rig(["triad"], [pierce, "basic_p2", precise, arc])
	check(ejected.eject_magazine_rounds([3]) and Build.special_kinds(ejected.s) == 2, "ejecting a kind breaks the triad")
	ejected.fire()
	check(not has_effect(effects(ejected), "triad"), "broken triad pays nothing")
	# Afterburner: a boost anywhere in the magazine readies the last single-hit attack.
	var after = rig(["afterburner"], ["charge", "basic_p2", pierce])
	after.fire(); after.fire()
	check(has_effect(effects(after), "afterburner", pierce), "afterburner fires with a non-adjacent boost")
	var after_legacy = rig(["afterburner"], ["charge", "basic_p2", pierce], false)
	after_legacy.fire(); after_legacy.fire()
	check(not has_effect(effects(after_legacy), "afterburner"), "legacy afterburner still needs the boost on that shot")
	# Compression stabiliser: an ordinary tactical round anywhere in the magazine.
	var compressed := ""
	for id in Content.AMMO:
		if Content.is_compressed(str(id)) and Content.is_attack(str(id)) and Content.heat_cost(str(id)) >= 2 and not Content.anchor(str(id)) in ["first", "last"]:
			compressed = str(id); break
	check(not compressed.is_empty(), "fixture compressed round found")
	if not compressed.is_empty():
		var sink = rig(["compression_sink"], [compressed, "basic_p2", precise])
		sink.fire()
		check(has_effect(effects(sink), "compression_sink", compressed), "compressed round cooled by a later ordinary round")
		var none = rig(["compression_sink"], [compressed, "basic_p2", "basic_p3"])
		none.fire()
		check(not has_effect(effects(none), "compression_sink"), "no ordinary round, no cooling")
	# HUD readout.
	var combo = rig(["triad"], ["charge", "basic_p2", pierce, precise, arc])
	var line := Build.combo_line(combo.s)
	check(line.contains("증폭탄→기본탄") and line.contains("삼중 4종"), "combo line names boost target and triad: " + line)
	check(Build.combo_line(rig([], ["basic_p2", "basic_p3"]).s).is_empty(), "plain magazine shows no combo")
	# Part text switches only in the new mode.
	var c = new_run(true)
	check(Content.part_spec("triad", c.s).text.contains("3종 이상") and Content.part_spec("triad", c.model.s).text.contains("3종 이상"), "triad text describes composition in new climbs")
	check(Content.part_spec("triad", new_run(false).s).text.contains("직전 두 발"), "legacy triad text unchanged")
	check(not Content.part_spec("opening", c.s).text.contains("결정합니다"), "opening text no longer promises manual order")

func save_checks() -> void:
	var c = new_run(true)
	c.enter(int(c.choices()[0].id))
	var data: Dictionary = JSON.parse_string(JSON.stringify({"campaign": c.s, "combat": JSON.parse_string(c.model.serialized_state()), "profile": c.profile}))
	var copy = Campaign.new()
	check(copy.restore_state(data.duplicate(true)), "new climb save restores")
	check(copy.model.s.magazine_loaded == c.model.s.magazine_loaded and Build.enabled(copy.s), "loaded record and version survive restore")
	var mismatch: Dictionary = data.duplicate(true); mismatch.campaign.erase("magazine_build_version")
	check(not Campaign.new().restore_state(mismatch), "campaign/combat build version mismatch rejected")
	var bad: Dictionary = data.duplicate(true); bad.combat.magazine_loaded = ["no_such_round"]
	check(not Campaign.new().restore_state(bad), "unknown loaded round rejected")
	var legacy = new_run(false)
	legacy.enter(int(legacy.choices()[0].id))
	var old: Dictionary = JSON.parse_string(JSON.stringify({"campaign": legacy.s, "combat": JSON.parse_string(legacy.model.serialized_state()), "profile": legacy.profile}))
	var restored = Campaign.new()
	check(restored.restore_state(old) and not Build.enabled(restored.model.s), "save without build version still restores unchanged")
