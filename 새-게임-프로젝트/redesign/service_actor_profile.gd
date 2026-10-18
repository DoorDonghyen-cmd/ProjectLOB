@tool
extends Resource
## Per-outfit pose registration. Raw PNGs stay unmodified.
@export var texture: Texture2D
@export var source_rect := Rect2()
@export var foot_in_source := Vector2(0.5, 1.0)
