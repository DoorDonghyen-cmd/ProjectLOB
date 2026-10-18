extends RefCounted
## Authored pixel hardware: structural details stay off the reading surface.
static var keys: Dictionary = {}
const DARK := Color("101b20")
const EDGE := Color("637771")

static func plate(canvas: CanvasItem, rect: Rect2, face: Color, light: Color=EDGE) -> void:
	var r:=Rect2(rect.position.round(),rect.size.floor())
	canvas.draw_rect(Rect2(r.position+Vector2(3,0),r.size-Vector2(6,0)),DARK)
	canvas.draw_rect(Rect2(r.position+Vector2(0,3),r.size-Vector2(0,6)),DARK)
	canvas.draw_rect(Rect2(r.position+Vector2(3,3),r.size-Vector2(6,9)),face)
	canvas.draw_rect(Rect2(r.position+Vector2(6,0),Vector2(r.size.x-12,3)),light)
	canvas.draw_rect(Rect2(r.position+Vector2(3,3),Vector2(3,6)),light)
	canvas.draw_rect(Rect2(r.position+Vector2(0,9),Vector2(3,r.size.y-18)),face.lightened(0.06))
	canvas.draw_rect(Rect2(r.position+Vector2(6,r.size.y-6),Vector2(r.size.x-12,3)),face.darkened(0.25))
	canvas.draw_rect(Rect2(r.position+Vector2(r.size.x-6,6),Vector2(3,r.size.y-12)),face.darkened(0.35))
	canvas.draw_rect(Rect2(r.position+Vector2(r.size.x-22,0),Vector2(10,3)),Color("354b4c"))

static func screw(canvas: CanvasItem, point: Vector2) -> void:
	canvas.draw_rect(Rect2(point,Vector2(6,6)),DARK)
	canvas.draw_rect(Rect2(point,Vector2(4,4)),Color("72817a"))
	canvas.draw_rect(Rect2(point+Vector2(0,2),Vector2(4,2)),Color("394b4b"))

static func vent(canvas: CanvasItem, point: Vector2, count: int=3) -> void:
	for i in range(count):
		canvas.draw_rect(Rect2(point+Vector2(0,i*6),Vector2(12,3)),DARK)
		canvas.draw_rect(Rect2(point+Vector2(0,i*6+3),Vector2(12,1)),Color("52645f"))

static func arrow(canvas: CanvasItem, point: Vector2, ink: Color) -> void:
	for i in range(3):
		canvas.draw_rect(Rect2(point+Vector2(i*2,i*2),Vector2(2,2)),ink)
		canvas.draw_rect(Rect2(point+Vector2(i*2,8-i*2),Vector2(2,2)),ink)

static func key_box(kind: String, state: String) -> StyleBoxTexture:
	var key:=kind+state
	if not keys.has(key):
		var face:=Color("96634b") if kind=="primary" else (Color("30474b") if kind=="reload" else Color("304145"))
		var light:=Color("c9aa7d") if kind=="primary" else Color("82958b")
		if kind=="reload": light=Color("8ba8ab")
		if kind=="danger": face=Color("75463b");light=Color("bd8468")
		if state=="hover": face=face.lightened(0.09);light=light.lightened(0.10)
		if state=="disabled": face=Color("233137");light=Color("465b59")
		var pressed:=state=="pressed"
		if pressed: face=face.darkened(0.18);light=light.darkened(0.25)
		var img:=Image.create(40,32,false,Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		if state=="focus":
			for x in [1,37]:
				for y in [3,23]: img.fill_rect(Rect2i(x,y,2,6),Color("c2d1ba"))
			for x in [3,31]:
				for y in [1,29]: img.fill_rect(Rect2i(x,y,6,2),Color("c2d1ba"))
		else:
			img.fill_rect(Rect2i(6,0,28,32),DARK)
			img.fill_rect(Rect2i(3,3,34,26),DARK)
			img.fill_rect(Rect2i(0,6,40,20),DARK)
			img.fill_rect(Rect2i(6,3,28,24),face)
			img.fill_rect(Rect2i(3,6,34,18),face)
			img.fill_rect(Rect2i(6,3 if not pressed else 5,28,2),light)
			img.fill_rect(Rect2i(3,6,2,16),light.darkened(0.15))
			img.fill_rect(Rect2i(6,24,28,3),face.darkened(0.32))
			img.fill_rect(Rect2i(6,27,28,2),face.darkened(0.55))
			img.fill_rect(Rect2i(35,6,2,18),face.darkened(0.5))
			# A few worn paint chips, kept inside the fixed nine-patch corners.
			img.fill_rect(Rect2i(8,3,3,2),light.darkened(0.4))
			img.fill_rect(Rect2i(29,25,4,2),light.darkened(0.3))
		var box:=StyleBoxTexture.new()
		box.texture=ImageTexture.create_from_image(img)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: box.set_texture_margin(side,12)
		box.content_margin_left=10;box.content_margin_right=10
		box.content_margin_top=4;box.content_margin_bottom=4
		if pressed: box.content_margin_top=6;box.content_margin_bottom=2
		keys[key]=box
	return keys[key].duplicate() as StyleBoxTexture
