extends Control
## Always-visible temperature; the outlined projection is the peak BEFORE reload.
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const Hardware = preload("res://redesign/instrument_skin.gd")
const READING_LEFT := 52.0
var current := 0
var threshold := 0
var limit := 12
var prediction: Dictionary = {}
var reduced_motion := false
var previous_value := 0
var response := 0.0
var reload_temperature := 0
var reload_preview := false
var cooling_receipt := ""

func preview_reload(enabled: bool) -> void:
	reload_preview = enabled
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(360, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func sync(state: Dictionary, forecast: Dictionary) -> void:
	current = int(state.get("heat", 0))
	previous_value = current
	response = 0.0
	limit = Content.heat_limit(state)
	threshold = Content.hot_threshold(state) if Content.has_part(state, "ember_core") or state.get("deck", []).has("thermal") else 0
	tooltip_text = "장전 중 화살표: 현재 열 → 사격 중 예상 최고 열 (냉각 후 수치 아님)\n열 한계 %d · 도달하면 남은 사격 중단과 강제 재장전\n일반 재장전: 열 −%d · 잔열 유지 / 강제 재장전: 열 0" % [limit, Content.reload_cooling(state)]
	if threshold > 0: tooltip_text += "\n고열 효과 조건: 발사 직전 열 %d 이상" % threshold
	mouse_filter = Control.MOUSE_FILTER_PASS
	prediction = forecast.get("heat", {}).duplicate(true)
	cooling_receipt = ""
	var history: Array = state.get("history", [])
	if not history.is_empty():
		var last: Dictionary = history.back()
		var detail: Dictionary = last.get("detail", {})
		if last.get("action", "") == "fire" and not detail.get("forced_reload", {}).is_empty():
			cooling_receipt = "과열 %d → %d · 강제 냉각" % [int(detail.get("heat_peak", 0)), current]
	queue_redraw()

func show_value(value: int) -> void:
	reload_preview = false
	cooling_receipt = ""
	if value != current:
		previous_value = current
		response = 0.0 if reduced_motion else 1.0
		set_process(response > 0)
	current = value
	prediction = {}
	queue_redraw()

func _process(delta: float) -> void:
	response = maxf(0.0, response - delta / 0.36)
	queue_redraw()
	if response <= 0: set_process(false)

func reading_text() -> String:
	if not reload_preview and int(prediction.get("fired_max", 0)) > 0:
		var high := int(prediction.get("peak_max", current))
		var low := int(prediction.get("peak_min", high))
		var expected := str(high) if low == high else "%d~%d" % [low, high]
		return "발열 %d → 예상 %s / %d" % [current, expected, limit]
	return "발열 %d / %d" % [current, limit]

func reading_font_size() -> int:
	var font_size := 30
	while font_size > 20 and FONT.get_string_size(reading_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - READING_LEFT - 30:
		font_size -= 1
	return font_size

func bar_rect() -> Rect2:
	return Rect2(READING_LEFT,42,maxf(66,size.x-READING_LEFT-30),18)

func cell_rect(index: int) -> Rect2:
	var bar:=bar_rect()
	var step:=bar.size.x/maxi(1,limit)
	return Rect2(bar.position+Vector2(floorf(index*step)+2,2),Vector2(maxf(2,floorf(step)-4),14))

func _draw() -> void:
	var peak := current if reload_preview else int(prediction.get("peak_max", current))
	var hot := (not reload_preview and float(prediction.get("overheat_probability", 0)) > 0) or current >= limit
	var ink := Color("e9a27d") if hot else Color("d4d9c8")
	var cooling := reload_preview or (response>0 and previous_value>current)
	var accent := Color("94b9bf") if cooling else (Color("cf8661") if hot else Color("bca47a"))
	Hardware.plate(self,Rect2(0,0,size.x,68),Color("2b3b3e"),Color("6f8076"))
	# The thermometer sits in a bolted instrument end-cap, outside the reading.
	draw_rect(Rect2(8,7,33,52),Color("1a2b30"))
	draw_rect(Rect2(39,7,2,52),Color("586b66"))
	Hardware.screw(self,Vector2(9,9))
	AmmoVisual.heat_icon(self,Vector2(24,25),1.5,accent)
	Hardware.vent(self,Vector2(18,46),2)
	Hardware.vent(self,Vector2(size.x-21,10),3)
	var title := reading_text()
	var title_size := reading_font_size()
	draw_string(FONT,Vector2(READING_LEFT,30),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-READING_LEFT-30,title_size,ink)
	# Recessed glass channel, separate from the raised outer casing.
	var bar:=bar_rect()
	draw_rect(bar.grow(3),Color("101b20"))
	draw_rect(Rect2(bar.position+Vector2(-3,bar.size.y+2),Vector2(bar.size.x+6,2)),Color("64756c"))
	for i in range(limit):
		var cell:=cell_rect(i)
		draw_rect(cell,Color("203136"))
		draw_rect(Rect2(cell.position,Vector2(cell.size.x,2)),Color("17262c"))
		if i < current:
			var color:=Color("bd7856") if i>=limit*0.75 else Color("9a9e78")
			draw_rect(cell,color)
			draw_rect(Rect2(cell.position,Vector2(cell.size.x,3)),Color("d4b181") if i>=limit*0.75 else Color("c0c09a"))
			draw_rect(Rect2(cell.position+Vector2(0,11),Vector2(cell.size.x,3)),color.darkened(0.32))
		elif i < peak:
			# Outline + broken central trace = forecast, never solid actual heat.
			draw_rect(cell,accent.darkened(0.32),false,1)
			draw_rect(Rect2(cell.position+Vector2(2,6),Vector2(maxf(2,cell.size.x-4),2)),accent.darkened(0.35))
		if response>0 and i<previous_value and i>=current:
			draw_rect(cell,Color(0.48,0.77,0.85,response*0.75))
		elif response>0 and i<current and i>=previous_value:
			draw_rect(cell,Color(1.0,0.82,0.55,response*0.6))
		if reload_preview and i>=reload_temperature and i<current:
			draw_rect(cell,Color("203b47"))
			draw_rect(cell.grow(-1),Color("9abdc8"),false,2)
			draw_rect(Rect2(cell.position+Vector2(3,6),Vector2(maxf(2,cell.size.x-6),2)),Color("9abdc8"))
		# Engraved tick marks use the same spacing as actual heat units.
		draw_rect(Rect2(cell.position.x,63,2,3 if i%2==0 else 2),Color("7a887a"))
	if threshold>0:
		var x:=bar.position.x+floorf(bar.size.x*float(threshold)/limit)
		draw_rect(Rect2(x-3,36,8,3),Color("d4b781"))
		draw_rect(Rect2(x,39,2,23),Color("d4b781"))
	# Hard limit end-stop and a segmented warning lamp, with no idle flashing.
	draw_rect(Rect2(bar.end.x+3,37,4,27),Color("c27e5c") if hot else Color("756b59"))
	for i in range(3):
		draw_rect(Rect2(bar.end.x+11,40+i*8,8,4),accent if hot or cooling else Color("536664"))
	var note: String="과열" if current>=limit else cooling_receipt
	if reload_preview:
		note="재장전 후 %d · −%d" % [reload_temperature,maxi(0,current-reload_temperature)]
		ink=Color("9abdc8")
	elif not prediction.is_empty() and int(prediction.get("fired_max",0))>0:
		note="과열 예상" if hot else ""
	elif response>0 and previous_value>current:
		note="냉각 −%d" % (previous_value-current)
		ink=Color("98c5cf")
	var title_width:=READING_LEFT+FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	var note_width:=maxf(0,size.x-title_width-46)
	var note_size:=21
	while note_size>16 and FONT.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,note_size).x>note_width: note_size-=1
	if FONT.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,note_size).x<=note_width:
		draw_string(FONT,Vector2(title_width+12,28),note,HORIZONTAL_ALIGNMENT_RIGHT,note_width,note_size,ink)
