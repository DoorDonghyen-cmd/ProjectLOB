extends SceneTree
## 실제 렌더러의 화면 증거. 게임 저장과 별도 QA 디렉터리를 사용한다.

var _output := ""
var _scene: Control

func _initialize() -> void:
	_output = OS.get_environment("QA_OUTPUT_DIR")
	if _output.is_empty():
		_output = "user://qa_runtime/preart_visual"
	DirAccess.make_dir_recursive_absolute(_output)
	RunManager.save_path_override = _output.path_join("meta.cfg")
	preload("res://scripts/core/playtest_logger.gd").enabled = false
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 540)
	root.gui_embed_subwindows = true
	_scene = load("res://scenes/combat/combat_scene.tscn").instantiate()
	root.add_child(_scene)
	await _capture("title")
	_scene._title_overlay._show_loading_guide()
	await _capture("loading_guide")
	_scene._title_overlay._reading_dialog.hide()
	RunManager.meta_lore_fragments = [1, 2, 3] as Array[int]
	_scene._title_overlay._show_lore_archive()
	await _capture("lore_archive")
	_scene._title_overlay._reading_dialog.hide()
	_scene.trigger_upper_roster_test("section_d")
	await _capture("management_roster")
	for enemy in _scene._cm.enemies:
		enemy.current_distance = 10
	_scene._combat_overlay._track_control.update_enemy_position_and_scale()
	await _capture("same_distance_roster")
	_scene.trigger_ammo_hand_ab_test(true)
	await create_timer(3.0).timeout
	await _capture("ammo_hand")
	_scene.queue_free()
	await process_frame
	print("PREART_VISUAL_CAPTURE completed: " + _output)
	quit(0)

func _capture(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	if capture == null or capture.is_empty():
		push_error("시각 QA 이미지 없음: " + name)
		quit(1)
		return
	var error := capture.save_png(_output.path_join(name + ".png"))
	if error != OK:
		push_error("시각 QA 이미지 저장 실패: " + name)
		quit(1)
