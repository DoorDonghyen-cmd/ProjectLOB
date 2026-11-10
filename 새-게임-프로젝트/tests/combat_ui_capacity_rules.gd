extends SceneTree
const Model = preload("res://tests/combat_ui_stage1_probe_model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var failures: Array=[]
var rows: Array=[]
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)

func run() -> void:
	var out:=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_ui_capacity_20261031/"):quit(2);return
	for encounter in [201,401,802]:
		for slots in [3,4,6]:
			var path: String=ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final/combat_single_731042_v12_carrier_n%d.json" % encounter)
			var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
			var model=Model.new()
			check(model.restore_state(original.combat),"Earned checkpoint restores")
			if encounter==401:check(model.reload_magazine(),"Legal shield opening")
			var starting_capacity: int=model.capacity()
			model.s.capacity_bonus=int(model.s.get("capacity_bonus",0))+slots-starting_capacity
			check(model.capacity()==slots,"Only candidate capacity changes")
			var order: Array=model.s.hand.duplicate()
			order.sort_custom(func(a,b):
				if a=="charge" or b=="charge":return a=="charge" and b!="charge"
				return int(Content.AMMO[a].dmg)>int(Content.AMMO[b].dmg))
			order=order.slice(0,slots)
			for id in Content.loading_order(order):check(model.load_round(str(id)),"Load owned round")
			check(model.s.deck==original.combat.deck,"No ammunition created")
			var state: Dictionary=model.s.duplicate(true);state.history=[]
			var unchanged:=JSON.stringify(state)
			var prediction:=Forecast.analyze(state,true,true)
			check(JSON.stringify(state)==unchanged,"Forecast preserves candidate and RNG")
			var restored=Model.new()
			var save_compatible: bool=restored.restore_state(state)
			check(save_compatible if slots<6 else not save_compatible,"Existing save validation remains strict; six-slot comparison needs a new versioned rule")
			model.advance_calls.clear()
			check(model.confirm() and model.fire(),"Candidate fires through current model")
			check(model.s.enemies==prediction.enemies and model.s.projectiles==prediction.projectiles and model.s.phase==prediction.phase,"Forecast equals execution")
			var detail: Dictionary=model.s.history.back().detail
			var action_cost:=0
			for call in model.advance_calls:action_cost+=int(call.requested_turns)
			var leftover: int=order.size()-detail.results.size()
			var total_damage:=0
			for shot in detail.results:
				total_damage+=int(shot.get("damage",0))
				for secondary in shot.get("secondary",[]):total_damage+=int(secondary.get("damage",0))
			var row:={"node":encounter,"original_capacity":starting_capacity,"capacity":slots,"save_compatible":save_compatible,"order":order,"fired":detail.results.size(),"unfired":leftover,"peak_heat":detail.heat_peak,"overheated":detail.overheated,"forced_reload":detail.forced_reload,"enemy_action_turns":action_cost,"phase":model.s.phase,"damage":total_damage,"discarded":model.s.discard.size()}
			rows.append(row)
			if encounter in [401,802]:
				var fixture:={"source":path,"note":"Capacity comparison only. Uses earned hand/deck; capacity_bonus is the sole proposed stat change. Boss uses a different earned encounter.","capacity":slots,"state":state,"prediction":prediction,"result":row}
				FileAccess.open(out.path_join("%s_%d.json" % ["boss" if encounter==802 else "normal",slots]),FileAccess.WRITE).store_string(JSON.stringify(fixture,"  "))
	FileAccess.open(out.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"note":"Single-gun controlled capacity comparison, not human fun or full-run balance."},"  "))
	print("CAPACITY RULES COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
