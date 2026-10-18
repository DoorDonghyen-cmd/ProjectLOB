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
}
const COLORS := {"armor": Color("9abdc7"), "weak_electric": Color("d9c87d"), "barrier": Color("93b8cd"), "burn": Color("e3a074"), "charge": Color("cfb67e"), "jam": Color("bca5b5"), "stance": Color("a9b7b2"), "aim": Color("e2b57b"), "wait": Color("9dadb0")}

static func entries(enemy: Dictionary) -> Array:
	var result: Array = []
	if str(enemy.get("weakness", "")) == "electric": result.append({"icon": "weak_electric", "value": "약점", "text": "전기 약점 · 전기 피해 +2"})
	if int(enemy.get("def", 0)) > 0: result.append({"icon": "armor", "value": str(int(enemy.def)), "text": "장갑 %d · 관통 수치로 무시" % int(enemy.def)})
	if int(enemy.get("barrier", 0)) > 0: result.append({"icon": "barrier", "value": str(int(enemy.barrier)), "text": "보호 %d · 타격을 막는 보호막" % int(enemy.barrier)})
	if int(enemy.get("burn", 0)) > 0: result.append({"icon": "burn", "value": str(int(enemy.burn)), "text": "화상 %d턴" % int(enemy.burn)})
	if int(enemy.get("charge_max", 0)) > 0:
		var remaining := int(enemy.charge_max) - int(enemy.get("charge",0))
		var resonance := str(enemy.get("species","")) == "resonant_eavesback"
		result.append({"icon":"charge","value":"%d턴" % remaining if resonance else "%d/%d" % [int(enemy.get("charge",0)),int(enemy.charge_max)],"text":"공명까지 %d턴 · 다른 적 %dm 추가 접근" % [remaining,int(enemy.get("charge_pull",2))] if resonance else "충전 %d/%d · 완료 시 지원 행동" % [int(enemy.get("charge",0)),int(enemy.charge_max)]})
	if int(enemy.get("jammed", 0)) > 0: result.append({"icon": "jam", "value": str(int(enemy.jammed)), "text": "특수 행동 차단 %d턴" % int(enemy.jammed)})
	if bool(enemy.get("stance", false)): result.append({"icon": "stance", "value": "", "text": "교대 태세 · 장갑 개폐 반복"})
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
