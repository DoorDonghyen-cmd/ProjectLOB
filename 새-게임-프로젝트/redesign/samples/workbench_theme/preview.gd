extends Control
## Composed visual prototype only: no campaign loading, saving or gameplay commands.
const Model=preload("res://redesign/model.gd")
const Content=preload("res://redesign/content.gd")
const MODES=["탄종 교체","탄환 압축","탄환 개조","덱 정리","가방 확장"]
var model=Model.new()
var ids: Array=["basic_p3","pierce_p3","precise_p2","bore","disrupt"]
var amounts: Array=[8,4,3,3,2]
var selected := 0
var mode := 1
signal inspected(mode_index: int, selected_ammo: String)

func _ready() -> void:
	model.start("burst",17,false,"carrier")
	for i in range(ids.size()):
		if not Content.AMMO.has(ids[i]):ids[i]="basic_p3"
		var slot: Button=get_node("Inventory/Inset/Rows/Slots/Slot%d"%i)
		slot.get_node("Content/Icon").item_id=ids[i]
		slot.get_node("Content/Name").text=Content.AMMO[ids[i]].name
		slot.get_node("Content/Count").text="%d발"%amounts[i]
		slot.pressed.connect(_select.bind(i))
	for i in range(MODES.size()):get_node("Tabs/Tab%d"%i).pressed.connect(_mode.bind(i))
	$Header/Exit.pressed.connect(func():get_tree().quit())
	_refresh()

func _select(index: int) -> void:
	selected=index
	_refresh()
func _mode(index: int) -> void:
	mode=index
	_refresh()
func _refresh() -> void:
	for i in range(MODES.size()):get_node("Tabs/Tab%d"%i).button_pressed=i==mode
	for i in range(ids.size()):get_node("Inventory/Inset/Rows/Slots/Slot%d"%i).button_pressed=i==selected
	var source: String=ids[selected]
	var target: String=Content.compressed_id(source)
	var before: int=Content.damage(source,model.s)
	var body: VBoxContainer=$Inspector/Inset/Content
	body.get_node("Title").text=MODES[mode]
	body.get_node("Name").text=Content.AMMO[source].name
	body.get_node("Name").visible=mode!=4
	var pairs: Array=[]
	var action: String=""
	var condition: String="정비 1회 사용 · 무료"
	var available := true
	match mode:
		0:
			target=ids[(selected+1)%ids.size()]
			pairs=[["내보낼 탄",Content.AMMO[source].name+" 1발"],["받을 탄",Content.AMMO[target].name+" 1발"],["보유 탄약","20발 유지"]]
			action="탄종 교체"
		1:
			available=not target.is_empty() and Content.AMMO.has(target)
			if available:
				pairs=[["소모 → 획득","일반 2발 → 고급 1발"],["피해","%d → %d"%[before,Content.damage(target,model.s)]],["발열",Content.heat_label(source,model.s)+" → "+Content.heat_label(target,model.s)],["보유 탄약","20 → 19발"]]
			action="2발 압축"
		2:
			target=Content.Variants.tuned(source,Content.AMMO,"power")
			available=not target.is_empty()
			if available:pairs=[["작업","화력 개조 · 1발"],["피해","%d → %d"%[before,Content.damage(target,model.s)]],["발열",Content.heat_label(source,model.s)+" → "+Content.heat_label(target,model.s)],["보유 탄약","20발 유지"]]
			action="화력 개조"
		3:
			target=source
			pairs=[["제거할 탄",Content.AMMO[source].name+" 1발"],["보유 수량","%d → %d발"%[amounts[selected],amounts[selected]-1]],["보유 탄약","20 → 19발"],["최소 보유","12발"]]
			action="1발 제거"
		4:
			target=source
			pairs=[["휴대 상한","32 → 34발"],["보유 탄약","20발 유지"],["탄약 지급","없음"]]
			action="가방 확장"
	for i in range(4):
		var key: Label=body.get_node("Stats/Key%d"%i)
		var value: Label=body.get_node("Stats/Value%d"%i)
		key.visible=i<pairs.size();value.visible=i<pairs.size()
		if i<pairs.size():key.text=pairs[i][0];value.text=pairs[i][1]
	body.get_node("Recipe").visible=false
	body.get_node("Recipe/Source").item_id=source
	body.get_node("Recipe/Source2").item_id=source
	body.get_node("Recipe/Source2").visible=mode==1
	body.get_node("Recipe/Result").item_id=target if available else source
	body.get_node("Condition").text=condition if available else "이 탄환은 화력 개조 불가"
	body.get_node("Condition").visible=not available
	body.get_node("Apply").text=action
	body.get_node("Apply").disabled=not available
	$InspectedRounds.visible=mode!=4
	$InspectedRounds/Source.item_id=source
	$InspectedRounds/Source2.item_id=source
	$InspectedRounds/Source2.visible=mode==1
	$InspectedRounds/Caption.text=Content.AMMO[source].name+(" 2발" if mode==1 else " 1발")
	inspected.emit(mode,source)
