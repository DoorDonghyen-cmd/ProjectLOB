extends RefCounted
## Baked pixelfx atlas: one cached texture, no runtime particles or RNG.
const SHEET=preload("res://assets/art/impact_parts_20261106/multiplier.png")
const CELL:=Vector2(216,136)
const FRAMES:=23
const COLUMNS:=4
# pixelfx pivot (84,106) is floor; this hit is authored 26px above it.
const CONTACT:=Vector2(84,80)

static func frame(progress: float) -> Rect2:
	var index:=mini(FRAMES-1,int(clampf(progress,0,1)*FRAMES))
	return Rect2(Vector2(index%COLUMNS,index/COLUMNS)*CELL,CELL)

static func draw(canvas: CanvasItem, point: Vector2, progress: float, style: Dictionary) -> void:
	if progress>=1.0 or not style.get("active",false):return
	var rank:=clampi(int(style.get("rank",1)),1,3)
	var factor:=0.82+0.12*(rank-1)
	var destination:=Rect2((point-CONTACT*factor).round(),(CELL*factor).round())
	canvas.draw_texture_rect_region(SHEET,destination,frame(progress),style.color)
	# A product stays recognisable around wide damage numbers. Higher tiers
	# get a second pair, while the simulation and impact duration stay fixed.
	if rank>=2:
		var color:=Color(style.color,(1.0-progress)*0.8)
		var radius:=28+rank*6+floorf(progress*24)
		for layer in range(2 if rank==3 else 1):
			for side in [-1,1]:
				var r:=radius+layer*8
				canvas.draw_polyline(PackedVector2Array([(point+Vector2(side*r,-10)).snapped(Vector2(2,2)),(point+Vector2(side*(r+6),0)).snapped(Vector2(2,2)),(point+Vector2(side*r,10)).snapped(Vector2(2,2))]),color,2,false)
