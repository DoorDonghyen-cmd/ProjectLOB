extends Control
## A small shared vocabulary for the overhead HUD and its tap-to-read legend.
const GLYPHS := {
	"armor": ["1111111", "1000001", "1011101", "1011101", "0111110", "0011100", "0001000"],
	"weak_electric": ["0001100", "0011000", "0110000", "1111110", "0001100", "0011000", "0110000"],
	"barrier": ["0011100", "0100010", "1001001", "1011101", "1001001", "0100010", "0011100"],
	"burn": ["0001000", "0011000", "0011010", "0111110", "1111111", "1101011", "0111110"],
	"charge": ["0111110", "1100011", "1001001", "1011101", "1001001", "1100011", "0111110"],
	"jam": ["1000001", "0100010", "0010100", "0001000", "0010100", "0100010", "1000001"],
	"stance": ["0010000", "0111110", "1110000", "0000000", "0000111", "0111110", "0000100"],
	"aim": ["0001000", "0011100", "0100010", "1101011", "0100010", "0011100", "0001000"],
	"wait": ["1111111", "0100010", "0010100", "0001000", "0010100", "0100010", "1111111"],
	"leap": ["0011100", "0100010", "1000001", "1000001", "1010000", "1100000", "1110000"],
}
const COLORS := {"armor": Color("9abdc7"), "weak_electric": Color("d9c87d"), "barrier": Color("93b8cd"), "burn": Color("e3a074"), "charge": Color("cfb67e"), "jam": Color("bca5b5"), "stance": Color("a9b7b2"), "aim": Color("e2b57b"), "wait": Color("9dadb0"), "leap": Color("cfb67e")}

static func entries(enemy: Dictionary) -> Array:
	var result: Array = []
	if str(enemy.get("weakness", "")) == "electric": result.append({"icon": "weak_electric", "value": "약점", "text": "전기 약점 · 전기 피해 +2"})
	if int(enemy.get("def", 0)) > 0: result.append({"icon": "armor", "value": str(int(enemy.def)), "text": "장갑 %d · 관통 수치로 무시" % int(enemy.def)})
	if int(enemy.get("barrier", 0)) > 0: result.append({"icon": "barrier", "value": str(int(enemy.barrier)), "text": "보호 %d · 타격을 막는 보호막" % int(enemy.barrier)})
	if int(enemy.get("burn", 0)) > 0: result.append({"icon": "burn", "value": "%d턴" % int(enemy.burn), "text": "화상 %d턴 · 적 행동 직전에 HP 피해 · 보호막 무시" % int(enemy.burn)})
	if preload("res://redesign/garden_hunters.gd").active(enemy):
		var leaping: bool=enemy.get("garden_leaping",false)
		result.append({"icon":"wait" if enemy.recovering and not leaping else "leap","value":"도약" if leaping else "휴식" if enemy.recovering else "%d턴" % int(enemy.leap_left),"text":preload("res://redesign/garden_hunters.gd").intent(enemy)})
	if preload("res://redesign/foundry_workers.gd").winding(enemy):
		var recovering := bool(enemy.get("recovering",false))
		result.append({"icon":"wait" if recovering else "charge","value":"정지" if recovering else "%d턴" % (int(enemy.windup_max)-int(enemy.windup)),"text":preload("res://redesign/foundry_workers.gd").intent(enemy)})
	if int(enemy.get("charge_max", 0)) > 0:
		var remaining := int(enemy.charge_max) - int(enemy.get("charge",0))
		var resonance := str(enemy.get("species","")) == "resonant_eavesback"
		result.append({"icon":"charge","value":"%d턴" % remaining,"text":("%s까지 %d턴 · 다른 적 %dm 추가 접근" % ["공명" if resonance else "독려",remaining,int(enemy.get("charge_pull",2))])})
	if preload("res://redesign/central_guard.gd").leader(enemy):
		result.append({"icon":"charge" if enemy.command_order=="advance" else "barrier","value":"%d턴" % int(enemy.command_left),"text":preload("res://redesign/central_guard.gd").intent(enemy)})
	if int(enemy.get("jammed", 0)) > 0: result.append({"icon": "jam", "value": str(int(enemy.jammed)), "text": "특수 행동 차단 %d턴" % int(enemy.jammed)})
	if bool(enemy.get("stance", false)):
		var guard := str(enemy.get("species","")) == "slum_plate"
		result.append({"icon":"stance", "value":("방어" if enemy.get("stance_closed",true) else "개방") if guard else "", "text":"교대 태세 · 장갑 개폐 반복"})
	if str(enemy.kind) == "spitter":
		if preload("res://redesign/ranged.gd").is_gatekeeper(enemy):
			var phase := str(enemy.ranged_phase)
			var gate_icon := "stance" if phase == "guard" else "aim" if phase == "prepare" else "wait"
			result.append({"icon":gate_icon,"value":"%d턴" % int(enemy.ranged_left) if phase != "waiting" else "개방","text":preload("res://redesign/ranged.gd").intent(enemy)})
			return result
		var preparing := str(enemy.get("ranged_phase", "prepare")) == "prepare"
		var value := "%d턴" % int(enemy.get("ranged_left", 2)) if preparing or str(enemy.get("ranged_phase", "")) == "recover" else ""
		result.append({"icon": "aim" if preparing else "wait", "value": value, "text": preload("res://redesign/ranged.gd").intent(enemy)})
	return result

static func draw_icon(canvas: CanvasItem, position: Vector2, id: String, pixel: int = 2, shadow: bool = false) -> void:
	var rows: Array = GLYPHS.get(id, GLYPHS.armor)
	if shadow:
		for y in range(rows.size()):
			for x in range(7):
				if rows[y][x] == "1": canvas.draw_rect(Rect2(position.round() + Vector2(x, y) * pixel + Vector2(1, 2), Vector2.ONE * pixel), Color("102028"))
	for y in range(rows.size()):
		for x in range(7):
			if rows[y][x] == "1": canvas.draw_rect(Rect2(position.round() + Vector2(x, y) * pixel, Vector2.ONE * pixel), COLORS.get(id, Color.WHITE))

var icon_id := "armor"
func _draw() -> void:
	draw_icon(self, (size - Vector2(14, 14)) * 0.5, icon_id)
