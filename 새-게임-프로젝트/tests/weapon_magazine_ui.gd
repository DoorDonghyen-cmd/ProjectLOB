extends "res://tests/combat_magazine_loop_ui.gd"

var action_times: Array = []

func wait_action() -> void:
	var started := Time.get_ticks_msec()
	while preview.busy and Time.get_ticks_msec()-started < 20000: await process_frame
	if Time.get_ticks_msec()>started: action_times.append(Time.get_ticks_msec()-started)
	check(not preview.busy, "Action animation finishes within 20s: "+str(preview.model.s.gun))
	await settle()

func weapon_layout() -> void:
	geometry()
	var bounds := preview.get_global_rect()
	for i in range(9):
		var card: Control = preview.node("Round%d" % i)
		check(card.visible == (i < preview.model.capacity()), "Visible slots match capacity")
		if not card.visible: continue
		check(bounds.encloses(card.get_global_rect()), "Magazine fits viewport")
		if i>0: check(not card.get_global_rect().intersects(preview.node("Round%d" % (i-1)).get_global_rect()), "Cards do not overlap")
		for label_name in ["Name","Role","Value","Cost","Gain"]:
			var label: Label = preview.node(label_name+str(i))
			var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
			check(width <= label.size.x+1, "Card label fits: "+label_name+str(i)+" / "+label.text)
			check(card.get_global_rect().encloses(label.get_global_rect()), "Card field is inside card")
	for id in ["Help","Fire","Cool","Reload"]:
		var button: Button=preview.node(id)
		check(bounds.encloses(button.get_global_rect()), "Button fits "+id)
		check(button.size.y*float(root.size.y)/800 >=44, "Touch target "+id)
		var width := button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
		check(width+24 <= button.size.x, "Button text fits "+id)

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapon_magazine_20261031/"): quit(2); return
	Input.emulate_mouse_from_touch=true
	preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate()
	preview.resume_saved=false; root.add_child(preview); await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=size; root.content_scale_size=Vector2i(1280,800)
		preview.gun_index=0; preview.case_index=1; preview.mount(false); await settle()
		for gun_index in range(5):
			check(preview.gun_index==gun_index,"Weapon navigation")
			weapon_layout(); await capture("ready_%s_%dx%d" % [preview.model.s.gun,size.x,size.y])
			if preview.model.s.gun=="scatter": check(preview.node("Prediction").text.contains("무작위") and preview.node("Value1").text.contains("~"),"Random forecast uses ranges and probability")
			var before: int=preview.model.s.shots
			await tap("Fire")
			check(int(preview.model.s.shots)>before,"Real touch fires weapon")
			check(preview.board.visual_events.any(func(e):return str(e.kind)=="shot"),"Shot animation plays")
			weapon_layout()
			await capture("fired_%s_%dx%d" % [preview.model.s.gun,size.x,size.y])
			var kept: Array=preview.model.s.magazine.duplicate()
			if not preview.node("Cool").disabled:
				await tap("Cool"); check(preview.model.s.magazine==kept,"Cooling preserves magazine")
			if not preview.node("Reload").disabled:
				await tap("Reload"); check(preview.model.s.phase in ["ready","reward","lost","won"],"Whole magazine exchange resolves")
			await tap("Help"); check(preview.overlay_open and preview.node("DetailBody").text.contains("과열"),"Weapon-specific rules available")
			var snapshot:=JSON.stringify(preview.model.s); preview.fire(); check(JSON.stringify(preview.model.s)==snapshot,"Modal blocks firing")
			if size==Vector2i(1280,800): await capture("rules_%s" % preview.model.s.gun)
			await tap("CloseDetail")
			await tap("Parts"); check(preview.overlay_open,"Actual parts detail available"); await tap("CloseDetail")
			await tap("Other")
		check(preview.gun_index==0,"Weapon selector wraps")
	# Replay verified default boss routes through public touch controls.
	var audits: Array=JSON.parse_string(FileAccess.get_file_as_string(out.get_base_dir().path_join("rules/rules.json"))).audit
	for gun_index in range(5):
		preview.gun_index=gun_index; preview.case_index=1; preview.mount(false); await settle()
		var gun: String=preview.model.s.gun
		var route: Array=[]
		for row in audits:
			if row.gun==gun and row.role=="boss" and row.seed==0: route=row.path if row.phase in ["won","reward"] else row.alternate
		check(not route.is_empty(), "Default boss route available")
		for action in route: await tap({"fire":"Fire","cool":"Cool","swap":"Reload","emergency":"Reload"}[action])
		check(preview.model.s.phase in ["won","reward"],"Boss victory through public inputs: "+gun)
		check(preview.node("Fire").disabled and not preview.node("Other").disabled,"Terminal combat blocks firing and allows next weapon")
		weapon_layout(); await capture("victory_"+gun)
	# Resume a random weapon after a real shot; no new target stream or shuffle.
	preview.gun_index=2; preview.case_index=1; preview.mount(false); await tap("Fire")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(preview.model.s))
	preview.queue_free(); await settle()
	preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate(); root.add_child(preview); await settle()
	check(preview.resumed and preview.gun_index==2 and preview.case_index==1 and JSON.parse_string(JSON.stringify(preview.model.s))==saved,"Random partial magazine resumes exactly")
	await capture("resumed_scatter")
	for i in range(4):
		var prior: int=preview.case_index
		await tap("Pressure"); check(preview.case_index==(prior+1)%4,"Four earned encounters navigate")
		weapon_layout()
	var raw:=FileAccess.get_file_as_string(preview.COMPARISON_SAVE)
	var bad: Dictionary=JSON.parse_string(raw); bad.gun_index=4
	FileAccess.open(preview.COMPARISON_SAVE,FileAccess.WRITE).store_string(JSON.stringify(bad))
	check(not preview.restore_comparison(),"Mismatched save weapon rejected")
	FileAccess.open(preview.COMPARISON_SAVE,FileAccess.WRITE).store_string(raw)
	check(preview.restore_comparison(),"Valid saved comparison restores")
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"action_animation_ms":action_times},"  "))
	print("WEAPON UI COMPLETE checks=%d failures=%d" % [checks,failures.size()]); preview.queue_free(); await settle(); quit(0 if failures.is_empty() else 1)
