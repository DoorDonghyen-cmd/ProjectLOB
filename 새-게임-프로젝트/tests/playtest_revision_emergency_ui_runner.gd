extends "res://tests/playtest_revision_inventory_ui_runner.gd"

func combat(supports: bool = true, distance: int = 40) -> void:
	var c=Campaign.new();c.start("heavy",731042,0,"balanced",3,"scout")
	if supports:
		for i in range(6):c.model.s.deck[i]="charge"
	check(c.enter(int(c.choices()[0].id)),"actual campaign combat entry")
	var m=c.model
	m.s.enemies=[Campaign.Content._enemy(["wall",100,6,1,distance])];m.assign_opening_lanes()
	m.s.reinforcements=[];m.s.encounter_total=1;m.s.deployed=1
	m.s.hand=[];m.s.draw=[];m.s.discard=m.s.deck.duplicate()
	if supports:
		for i in range(6):
			m.s.discard.erase("charge")
			if i<4:m.s.hand.append("charge")
			else:m.s.draw.append("charge")
	screen.campaign=c;screen.model=m;screen.page="run";screen.debug_session=false
	screen.hand_layout_key=""
	screen._changed();await settle()
	check(screen.find_children("load_charge*","Button",true,false).filter(func(b):return b.is_visible_in_tree()).size()==(4 if supports else 0),"fixture shows actual support hand")

func action_done() -> void:
	for i in range(300):
		if not screen.busy:break
		await process_frame
	await settle()
	check(not screen.busy,"presentation completes")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=true;screen.presentation_speed=0.04
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=resolution
		await combat()
		var supply:Button=screen.find_child("emergency_resupply",true,false)
		check(supply!=null and supply.text.contains("적 3턴"),"visible first supply cost")
		check(not screen.main_scroll.get_h_scroll_bar().visible,"no horizontal overflow")
		await capture("exhausted_%dx%d"%[resolution.x,resolution.y])
		await press("emergency_resupply");await action_done()
		check(screen.model.s.hand.count("basic_p2")==4 and screen.model.s.emergency_uses==1,"touch supplies attack hand")
		check(screen.find_child("emergency_resupply",true,false)==null,"supply hidden while ammunition remains")
		check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"supply animation matches model")
		var resumed=Campaign.new()
		check(resumed.restore() and JSON.parse_string(JSON.stringify(resumed.model.s))==JSON.parse_string(JSON.stringify(screen.model.s)),"supply autosave exact")
		await capture("supplied_%dx%d"%[resolution.x,resolution.y])
		screen._ammo_bag();await settle()
		var hint=screen.find_child("StateHint",true,false)
		check(hint.text.contains("이번 전투 보급 1회") and hint.text.contains("휴대 20/28장") and hint.text.contains("남은 탄 10장"),"bag separates owned and generated supply")
		await capture("bag_%dx%d"%[resolution.x,resolution.y]);await press("workspace_close")
		# All four actual touch-loaded rounds are fired; the next cost rises.
		for i in range(4):
			var available=screen.find_children("load_basic_p2*","Button",true,false).filter(func(b):return not b.disabled)
			check(not available.is_empty(),"unloaded supplied copy available")
			if not available.is_empty():await press(available[0].name)
		await press("confirm");await press("fire");await action_done()
		supply=screen.find_child("emergency_resupply",true,false)
		check(supply!=null and supply.text.contains("적 4턴"),"repeat supply has larger visible cost")
		await capture("repeat_%dx%d"%[resolution.x,resolution.y])
		await combat(false,1)
		supply=screen.find_child("emergency_resupply",true,false)
		check(supply.get_meta("reload_lethal",false) and supply.text.contains("접촉 위험"),"lethal supply warned before input")
		await capture("danger_%dx%d"%[resolution.x,resolution.y])
		await press("emergency_resupply");await action_done()
		check(screen.campaign.s.phase=="lost" and resumed.restore() and resumed.s.phase=="lost","supply defeat autosaves")
	# Ordinary wait still wins on a final burn without manufacturing a pack.
	await combat(false,20)
	screen.model.s.enemies[0].hp=1;screen.model.s.enemies[0].burn=1;screen.redraw();await settle()
	await press("reload");await action_done()
	check(screen.campaign.s.phase=="reward" and screen.model.s.emergency_uses==0,"touch wait finishes remaining burn")
	print("PLAYTEST REVISION EMERGENCY UI COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
