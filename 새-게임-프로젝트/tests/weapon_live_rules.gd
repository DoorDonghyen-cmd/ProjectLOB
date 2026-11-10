extends "res://tests/weapon_abilities_rules.gd"
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_live_20261106/rules"):quit(2);return
	for gun in Model.WeaponRoles.KINDS:
		var raw=Model.new();raw.start(gun,17)
		roundtrip(raw,gun+" raw Model entry")
		for outfit in Content.OUTFITS:
			var c=Cases.Campaign.new();c.start(gun,17,0,"balanced",4,outfit,true)
			check(c.model.s.gun==gun and Model.WeaponRoles.kind(c.model.s)==gun,"native matching profile "+gun+outfit)
			check(c.model.s.deck.size()==20 and c.model.capacity()==7 and Model.MagazineTrial.pulse(c.model.s)==3,"native comparison platform retained")
			check(c.advance_departure(true) and c.enter(101),"real native entry "+gun+outfit)
			roundtrip(c.model,gun+outfit)
			forecast_matches(c.model,gun+outfit)
			var state: Dictionary=c.model.s.duplicate(true);state.erase("weapon_role_trial")
			check(not Model.new().restore_state(state),"new gun cannot load without ability state")
			state=c.model.s.duplicate(true);state.weapon_role_trial.kind="rewinder" if gun=="deadbolt" else "deadbolt"
			check(not Model.new().restore_state(state),"new gun cannot load another gun's ability")
			var path: String="user://native_"+gun+"_"+outfit+".json"
			check(c.save(path)==OK,"native Campaign save")
			var restored=Cases.Campaign.new();check(restored.restore(path),"native Campaign restore")
			check(normalized(c.s)==normalized(restored.s) and normalized(c.model.s)==normalized(restored.model.s),"complete native campaign/model/RNG roundtrip")
	# Existing fixtures retain burst as their ID and the exact old comparison rules.
	for role in Model.WeaponRoles.KINDS:
		var legacy=Cases.build(role,1);roundtrip(legacy,"retained burst comparison "+role)
		check(legacy.s.gun=="burst" and Model.WeaponRoles.kind(legacy.s)==role,"old comparison state retained")
	deadbolt();rewinder();save_rejection()
	FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audit":audit},"  "))
	print("WEAPON LIVE RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
