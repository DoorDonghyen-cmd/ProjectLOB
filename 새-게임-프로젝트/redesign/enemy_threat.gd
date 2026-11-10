extends RefCounted
## Conditional intent: one enemy action with no intervening player attack.
## Use the resolver so burn, commands, interruption and recovery keep their order.
const Model = preload("res://redesign/model.gd")
const Ranged = preload("res://redesign/ranged.gd")
const COLORS := {"quiet": Color("b3c1b8"), "action": Color("edc47a"), "danger": Color("f29780")}

static func analyze(state: Dictionary) -> Dictionary:
	if state.is_empty() or not state.get("phase", "") in ["plan", "ready"]: return {}
	var copy = Model.new()
	# Enemy advancement never reads receipts; exclude the entire run before copying.
	var detached := state.duplicate(false)
	detached.history = []
	copy.s = detached.duplicate(true)
	var events: Array = copy._advance(1)
	var result: Dictionary = {}
	for i in range(state.enemies.size()):
		var enemy: Dictionary = state.enemies[i]
		if int(enemy.hp) <= 0: continue
		var after: Dictionary = copy.s.enemies[i]
		var movement := int(enemy.distance) - int(after.distance)
		var text := "접근" if movement > 0 else "대기"
		var tone := "quiet"
		for event in events:
			if str(event.kind) == "projectile_launch" and int(event.source) == i:
				text = "발사"; tone = "action"
			if int(event.get("target", -1)) != i: continue
			match str(event.kind):
				"charge":
					if event.released: text = "독려"; tone = "action"
				"central_command":
					if event.released: text = "전진 지시" if event.order == "advance" else "차폐"; tone = "action"
				"foundry_state", "garden_state":
					if movement > int(enemy.speed): text = "돌진"; tone = "action"
		if int(after.hp) <= 0:
			text = "화상 처치"; tone = "quiet"
		elif int(after.distance) <= 0:
			text = "접촉!"; tone = "danger"
		elif int(enemy.get("slow_left",0))>0:
			text="감속·차단" if int(enemy.get("jammed",0))>0 else "감속 접근"
		elif int(enemy.get("jammed", 0)) > 0:
			text = "접근·차단" if movement > 0 else "차단 중"
		elif text == "대기" and str(enemy.kind) == "spitter":
			text = "조준" if enemy.get("ranged_phase", "") == "prepare" else "탄 비행" if enemy.get("ranged_phase", "") == "waiting" else "회복"
		result[i] = {"text": "다음 " + text, "tone": tone, "step": movement,
			"detail": "다음 적 행동: %s · 실제 접근 %dm\n공격·밀기·차단 전 기준입니다. 재장전은 여러 적 행동을 진행할 수 있습니다." % [text, movement]}
	return result
