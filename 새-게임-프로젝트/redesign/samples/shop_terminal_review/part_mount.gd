extends HBoxContainer

signal parts_changed

const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/content.gd")
const PartChoice = preload("res://redesign/part_choice.gd")

var campaign: Campaign
var selected_id := ""
var outgoing := ""
var stored_buttons: Dictionary = {}
var perform_action: Callable

func _feedback_transaction(event: Dictionary, effects) -> void:
	if campaign==null or str(event.command) not in ["equip","replace_part"]:return
	var before:Array=event.before.equipped;var after:Array=event.after.equipped
	var id:=str(event.extra) if event.command=="replace_part" else str(event.value)
	var index:=after.find(id) if after.has(id) else before.find(id)
	if index>=0 and index<%Slots.get_child_count():effects.pulse(%Slots.get_child(index),"installed")
	if stored_buttons.has(id):effects.pulse(stored_buttons[id],"stored")
	effects.pulse(%Result,"complete")

func _ready() -> void:
	for index in range(Campaign.MAX_EQUIPPED_PARTS):
		%Slots.get_child(index).pressed.connect(select_slot.bind(index))
	%Apply.pressed.connect(apply_selection)

func open(run: Campaign, preferred: String) -> void:
	campaign = run
	var equipped := campaign.equipped_parts()
	var stored := rebuild_storage(equipped)
	selected_id = preferred if campaign.s.parts.has(preferred) else str(equipped[0]) if not equipped.is_empty() else str(stored[0]) if not stored.is_empty() else ""
	outgoing = ""
	%Result.text = ""
	refresh()
	if stored_buttons.has(selected_id):
		stored_buttons[selected_id].grab_focus()
	elif equipped.has(selected_id):
		%Slots.get_child(equipped.find(selected_id)).grab_focus()

func rebuild_storage(equipped: Array) -> Array:
	for button in stored_buttons.values():
		%Storage.remove_child(button)
		button.queue_free()
	stored_buttons.clear()
	var stored: Array = campaign.s.parts.filter(func(id): return not equipped.has(id))
	for value in stored:
		var id := str(value)
		var button := Button.new()
		button.name = "Stored_" + id
		button.text = part_name(id) + (" · 코어" if Data.is_core_part(id) else "")
		button.custom_minimum_size.y = 44
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(select_part.bind(id))
		%Storage.add_child(button)
		stored_buttons[id] = button
	%StorageEmpty.visible = stored.is_empty()
	%StorageCount.text = "보관함 · %d개" % stored.size()
	return stored

func part_name(id: String) -> String:
	return str(Data.part_spec(id, campaign.model.s).name)

func select_part(id: String) -> void:
	selected_id = id
	outgoing = ""
	%Result.text = ""
	refresh()

func select_slot(index: int) -> void:
	var equipped := campaign.equipped_parts()
	if index >= equipped.size():
		return
	var id := str(equipped[index])
	if selected_id.is_empty() or equipped.has(selected_id) or campaign.can_equip(selected_id):
		select_part(id)
	else:
		outgoing = id
		%Result.text = ""
		refresh()

func valid_replacements(equipped: Array) -> Array:
	var valid: Array = []
	for index in range(equipped.size()):
		var proposed := equipped.duplicate()
		proposed[index] = selected_id
		if Data.valid_part_set(str(campaign.s.gun), proposed):
			valid.append(equipped[index])
	return valid

