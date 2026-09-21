extends SceneTree
## Deterministic contract tests for the public reserve and low-HP horde loop.

const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func enemy(kind: String, hp: int, armor: int, speed: int, distance: int, extra: Dictionary = {}) -> Dictionary:
	var result := {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": hp, "max_hp": hp, "def": armor, "speed": speed, "distance": distance, "burn": 0}
	for key in extra: result[key] = extra[key]
	return result

func configure_horde(model, reserve_size: int = 2) -> void:
	model.s.enemies = [
		enemy("runner", 3, 0, 2, 12),
		enemy("evader", 3, 0, 2, 16),
		enemy("runner", 3, 0, 2, 20),
		enemy("wall", 3, 0, 1, 24),
	]
	model.s.reinforcements = [
		enemy("runner", 4, 0, 2, 26),
		enemy("absorber", 6, 1, 1, 30, {"barrier": 0, "barrier_max": 0}),
	].slice(0, reserve_size)
	model.s.encounter_total = model.s.enemies.size() + model.s.reinforcements.size()
	model.s.deployed = model.s.enemies.size()
	model.s.wave = 1
	model.assign_opening_lanes()

func load_basics(model, count: int) -> void:
	for i in range(count): check(model.load_round("basic"), "basic %d loads" % i)
	check(model.confirm(), "magazine confirms")

func _run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)

	for region in range(5):
		var nodes := CampaignContent.nodes(region, 731042)
		for node in nodes:
			if node.kind not in ["combat", "boss"]: continue
			var pack := CampaignContent.encounter_pack(node, 731042, "single", 0, 0)
			check(pack.active.size() <= 4, "active front is capped at four r%d n%d" % [region, node.id])
			check(pack.total == pack.active.size() + pack.reserve.size(), "pack count is exact r%d n%d" % [region, node.id])
			check(pack.total <= 8, "encounter total is capped at eight r%d n%d" % [region, node.id])

	var wipe = Model.new()
	wipe.start("single", 731042)
	configure_horde(wipe, 2)
	var reserve_distances := [wipe.s.reinforcements[0].distance, wipe.s.reinforcements[1].distance]
	load_basics(wipe, 4)
	var wipe_forecast := Forecast.analyze(wipe.s)
	check(wipe_forecast.deployments.size() == 2 and wipe_forecast.phase == "ready", "forecast includes forced next wave without premature victory")
	check(wipe.fire(), "full front volley resolves")
	var wipe_detail: Dictionary = wipe.s.history.back().detail
	check(wipe_detail.deployments.size() == 2, "full front wipe deploys both reserves")
	check(wipe.s.phase == "ready" and wipe.alive_count() == 2 and wipe.reserve_count() == 0, "reserve keeps encounter active")
	check([wipe.s.enemies[4].distance, wipe.s.enemies[5].distance] == reserve_distances, "newly deployed enemies do not move on entry turn")
	check(wipe.s.wave == 2 and wipe.s.deployed == 6, "wave and deployed counters advance")

	var top_up = Model.new()
	top_up.start("single", 17)
	configure_horde(top_up, 2)
	load_basics(top_up, 2)
	check(top_up.fire(), "partial volley resolves")
	var partial_detail: Dictionary = top_up.s.history.back().detail
	check(partial_detail.deployments.size() == 2 and top_up.alive_count() == 4, "two survivors are topped back up to four")
	check(top_up.s.enemies[2].distance == 18 and top_up.s.enemies[3].distance == 23, "old survivors advance before reinforcements enter")
	check(top_up.s.enemies[4].distance == 26 and top_up.s.enemies[5].distance == 30, "top-up reinforcements keep disclosed distance")
	check([top_up.s.enemies[2].lane, top_up.s.enemies[3].lane] == [2, 3], "survivors keep their original lanes")
	check([top_up.s.enemies[4].lane, top_up.s.enemies[5].lane] == [0, 1], "reinforcements use only vacated lanes")

	var execution = Model.new()
	execution.start("amplifier", 31)
	execution.s.enemies = [enemy("runner", 4, 0, 1, 12), enemy("runner", 4, 0, 1, 16), enemy("runner", 4, 0, 1, 20)]
	execution.s.reinforcements = []
	execution.s.encounter_total = 3
	execution.s.deployed = 3
	load_basics(execution, 3)
	check(execution.fire(), "execution chain fires")
	check(execution.s.history.back().detail.results.size() == 3 and execution.s.turns == 1, "amplifier continues through consecutive kills in one turn")

	var stopped = Model.new()
	stopped.start("amplifier", 32)
	stopped.s.enemies = [enemy("runner", 5, 0, 1, 12), enemy("runner", 4, 0, 1, 16)]
	stopped.s.reinforcements = []
	stopped.s.encounter_total = 2
	stopped.s.deployed = 2
	load_basics(stopped, 3)
	check(stopped.fire(), "failed execution shot resolves")
	check(stopped.s.history.back().detail.results.size() == 1 and stopped.s.magazine.size() == 2, "first survivor ends execution chain")
	check(stopped.s.enemies[0].distance == 11 and stopped.s.enemies[1].distance == 15, "surviving front advances once")

	var save_path := output.path_join("horde_state.json")
	check(top_up.save_run(save_path) == OK, "horde state saves")
	var restored = Model.new()
	check(restored.restore_run(save_path), "horde state restores")
	check(restored.s.reinforcements == top_up.s.reinforcements and restored.s.wave == top_up.s.wave and restored.s.deployed == top_up.s.deployed, "reserve state round trips exactly")

	var report := FileAccess.open(output.path_join("horde_reinforcement_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("HORDE REINFORCEMENT COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
