extends SceneTree
## RETIRED 2026-11-08 as a run target: checks old gate grid (city_gate_*, GateUpgradeGrid), replaced 2026-11-07. Replaced by: gate_live_ui.
## Still the base class of combat_rhythm_ui_runner, late_growth_ui_runner; do not delete.
## Current UI suites: docs/qa/ui-test-suites.md
const Campaign = preload("res://redesign/campaign.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
var screen
var out: String
var checks := 0
var failures: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("FAIL: "+label)

func settle() -> void:
	for i in range(14): await process_frame
	await RenderingServer.frame_post_draw

func snap(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(out.path_join(label+".png"))

func tap(key: String) -> void:
	var button = screen.find_child(key,true,false)
	check(button is Button and not button.disabled,"available button "+key)
	if not button is Button or button.disabled: return
	button.grab_focus()
	var parent = button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await settle()
	check(button.get_viewport_rect().encloses(button.get_global_rect()),"touch target visible "+key)
	for down in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=0;event.position=button.get_global_rect().get_center();event.pressed=down
		root.push_input(event,true)
		await process_frame
	await settle()

func fixture():
	var c=Campaign.new()
	check(c.restore("res://tests/fixtures/foundry_entry_single.json"),"earned fixture restored")
	c.s.gate_version=1;c.s.boss_loot_paid=true;c.model.s.gate_mods={};Gates.begin(c.model.s)
	c.s.region=0
	var boss: Dictionary=c.current_nodes().filter(func(n):return n.kind=="boss")[0]
	c.s.node=boss.id;c.s.floor=boss.floor;c.s.phase="gate";c.s.resolved=false
	return c

func mount(c) -> void:
	screen.campaign=c;screen.model=c.model;screen.page="run";screen.debug_session=false
	screen.redraw()
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/gate/"): quit(1);return
	out=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=true
	root.add_child(screen)
	await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=size
		root.content_scale_size=size
		await mount(fixture())
		check(screen.find_child("GateUpgradeGrid",true,false).get_child_count()==3,"three initial choices")
		var before=JSON.stringify(screen.campaign.s)
		await tap("city_gate_thermal")
		check(JSON.stringify(screen.campaign.s)==before,"selection alone does not apply")
		for id in ["thermal","chain","production"]:
			var b=screen.find_child("city_gate_"+id,true,false)
			# Controls use the viewport's logical coordinates under window stretch.
			check(b!=null and b.get_global_rect().position.x>=0 and b.get_global_rect().end.x<=b.get_viewport_rect().size.x,"gate card fits width "+id+"/"+str(size.x))
		await snap("gate_selected_"+str(size.x))
		await tap("city_gate_apply")
		check(screen.campaign.s.region==0 and screen.campaign.gate_ready() and Gates.level(screen.model.s,"thermal")==1,"confirmed upgrade waits at gate")
		var resumed=Campaign.new()
		check(resumed.restore(Campaign.SAVE) and resumed.gate_ready(),"automatic save resumes rest")
		await mount(resumed)
		for key in ["city_gate_parts","city_gate_ammo","city_gate_depart"]:
			var control=screen.find_child(key,true,false)
			check(control!=null and control.get_viewport_rect().encloses(control.get_global_rect()),"rest action visible "+key+"/"+str(size.x))
		await snap("gate_rest_"+str(size.x))
		await tap("city_gate_parts")
		check(screen.find_child("PartsWorkspace",true,false).is_visible_in_tree(),"gate opens parts")
		var equipped: String=screen.campaign.equipped_parts()[0]
		await tap("city_deck_equip_"+equipped)
		check(not screen.campaign.is_equipped(equipped) and screen.campaign.gate_ready(),"touch unequips without leaving gate")
		await tap("city_deck_equip_"+equipped)
		check(screen.campaign.is_equipped(equipped),"touch reequips owned part")
		var equipped_save=Campaign.new()
		check(equipped_save.restore(Campaign.SAVE) and equipped_save.gate_ready() and equipped_save.is_equipped(equipped),"part change auto saves at gate")
		await snap("gate_parts_"+str(size.x))
		await tap("workspace_close")
		await tap("city_gate_ammo")
		check(screen.find_child("DeckPanel",true,false).is_visible_in_tree(),"gate opens ammo")
		await snap("gate_ammo_"+str(size.x))
		await tap("workspace_close")
		await tap("city_gate_depart")
		check(screen.campaign.s.region==1 and screen.campaign.s.phase=="map","explicit departure advances")
		var departed=Campaign.new()
		check(departed.restore(Campaign.SAVE) and departed.s.region==1 and departed.s.phase=="map","departure auto saves next map")
	await mount(fixture())
	await tap("city_gate_production")
	await tap("city_gate_apply")
	await snap("production_specimens")
	var specimen: String=Gates.specimens(screen.model.s.deck)[0]
	await tap("gate_specimen_"+specimen)
	var originals:=Gates.basics(screen.model.s.deck)
	var prior: Array=screen.model.s.deck.duplicate()
	for i in range(3): await tap("gate_source_plus_"+str(originals[i]))
	await snap("production_sources")
	check(screen.model.s.deck==prior,"production preview leaves inventory intact")
	await tap("gate_production_apply")
	check(screen.campaign.gate_ready() and screen.model.s.deck.size()==prior.size(),"production confirms at rest and conserves total")
	check(screen.model.s.deck.count(specimen)==prior.count(specimen)+3,"three copies received")
	await tap("city_gate_depart")
	await mount(fixture())
	await tap("city_gate_skip")
	check(not screen.campaign.s.resolved,"skip requires confirmation")
	await tap("gate_skip_confirm")
	check(screen.campaign.gate_ready() and screen.model.s.gate_mods.is_empty(),"skip opens rest without upgrade")
	await snap("gate_rest_skipped")
	root.size=Vector2i(1008,630);root.content_scale_size=root.size
	screen.preferences.data.text_scale=1.2
	screen.redraw()
	await snap("gate_rest_large_text")
	for key in ["city_gate_parts","city_gate_ammo","city_gate_depart"]:
		var b=screen.find_child(key,true,false)
		check(b.get_viewport_rect().encloses(b.get_global_rect()),"large text action visible "+key)
	await tap("city_gate_depart")
	screen.preferences.data.text_scale=1.0
	await mount(fixture())
	screen.campaign.s.phase="reward"
	screen.redraw()
	await snap("boss_loot")
	check(screen.find_child("RewardGrid",true,false).get_child_count()==3,"boss only three card offers")
	check(screen.find_child("city_reward_credits",true,false)==null,"no duplicate currency claim")
	root.size=Vector2i(1008,630)
	await settle()
	await snap("boss_loot_1008")
	var skip=screen.find_child("city_reward_skip",true,false)
	check(skip.get_global_rect().end.y<=skip.get_viewport_rect().size.y,"boss skip visible without scrolling at 1008")
	await tap("city_reward_skip")
	check(screen.campaign.s.phase=="gate","loot leads to gate")
	# Loaded combat demonstration, not a claim of naturally earned two upgrades.
	var combat=fixture()
	combat.s.region=1;combat.s.floor=0;combat.s.node=0;combat.s.phase="map";combat.s.resolved=true
	combat.model.s.gate_mods={"thermal":1,"chain":1}
	combat.enter(combat.choices()[0].id)
	combat.model.s.gate_charge=6
	combat.model.s.gate_chain=1
	await mount(combat)
	root.size=Vector2i(1008,630)
	screen.redraw()
	await snap("combat_status_1008")
	var gauge=screen.find_child("HeatGauge",true,false)
	check(gauge!=null and gauge.gate_note.contains("축열 +6") and gauge.gate_note.contains("1.25"),"combat gate status visible")
	gauge.show_gate_values(screen.model.s,0,150)
	check(gauge.gate_note.contains("축열 +0") and gauge.gate_note.contains("1.50"),"impact updates bonus status immediately")
	screen._debug_city("gate")
	await settle()
	check(screen.find_child("GateUpgradeGrid",true,false).get_child_count()==3,"developer gate preview exposes all three choices")
	var file=FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	print("GATE UI COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	screen.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
