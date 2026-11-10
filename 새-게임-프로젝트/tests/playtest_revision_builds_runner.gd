extends "res://tests/ammo_expansion_rules_runner.gd"
## Fixed-budget comparison using the real resolver. No campaign win-rate claim.
const CASES := {
	"volley": {"core":"volley_drive","parts":["duplex","sequencer"],"order":["charge","precise_p3","precise_p3"],"heat":0},
	"siege": {"core":"siege_drive","parts":["sequencer","afterburner"],"order":["charge","pierce_p3"],"heat":0},
	"thermal": {"core":"thermal_drive","parts":["sequencer","reclaimer"],"order":["charge_heat","pierce_p3","cool"],"heat":7}
}

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	var rows: Array=[]
	for build in CASES:
		var recipe: Dictionary=CASES[build]
		for level in [0,4,8]:
			for scenario in ["crowd","armor","boss"]:
				for package in ["matched","unmatched","none"]:
					for ammunition in ["selected","basic"]:
						var order: Array=recipe.order.duplicate()
						if ammunition=="basic":order.fill("basic_p3")
						var enemies: Array=[["runner",20,0,2,24],["runner",24,0,2,28],["runner",30,0,2,32]]
						if scenario=="armor":enemies=[["wall",30,5,1,22],["wall",40,5,1,28]]
						if scenario=="boss":enemies=[["wall",140,3,2,24],["runner",16,0,3,30]]
						var model=fixture(order,enemies,"burst")
						model.s.combat_revision=int(OS.get_environment("QA_COMBAT_REVISION"))
						model.s.equipped_parts=[recipe.core]
						if package=="matched":model.s.equipped_parts.append_array(recipe.parts)
						if package=="unmatched":model.s.equipped_parts.append_array(["coil","capacitor"])
						model.s.engine.levels[recipe.core]=level
						model.s.heat=int(recipe.heat)
						for id in Ammo.loading_order(order):check(model.load_round(str(id)),"legal benchmark load")
						var prediction:=Forecast.analyze(model.s,true,true)
						check(model.confirm() and model.fire(),"legal benchmark shot")
						check(prediction.enemies==model.s.enemies,"benchmark prediction agrees")
						var damage:=0;var alive:=0;var margin:=99.0
						for e in model.s.enemies:
							damage+=int(e.max_hp)-int(e.hp)
							if int(e.hp)>0:alive+=1;margin=minf(margin,float(e.distance)/maxi(1,int(e.speed)))
						rows.append({"build":build,"growth":level,"scenario":scenario,"parts":package,"ammo":ammunition,"damage":damage,"kills":enemies.size()-alive,"turns":model.s.turns,"shots":model.s.shots,"heat":model.s.heat,"margin":margin,"phase":model.s.phase})
	var result:={"method":"Same gun, core level, enemy state and loaded round count within each build. Matched/unmatched modules use two slots; no modules is a control. Ammo acquisition rarity is not normalized. Synthetic encounters, not campaign/player win rate.","checks":checks,"failures":failures,"rows":rows}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("builds.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PLAYTEST REVISION BUILDS COMPLETE cases=%d checks=%d failures=%d"%[rows.size(),checks,failures])
	quit(1 if failures else 0)
