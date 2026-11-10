@tool
extends Control

const GLASS := Color("101510")
const AMBER := Color("c0a36c")

var record_active := false:
	set(value):
		record_active = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var width := floorf(size.x)
	var height := floorf(size.y)
	if width < 460 or height < 250:
		return
	_draw_plate(Rect2(7, 9, width, height), 11, Color("0a0a08"))
	_draw_plate(Rect2(0, 0, width, height), 11, Color("6b6250"))
	_draw_plate(Rect2(3, 3, width - 6, height - 9), 9, Color("8b8068"))
	draw_rect(Rect2(13, 4, width - 26, 3), Color("aaa088"))
	draw_rect(Rect2(5, 13, 3, height - 29), Color("a0967c"))
	draw_rect(Rect2(width - 7, 13, 3, height - 29), Color("605745"))
	draw_rect(Rect2(13, height - 9, width - 26, 4), Color("52493a"))

	# A recessed black mask and a stepped rim give the glass its depth.
	_draw_plate(Rect2(13, 8, width - 26, height - 76), 8, Color("3e382c"))
	_draw_plate(Rect2(17, 10, width - 34, height - 81), 8, Color("242219"))
	_draw_plate(Rect2(23, 14, width - 46, height - 86), 6, GLASS)
	draw_rect(Rect2(25, height - 73, width - 50, 2), Color("81755d"))

	var rail_y := height - 68
	_draw_plate(Rect2(13, rail_y, width - 26, 57), 6, Color("4c4537"))
	_draw_plate(Rect2(16, rail_y + 2, width - 32, 52), 4, Color("625947"))
	draw_rect(Rect2(25, rail_y + 2, width - 50, 2), Color("7d7158"))
	draw_rect(Rect2(27, rail_y + 5, 238, 47), Color("383229"))
	_draw_tape_slot(Vector2(280, rail_y + 14))
	_draw_vents(Vector2(width - 153, rail_y + 17))

	for screw in [Vector2(18, rail_y + 24), Vector2(width - 30, rail_y + 24)]:
		draw_rect(Rect2(screw, Vector2(6, 6)), Color("3e372c"))
		draw_rect(Rect2(screw + Vector2(1, 2), Vector2(4, 1)), Color("91836a"))

func _draw_plate(rect: Rect2, cut: float, color: Color) -> void:
	var lo := rect.position
	var hi := rect.end
	draw_colored_polygon(PackedVector2Array([
		Vector2(lo.x + cut, lo.y), Vector2(hi.x - cut, lo.y),
		Vector2(hi.x, lo.y + cut), Vector2(hi.x, hi.y - cut),
		Vector2(hi.x - cut, hi.y), Vector2(lo.x + cut, hi.y),
		Vector2(lo.x, hi.y - cut), Vector2(lo.x, lo.y + cut),
	]), color)

func _draw_tape_slot(origin: Vector2) -> void:
	var x := origin.x
	var y := origin.y
	_draw_plate(Rect2(x, y, 170, 28), 3, Color("302a21"))
	draw_rect(Rect2(x + 4, y + 4, 162, 19), Color("1c1a14"))
	draw_rect(Rect2(x + 8, y + 6, 154, 2), Color("3f3527"))
	draw_rect(Rect2(x + 10, y + 17, 150, 5), Color("4f4431"))
	# Only the cartridge edge and its paper tab are visible in the drive.
	draw_rect(Rect2(x + 41, y + 9, 88, 9), Color("514735"))
	draw_rect(Rect2(x + 54, y + 10, 58, 4), Color("9f855d") if record_active else Color("72654d"))
	draw_rect(Rect2(x + 54, y + 10, 8, 4), Color("97613c"))
	draw_rect(Rect2(x + 2, y + 25, 166, 2), Color("8c7c60"))
	draw_rect(Rect2(x + 179, y + 7, 22, 15), Color("322b22"))
	draw_rect(Rect2(x + 183, y + 11, 14, 6), AMBER if record_active else Color("64513a"))
	if record_active:
		draw_rect(Rect2(x + 184, y + 11, 12, 2), Color("ffd394"))

func _draw_vents(origin: Vector2) -> void:
	for index in range(7):
		var x := origin.x + index * 13
		draw_rect(Rect2(x, origin.y, 8, 23), Color("393226"))
		draw_rect(Rect2(x + 7, origin.y + 1, 2, 21), Color("796c53"))
