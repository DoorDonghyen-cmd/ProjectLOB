@tool
extends Control

const Ascent = preload("res://redesign/ascent_background.gd")
const Actor = preload("res://redesign/weapon_actor.gd")
const HOME = preload("res://assets/art/tower_sample_20261003/residential_tower.png")
const GRADE = preload("res://redesign/results/stage_grade.tres")
const LOSS_LIGHT := Color("c5afb9")
const LOSS_DUSK := Color("88738b")

var backdrop: Texture2D = HOME
var actor: Texture2D
var light_fade: Tween
var floor_y := 720.0
var tint := Color.WHITE
var focus_x := 0.13

func _ready() -> void:
	if actor == null:
		actor = Actor.portrait("carrier")
	resized.connect(queue_redraw)

func present(campaign, won: bool, motion: float) -> void:
	if light_fade != null:
		light_fade.kill()
		light_fade = null
	if won:
		backdrop = HOME
		floor_y = 720.0
		tint = Color("ffdbc0")
		focus_x = 0.13
		actor = Actor.portrait(str(campaign.s.outfit))
	else:
		var profile := Ascent.profile(int(campaign.s.region), int(campaign.s.floor), int(campaign.region_info().floors))
		backdrop = Ascent.texture(profile)
		floor_y = float(profile.floor_y)
		tint = LOSS_LIGHT if motion > 0.0 else LOSS_DUSK
		focus_x = 0.5
		actor = null
		if motion > 0.0:
			light_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			light_fade.tween_method(set_light, LOSS_LIGHT, LOSS_DUSK, 0.85 * motion)
	queue_redraw()

func _draw() -> void:
	if backdrop == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var floor := roundf(size.y * 0.77)
	var source := backdrop.get_size()
	var scale_factor := maxf(size.x / source.x, maxf(floor / floor_y, (size.y - floor) / (source.y - floor_y)))
	var view_size := size / scale_factor
	var crop := Rect2(Vector2((source.x - view_size.x) * focus_x, floor_y - floor / scale_factor), view_size)
	var bounds := Rect2(Vector2.ZERO, size)
	draw_texture_rect_region(backdrop, bounds, crop, tint)
	if actor != null:
		draw_actor(Vector2(roundf(size.x * 0.30), floor))
	draw_texture_rect(GRADE, bounds, false)

func draw_actor(foot: Vector2) -> void:
	var figure_size := (actor.get_size() * (minf(176.0, size.y * 0.22) / actor.get_height())).round()
	var origin := (foot - Vector2(figure_size.x / 2.0, figure_size.y)).round()
	draw_set_transform(Vector2(foot.x, foot.y + 2.0), 0.0, Vector2(1.0, 0.17))
	draw_circle(Vector2.ZERO, 48.0, Color(0.025, 0.02, 0.024, 0.54))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(actor, Rect2(origin, figure_size), false, tint)

func set_light(color: Color) -> void:
	tint = color
	queue_redraw()