func refresh() -> void:
	var equipped := campaign.equipped_parts()
	var active := equipped.has(selected_id)
	var can_install := not active and not selected_id.is_empty() and campaign.can_equip(selected_id)
	var needs_slot := not selected_id.is_empty() and not active and not can_install
	var valid := valid_replacements(equipped) if needs_slot else []
	if not valid.has(outgoing):
		outgoing = ""
	%MountCount.text = "장착대 · %d / %d" % [equipped.size(), Campaign.MAX_EQUIPPED_PARTS]
	for index in range(Campaign.MAX_EQUIPPED_PARTS):
		var slot := %Slots.get_child(index) as Button
		var id := str(equipped[index]) if index < equipped.size() else ""
		var glyph = slot.get_node("Glyph")
		glyph.visible = not id.is_empty()
		if glyph.visible:
			glyph.item_id = id
		slot.tooltip_text = "빈 슬롯" if id.is_empty() else part_name(id)
		slot.disabled = id.is_empty() or (needs_slot and not valid.has(id))
		slot.set_pressed_no_signal(not id.is_empty() and (id == selected_id or id == outgoing))
	for id in stored_buttons:
		stored_buttons[id].set_pressed_no_signal(id == selected_id)

	%SelectedGlyph.visible = not selected_id.is_empty()
	%PartName.text = "선택한 파츠 없음" if selected_id.is_empty() else part_name(selected_id)
	%PartStatus.text = "" if selected_id.is_empty() else ("장착 중" if active else "보관 중") + (" · 코어" if Data.is_core_part(selected_id) else "")
	%Instruction.text = ""
	%Gain.text = ""
	%Loss.text = ""
	%Stats.text = ""
	%Apply.disabled = not active and not can_install and outgoing.is_empty()
	%Apply.text = "장착 해제" if active else "교체 장착" if needs_slot else "장착"
	if selected_id.is_empty():
		%Instruction.text = "획득한 파츠는 여기에 표시됩니다."
	else:
		%SelectedGlyph.item_id = selected_id
		describe_change(equipped, active, can_install, valid)
	for label in [%PartStatus, %Instruction, %Gain, %Loss, %Stats]:
		label.visible = not label.text.is_empty()
	%DetailsScroll.scroll_vertical = 0

func describe_change(equipped: Array, active: bool, can_install: bool, valid: Array) -> void:
	var before: Dictionary = campaign.model.s
	var after := before.duplicate(true)
	var proposed := equipped.duplicate()
	var removed := ""
	if active:
		proposed.erase(selected_id)
		removed = selected_id
	elif can_install:
		proposed.append(selected_id)
		%Instruction.text = "빈 슬롯에 장착"
	elif not outgoing.is_empty():
		proposed[proposed.find(outgoing)] = selected_id
		removed = outgoing
		%Instruction.text = "교체 대상 · " + part_name(outgoing)
	else:
		%Instruction.text = "교체할 장착 슬롯을 고르세요." if not valid.is_empty() else "이 구성에는 장착할 수 없습니다."
		%Gain.text = PartChoice.effect(selected_id, before)
		return
	after.equipped_parts = proposed
	if not active:
		%Gain.text = "얻음  " + PartChoice.effect(selected_id, after)
		var cost := str(Data.part_spec(selected_id, after).get("downside", ""))
		if not cost.is_empty():
			%Gain.text += "\n대가  " + cost
	if not removed.is_empty():
		%Loss.text = ("해제 시 잃음  " if active else "잃음  ") + PartChoice.effect(removed, before)
		var cost := str(Data.part_spec(removed, before).get("downside", ""))
		if not cost.is_empty():
			%Loss.text += "\n해제  " + cost
	var deltas := PartChoice.deltas(before, after)
	if Data.capacity(before) != Data.capacity(after):
		deltas.append("탄창  %d → %d칸" % [Data.capacity(before), Data.capacity(after)])
	if Data.heat_limit(before) != Data.heat_limit(after):
		deltas.append("열 한계  %d → %d" % [Data.heat_limit(before), Data.heat_limit(after)])
	%Stats.text = "\n".join(deltas)

func apply_selection() -> void:
	if %Apply.disabled or selected_id.is_empty():
		return
	var was_active := campaign.is_equipped(selected_id)
	var changed: bool
	if perform_action.is_valid():
		changed = perform_action.call("equip", selected_id, "") if outgoing.is_empty() else perform_action.call("replace_part", outgoing, selected_id)
	else:
		changed = campaign.equip(selected_id) if outgoing.is_empty() else campaign.replace_part(outgoing, selected_id)
	if not changed:
		refresh()
		return
	var result := "교체 완료" if not outgoing.is_empty() else "장착 해제" if was_active else "장착 완료"
	outgoing = ""
	var equipped := campaign.equipped_parts()
	rebuild_storage(equipped)
	refresh()
	%Result.text = result
	if stored_buttons.has(selected_id):
		stored_buttons[selected_id].grab_focus()
	else:
		%Slots.get_child(equipped.find(selected_id)).grab_focus()
	parts_changed.emit()
