extends SceneTree
var errors := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		errors+=1
		print("FAIL: "+label)

func settle() -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw

func tap(button: Button) -> void:
	var point := root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for held in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=0
		event.position=point
		event.pressed=held
		Input.parse_input_event(event)
		await process_frame
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_recast/"): quit(1);return
	var scene: Control=load("res://redesign/samples/ammo_recast.tscn").instantiate()
	root.add_child(scene)
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution
		scene.reset()
		await settle()
		for key in ["%Fire","%Reload","%Hand","%Battle"]:
			check(scene.get_global_rect().encloses(scene.get_node(key).get_global_rect()),"visible "+key+str(resolution))
		var hand: HBoxContainer=scene.get_node("%Hand")
		check(hand.get_child_count()==10,"ten separate cards")
		check(scene.Content.hand_capacity(scene.model.s)==10,"sample has a real ten-card bag")
		for i in range(10):
			var card: Button=hand.get_child(i)
			check(scene.get_global_rect().encloses(card.get_global_rect()),"card fully on screen %d"%i)
			check(card.size.y<=132,"compact card height %d"%i)
			check(card.size.x>=112,"card target width %d"%i)
			if i>0:
				check(not card.get_global_rect().intersects(hand.get_child(i-1).get_global_rect()),"no card overlap %d"%i)
		check(scene.model.s.plan==["charge","basic_p2"],"real last-in-first-out plan")
		var heat_forecast: Dictionary=scene.Forecast.analyze(scene.model.s)
		check(scene.get_node("%Heat").value>0,"loaded rounds visibly forecast heat")
		check(scene.get_node("%Heat").value==heat_forecast.heat.peak_max,"heat uses actual forecast")
		check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("recast_%d.png"%resolution.x))==OK,"capture")
		for i in [0,9]:
			await tap(hand.get_child(i))
			check(scene.model.s.plan.size()==3 and scene.model.s.plan.front()==scene.IDS[i],"touch loads edge card %d"%i)
			await tap(scene.get_node("%Queue").get_child(0))
			check(scene.model.s.plan==["charge","basic_p2"],"touch returns edge card %d"%i)
		var before: int=scene.model.s.shots
		scene.get_node("%Fire").pressed.emit()
		check(scene.model.s.phase=="ready","confirm uses actual model")
		scene.get_node("%Fire").pressed.emit()
		check(scene.model.s.shots>before,"fire uses actual model")
		check(scene.get_node("%HeatText").text.begins_with("발열  %d"%scene.model.s.heat),"current heat matches actual fired state")
		await settle()
		check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("fired_%d.png"%resolution.x))==OK,"fired capture")
	scene.queue_free();await process_frame
	print("AMMO RECAST PREVIEW COMPLETE failures=%d"%errors)
	quit(0 if errors==0 else 1)
