extends RefCounted
## Player-facing clues are separate from deterministic, undisclosed outcomes.
const SCENES := {
	"siphon": {"title":"문 너머의 발소리", "text":"닫힌 배급문 안쪽에서 금속이 바닥을 긁는다.
문틈에는 아직 따뜻한 찻잔과 빈 탄피가 놓여 있다.", "choices":[
		{"id":"open", "label":"문을 열어 살핀다", "hint":"긁는 소리가 문 바로 뒤에서 멎었다.", "cost":0},
		{"id":"knock", "label":"문을 두드려 신호한다", "hint":"문에 적힌 글씨: 사람이면 두 번, 기다릴 것.", "cost":0}]},
	"archive": {"title":"봉인된 유실물", "text":"배급 대상에서 지워진 주소의 물자함이다.
비상 전원은 살아 있지만, 경비 회로의 표시등도 깜박인다.", "choices":[
		{"id":"unlock", "label":"봉인을 푼다", "hint":"꺼진 함에 전력을 흘립니다.", "cost":8},
		{"id":"record", "label":"쪽지를 읽는다", "hint":"누군가 돌아올 사람의 이름을 적어 두었다.", "cost":0}]},
	"salvage": {"title":"멈춘 보급 수레", "text":"수레 아래 끼인 쇳조각 너머로 탄약함이 보인다.
통로의 순찰등은 꺼졌지만, 먼 곳에서 태엽 소리가 다가온다.", "choices":[
		{"id":"pull", "label":"수레를 끌어낸다", "hint":"바퀴가 움직일 때마다 금속성 소음이 난다.", "cost":0},
		{"id":"power", "label":"보조 모터를 가동한다", "hint":"소음 없이 수레를 움직입니다.", "cost":6}]}
}

static func scene(kind: String) -> Dictionary:
	return SCENES.get(kind, SCENES.siphon)

static func choice(kind: String, id: String) -> Dictionary:
	for option in scene(kind).choices:
		if option.id == id: return option
	return {}

static func outcome(kind: String, id: String, seed_value: int, node_id: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + node_id * 104729 + 773
	var roll := random.randf()
	match kind + ":" + id:
		"siphon:open":
			if roll < 0.5: return {"type":"combat", "bonus":18, "text":"문이 열리자 경비 인형이 몸을 일으킨다. 뒤편에 주민들의 비상 자금함이 보인다."}
			return {"type":"credits", "amount":16, "text":"소리의 주인은 의족을 수리하던 주민이었다. 길을 터 준 대가로 비상 자금을 나눠 준다. · +16Cr"}
		"siphon:knock": return {"type":"credits", "amount":6, "text":"한참 뒤, 배급문 아래로 동전과 쪽지가 밀려 나온다. “위쪽 문은 열지 마.” · +6Cr"}
		"archive:unlock":
			if roll < 0.4: return {"type":"combat", "bonus":22, "text":"봉인이 풀리자 경비 회로가 깨어났다. 잠금장치 뒤의 비상 자금은 아직 남아 있다."}
			return {"type":"ammo", "amount":10, "text":"물자함은 무사했다. 탄환과 운송비가 남아 있다. 쪽지의 주인은 끝내 돌아오지 않았다. · +10Cr"}
		"archive:record": return {"type":"lore", "text":"“이번 배급에는 이름이 있을 거야.” 마지막 줄만 여러 번 고쳐 썼다. 쪽지를 기록에 남겼다."}
		"salvage:pull":
			if roll < 0.5: return {"type":"combat", "bonus":18, "text":"바퀴가 긁히는 소리에 순찰 기계가 방향을 바꿨다. 수레의 주인이 뒤편에서 보수를 약속한다."}
			return {"type":"ammo", "amount":0, "text":"수레를 끌어내자 주인이 어둠 속에서 나왔다. 고맙다며 탄약함을 열어 준다."}
		"salvage:power": return {"type":"ammo", "amount":0, "text":"모터가 조용히 수레를 밀어냈다. 기다리던 주인이 탄약함을 열어 준다."}
	return {}
