class_name DragScroll
extends Node

## ═══════════════════════════════════════════════════
## 드래그 스크롤 — ScrollContainer를 손가락/마우스로 끌어서 스크롤할 수 있게 한다.
##
## 문제: ScrollContainer 안에 Button이 깔려 있으면 그 위에서 끌어도 스크롤되지 않는다.
##   포인터 입력을 Button이 먼저 받아 처리해 버려 ScrollContainer까지 닿지 않기 때문이다.
##   본작은 카드형 버튼으로 목록을 채우는 화면이 많아(지도·상점·가방·도감) 거의 모든
##   스크롤 영역이 이 문제에 걸린다. 스크롤바를 정확히 집어야만 움직이는 상태였다.
##
## 해법: GUI 처리보다 **먼저** 도는 `_input()`에서 드래그를 직접 관측해 스크롤한다.
##   - 임계값(DRAG_THRESHOLD)을 넘기 전에는 아무것도 소비하지 않는다 → 탭(클릭)은 그대로 동작
##   - 임계값을 넘는 순간 눌려 있던 버튼의 누름을 취소한다 → 스크롤하다 손을 떼도 오작동 없음
##   - 이후 이동/떼기 이벤트를 소비한다 → 드래그가 클릭으로 오인되지 않음
##
## ⚠️ 터치가 아니라 **마우스 이벤트**를 본다. Godot의 `emulate_mouse_from_touch`가
##    기본 활성이라 손가락 입력이 마우스 이벤트로 들어오기 때문이며, 덕분에 데스크톱
##    드래그와 모바일 터치를 한 경로로 처리한다. 이 설정을 끄면 이 헬퍼도 동작하지 않는다.
## ═══════════════════════════════════════════════════

## 이 거리(px)를 넘게 움직여야 스크롤로 판정한다. 그 전까지는 탭으로 취급한다.
## 너무 작으면 손가락이 미세하게 흔들려도 버튼이 눌리지 않고,
## 너무 크면 짧은 스크롤이 먹지 않는다.
const DRAG_THRESHOLD := 8.0

## 손을 뗀 뒤 미끄러지는 정도. 0이면 즉시 정지.
const INERTIA_DAMPING := 7.0
const INERTIA_MIN_SPEED := 0.4

var _scroll: ScrollContainer
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _cancelling := false


## 대상 ScrollContainer에 드래그 스크롤을 붙인다.
static func attach(sc: ScrollContainer) -> DragScroll:
	var helper := DragScroll.new()
	helper.name = "DragScroll"
	helper._scroll = sc
	sc.add_child(helper)
	return helper


func _can_scroll_v() -> bool:
	return _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func _can_scroll_h() -> bool:
	return _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func _input(event: InputEvent) -> void:
	if _cancelling or _scroll == null or not is_instance_valid(_scroll):
		return
	if not _scroll.is_visible_in_tree():
		_pressing = false
		_dragging = false
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 누름 자체는 소비하지 않는다. 아직 탭인지 드래그인지 알 수 없다.
			if _scroll.get_global_rect().has_point(event.global_position):
				_pressing = true
				_dragging = false
				_press_pos = event.global_position
				_last_pos = event.global_position
				_velocity = Vector2.ZERO
		else:
			if _dragging:
				# 드래그였으므로 떼기를 삼킨다 — 버튼이 클릭으로 받지 않도록.
				get_viewport().set_input_as_handled()
			_pressing = false
			_dragging = false

	elif event is InputEventMouseMotion and _pressing:
		var delta: Vector2 = event.global_position - _last_pos
		_last_pos = event.global_position

		if not _dragging:
			var moved: Vector2 = event.global_position - _press_pos
			var passed: bool = (_can_scroll_v() and absf(moved.y) > DRAG_THRESHOLD) \
				or (_can_scroll_h() and absf(moved.x) > DRAG_THRESHOLD)
			if not passed:
				return
			_dragging = true
			_cancel_pending_button_press()

		_apply_scroll(delta)
		_velocity = delta
		get_viewport().set_input_as_handled()


## 눌려 있던 버튼의 누름을 취소한다.
## 화면 밖 좌표로 "떼기"를 보내면 버튼은 영역 밖에서 떼진 것으로 보고
## pressed 시그널을 내지 않은 채 눌림 상태만 해제한다.
func _cancel_pending_button_press() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = Vector2(-100000, -100000)
	ev.global_position = ev.position

	_cancelling = true   # push_input이 _input을 재진입시키므로 가드
	vp.push_input(ev, true)
	_cancelling = false


func _apply_scroll(delta: Vector2) -> void:
	if _can_scroll_v():
		_scroll.scroll_vertical -= int(delta.y)
	if _can_scroll_h():
		_scroll.scroll_horizontal -= int(delta.x)


## 손을 뗀 뒤의 관성. 목록이 긴 화면(35층 지도 등)에서 체감 차이가 크다.
func _process(delta: float) -> void:
	if _dragging or _scroll == null or not is_instance_valid(_scroll):
		return
	if _velocity.length() < INERTIA_MIN_SPEED:
		_velocity = Vector2.ZERO
		return
	_apply_scroll(_velocity)
	_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * INERTIA_DAMPING, 0.0, 1.0))
