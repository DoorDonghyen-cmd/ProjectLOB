extends "res://tests/combat_hierarchy_ui_runner.gd"
var observed_reload_steps := 0

func observe_reload(event: Dictionary) -> void:
	if str(event.get("kind","")) not in ["reload_turn","cooling_turn"]: return
	var impulse = screen.find_child("reload",true,false).get_node("UIImpulse")
	check(impulse.step_current == int(event.turn)+1 and impulse.step_total == int(event.total),"reload marks reflect actual enemy turns")
	observed_reload_steps += 1

func focus_control(key: String) -> void:
	var control := screen.find_child(key,true,false) as Control
	check(control != null,"focus target "+key)
	control.grab_focus()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_affordance/ui"):
		quit(1); return
	var preview: Control = load("res://redesign/combat_workbench.tscn").instantiate()
	check(preview.has_node("TacticalGrid/QueuePanel/QueueColumn/FiringRail/MagazineHost"),"magazine composition exists before ready")
	check(preview.has_node("TacticalGrid/QueuePanel/QueueColumn/EditorPreviewThermal/Reload"),"thermal/action reference exists before ready")
	preview.free()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size = resolution
		await setup_hand(["basic","charge","pierce_c","cool","push"])
		screen.model.s.gun = "burst"
		screen.campaign.s.gun = "burst"
		screen.model.s.heat = 11
		await refresh()
		var baseline := layout_snapshot()
		check(screen.find_children("EditorPreview*","Control",true,false).is_empty(),"editor examples never leak into gameplay")
		var state: Dictionary = screen.model.s.duplicate(true)
		await focus_control("load_pierce_c")
		check(screen.magazine_view.candidate_id == "pierce_c","keyboard previews two-slot insertion")
		var rect: Rect2 = screen.magazine_view.insertion_preview_rect()
		check(rect.size.x > screen.magazine_view.size.x * 0.45 and rect.size.x < screen.magazine_view.size.x * 0.55,"two-slot cue spans exactly half four-slot magazine")
		check(screen.model.s == state,"preview does not mutate state or RNG")
		stable_layout(baseline,"candidate focus")
		await capture("insertion_%d" % resolution.x)
		await focus_control("reload")
		var heat = screen.find_child("HeatGauge",true,false)
		check(heat.reload_preview and heat.current == 11 and heat.reload_temperature == 2,"reload preview shows actual eleven-to-two cooling")
		check(screen.magazine_view.candidate_id.is_empty(),"leaving card removes insertion cue")
		check(screen.model.s == state,"reload focus consumes no turn or heat")
		stable_layout(baseline,"reload focus")
		await capture("cooling_%d" % resolution.x)
		await focus_control("ammo_bag")
		check(not heat.reload_preview,"utility focus restores fire prediction")
		await tap("load_basic")
		check(screen.find_child("load_basic",true,false).get_node("CardInfo").footer_text() == "장전됨","held card states why it is unavailable")
		await tap("load_pierce_c")
		check(screen.model.s.plan == ["pierce_c","basic"],"touch load follows previewed LIFO position")
		await tap("load_charge")
		check(screen.find_child("load_push",true,false).get_node("CardInfo").footer_text() == "탄창 공간 부족","full magazine explains blocked card")
		await focus_control("confirm")
		check(screen.magazine_view.candidate_id.is_empty(),"full rail has no stale insertion target")
		check(screen.find_child("confirm",true,false).text.contains("3발"),"confirmation counts bullets rather than occupied slots")
		stable_layout(baseline,"full magazine")
		await capture("planned_%d" % resolution.x)
		await tap("confirm")
		screen.battle_view.feedback_changed.connect(observe_reload)
		await focus_control("fire")
		check(screen.magazine_view.candidate_id.is_empty(),"ready phase clears insertion")
		stable_layout(baseline,"ready")
		await capture("ready_%d" % resolution.x)
		await tap("fire")
		fit()
		check(not screen.find_child("HeatGauge",true,false).reload_preview,"post-action has no stale preview")
		await setup_hand(["basic","basic","charge","cool","push"])
		# Real pointer event, then keyboard fallback, then exit: both input modes share cues.
		var pointer := InputEventMouseMotion.new()
		pointer.position = screen.find_child("load_charge",true,false).get_global_rect().get_center()
		root.push_input(pointer,true)
		await settle()
		check(screen.magazine_view.candidate_id == "charge","pointer hover previews insertion")
		pointer = InputEventMouseMotion.new()
		pointer.position = Vector2(3,3)
		root.push_input(pointer,true)
		await settle()
		check(screen.magazine_view.candidate_id.is_empty(),"pointer exit clears cue")
	check(observed_reload_steps >= 3,"actual forced reload progress was observed")
	screen.queue_free()
	await process_frame
	print("COMBAT AFFORDANCE UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
