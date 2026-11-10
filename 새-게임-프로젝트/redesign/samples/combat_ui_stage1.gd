extends Control
## Isolated composition study. Uses current combat rules; never opens player saves.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Reserve = preload("res://redesign/ammo_reserve.gd")
@export_enum("A", "B") var composition := "A"
var model = Model.new()
var fixture: Dictionary = {}
var last_prediction: Dictionary = {}
var pressure := false
var overlay_open := false
var busy := false
@onready var board = find_child("Battle", true, false)

func node(id: String) -> Node:
	return find_child(id, true, false)

func _ready() -> void:
	board.set_route_background(0, 4, 8)
	board.character_reference_height = 300.0
	node("Fire").pressed.connect(fire)
	node("Reload").pressed.connect(reload_magazine)
	node("Reset").pressed.connect(func(): mount(false))
	node("Pressure").pressed.connect(func(): mount(not pressure))
	node("Other").pressed.connect(change_composition)
	node("Bag").pressed.connect(func(): show_detail("탄약", "남은 탄 %d장\n예비 %d장 · 손패 %d장 · 사용함 %d장\n이번 전투의 사용탄은 다시 섞지 않습니다.\n다음 전투에 보유 탄약이 복구됩니다." % [Reserve.remaining(model.s), model.s.draw.size(), model.s.hand.size(), model.s.discard.size()]))
	node("Parts").pressed.connect(func(): show_detail("돌파 코어", "실제 획득한 성장 파츠\n강화된 단발과 초과 피해 전달이\n앞 적의 처치를 다음 적에게 연결합니다.\n시안의 피해 수치는 현행 전투 계산 결과입니다."))
	node("CloseDetail").pressed.connect(close_detail)
	mount(false)

func mount(danger: bool) -> void:
	pressure = danger
	var filename := "combat_ui_stage1_pressure.json" if danger else "combat_ui_stage1_fixture.json"
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/" + filename))
	model = Model.new()
	model.s = fixture.state.duplicate(true)
	model.s.history = []
	close_detail()
	refresh()

func refresh() -> void:
	var active: bool = model.s.phase in ["plan", "ready"]
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	last_prediction = Forecast.analyze(model.s, true, true) if active and not stack.is_empty() else {}
	board.sync(model.s, {})
	var title := "지금이 돌파할 틈입니다"
	var hint := "방패 개방 · 장갑 없이 공격할 수 있습니다"
	var reload_copy = Model.new(); reload_copy.s = model.s.duplicate(true)
	var lethal := false
	if active:
		reload_copy.reload_magazine()
		lethal = reload_copy.s.phase == "lost"
	if lethal:
		title = "눈앞의 적부터 막아야 합니다"
		hint = "다시 장전하면 적이 도달합니다"
	elif model.s.enemies.any(func(e): return e.hp > 0 and e.get("def", 0) > 0):
		title = "방패가 다시 닫혔습니다"; hint = "장갑을 뚫거나 개방 시점을 노리세요"
	if model.s.phase in ["reward", "won"]:
		title = "길을 열었습니다"; hint = "증폭과 돌파로 전열을 정리했습니다"
	elif model.s.phase == "lost":
		title = "적이 도달했습니다"; hint = "구성 시안 · 초기화로 같은 상황을 다시 확인합니다"
	node("IntentTitle").text = title
	node("IntentHint").text = hint
	node("IntentTitle").modulate = Color("f4ad89") if lethal or model.s.phase == "lost" else Color("f0dfb9")
	node("HeatLabel").text = "발열  %d / %d" % [model.s.heat, Content.heat_limit(model.s)]
	node("HeatBar").max_value = Content.heat_limit(model.s)
	node("HeatBar").value = model.s.heat
	var prediction_text := "사격 결과를 확인하세요"
	if not last_prediction.is_empty():
		var kills := 0
		for i in range(model.s.enemies.size()):
			if model.s.enemies[i].hp > 0 and last_prediction.enemies[i].hp <= 0: kills += 1
		prediction_text = "적 %d명 처치 예상  ·  최고 열 %d / %d" % [kills, last_prediction.heat.peak_max, Content.heat_limit(model.s)]
	elif model.s.phase in ["reward", "won"]:
		prediction_text = "전투 승리  ·  다음 보상으로 이어집니다"
	elif model.s.phase == "lost": prediction_text = "재장전 중 접근  ·  접촉으로 패배"
	node("Prediction").text = prediction_text
	node("MagazineTitle").text = "이번 탄창  %d / %d" % [stack.size(), model.capacity()]
	node("Fire").disabled = not active or stack.is_empty()
	node("Fire").text = "장전하고 발사" if model.s.phase == "plan" else "발사"
	node("Reload").disabled = not active
	node("Reload").text = "다시 장전 · 접촉 위험" if lethal else "다시 장전 · 적 %d행동" % model.reload_cost()
	node("Reload").modulate = Color("f4ad89") if lethal else Color.WHITE
	node("Bag").text = "남은 탄 %d장" % Reserve.remaining(model.s)
	node("Pressure").text = "기본 상황" if pressure else "근접 상황"
	node("StatusNote").text = "선택 중에는 적이 움직이지 않습니다" if active else "구성 시안 · 실제 저장에는 반영되지 않습니다"
	for i in range(3):
		var id: String = str(stack[i]) if i < stack.size() else ""
		node("Round%d" % i).modulate.a = 1.0 if not id.is_empty() else 0.35
		if id.is_empty(): continue
		node("Icon%d" % i).item_id = id
		node("Name%d" % i).text = Content.AMMO[id].name
		var shot: Dictionary = last_prediction.shots[i] if not last_prediction.is_empty() and i < last_prediction.shots.size() else {}
		var total_damage := int(shot.get("damage", Content.AMMO[id].dmg))
		for secondary in shot.get("secondary", []): total_damage += int(secondary.get("damage", 0))
		node("Value%d" % i).text = "+%d" % int(shot.get("boost_granted",3)) if id == "charge" else str(total_damage)
		node("Role%d" % i).text = "다음 공격" if id == "charge" else "총 피해 예상"
		node("Gain%d" % i).text = "코어 ×%.0f" % (float(shot.get("engine_percent",100))/100.0) if int(shot.get("engine_percent",100)) > 100 else ""
		node("Cost%d" % i).text = "발열 " + Content.heat_label(id, model.s)

func fire() -> void:
	if busy: return
	if model.s.phase == "plan" and not model.confirm(): return
	if model.fire(): refresh()

func reload_magazine() -> void:
	if busy: return
	if model.reload_magazine(): refresh()

func show_detail(title: String, body: String) -> void:
	node("DetailTitle").text = title
	node("DetailBody").text = body
	node("Detail").show()
	overlay_open = true
	node("CloseDetail").grab_focus()

func close_detail() -> void:
	node("Detail").hide()
	overlay_open = false

func change_composition() -> void:
	get_tree().change_scene_to_file("res://redesign/samples/combat_ui_stage1_%s.tscn" % ("b" if composition == "A" else "a"))
