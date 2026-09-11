extends SceneTree
## 프레임을 실제로 진행하여 최소 크기·스크롤·입력·장전 비용을 검증한다.
var _checks: Array[Dictionary] = []
var _scene: Control
var _output: String

func _initialize() -> void:
	_output = OS.get_environment("QA_OUTPUT_DIR")
	if _output.is_empty():
		_output = "user://qa_workbench"
	DirAccess.make_dir_recursive_absolute(_output)
	RunManager.save_path_override = _output.path_join("meta.cfg")
	preload("res://scripts/core/playtest_logger.gd").enabled = false
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	_checks.append({"pass": ok, "label": label})
	print("PASS " if ok else "FAIL ", label)

func _settle() -> void:
	for frame in range(12):
		await process_frame

func _bounds(drawer: BagInventoryDrawer, label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(viewport.encloses(drawer.get_global_rect()), label + " 작업대가 화면 내부")
	_check(viewport.encloses(drawer._drawer_actions.get_global_rect()), label + " 확정/취소 버튼이 화면 내부")
	_check(drawer._drawer_actions.size.y >= 44, label + " 버튼 높이44 이상")
	_check(drawer._drawer_body_ammo.get_global_rect().end.y <= drawer._drawer_actions.global_position.y,
		label + " 카드가 버튼을 가리지 않음")
	_check(drawer._drawer_stack_scroll.get_global_rect().end.y <= drawer._drawer_actions.global_position.y,
		label + " 긴 탄창이 버튼을 가리지 않음")

func _run() -> void:
	root.size = Vector2i(960, 540)
	_scene = load("res://scenes/combat/combat_scene.tscn").instantiate()
	root.add_child(_scene)
	_scene.trigger_upper_roster_test("section_d")
	await _settle()
	var overlay: CombatOverlayV2 = _scene._combat_overlay
	var drawer: BagInventoryDrawer = overlay._drawer_panel
	var cm: CombatManager = _scene._cm
	_check(drawer.visible, "교전 시작 시 자동으로 순서 설계 열기")
	_check(drawer._enemy_context.get_child_count() == 4, "공개 대열4체를 장전 중 표시")
	var displayed: Array[float] = []
	for enemy: EnemyInstance in cm.enemies:
		var track: EnemyTrackView = overlay._track_control
		var offset := track._same_distance_formation_offset(enemy)
		displayed.append((0.16 + float(enemy.current_distance) / track.global_max_dist * 0.72 + offset.x) * track.size.x)
	displayed.sort()
	for i in range(1, displayed.size()):
		_check(displayed[i] - displayed[i - 1] >= 107.0, "인접거리 적의 배지·선택 영역 분리")
	_bounds(drawer, "4체 960x540")
	var supply: BulletData = overlay._basic_supply_bullet
	var count_before := int(overlay._bullet_pool.get(supply, 0))
	# 실제 카드 버튼의 입력 연결을 통해 삽탄한다.
	var supply_card: Control = drawer._drawer_inventory_grid.get_child(0)
	var input_button: Button = supply_card.get_child(supply_card.get_child_count() - 1)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = input_button.get_global_rect().get_center()
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _settle()
	_check(overlay._loaded_bullets.size() == 1, "카드 클릭이 실제 장전으로 연결")
	overlay.request_insert_bullet(supply)
	_check(overlay._loaded_bullets.size() == 2, "추가 삽탄 순서를 유지")
	drawer._drawer_undo_btn.pressed.emit()
	_check(overlay._loaded_bullets.size() == 1 and int(overlay._bullet_pool[supply]) == count_before - 1,
		"최근 장전 취소는 보급 수량 반환")
	_check(cm.telemetry_shots.is_empty(), "계획·취소 동안 격발 없음")
	var tactical: BulletData = null
	for bullet: BulletData in overlay._bullet_pool:
		if bullet != supply and int(overlay._bullet_pool[bullet]) > 0:
			tactical = bullet
			break
	overlay.request_insert_bullet(tactical)
	drawer._drawer_confirm_btn.pressed.emit()
	_check(cm.state == CombatManager.State.PLAYER_TURN and not drawer.visible, "확정 후 전장 복귀")
	_check(cm.magazine.peek() == tactical, "마지막 장전 전술탄이 첫 발사")
	_check(cm.telemetry_shots.is_empty(), "장전 확정은 자동 발사하지 않음")
	overlay._on_fire_pressed()
	await create_timer(1.2).timeout
	_check(cm.telemetry_shots.size() == 1, "별도 발사 입력이 정확히1발 처리")
	# 세 닫기 경로 모두 추가 장전 비용을 정산하고 중복 닫기는 재과금하지 않는다.
	for close_path in ["WorkbenchBattlefieldButton", "WorkbenchCloseTab", "confirm"]:
		overlay._toggle_drawer(true)
		overlay.request_insert_bullet(supply)
		var before: Array[int] = []
		for enemy: EnemyInstance in cm.enemies:
			enemy.current_distance = 24
			before.append(enemy.current_distance)
		_check(cm.has_inserted_bullet_this_turn, close_path + " 추가 장전 비용 대기")
		if close_path == "confirm":
			drawer._drawer_confirm_btn.pressed.emit()
		else:
			var close_button: Button = drawer.find_child(close_path, true, false)
			close_button.pressed.emit()
		_check(not cm.has_inserted_bullet_this_turn, close_path + " 전진 비용 정산")
		var moved := false
		for index in range(cm.enemies.size()):
			moved = moved or cm.enemies[index].current_distance < before[index]
		_check(moved, close_path + " 실제 적 전진")
		var after: Array[int] = []
		for enemy: EnemyInstance in cm.enemies:
			after.append(enemy.current_distance)
		overlay._toggle_drawer(false)
		for index in range(cm.enemies.size()):
			_check(cm.enemies[index].current_distance == after[index], close_path + " 중복 닫기 추가 과금 없음")
	overlay._on_reload_pressed()
	await _settle()
	_check(cm.state == CombatManager.State.LOADING and drawer.visible, "리로드 완료 시 순서 설계 자동 복귀")
	_scene.trigger_tempo_full_auto_test()
	await _settle()
	_bounds(_scene._combat_overlay._drawer_panel, "6발 탄창")
	_scene.trigger_upper_roster_test("section_e")
	await _settle()
	drawer = _scene._combat_overlay._drawer_panel
	var ui_text = preload("res://tests/suite_ui_smoke.gd")
	_check(ui_text._has_label_text(drawer._enemy_context, "방벽 3/3"), "흡수형은 실제 방벽 내구도 표시")
	_check(not ui_text._has_label_text(drawer._enemy_context, "HP 99"), "흡수형의 내부 HP 센티널을 체력으로 표시하지 않음")
	_scene.trigger_ammo_hand_ab_test(true)
	await create_timer(1.0).timeout
	await _settle()
	drawer = _scene._combat_overlay._drawer_panel
	_check(drawer.visible and not _scene._combat_overlay._ammo_reveal_layer.visible, "B 공개 연출 종료 후 작업대 표시")
	_bounds(drawer, "B 공개 패")
	_check(drawer._ammo_preview_row.get_child_count() == 2, "다음 보충2발 표시 보존")
	var failures := 0
	for check in _checks:
		if not bool(check.get("pass", false)):
			failures += 1
	var file := FileAccess.open(_output.path_join("workbench_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": _checks, "failures": failures}, "\t"))
	file.close()
	_scene.queue_free()
	await process_frame
	print("WORKBENCH checks=", _checks.size(), " failures=", failures)
	quit(1 if failures > 0 else 0)
