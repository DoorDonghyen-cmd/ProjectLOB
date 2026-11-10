extends "res://redesign/samples/hud/combat_weapon_hud.gd"
const TRIAL_SAVE:="user://fire_heat_comparison_v1.json"
const NODES:=[101,401,802]
const CASE_NAMES:=["첫 교전","장갑 진지","첫 관문"]
var options:={"version":1,"input":"range","reload":"none","damage":false,"rounds":0}
var openings: Array=[]

func _ready()->void:
	openings=JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/fire_heat/openings.json"))
	case_index=1
	super._ready()
	for connection in node("Help").get_signal_connection_list("pressed"):node("Help").disconnect("pressed",connection.callable)
	node("Help").pressed.connect(func():
		hud.close_menu()
		show_detail("사격과 열 비교",weapon_hint()+"\n\n첫 탄에서 오른쪽으로 끌어 선두 범위를 정합니다.\n놓기만 해서는 발사하지 않습니다. 사격 버튼으로 확정합니다.\n탄창 밖에 놓기·Esc·창 포커스 이탈은 범위 변경을 취소합니다.\n짧게 누르기는 기존 빼내기 선택입니다.\n메뉴의 -/+로도 발수를 정할 수 있습니다.\n\n"+node("TrialRules").text))
	node("TrialInput").pressed.connect(change_option.bind("input"))
	node("TrialReload").pressed.connect(change_option.bind("reload"))
	node("TrialDamage").pressed.connect(change_option.bind("damage"))
	node("TrialBaseline").pressed.connect(baseline)
	node("BudgetLess").pressed.connect(func():select_budget(current_budget()-1))
	node("BudgetMore").pressed.connect(func():select_budget(current_budget()+1))
	hud.cycle_focus(["MenuClose","TrialInput","TrialReload","TrialDamage","TrialBaseline","BudgetLess","BudgetMore","Help","Reset","Pressure","Other","EffectsVolume","CombatMotion"])
	board.feedback_changed.connect(func(event):
		if event.has("heat"):show_trial_heat(int(event.heat)))
	refresh()

func opening()->Dictionary:
	for row in openings:
		if row.gun==GUNS[gun_index] and int(row.node)==NODES[case_index]:return row.state.duplicate(true)
	return {}

func mount(_boss: bool)->void:
	if drag!=null:drag.cancel()
	eject_mode=false;eject_selected.clear();eject_preview={}
	model=Model.new()
	if not model.restore_state(opening()):push_error("Current earned comparison opening cannot restore");return
	options.rounds=0;model.s.fire_heat_trial=options.duplicate(true)
	pressure=case_index==2;receipt="같은 진입 상태 · 조건 변경 시 이 전투 처음부터"
	set_backdrop();close_detail();persist();refresh()

func set_backdrop()->void:board.set_route_background(0,[1,4,8][case_index],8)
func next_case()->void:
	if busy or overlay_open or eject_mode:return
	case_index=(case_index+1)%NODES.size();mount(false)
func change_option(key: String)->void:
	if busy:return
	if key=="damage":options.damage=not options.damage
	else:
		var values: Array=Trial.INPUTS if key=="input" else Trial.RELOADS
		options[key]=values[(values.find(options[key])+1)%values.size()]
	mount(false)
func baseline()->void:
	if busy:return
	options={"version":1,"input":"fixed","reload":"legacy","damage":false,"rounds":0};mount(false)

func refresh()->void:
	super.refresh()
	if model==null or model.s.is_empty():return
	var range_mode:=Trial.range_enabled(model.s)
	node("TrialInput").text="사격 · "+("앞줄 범위 선택" if options.input=="range" else "기존 고정 묶음")
	node("TrialReload").text="탄창 교체 · "+{"legacy":"기존 냉각","none":"열 유지","small":"열 -2"}[options.reload]
	node("TrialDamage").text="고열 위력 · "+("80% 시험" if options.damage else "기존 유지")
	node("BudgetValue").text="이번 사격 최대 %d발"%current_budget()
	node("BudgetLess").disabled=not range_mode or current_budget()<=1
	node("BudgetMore").disabled=not range_mode or current_budget()>=maximum_budget()
	show_trial_heat(int(model.s.heat))
	node("TrialRules").text="조건 변경 → 같은 전투 처음부터.\n짧은 묶음도 적 1행동. 리액터 4발째는 강행 조건일 때만.\n열 유지/-2 교체는 연속 발열을 끊지 않습니다. 냉각 약실 +4 유지.\n80% 시험: 발사 전 열 75%부터 위력 ×0.8(버림, 최소1), 장갑 차감 전. 화상은 그대로."

func show_trial_heat(heat: int)->void:
	var mode: String={"legacy":"기존 냉각","none":"열 유지","small":"열 -2"}[options.reload]
	var title: String=CASE_NAMES[case_index]+" · "+("앞줄 끌기" if options.input=="range" else "고정 사격")+" · "+mode
	if options.damage:title+=" · "+("위력80%" if heat>=Trial.threshold(Content.heat_limit(model.s)) else "80% 시험")
	node("Title").text=title;node("Title").tooltip_text=title+"\n메뉴에서 조건 변경 · 짧게 누르면 빼내기 선택"

func persist()->void:
	var file:=FileAccess.open(TRIAL_SAVE+".tmp",FileAccess.WRITE)
	if file==null:save_ok=false;return
	file.store_string(JSON.stringify({"format":"lob_fire_heat_trial","version":1,"gun":gun_index,"case":case_index,"state":model.s}));file.close()
	save_ok=DirAccess.rename_absolute(TRIAL_SAVE+".tmp",TRIAL_SAVE)==OK
func restore_comparison()->bool:
	if not FileAccess.file_exists(TRIAL_SAVE):return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(TRIAL_SAVE))
	var restored=Model.new()
	if not data is Dictionary or data.get("format")!="lob_fire_heat_trial" or data.get("version")!=1:return false
	if not restored._whole(data.get("gun"),0,4) or not restored._whole(data.get("case"),0,2) or not data.get("state") is Dictionary:return false
	if not restored.restore_state(data.state) or not Trial.enabled(restored.s):return false
	if restored.s.gun!=GUNS[int(data.gun)] or int(restored.s.get("encounter_id",0))!=NODES[int(data.case)]:return false
	gun_index=int(data.gun);case_index=int(data.case);model=restored;options=Trial.config(model.s).duplicate(true)
	return true
