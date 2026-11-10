extends "res://redesign/weapon_actor.gd"
## Art comparison only. Use long-body poses; the campaign still owns a Rivet.
## No production catalogue or save ID is replaced by this preview actor.
const SOURCE := "res://assets/art/rivet_twohand_20261106/rivet_carbine_v1.png"
const PILOT := "res://assets/art/style_pilot_20261106/"
const PROFILE := {"grip":Vector2(640,445), "support":Vector2(1550,430), "muzzle":Vector2(2080,285), "part":Rect2(865,150,350,270), "release":Vector2(0,145), "heat":Rect2(1335,175,750,180)}
static var textures: Dictionary = {}
var style_mode := "raw"

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

func _init() -> void:
	gun_id="burst"

func configure(_gun: String, action: String, recoil: float = 0.0, reload_phase: float = -1.0, heat: float = 0.0) -> bool:
	# Only visual body-family selection is borrowed from the long-gun actor.
	return super.configure("burst",action,recoil,reload_phase,heat)

func set_style(value: String) -> void:
	if style_mode == value: return
	style_mode=value
	_refresh_weapon_layer();queue_redraw()

func weapon_texture() -> Texture2D:
	return texture(PILOT+"rivet_"+("quiet" if style_mode=="curated" else style_mode)+".png") if style_mode!="raw" else texture(SOURCE)

func body_texture() -> Texture2D:
	if outfit_id=="work" and style_mode in ["quiet","coarse"]:
		return texture(PILOT+("hero_idle_" if pose_id=="idle" else "hero_")+style_mode+".png")
	return super.body_texture()

func registered_transform() -> Transform2D:
	var frame:=frame_for(outfit_id,"burst",pose_id)
	var factor: float=(POSES.long.aim.support-POSES.long.aim.grip).length()/(PROFILE.support-PROFILE.grip).length()
	var angle:=deg_to_rad(float(frame.get("angle",0)))
	if frame.has("support"): angle=(frame.support-frame.grip).angle()-(PROFILE.support-PROFILE.grip).angle()
	angle+=deg_to_rad(-7.0*recoil_amount)
	var result:=Transform2D(angle,Vector2.ONE*factor,0,FOOT+(frame.grip-frame.foot)*frame.scale)
	result.origin-=result.basis_xform(PROFILE.grip)
	return result

func registered_muzzle(foot: Vector2, scale_value: float) -> Vector2:
	return (foot+(registered_transform()*PROFILE.muzzle-FOOT)*BODY_SCALE*scale_value).round()

func draw_weapon_layers(painter: CanvasItem, pixel_step: float = 1.0) -> void:
	var profile:=PROFILE.duplicate();profile.image=weapon_texture()
	var raster:=Transform2D(0,Vector2.ONE/pixel_step,0,Vector2.ZERO)
	painter.draw_set_transform_matrix(raster*registered_transform())
	if pose_id in ["reload_open","reload_seat","cooling"]:
		_draw_open_weapon(painter,profile,reload_amount,raster)
	else: _draw_weapon_region(painter,profile.image,Rect2(Vector2.ZERO,profile.image.get_size()))
	painter.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_weapon_region(painter: CanvasItem, image: Texture2D, region: Rect2, offset: Vector2 = Vector2.ZERO) -> void:
	painter.draw_texture_rect_region(image,Rect2(region.position+offset,region.size),region)
	if heat_amount<=0: return
	var metal:=region.intersection(PROFILE.heat)
	if metal.has_area(): painter.draw_texture_rect_region(image,Rect2(metal.position+offset,metal.size),metal,Color(1.8,0.8,0.5,heat_amount*0.65))
