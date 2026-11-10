extends "res://redesign/samples/hud/combat_weapon_hud.gd"
const Cases=preload("res://redesign/samples/weapon_roles/cases.gd")
const ROLE_SAVE := "user://weapon_role_comparison_v1.json"
var role_index := 0

func _ready() -> void:
	gun_index=1
	super._ready()
	for connection in node("Help").get_signal_connection_list("pressed"):
		node("Help").disconnect("pressed",connection.callable)
	node("Help").pressed.connect(func():
		hud.close_menu()
		show_detail("총기 비교",weapon_hint()+"\n\n첫 교전은 현재 새 도전의 시작 구성입니다.\n정예·관문은 같은 20장 덱과 제3 격발기를 쓰는 비교 구성입니다. 자연 획득 경로를 재현한 판은 아닙니다.\n메뉴의 다음 총기로 데드볼트·리와인더·래칫을 비교합니다.\n\n황동 자물쇠 ×3 = 강화·봉인탄\n청록 테두리 = 이번 사격\n빨강 = 빼내기 선택\n\n현재 총기 외형은 비교용 공용 외형입니다."))
	board.shot_started.connect(func(_result):
		# The shared feedback spends one displayed occurrence at shot start.
		for i in range(hud.feedback.shots_shown): node("Seal%d"%i).hide())
	board.feedback_changed.connect(func(event):
		if hud.feedback.action_kind=="reload":
			if event.get("kind","")=="reload_turn":
				for i in range(slot_count): node("Seal%d"%i).hide()
			elif hud.feedback.swap_ready: show_seals())

func mount(_boss: bool) -> void:
	if drag!=null: drag.cancel()
	eject_mode=false;eject_selected.clear();eject_preview={}
	model=Cases.build(Cases.PROFILES[role_index],case_index)
	if model==null: push_error("Weapon role comparison opening failed"); return
	pressure=case_index==2
	receipt=Cases.TITLES[case_index]
	set_backdrop();close_detail();persist();refresh()

func set_backdrop() -> void: board.set_route_background(0,[1,4,8][case_index],8)

func next_case() -> void:
	if busy or overlay_open or eject_mode: return
	case_index=(case_index+1)%Cases.TITLES.size();mount(false)

func next_weapon() -> void:
	if busy or overlay_open or eject_mode: return
	role_index=(role_index+1)%Cases.PROFILES.size();mount(false)

func weapon_hint() -> String:
	if model!=null and Model.WeaponRoles.enabled(model.s): return Model.WeaponRoles.TEXT[Model.WeaponRoles.kind(model.s)]
	return super.weapon_hint()

func refresh() -> void:
	super.refresh()
	node("Title").text=Cases.TITLES[case_index]
	node("PreviewLabel").text=Content.weapon_spec(model.s).name
	node("Pressure").text="다음 전투"
	show_seals()

func show_seals() -> void:
	for i in range(slot_count):
		node("Seal%d"%i).visible=i==Model.WeaponRoles.mark(model.s)

func select_ejection(index: int) -> void:
	if busy or overlay_open or (drag!=null and drag.suppress_tap()): return
	if index==Model.WeaponRoles.mark(model.s):
		show_detail("봉인탄 ×3","이번 탄창의 이 한 발만 직접 피해 ×3.\n빼낼 수 없으며, 발사하면 탄창 교체 잠금이 풀립니다.\n냉각은 그대로 사용할 수 있습니다.\n화상·전격 전이·기폭 효과는 강화하지 않습니다.")
		return
	super.select_ejection(index)

func persist() -> void:
	if model==null: return
	var file:=FileAccess.open(ROLE_SAVE+".tmp",FileAccess.WRITE)
	if file==null: save_ok=false;return
	file.store_string(JSON.stringify({"format":"lob_weapon_roles","version":1,"role_index":role_index,"case_index":case_index,"combat":model.s}))
	file.close()
	save_ok=DirAccess.rename_absolute(ROLE_SAVE+".tmp",ROLE_SAVE)==OK

func restore_comparison() -> bool:
	if not FileAccess.file_exists(ROLE_SAVE): return false
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROLE_SAVE))
	var restored=Model.new()
	if not data is Dictionary or data.get("format","")!="lob_weapon_roles" or not restored._whole(data.get("version"),1,1) or not restored._whole(data.get("role_index"),0,2) or not restored._whole(data.get("case_index"),0,2) or not data.get("combat") is Dictionary: return false
	if not restored.restore_state(data.combat): return false
	var expected: String=Cases.PROFILES[int(data.role_index)]
	if restored.s.gun!="burst" or (expected=="control" and Model.WeaponRoles.enabled(restored.s)) or (expected!="control" and Model.WeaponRoles.kind(restored.s)!=expected): return false
	role_index=int(data.role_index);case_index=int(data.case_index);model=restored
	pressure=case_index==2
	eject_mode=false;eject_selected.clear();eject_preview={}
	return true
