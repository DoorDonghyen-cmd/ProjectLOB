extends RefCounted
## Pure receipt-to-visual mapping. One muzzle pulse and one carrier per result;
## hit stacks and broad gas flashes never manufacture additional projectiles.
const Style=preload("res://redesign/impact_style.gd")
const Content=preload("res://redesign/content.gd")
const Projectile=preload("res://redesign/projectile_visual.gd")
const Enhanced=preload("res://redesign/enhanced_shot_fx.gd")
const ATLAS=preload("res://assets/art/firing_fx_20261106/muzzle.png")
const GUNS:=["single","burst","scatter","heavy","amplifier"]
const LENGTHS:=[26.0,36.0,22.0,32.0,52.0]
const WIDTHS:=[2.0,2.0,4.0,4.0,2.0]
const CELL:=Vector2(96,64)
const PIVOT:=Vector2(20,32)

static func profile(gun: String, result: Dictionary, innate_part: String = "") -> Dictionary:
	var index:=maxi(0,GUNS.find("burst" if gun=="rewinder" else "single" if gun=="deadbolt" else gun))
	var attack:=Content.is_attack(str(result.get("id","basic")))
	var style:=Style.resolve(result,"shot",attack)
	if not attack:style={"color":Color("a7bbc4"),"rank":0,"family":"muted","active":false}
	var tier := Enhanced.tier(result, style, attack)
	var part_powered: bool = tier != Enhanced.Tier.STANDARD and damage_part_used(result, style.sources, innate_part)
	return {"index":index,"gun":GUNS[index],"color":style.color,"rank":int(style.rank),"family":style.family,"attack":attack,"length":LENGTHS[index],"width":WIDTHS[index],"overdrive":attack and gun=="heavy" and bool(result.get("overdrive",false)),"projectile":Projectile.spec(Content.source_id(str(result.get("id","basic"))),attack),"tier":tier,"part_powered":part_powered}

static func damage_part_used(result: Dictionary, sources: Array, innate_part: String) -> bool:
	if not sources.any(func(id): return id != innate_part): return false
	var math: Dictionary = result.get("math", {})
	var engine := str(result.get("engine_id", ""))
	return (
		int(math.get("part_bonus", 0)) > 0
		or int(math.get("tag_add", 0)) > 0
		or int(math.get("tag_percent", 100)) > 100
		or int(result.get("part_factor", math.get("part_factor", 1))) > 1
		or (engine != innate_part and sources.has(engine))
		or sources.has("duplex")
		or sources.has("resonator")
	)

static func geometry(origin: Vector2, target: Vector2, progress: float, data: Dictionary, reduced: bool=false) -> Dictionary:
	return Projectile.geometry(origin,target,progress,data,reduced)

static func flash_frame(progress: float) -> int:
	return clampi(floori(clampf(progress,0,1)/0.42*6.0),0,5)

static func draw_flash(canvas: CanvasItem, muzzle: Vector2, angle: float, progress: float, data: Dictionary, reduced: bool, camera: Transform2D) -> void:
	if data.is_empty() or progress>=0.42:return
	var color:Color=data.color
	canvas.draw_set_transform_matrix(camera*Transform2D(angle,muzzle.round()))
	if reduced or not data.attack:
		if progress<0.2:canvas.draw_rect(Rect2(0,-1,8 if data.attack else 4,2),Color(color,0.7))
	else:
		var frame:=int(data.index)*6+flash_frame(progress)
		var region:=Rect2(Vector2(frame%5,frame/5)*CELL,CELL)
		var scale_value:=1.0+int(data.rank)*0.10
		canvas.draw_texture_rect_region(ATLAS,Rect2(-PIVOT*scale_value,CELL*scale_value),region,color)
		if data.get("part_powered", false):
			Enhanced.draw_muzzle(canvas, progress, data.tier, color)
		if data.overdrive and progress<0.14:
			# Extra gas at the collar, not another bullet or a second pulse.
			for side in [-1,1]:canvas.draw_rect(Rect2(0,side*6-2,7,4),Color(color,0.7))
	canvas.draw_set_transform_matrix(camera)

static func draw_projectile(canvas: CanvasItem, origin: Vector2, target: Vector2, progress: float, data: Dictionary, reduced: bool, camera: Transform2D=Transform2D.IDENTITY) -> void:
	if data.is_empty():return
	var path:=geometry(origin,target,progress,data,reduced)
	Projectile.draw(canvas,path,data,reduced,camera)
