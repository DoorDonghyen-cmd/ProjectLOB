@tool
extends Control
## Empty space has a state; it is not another button or a stretched card.
const FONT = preload("res://redesign/combat_pixel_font.tres")
const Hardware = preload("res://redesign/instrument_skin.gd")
@export_enum("locked", "empty", "used", "compressed") var slot_state := "locked"

func _ready() -> void:
	custom_minimum_size=Vector2(108,132)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_PASS
	tooltip_text={"locked":"미확장 가방 칸 · 현재 복장과 가방 용량에 포함되지 않습니다.","empty":"빈 가방 칸 · 현재 패에 탄환이 없습니다.","used":"이 패에서 사용한 탄환의 자리 · 재장전하면 새 패를 뽑습니다.","compressed":"두 탄환이 압축된 자리 · 탄창의 압축탄을 회수하면 원래 탄으로 돌아옵니다."}[slot_state]
	queue_redraw()

func _draw() -> void:
	var locked:=slot_state=="locked"
	var edge:=Color("2f3b3e") if locked else Color("475858")
	Hardware.plate(self,Rect2(0,0,size.x,size.y-2),Color("142328") if locked else Color("1c2e32"),edge)
	draw_rect(Rect2(8,9,size.x-16,size.y-24),Color("111e23") if locked else Color("14242a"))
	# Empty positions are recessed and quiet, rather than raised clickable cards.
	draw_rect(Rect2(8,9,size.x-16,3),Color("0e1b20"))
	var p: Vector2=(size*Vector2(0.5,0.44)).round()
	if locked:
		draw_rect(Rect2(p+Vector2(-7,-3),Vector2(14,12)),edge)
		draw_rect(Rect2(p+Vector2(-4,-10),Vector2(8,9)),edge,false,2)
	else: draw_line(p-Vector2(8,0),p+Vector2(8,0),edge,2)
	var caption: String={"locked":"미확장","empty":"빈 칸","used":"사용함","compressed":"압축됨"}[slot_state]
	draw_string(FONT,Vector2(4,size.y-19),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-8,16,Color("667675") if locked else Color("91a39c"))
