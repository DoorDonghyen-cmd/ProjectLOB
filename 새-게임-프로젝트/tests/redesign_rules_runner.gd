extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + label)

func fixture(gun: String = "single"):
	var m = Model.new()
	m.start(gun, 731042)
	m.s.hand = ["bore", "pierce", "mark", "push", "charge", "slow", "precise"]
	m.s.enemies = [{"kind": "wall", "name": "fixture", "hp": 100, "max_hp": 100, "def": 3, "eva": 4, "speed": 2, "distance": 30, "slow": 0}]
	return m

func _run() -> void:
	var m = fixture()
	check(not m.fire() and not m.confirm() and not m.reload_magazine(), "illegal commands rejected")
	var original: Dictionary = m.s.duplicate(true)
	check(not m.load_round("absent") and m.s == original, "invalid ammo no mutation")
	m.load_round("basic")
	m.load_round("bore")
	check(m.preview().id == "bore", "last load first fire")
	var before: Dictionary = m.s.duplicate(true)
	m.preview()
	check(m.s == before, "preview does not alter any state / RNG")
	m.undo()
	check(m.s.turns == 0 and m.available("bore") == 1, "undo restores availability without time")
	m.load_round("bore")
	m.confirm()
	check(not m.undo() and not m.load_round("basic"), "confirmed order immutable")
	var preview: Dictionary = m.preview()
	m.fire()
	check(m.s.enemies[0].hp == preview.hp and m.s.buff.get("pen") == 3, "preview and shot resolver agree")
	m.fire()
	check(m.s.enemies[0].hp == 94, "bore then basic penetrates armor with single bonus")
	check(m.s.turns == 2 and m.s.enemies[0].distance == 26, "single fire advances once each")
	m.reload_magazine()
	check(m.s.turns == 3 and m.s.enemies[0].distance == 24, "single reload costs one turn")
	check(m.s.buff.is_empty() and m.s.supply == 3 and m.s.phase == "plan", "reload resets buffs and supply")
	m = fixture()
	m.load_round("bore")
	m.load_round("basic")
	m.confirm()
	m.fire()
	check(m.s.enemies[0].hp == 100, "reverse ordering blocks basic on armor")
	m = fixture()
	m.s.enemies[0].eva = 9
	m.load_round("pierce")
	m.load_round("bore")
	m.confirm()
	m.fire()
	check(m.s.buff.get("pen") == 3 and m.s.enemies[0].hp == 100, "miss still prepares next shot")
	m.fire()
	check(m.s.buff.is_empty(), "buff spent even on missed next shot")
	m = fixture()
	m.s.hand = ["push", "push"]
	m.load_round("push")
	m.load_round("push")
	m.confirm()
	m.fire()
	m.fire()
	check(m.s.enemies[0].distance == 28 and m.s.push_left == 0, "push applies through armor but capped at two per magazine")
	m = fixture("burst")
	m.s.enemies[0].def = 0
	m.load_round("basic")
	m.load_round("basic")
	m.load_round("basic")
	m.load_round("charge")
	check(not m.load_round("pierce"), "capacity respected")
	m.confirm()
	m.fire()
	check(m.s.shots == 4 and m.s.turns == 1 and m.s.enemies[0].distance == 28, "burst all shots one advance")
	check(m.s.enemies[0].hp == 86, "one shot charge effect not entire magazine")
	m.reload_magazine()
	check(m.s.turns == 4 and m.s.enemies[0].distance == 22, "burst reload three turns")
	m = fixture("burst")
	m.s.enemies[0].distance = 3
	m.load_round("basic")
	m.confirm()
	m.reload_magazine()
	check(m.s.phase == "lost" and m.s.turns == 2, "reload stops at lethal turn")
	m = fixture()
	m.s.enemies[0].distance = 2
	m.s.enemies[0].hp = 1
	m.s.enemies[0].def = 0
	m.load_round("basic")
	m.confirm()
	m.fire()
	check(m.s.phase == "reward", "last kill resolves before advance")
	check(not m.choose_reward("unknown"), "invalid reward rejected")
	check(m.choose_reward("slow") and m.s.floor == 1 and m.s.deck.count("slow") == 1, "reward adds exactly once and advances")
	check(not m.choose_reward("slow"), "duplicate reward rejected")
	m = fixture()
	m.load_round("slow")
	m.confirm()
	m.fire()
	check(m.s.enemies[0].distance == 30 and m.s.enemies[0].slow == 0, "slow affects exactly next movement")
	m.reload_magazine()
	check(m.s.enemies[0].distance == 28, "slow does not persist")
	m = Model.new()
	m.start("single", 731042)
	for cycle in range(5):
		var available: Array = m.s.hand.duplicate()
		m.load_round(str(available[0]))
		m.confirm()
		m.s.enemies[0].hp = 1000
		m.s.enemies[0].max_hp = 1000
		m.s.enemies[0].distance = 1000
		m.fire()
		m.reload_magazine()
		var owned: Array = m.s.hand + m.s.draw + m.s.discard + m.s.magazine
		owned.sort()
		var deck: Array = m.s.deck.duplicate()
		deck.sort()
		check(owned == deck, "tactical inventory conserved cycle %d" % cycle)
	var path := "user://redesign_rules_save.json"
	m.load_round("basic")
	check(m.save_run(path) == OK, "save planning state")
	var restored = Model.new()
	check(restored.restore_run(path), "restore planning state")
	check(JSON.parse_string(JSON.stringify(m.s)) == restored.s, "full state including RNG preserved")
	m.confirm()
	restored.confirm()
	m.fire()
	restored.fire()
	m.reload_magazine()
	restored.reload_magazine()
	check(JSON.parse_string(JSON.stringify(m.s)) == JSON.parse_string(JSON.stringify(restored.s)), "future shuffle and actions identical after resume")
	check(m.save_run(path) == OK, "atomic replacement of existing save")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	check(not restored.restore_run(path), "truncated save safely rejected")
	for big_seed in [9007199254740993, -9007199254740993]:
		m = Model.new()
		m.start("single", big_seed)
		check(m.save_run(path) == OK and restored.restore_run(path), "large seed round trip")
		check(str(restored.s.seed) == str(big_seed), "large seed preserves every digit")
		m.s.floor = 1
		restored.s.floor = 1
		m.begin_encounter()
		restored.begin_encounter()
		check(m.s.hand == restored.s.hand and m.s.rng_state == restored.s.rng_state, "large seed next encounter deterministic")
	var valid: Dictionary = m.s.duplicate(true)
	var malformed: Array = []
	var too_many: Dictionary = valid.duplicate(true)
	too_many.plan = ["basic", "basic", "basic", "basic", "basic"]
	too_many.supply = 9
	malformed.append(too_many)
	var bad_enemy: Dictionary = valid.duplicate(true)
	bad_enemy.enemies = [{}]
	malformed.append(bad_enemy)
	var duplicated: Dictionary = valid.duplicate(true)
	duplicated.hand.append(duplicated.hand[0])
	malformed.append(duplicated)
	for data in malformed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var before_restore: Dictionary = restored.s.duplicate(true)
		check(not restored.restore_run(path) and restored.s == before_restore, "invalid snapshot rejected without altering live state")
	m.s = too_many
	check(not m.confirm(), "confirm independently rejects over-capacity plan")
	m = Model.new()
	m.start("single", 42)
	m.s.floor = 1
	check(not m.reward_options().has("loader"), "single gun excludes ineffective reload part")
	print("REDESIGN RULES: %d passed / %d failed" % [passed, failed])
	quit(1 if failed else 0)
