extends SceneTree
## Small isolated probes for the 2026-10-26 playtest review, not a balance verdict.
const Model = preload("res://redesign/model.gd")
const Data = preload("res://redesign/content.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; print("FAIL: " + label)

func target(hp: int, armor: int = 0):
	var model = Model.new()
	model.start("burst", 261026)
	model.s.enemies.resize(1)
	model.s.enemies[0].hp = hp
	model.s.enemies[0].max_hp = hp
	model.s.enemies[0].def = armor
	model.s.enemies[0].distance = 60
	model.s.reinforcements = []
	model.s.projectiles = []
	return model

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_20261026/"):
		quit(2); return
	var armor_cases: Array = []
	for armor in [0, 3, 5]:
		for ammo in ["basic_p3", "pierce_p3"]:
			var model = target(200, armor)
			var result: Dictionary = model._shot(ammo, 0)
			armor_cases.append({"armor":armor,"ammo":ammo,"raw":result.math.raw,"effective_armor":result.math.armor,"damage":result.damage})
	check(armor_cases[2].damage < armor_cases[0].damage, "armor reduces real hit damage")
	check(armor_cases[3].damage > armor_cases[2].damage, "piercing improves matched-power hit into armor")
	var heat_cases: Array = []
	for hp in [200, 1]:
		var model = target(hp)
		model.s.hand = ["basic_p3"]
		model.s.heat = Data.heat_limit(model.s) - Data.heat_delta("basic_p3", model.s)
		check(model.load_round("basic_p3") and model.confirm() and model.fire(), "legal heat probe")
		var event: Dictionary = model.s.history.back().detail
		heat_cases.append({"enemy_hp_before":hp,"turns":model.s.turns,"heat_peak":event.heat_peak,"heat_after":model.s.heat,"forced_reload":event.forced_reload,"phase":model.s.phase})
	check(not heat_cases[0].forced_reload.is_empty(), "surviving enemies trigger forced cooling")
	check(heat_cases[1].forced_reload.is_empty() and heat_cases[1].turns == 1, "winning shot skips forced cooling")
	var exhausted = target(200)
	exhausted.s.reserve_version = 1
	for zone in ["hand", "draw", "magazine", "plan"]: exhausted.s[zone] = []
	exhausted._settle_ammo_exhaustion()
	check(exhausted.s.phase == "lost" and exhausted.s.loss_reason == "ammo", "finite reserve exhaustion already resolves defeat")
	var result := {"armor":armor_cases,"heat":heat_cases,"exhaustion":exhausted.s.loss_reason,"failures":failures,"scope":"Current resolver probes; not campaign win rate, player save reproduction or frame profiling."}
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("mechanics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")); file.close()
	print(JSON.stringify(result))
	print("PLAYTEST MECHANICS COMPLETE failures=%d" % failures)
	quit(1 if failures else 0)
