extends "res://redesign/samples/combat_ui_stage1.gd"
## Six-slot comparison uses owned ammunition and the current combat resolver.
## Candidate capacity lives only in this unsaved study, never a campaign save.
var study_capacity := 6
var fired_detail: Dictionary = {}

func mount(boss: bool) -> void:
	pressure=boss
	var path := "res://redesign/samples/combat_ui_capacity_%s_%d.json" % ["boss" if boss else "normal",study_capacity]
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	model=Model.new();model.s=fixture.state.duplicate(true);model.s.history=[]
	fired_detail={}
	if is_instance_valid(board):board.set_route_background(0,8 if boss else 4,8)
	close_detail();refresh()

func refresh() -> void:
	super.refresh()
	# This composition owns the action receipt below the battlefield. Keep the
	# inherited corner receipt from colliding with the named-enemy header.
	board.salvo_receipt={};board.receipt_is_previous=false;board.queue_redraw()
	node("Title").text="첫 관문 · 강적 비교" if pressure else "교대 방패 진지"
	node("PreviewLabel").text="A안 · 탄창 용량 비교"
	node("Pressure").text="기본 전투" if pressure else "강적 전투"
	node("Other").text="3칸 비교" if study_capacity==6 else "6칸 비교"
	var stack: Array=model.s.plan if model.s.phase=="plan" else model.s.magazine
	var shots: Array=last_prediction.get("shots",[])
	var is_result := not fired_detail.is_empty()
	var ended: bool = model.s.phase in ["won","reward"] if is_result else str(last_prediction.get("phase","")) in ["won","reward"]
	var heat_cut := bool(fired_detail.get("overheated",false)) if is_result else float(last_prediction.get("heat",{}).get("forced_probability",0.0))>0.0
	if is_result:
		stack=fixture.state.plan
		shots=fired_detail.results
		var unfired: int=stack.size()-shots.size()
		node("MagazineTitle").text="발사 결과  %d / %d발" % [shots.size(),stack.size()]
		var forced: Dictionary=fired_detail.get("forced_reload",{})
		if not forced.is_empty():
			node("IntentTitle").text="과열로 사격이 멈췄습니다"
			node("IntentHint").text="미발사 %d발 배출 · 강제 재장전 중 적 %d행동" % [unfired,int(forced.cost)]
		node("Prediction").text="%d발 발사 · 최고 열 %d / %d" % [shots.size(),fired_detail.heat_peak,Content.heat_limit(model.s)]
	var remaining: int=stack.size()-shots.size()
	if not stack.is_empty():
		var reason := "전투 종료" if ended else "과열 중단" if heat_cut else "사격 중단"
		node("CapacityNote").text="%d발 장전 · %d발 %s · %d발 미발사 (%s)" % [stack.size(),shots.size(),"발사" if is_result else "발사 예상",remaining,reason] if remaining>0 else "%d발 모두 %s" % [stack.size(),"발사" if is_result else "발사 가능"]
	else:node("CapacityNote").text="초기화로 같은 탄창을 다시 비교할 수 있습니다"
	for i in range(6):
		var card: Control=node("Round%d" % i)
		var available := i<stack.size() and i<study_capacity
		var not_fired := available and i>=shots.size()
		card.modulate.a=0.72 if not_fired else 0.45 if not available else 1.0
		node("Icon%d" % i).visible=available
		node("Gain%d" % i).text=""
		if not available:
			node("Name%d" % i).text="빈칸" if i<study_capacity else "비교 제외"
			node("Role%d" % i).text="";node("Value%d" % i).text="—";node("Cost%d" % i).text=""
			continue
		var id: String=str(stack[i])
		node("Icon%d" % i).item_id=id
		node("Name%d" % i).text=Content.AMMO[id].name
		node("Cost%d" % i).text="열 "+Content.heat_label(id,model.s)
		if not_fired:
			node("Role%d" % i).text="미발사"
			node("Value%d" % i).text="—"
			node("Gain%d" % i).text="전투 종료" if ended else "과열 중단" if heat_cut else "중단"
			continue
		var shot: Dictionary=shots[i]
		var damage:=int(shot.get("damage",0))
		for secondary in shot.get("secondary",[]):damage+=int(secondary.get("damage",0))
		node("Role%d" % i).text="다음 공격" if id=="charge" else "총 피해"
		node("Value%d" % i).text="+%d" % int(shot.boost_granted) if id=="charge" else str(damage)
		node("Gain%d" % i).text="코어 ×%.0f" % (float(shot.get("engine_percent",100))/100.0) if int(shot.get("engine_percent",100))>100 else ""

func fire() -> void:
	if busy:return
	if model.s.phase=="plan" and not model.confirm():return
	if model.fire():
		fired_detail=model.s.history.back().detail.duplicate(true)
		refresh()

func reload_magazine() -> void:
	if model.reload_magazine():fired_detail={};refresh()

func change_composition() -> void:
	study_capacity=3 if study_capacity==6 else 6
	mount(pressure)
