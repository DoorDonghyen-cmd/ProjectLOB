extends RefCounted
## 드래그 스크롤 검증 — 버튼이 깔린 스크롤 영역을 끌어서 움직일 수 있는가.
##
## 배경(2026-07-24 보고): 손가락으로 목록을 끌어도 스크롤되지 않는 화면이 있었다.
##   원인은 ScrollContainer 안의 Button이 포인터 입력을 먼저 가져가 스크롤까지 닿지 않는 것.
##   본작은 카드형 버튼으로 목록을 채우는 화면이 많아(지도·상점·가방·도감) 거의 전부 해당됐다.
##
## 검증 대상은 두 가지다. 이 둘이 드래그 스크롤의 계약이다.
##   ① 버튼 위에서 끌어도 스크롤된다
##   ② 끌었다가 손을 떼면 버튼이 눌리지 않는다 (드래그가 클릭으로 오인되지 않는다)
##
## ⚠️ 헤드리스에서는 레이아웃이 프레임 경계에서 정리되므로, 스크롤 범위를 직접 지정해
##    레이아웃 의존을 제거한다. 검증하려는 것은 레이아웃이 아니라 입력 처리이기 때문이다.

const DragScrollScript := preload("res://scripts/ui/components/drag_scroll.gd")


static func _press(vp: Viewport, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev, true)


static func _move(vp: Viewport, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev, true)


static func _release(vp: Viewport, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev, true)


static func run(t, tree: SceneTree) -> void:
	t.section("DragScroll")

	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(400, 300)
	tree.root.add_child(host)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(400, 300)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	# 목록을 채우는 버튼들. 이 버튼들이 입력을 가로채는 것이 원래 문제였다.
	var clicked := {"count": 0}
	var buttons: Array[Button] = []
	for i in range(20):
		var b := Button.new()
		b.text = "항목 %d" % i
		b.custom_minimum_size = Vector2(380, 60)
		b.pressed.connect(func(): clicked.count += 1)
		vbox.add_child(b)
		buttons.append(b)

	DragScrollScript.attach(scroll)

	# 레이아웃 정리를 기다리지 않고 스크롤 범위를 직접 지정한다(입력 처리만 검증).
	var vbar := scroll.get_v_scroll_bar()
	vbar.min_value = 0
	vbar.max_value = 1200
	vbar.page = 300
	scroll.scroll_vertical = 0

	var vp: Viewport = tree.root
	var center := Vector2(200, 150)

	# ── ① 버튼 위에서 끌면 스크롤된다 ──
	_press(vp, center)
	_move(vp, center + Vector2(0, -20))   # 임계값(8px) 초과 → 드래그 판정
	_move(vp, center + Vector2(0, -60))
	var scrolled_to: int = scroll.scroll_vertical
	_release(vp, center + Vector2(0, -60))

	t.check(scrolled_to > 0, "⭐ 버튼 위에서 끌어도 스크롤됨 (scroll_vertical = %d)" % scrolled_to)

	# ── ② 끌었다면 버튼이 눌리지 않는다 ──
	t.eq(clicked.count, 0, "⭐ 드래그는 클릭으로 오인되지 않음")

	# ── ③ 임계값 미만의 흔들림은 여전히 탭이다 ──
	# 손가락은 완벽히 정지하지 않으므로, 미세 이동까지 드래그로 보면 버튼을 누를 수 없게 된다.
	clicked.count = 0
	var before_tap: int = scroll.scroll_vertical
	_press(vp, center)
	_move(vp, center + Vector2(0, -3))    # 임계값 미만
	_release(vp, center + Vector2(0, -3))
	t.eq(scroll.scroll_vertical, before_tap, "미세 이동은 스크롤을 일으키지 않음")

	# ── ④ 아래로 끌면 반대 방향으로 스크롤된다 ──
	scroll.scroll_vertical = 400
	_press(vp, center)
	_move(vp, center + Vector2(0, 20))
	_move(vp, center + Vector2(0, 60))
	var after_down: int = scroll.scroll_vertical
	_release(vp, center + Vector2(0, 60))
	t.check(after_down < 400, "아래로 끌면 위로 되돌아감 (%d → %d)" % [400, after_down])

	# ── ⑤ 가로 스크롤이 꺼진 컨테이너는 가로 드래그에 반응하지 않는다 ──
	scroll.scroll_vertical = 200
	var before_h: int = scroll.scroll_vertical
	_press(vp, center)
	_move(vp, center + Vector2(-60, 0))
	_release(vp, center + Vector2(-60, 0))
	t.eq(scroll.scroll_vertical, before_h, "가로 드래그는 세로 스크롤을 건드리지 않음")

	# ── 정리 ──
	host.queue_free()
