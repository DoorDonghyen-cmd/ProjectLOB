extends "res://redesign/residential_battle_view.gd"
const HumanArt = preload("res://redesign/slum_art.gd")
const Slum = preload("res://redesign/slum_roster.gd")
var human_sprites: Dictionary = {}
var reserve_sprites: Dictionary = {}
var firing_human := -1

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state,prediction)
	firing_human = -1
	for actor in human_sprites.values(): actor.hide()
	for actor in reserve_sprites.values(): actor.hide()

func _draw() -> void:
	for actor in human_sprites.values(): actor.hide()
	for actor in reserve_sprites.values(): actor.hide()
	super._draw()

func _draw_reinforcement_actor(index: int, rect: Rect2) -> void:
	var enemy: Dictionary=reinforcements[index]
	if not Slum.human(enemy):
		super._draw_reinforcement_actor(index,rect)
		return
	if not reserve_sprites.has(index):
		var sprite:=Polygon2D.new()
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout:=ShaderMaterial.new()
		cutout.shader=CUTOUT;sprite.material=cutout
		add_child(sprite);reserve_sprites[index]=sprite
	var actor: Polygon2D=reserve_sprites[index]
	var pose:=HumanArt.pose(str(enemy.species))
	var points:=PackedVector2Array()
	var ratio: float=22.0/float(pose.height)
	for point in pose.uv:points.append((point-pose.anchor)*float(pose.scale)*ratio)
	actor.polygon=points;actor.uv=pose.uv;actor.texture=pose.texture
	actor.position=(rect.position+Vector2(12,23)).round()
	actor.modulate=Color("a7b6b5")
	actor.show()

func human_frame(index: int) -> int:
	var enemy: Dictionary = enemies[index]
	if not actor_motion_enabled() or fast_forward: return 0
	if firing_human == index or attacking_indices.has(index): return 2
	if str(enemy.species) == Slum.LEADER:
		if challenge_target == index: return 2
		if int(enemy.get("charge",0)) >= int(enemy.get("charge_max",3))-1: return 1
	if str(enemy.kind) == "spitter":
		return 1 if str(enemy.get("ranged_phase",""))=="prepare" and int(enemy.get("ranged_left",2))<=1 else 0
	return 1 if moving_indices.has(index) and sin(march_phase)>0.0 else 0

func concept_rect(index: int) -> Rect2:
	if not Slum.human(enemies[index]): return super.concept_rect(index)
	var pose := HumanArt.pose(str(enemies[index].species),human_frame(index))
	var bounds := Rect2(pose.uv[0],Vector2.ZERO)
	for point in pose.uv: bounds=bounds.expand(point)
	return Rect2((enemy_feet(index)+_actor_offset(index)+(bounds.position-pose.anchor)*pose.scale).round(),bounds.size*pose.scale)

func enemy_head_y(index: int) -> float:
	if Slum.human(enemies[index]): return enemy_feet(index).y-float(HumanArt.REGISTRATION[str(enemies[index].species)].height)
	return super.enemy_head_y(index)

func enemy_hud_width(index: int) -> float:
	if str(enemies[index].get("species",""))==Slum.LEADER: return 200.0
	return super.enemy_hud_width(index)

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Slum.human(enemies[index]):
		return enemy_feet(index)-Vector2(0,48)
	return super.enemy_position(index)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if not Slum.human(enemies[index]):
		super._draw_enemy_actor(index,foot,lift,stride)
		return
	if not human_sprites.has(index):
		var sprite := Polygon2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout := ShaderMaterial.new()
		cutout.shader = CUTOUT
		sprite.material = cutout
		add_child(sprite)
		human_sprites[index] = sprite
	var actor: Polygon2D = human_sprites[index]
	var pose := HumanArt.pose(str(enemies[index].species),human_frame(index))
	var points := PackedVector2Array()
	for point in pose.uv: points.append((point-pose.anchor)*pose.scale)
	actor.polygon = points
	actor.uv = pose.uv
	actor.texture = pose.texture
	actor.position = (finish_camera()*(foot+_actor_offset(index))).round()
	actor.scale = finish_camera().get_scale()
	actor.z_index = actor_layer(index)
	actor.modulate = actor_tint(index)
	ActorArtStyle.apply(actor.material, float(pose.scale), cohesive_actor_art)
	actor.show()

func _after_advance_tick(events: Array) -> void:
	# Hold the firing key pose while the actual projectile launch is presented.
	for event in events:
		if str(event.kind)=="projectile_launch" and Slum.human(enemies[int(event.source)]):
			firing_human=int(event.source)
	await super._after_advance_tick(events)
	firing_human=-1

func actor_pick_rect(index: int) -> Rect2:
	if Slum.human(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)
