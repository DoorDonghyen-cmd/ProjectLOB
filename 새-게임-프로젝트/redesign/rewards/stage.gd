@tool
extends TextureRect

const Ascent = preload("res://redesign/ascent_background.gd")
const Actor = preload("res://redesign/weapon_actor.gd")

var floor_y := 728.0
var actor: Texture2D

func _ready() -> void:
	actor = Actor.portrait("carrier")
	resized.connect(queue_redraw)

func present(campaign) -> void:
	var profile := Ascent.profile(int(campaign.s.region), int(campaign.s.floor), int(campaign.region_info().floors))
	texture = Ascent.texture(profile)
	floor_y = float(profile.floor_y)
	actor = Actor.portrait(str(campaign.s.outfit))
	queue_redraw()

func _draw() -> void:
	if texture == null or size.x <= 0 or size.y <= 0:
		return
	var source := texture.get_size()
	var ground := roundf(maxf(100.0, size.y - 312.0))
	var factor := maxf(size.x / source.x, ground / floor_y)
	var extent := size / factor
	var crop := Rect2(Vector2((source.x - extent.x) * 0.5, floor_y - ground / factor), extent)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), crop, Color("c3bfc1"))
	if actor != null:
		var foot := Vector2(roundf(size.x * 0.76), ground + 11)
		var figure := (actor.get_size() * (clampf(ground * 0.55, 74.0, 185.0) / actor.get_height())).round()
		draw_set_transform(foot, 0.0, Vector2(1, 0.16))
		draw_circle(Vector2.ZERO, figure.x * 0.42, Color(0.04, 0.035, 0.038, 0.65))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(actor, Rect2((foot - Vector2(figure.x / 2.0, figure.y)).round(), figure), false, Color("d5c4b4"))
