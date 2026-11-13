extends "res://redesign/samples/shop_terminal_review/part_mount.gd"
## The shared live workbench for the map and shop.

const StorageRow = preload("res://redesign/build/part_storage_row.tscn")
const Engines = preload("res://redesign/damage_engines.gd")
const READING_NOTE := "교전 중 · 열람만 가능"

var workshop

func _ready() -> void:
	super._ready()
	%PartRules.pressed.connect(_show_rules)
	%PartDismantle.pressed.connect(_dismantle)
	resized.connect(fit)

func _show_rules() -> void:
	if not selected_id.is_empty(): workshop.show_rules(selected_id)

func _dismantle() -> void:
	if workshop.can_dismantle(selected_id): workshop.dismantle(selected_id)

func storage_button(id: String) -> Button:
	var row: Button = StorageRow.instantiate()
	row.get_node("Inset/Line/Glyph").item_id = id
	var title := part_name(id) + (" · 코어" if Data.is_core_part(id) else "")
	row.get_node("Inset/Line/PartName").text = title
	var engine := Engines.value(campaign.model.s, id)
	row.get_node("Inset/Line/Value").text = engine if not engine.is_empty() else str(Data.part_spec(id, campaign.model.s).get("value", ""))
	row.tooltip_text = title
	return row

func display_slot(slot: Button, id: String) -> void:
	slot.display(id, "빈 슬롯" if id.is_empty() else part_name(id))

func installation_source() -> Control:
	return %SelectedGlyph if %SelectedGlyph.is_visible_in_tree() else %PartName

func refresh() -> void:
	super.refresh()
	var model = campaign.model
	var equipped := campaign.equipped_parts()
	var has_part := not selected_id.is_empty()
	var replacing := not outgoing.is_empty()
	var active := equipped.has(selected_id)
	%GunName.text = Data.GUNS[campaign.s.gun].name
	%GunStats.text = "탄창 %d칸 · 탄창 교체 적 %d행동" % [model.capacity(), model.reload_cost()]
	if %WeaponArt.gun_id != str(campaign.s.gun): %WeaponArt.gun_id = str(campaign.s.gun)
	%MountCount.text = "%d / %d" % [equipped.size(), Campaign.MAX_EQUIPPED_PARTS]
	%StorageCount.text = "보유 파츠 · %d개" % stored_buttons.size()
	%PreviewHeading.text = %PartStatus.text if active else "파츠 정보" if not has_part else "교체 미리보기" if replacing else "장착 미리보기"
	%Before.visible = replacing
	%SwapArrow.visible = replacing
	%After.visible = has_part
	if replacing:
		%PreviousGlyph.item_id = outgoing
		%PreviousName.text = part_name(outgoing)
		# The side-by-side parts already name the swap target.
		%Instruction.hide()
	%PartStatus.hide()
	%PartRules.visible = has_part
	%PartDismantle.visible = has_part and workshop.can_dismantle(selected_id)
	if not campaign.can_manage_parts():
		%Apply.disabled = true
		%Instruction.text = READING_NOTE
		%Instruction.show()
	fit()
	workshop.ui._workspace_focus_chain.call_deferred()

func fit() -> void:
	if campaign == null: return
	var safe: Rect2 = workshop.ui.ReadableUI.available(workshop)
	var compact := safe.size.y < 620
	var short := safe.size.y < 420
	var shelf_limit := 92 if safe.size.y < 500 else 140 if compact else 188
	var shelf_content := maxi(44, stored_buttons.size() * 48 - 4)
	%StorageScroll.custom_minimum_size.y = minf(shelf_limit, shelf_content)
	%PreviewBody.add_theme_constant_override("separation", 4 if short else 6)
	%DetailsScroll.custom_minimum_size.y = 40 if short else 44
	%PreviousGlyph.visible = not compact and not outgoing.is_empty()
	%SelectedGlyph.visible = not compact and not selected_id.is_empty()
	for slot in %Slots.get_children():
		slot.custom_minimum_size.y = 56 if compact else 70

func show_result(message: String) -> void:
	super.show_result(message)
	%Result.visible = not message.is_empty()
