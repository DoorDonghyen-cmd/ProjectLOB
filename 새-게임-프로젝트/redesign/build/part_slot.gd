@tool
extends Button

@export var sample_part := "opening":
	set(value):
		sample_part = value
		if Engine.is_editor_hint() and is_node_ready(): display(value, sample_caption)
@export var sample_caption := "선두 격발기":
	set(value):
		sample_caption = value
		if Engine.is_editor_hint() and is_node_ready(): display(sample_part, value)

func _ready() -> void:
	display(sample_part, sample_caption)

func display(id: String, caption: String) -> void:
	$Glyph.visible = not id.is_empty()
	if not id.is_empty(): $Glyph.item_id = id
	$Caption.text = caption
