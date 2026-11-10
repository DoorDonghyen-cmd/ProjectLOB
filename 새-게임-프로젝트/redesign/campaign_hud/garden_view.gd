@tool
extends "res://redesign/garden_battle_view.gd"
var line_readout=preload("res://redesign/campaign_hud/line_readout.gd").new(self)
func compact() -> bool:
	return size.y < 264.0

func actor_factor() -> float:
	return clampf((size.y - 80.0) / 160.0, 0.45, 1.0) if compact() else 1.0

func ground_y() -> float:
	return size.y - 42.0 if compact() else super.ground_y()

func character_scale() -> float:
	return line_readout.HERO_SCALE * actor_factor()

func concept_rect(index: int) -> Rect2:
	var rect := super.concept_rect(index)
	var foot := enemy_feet(index) + _actor_offset(index)
	return Rect2((foot + (rect.position - foot) * actor_factor()).round(), (rect.size * actor_factor()).round())

func enemy_head_y(index: int) -> float:
	var foot := enemy_feet(index).y
	return foot - (foot - super.enemy_head_y(index)) * actor_factor()

func enemy_position(index: int) -> Vector2:
	var point := super.enemy_position(index)
	if Ranged.is_projectile(index): return point
	var foot := enemy_feet(index)
	return (foot + (point - foot) * actor_factor()).round()

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	super._draw_enemy_actor(index, foot, lift, stride)
	if hunter_sprites.has(index): hunter_sprites[index].scale *= actor_factor()

func _draw_backdrop() -> void:
	if not compact():
		super._draw_backdrop()
		return
	if tower_texture == null: return
	draw_texture_rect_region(tower_texture, Rect2(Vector2.ZERO, size), background_source_rect())
	draw_rect(Rect2(0, player_feet().y + 2, size.x, 2), Color("587079"))
	draw_rect(Rect2(0, size.y - 20, size.x, 20), Color("101e25"))
	draw_rect(Rect2(0, size.y - 20, size.x, 1), Color("3d555c"))

func enemy_hud_width(index: int) -> float:
	return line_readout.hud_width(index)

func enemy_plaque(index: int) -> Rect2:
	return line_readout.plaque(index)

func _draw_crowding(canvas: CanvasItem) -> void:
	line_readout.draw_badges(canvas)

func _draw_player(foot: Vector2) -> void:
	line_readout.draw_player(foot)

func intent_rect(index: int) -> Rect2:
	return line_readout.intent_rect(index)

func _draw_enemy_plaque(index: int, canvas: CanvasItem = null) -> void:
	line_readout._draw_enemy_plaque(index,canvas)

func _draw_hud_text(position: Vector2,text: String,alignment: int,width: float,font_size: int,color: Color,canvas: CanvasItem=null)->void:
	line_readout._draw_hud_text(position,text,alignment,width,font_size,color,canvas)
