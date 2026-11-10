extends "res://tests/combat_hud_ui.gd"
const RoleScene=preload("res://redesign/samples/weapon_roles/screen.tscn")
const RoleModel=preload("res://redesign/model.gd")

func make_preview(resume: bool=false) -> void:
	preview=RoleScene.instantiate();preview.resume_saved=resume
	root.add_child(preview);await settle()
	preview.hud.feedback.preferences.data.motion="instant"
	preview.hud.feedback.preferences.data.effects_volume=0.0
	preview.hud.feedback.configure()

func select_case(role: int,index: int) -> void:
	preview.role_index=role;preview.case_index=index;preview.mount(false);await settle()

func sealed_layout() -> void:
	hud_layout()
	for id in ["ReloadName","ReloadCost","CoolName","CoolCost"]:
		var label: Label=preview.node(id)
		var width: float=label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		check(width<=label.size.x+1,"New action text fits without ellipsis: "+id)
	var mark: int=RoleModel.WeaponRoles.mark(preview.model.s)
	for i in range(preview.slot_count):
		var seal: Control=preview.node("Seal%d"%i)
		check(seal.visible==(i==mark),"Only one physical occurrence displays brass seal")
		if seal.visible:
			check(preview.node("Face%d"%i).get_global_rect().encloses(seal.get_global_rect()),"Seal fits unchanged card face")
			check(seal.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Seal cannot intercept touch")
	if mark>=0:
		check(preview.node("Reload").disabled and preview.node("ReloadCost").text=="봉인탄 먼저","Locked reload has a short reason")

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/weapon_abilities_20261106/"): quit(2);return
	Input.emulate_mouse_from_touch=true
	await make_preview()
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(1008,454)]:
		root.size=extent;await settle()
		for role in range(3):
			await select_case(role,1)
			sealed_layout()
			check(preview.node("Weapon").text==["데드볼트","리와인더","래칫"][role],"Approved weapon name")
			await capture(["deadbolt","rewinder","ratchet"][role]+"_%dx%d"%[extent.x,extent.y])
	root.size=Vector2i(1280,800);await select_case(0,2)
	var state_before: Dictionary=preview.model.s.duplicate(true)
	var mark: int=RoleModel.WeaponRoles.mark(preview.model.s)
	await tap("Select%d"%mark)
	check(preview.node("Detail").visible and preview.eject_selected.is_empty(),"Touching sealed card explains lock without selecting ejection")
	await tap("CloseDetail")
	check(preview.model.s==state_before,"Inspection never rerolls or mutates model")
	await tap("Reload")
	check(preview.model.s==state_before,"Disabled reload touch cannot reroll")
	var eject_index:=0 if mark!=0 else 1
	await tap("Select%d"%eject_index)
	check(preview.eject_selected==[eject_index],"Normal card remains directly selectable")
	await tap("EjectToggle")
	check(preview.model.ejection_remaining()==1 and RoleModel.WeaponRoles.mark(preview.model.s)==mark-(1 if eject_index<mark else 0),"UI ejection preserves seal occurrence")
	sealed_layout()
	preview.select_budget(1)
	var attempts:=0
	while RoleModel.WeaponRoles.locked(preview.model.s) and preview.model.s.phase=="ready" and attempts<8:
		await tap("Fire");attempts+=1
	check(not RoleModel.WeaponRoles.locked(preview.model.s),"Real touch fire consumes the seal")
	if preview.model.s.phase=="ready":
		check(not preview.node("Reload").disabled,"Reload reopens immediately after seal spent")
		await tap("Reload")
		check(RoleModel.WeaponRoles.locked(preview.model.s),"Real UI reload marks next magazine")
		sealed_layout()
	await capture("deadbolt_after_reload")
	# The independent comparison save is restored through the same strict Model.
	preview.persist();var saved: Dictionary=canonical(preview.model.s)
	preview.queue_free();await settle();await make_preview(true)
	check(preview.resumed and canonical(preview.model.s)==saved,"Comparison resume preserves exact seal/order/RNG")
	await select_case(1,2)
	preview.select_budget(1)
	for unused in range(3):
		if int(preview.model.s.heat)>0: break
		await tap("Fire")
	var before: Dictionary=preview.model.s.duplicate(true)
	var expected: Array=before.magazine.duplicate();expected.reverse()
	check(preview.node("CoolName").text=="냉각·역전","Cooling advertises first reversal")
	await capture("rewinder_before_cooling")
	await tap("Cool")
	check(preview.model.s.magazine==expected and preview.model.s.weapon_role_trial.rewound,"Touch cooling reverses the surviving magazine")
	check(preview.node("CoolName").text=="냉각","Used reversal returns to normal cooling label")
	check(int(preview.model.s.turns)==int(before.turns)+1,"Native cooling costs one enemy action")
	await capture("rewinder_after_cooling")
	preview.persist();saved=canonical(preview.model.s)
	preview.queue_free();await settle();await make_preview(true)
	check(preview.resumed and canonical(preview.model.s)==saved,"Comparison resume retains used reversal")
	await tap("Menu");await tap("Other")
	check(preview.role_index==2 and not RoleModel.WeaponRoles.enabled(preview.model.s),"Menu switches to unchanged Ratchet control")
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_sizes":["1280x800","1170x540","1008x454"]},"  "))
	preview.queue_free();await settle()
	print("WEAPON ABILITIES UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
