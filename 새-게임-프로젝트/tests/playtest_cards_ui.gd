extends "res://tests/playtest_presentation_ui.gd"
const Model=preload("res://redesign/model.gd")
var current_ui
var current_command:=""
var shot_count:=0
var previous_stack: Array=[]
var previous_remaining:=0
var captures:=false
var captured: Dictionary={}

func canonical(value):return JSON.parse_string(JSON.stringify(value))

func snapshot(label: String)->void:
	if not captures or captured.has(label):return
	captured[label]=true
	await capture(label)

func observe_shot(_result: Dictionary)->void:
	shot_count+=1
	for i in range(previous_stack.size()):
		check(current_ui.node("Name%d"%i).visible==(i>=shot_count),"only emitted cartridges disappear")
	check(current_ui.node("MagazineTitle").text=="탄창 %d / %d"%[previous_stack.size()-shot_count,current_ui.model.capacity()],"live magazine count follows each shot")
	check(current_ui.node("Bag").text=="남은 %d발"%(previous_remaining-shot_count),"live reserve count follows each shot")
	snapshot.call_deferred("shot_%d"%shot_count)

func observe_event(event: Dictionary)->void:
	if event.kind=="reload_turn" and current_command=="Reload" and int(event.turn)==0:
		check(current_ui.hud.feedback.swap_empty,"replacement starts by removing the old magazine")
		check_empty_sockets.call_deferred()
	elif event.kind=="turn_complete" and current_command=="Reload":
		var seated: bool=current_ui.hud.feedback.swap_ready
		for i in range(current_ui.slot_count):
			check(current_ui.node("Name%d"%i).visible==(seated and i<current_ui.model.s.magazine.size()),"reload sockets follow empty/seated phase")
		snapshot.call_deferred("reload_seated" if seated else "reload_empty")
	elif event.kind=="cooling_turn" and current_command=="Cool":
		check(not current_ui.hud.feedback.swap_empty,"cooling never removes magazine")
		for i in range(previous_stack.size()):check(current_ui.node("Name%d"%i).visible,"cooling preserves cards")

func check_empty_sockets()->void:
	if current_ui.board.reduced_feedback:return
	await create_timer(0.14*current_ui.board.speed_scale).timeout
	if not current_ui.busy or current_ui.hud.feedback.swap_ready:return
	for i in range(current_ui.slot_count):check(not current_ui.node("Name%d"%i).visible,"old cards clear before seating the new magazine")
	await snapshot("reload_empty")

func command(id: String)->void:
	current_command=id;shot_count=0
	previous_stack=current_ui.model.s.magazine.duplicate()
	previous_remaining=Model.Reserve.remaining(current_ui.model.s)
	var oracle=Model.new();oracle.s=current_ui.model.s.duplicate(true)
	var ok: bool=oracle.call({"Fire":"fire","Cool":"cool_magazine","Reload":"reload_magazine"}[id])
	check(ok,"oracle accepts "+id)
	if not ok:return
	var target: Button=current_ui.node(id)
	check(not target.disabled,"public action enabled "+id)
	var point: Vector2=target.get_global_transform_with_canvas()*(target.size*0.5)
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
		root.push_input(event,true);await process_frame
	var started:=Time.get_ticks_msec()
	while current_ui.busy and Time.get_ticks_msec()-started<12000:await process_frame
	await settle()
	check(not current_ui.busy,"command releases input "+id)
	check(canonical(current_ui.model.s)==canonical(oracle.s),"UI preserves entire model/RNG "+id)
	if id=="Fire":check(shot_count==oracle.s.history.back().detail.results.size(),"one consumed card per real result")
	for i in range(current_ui.model.s.magazine.size()):
		check(current_ui.node("Name%d"%i).visible,"idle restores remaining cards")
		check(current_ui.node("Face%d"%i).modulate==Color.WHITE,"no stranded animation tint")
	records.append({"gun":current_ui.model.s.gun,"motion":current_ui.hud.feedback.preferences.data.motion,"command":id,"shots":shot_count,"phase":current_ui.model.s.phase})

func run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_20261102/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true
	root.size=Vector2i(1280,800)
	for gun in Content.GUNS:
		for motion in ["normal","fast","instant"]:
			await mount("carrier",gun);current_ui=host.campaign_hud
			current_ui.hud.feedback.save_setting("motion",motion)
			captures=gun=="single" and motion=="normal"
			current_ui.board.shot_started.connect(observe_shot)
			current_ui.board.feedback_changed.connect(observe_event)
			if captures:
				for dimensions in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
					root.size=dimensions;await settle()
					await capture("ready_%dx%d"%[dimensions.x,dimensions.y])
			var shots: Array=current_ui.last_prediction.shots
			for i in range(current_ui.model.s.magazine.size()):
				var firing:=i<shots.size() and float(shots[i].get("used_probability",1))>0
				var face: Control=current_ui.node("Face%d"%i)
				check(face.offset_top==(0 if firing else 8),"actual forecast raises only firing group")
				check(face.size.y==96,"card art retains 96px height")
			await command("Fire");await command("Cool");await command("Reload")
			print("CARDS ",gun," ",motion)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("PRESENTATION COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
