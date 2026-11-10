extends "res://tests/ammo_risk_ui_runner.gd"
## Captures the shared-frame layout mockups from real debug states.
## Isolated save only; the mockup never issues game commands.

const Board = preload("res://redesign/samples/mockups/ui_frame_mockup.gd")
const WorldArt = preload("res://redesign/world_art.gd")
const Content = preload("res://redesign/content.gd")
var board: Control


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ui_mockup/"):
		quit(1)
		return
	for resolution in [Vector2i(1440, 630), Vector2i(1008, 630)]:
		root.size = resolution
		await shoot_all(resolution.x)
	print("UI FRAME MOCKUP COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)


func fresh_screen() -> void:
	if is_instance_valid(board):
		board.queue_free()
	if is_instance_valid(screen):
		screen.queue_free()
	await process_frame
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.04
	root.add_child(screen)
	await settle()
	board = Board.new()
	check(board != null, "mockup board loads")
	root.add_child(board)
	board.position = Vector2.ZERO
	board.size = root.get_visible_rect().size
	await process_frame


func combat_state(setup: Callable, gun: String) -> void:
	await fresh_screen()
	setup.call()
	await settle()
	screen.model.s.gun = gun
	screen.model.s.weapon_version = 1
	screen.redraw()
	await settle()
	screen.battle_view.reduced_feedback = true


func shoot_all(width: int) -> void:
	# 1. common frame sheet
	await fresh_screen()
	screen._debug_challenge("elite")
	await settle()
	board.show_kit(screen.model.s)
	screen.visible = false
	await capture("1_frame_%d" % width)
	# 2. main-run combat: readable elite line, then the crowded garden gate
	for scenario in [["2_combat_elite", func(): screen._debug_challenge("elite"), "single", "정예 · 약탈단 두목"], ["2_combat_crowded", func(): screen._debug_garden_background(1, "boss"), "scatter", "관문 · 수로의 어미"]]:
		await combat_state(scenario[1], scenario[2])
		# Load the first two hand cards through the real input path.
		var hand: Array = screen.model.s.hand
		for i in [1, 0]:
			var copy := hand.slice(0, i + 1).count(hand[i])
			await tap("load_" + str(hand[i]) + ("" if copy == 1 else "_%d" % copy))
		var state: Dictionary = screen.model.s
		var view: Control = screen.battle_view
		var original := hash(state)
		var place := str(screen.campaign.region_info().get("name", "승강장·주거 통로")) if screen.campaign != null else "승강장·주거 통로"
		board.show_combat(view, state, place, scenario[3], screen.combat_forecast)
		screen.visible = false
		await capture("%s_%d" % [scenario[0], width])
		check(hash(state) == original, "mockup never changes combat state " + scenario[0])
	# 3. map
	await fresh_screen()
	screen._debug_city("map")
	await settle()
	board.show_map(screen.campaign, WorldArt.region_texture(0))
	screen.visible = false
	await capture("3_map_%d" % width)
	# 4. place template: encounter and supply share one layout
	await fresh_screen()
	var state: Dictionary = screen.model.s if screen.model != null else {}
	board.show_place("승강장·주거 통로", "조우", load("res://assets/art/director_20261002/transit_platform.png"), "비공개 구획", "부품 신호가 잡힙니다. 얻는 것과 다음 전투의 비용을 함께 확인하세요.", "탄환을 크레딧으로 바꿀 수 있습니다", [
		{"title": "기본탄 · 피해 1 · 열 +1", "detail": "1장 분해 · 덱 8장은 유지", "icon": "basic", "tag": "+16 Cr"},
		{"title": "기본탄 · 피해 2 · 열 +2", "detail": "1장 분해 · 덱 8장은 유지", "icon": "basic", "tag": "+16 Cr", "selected": true},
		{"title": "기본탄 · 피해 3 · 열 +3", "detail": "1장 분해 · 덱 8장은 유지", "icon": "basic", "tag": "+16 Cr"},
	], state, "분해하고 받기", "그대로 통과", "기본탄(피해 2) 1장 → +16 Cr · 덱 20 → 19장 · 75 → 91 Cr")
	screen.visible = false
	await capture("4_encounter_%d" % width)
	board.show_place("승강장·주거 통로", "탄약고", load("res://assets/art/service_background_grouped_20261025/supply.png"), "밀수 창고", "가져갈 탄환을 고르세요. 한 장을 받을 수 있습니다.", "한 장을 고르세요", [
		{"title": "기본탄", "detail": "피해 1 · 물리 탄환", "icon": "basic", "tag": "열 +1"},
		{"title": "기폭탄", "detail": "남은 화상을 피해로 바꿉니다", "icon": "detonate", "tag": "열 +3", "selected": true},
	], state, "1장 확보", "그대로 통과", "기폭탄 1장 추가 · 덱 20 → 21장 · 휴대 21/30")
	screen.visible = false
	await capture("4_supply_%d" % width)
	# 5. shop
	await fresh_screen()
	screen._debug_city("shop")
	await settle()
	var shop_state: Dictionary = screen.campaign.model.s
	var parts: Array = Content.PARTS.keys().filter(func(id): return str(Content.PARTS[id].get("kind", "")) != "core")
	var products: Array = [{"kind": "ammo", "id": "pierce", "category": "탄환 · 일반", "name": Content.AMMO.pierce.name, "stat": "피해 %s · 관통" % Content.primary_stat("pierce", shop_state).value, "note": "장갑을 뚫는 탄. 장갑 적이 늘어나는 2구역 전에 한 장 확보해 두면 좋습니다.", "price": "12 Cr", "owned": "보유 0장", "changes": [["덱", "20 → 21장"], ["철갑탄", "0 → 1장"], ["크레딧", "75 → 63 Cr"]]}]
	for id in parts.slice(0, 2):
		var spec: Dictionary = Content.part_spec(id, shop_state)
		products.append({"kind": "part", "id": id, "category": "파츠", "name": spec.name, "stat": str(spec.get("value", "")), "note": str(spec.get("upside", "")) + " · 대가: " + str(spec.get("downside", "없음")), "price": "30 Cr", "owned": "미보유"})
	board.show_shop(shop_state, load("res://assets/art/service_background_grouped_20261025/shop.png"), products, 0)
	screen.visible = false
	await capture("5_shop_%d" % width)
