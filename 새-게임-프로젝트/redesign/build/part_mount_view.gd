extends "res://redesign/samples/shop_terminal_review/part_mount.gd"
## The shop terminal's part mount, reused in the build workshop (2026-11-08). Adds the
## workshop-only actions (rules, dismantle where allowed) and a read-only mode for
## states where parts cannot change (combat, run ended).
var read_only := false
var workshop
var rules_button: Button
var dismantle_button: Button
var rule_label: Label

func _ready() -> void:
	super._ready()
	var row: Node = %Apply.get_parent()
	rules_button = Button.new()
	rules_button.name = "PartRules"
	rules_button.text = "규칙"
	rules_button.custom_minimum_size = Vector2(72, 44)
	rules_button.pressed.connect(on_rules)
	row.add_child(rules_button)
	dismantle_button = Button.new()
	dismantle_button.name = "PartDismantle"
	dismantle_button.text = "분해 · +10Cr"
	dismantle_button.custom_minimum_size = Vector2(0, 44)
	dismantle_button.pressed.connect(on_dismantle)
	row.add_child(dismantle_button)
	# The workshop has room for the part's full rule under the change summary.
	rule_label = Label.new()
	rule_label.name = "PartRuleText"
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_label.add_theme_color_override("font_color", Color("a59c8b"))
	%Instruction.get_parent().add_child(rule_label)

func on_rules() -> void:
	if workshop != null and not selected_id.is_empty(): workshop.show_rules(selected_id)

func on_dismantle() -> void:
	if workshop != null and not selected_id.is_empty(): workshop.dismantle(selected_id)

func refresh() -> void:
	super.refresh()
	if rules_button == null: return
	rules_button.visible = not selected_id.is_empty()
	dismantle_button.visible = workshop != null and not selected_id.is_empty() and workshop.can_dismantle(selected_id)
	if rule_label == null: return
	rule_label.text = "" if selected_id.is_empty() else str(Data.part_spec(selected_id, campaign.model.s).text)
	rule_label.visible = not rule_label.text.is_empty()
	if read_only and not selected_id.is_empty():
		%Apply.disabled = true
		%Instruction.text = "교전 중 · 열람만 가능"
		%Instruction.visible = true
