extends SceneTree
## Current vs tag scheme, what the parts actually do (2026-11-11, user: "지금의 태그 방식과
## 이전의 방식이 구체적으로 어떤 차이를 만드는지부터 비교"). Region 4-5 fights saved by the
## seed-17 climbs of both schemes are solved and replayed; every shot is tallied: special or
## basic round, which parts reported an effect, damage.
const Campaign = preload("res://redesign/campaign.gd")
const Content = preload("res://redesign/content.gd")
const Solver = preload("res://tests/fire_control_solver.gd")

func _initialize() -> void: run.call_deferred()

## Controlled: the current-scheme climb's own fights (same deck, same enemies) with only the
## parts swapped for the tag scheme's typical set (what the tag climbs equipped at the end).
const TAG_SETS := {
	"single": ["third_striker", "opening", "tag_single_add", "tag_single_mult", "tag_copy"],
	"burst": ["third_striker", "resonator", "tag_multi_add", "tag_control_mult", "duplex"],
	"heavy": ["tag_fire_add", "tag_burning_mult", "tag_fire_burn", "tag_low_mult", "compression_sink"]}
var swap_gun := ""

func tally(folder: String, gun: String) -> Dictionary:
	var solver = Solver.new()
	var out := {"fights": 0, "won": 0, "turns": 0, "shots": 0, "special_shots": 0, "touched": 0, "special_touched": 0, "damage": 0, "special_damage": 0, "parts": {}, "rounds": {}, "equipped": []}
	var files: Array = []
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("combat_%s_17_r4" % gun) or name.begins_with("combat_%s_17_r5" % gun): files.append(name)
	files.sort()
	for name in files:
		var c = Campaign.new()
		if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(name)))): continue
		out.fights += 1
		if not swap_gun.is_empty():
			c.model.s.tag_build_version = preload("res://redesign/tag_build.gd").VERSION
			for id in TAG_SETS[swap_gun]:
				if not c.s.parts.has(id): c.s.parts.append(id)
			c.s.equipped_parts = TAG_SETS[swap_gun].duplicate()
			c._sync_equipped_parts()
		out.equipped = c.s.equipped_parts.duplicate()
		var path: Array = solver.solve(c.model)
		if path.is_empty(): path = solver.solve(c.model, 12, 10)
		var m = c.model
		var start_turns := int(m.s.turns)
		var start_history: int = m.s.history.size()
		for step in path:
			match str(step.action):
				"fire":
					m.s.fire_heat_trial.rounds = int(step.get("rounds", 0)); m.fire()
				"cool": m.cool_magazine()
				"reload": m.reload_magazine()
				"emergency": m.emergency_resupply()
				"eject": m.eject_magazine_rounds(step.indices)
		if m.s.phase in ["reward", "won"]: out.won += 1
		out.turns += int(m.s.turns) - start_turns
		for i in range(start_history, m.s.history.size()):
			for shot in m.s.history[i].get("detail", {}).get("results", []):
				var id := str(shot.get("id", ""))
				if id.is_empty() or not Content.AMMO.has(id): continue
				var special := Content.source_id(id) != "basic"
				var effects: Array = shot.get("part_effects", [])
				var damage := int(shot.get("damage", 0))
				out.shots += 1; out.damage += damage
				out.rounds[Content.source_id(id)] = int(out.rounds.get(Content.source_id(id), 0)) + 1
				if special: out.special_shots += 1; out.special_damage += damage
				if not effects.is_empty():
					out.touched += 1
					if special: out.special_touched += 1
				var seen: Array = []
				for effect in effects:
					var part := str(effect.get("id", ""))
					if seen.has(part): continue
					seen.append(part)
					out.parts[part] = int(out.parts.get(part, 0)) + 1
	return out

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/tag_build_20261110/"): quit(2); return
	var base := OS.get_environment("QA_CLIMB_DIR")
	var report := {}
	for gun in ["single", "burst", "heavy"]:
		for scheme in [["current", "tags/%s_tags0" % gun, ""], ["tags", "tags_equip/%s_tags1_s17" % gun, ""], ["swap", "tags/%s_tags0" % gun, gun]]:
			swap_gun = str(scheme[2])
			var row := tally(base.path_join(str(scheme[1])), gun)
			report["%s/%s" % [gun, scheme[0]]] = row
			print("COMPARE %s %s fights=%d won=%d turns=%d shots=%d special=%d touched=%d special_touched=%d damage=%d special_damage=%d parts=%s equipped=%s rounds=%s" % [gun, scheme[0], row.fights, row.won, row.turns, row.shots, row.special_shots, row.touched, row.special_touched, row.damage, row.special_damage, JSON.stringify(row.parts), JSON.stringify(row.equipped), JSON.stringify(row.rounds)])
	FileAccess.open(output.path_join("scheme_compare.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	quit(0)
