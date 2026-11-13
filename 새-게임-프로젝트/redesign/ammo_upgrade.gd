extends RefCounted
## Permanent workshop growth: one exact pair becomes one improved round.
## Old tuned IDs remain content/save data; no 1-to-1 workshop operation is offered.
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")

static func profile_mark(id: String) -> String:
	var spec: Dictionary = Ammo.AMMO[id]
	if not spec.get("profile",false): return ""
	return "위력 %d" % int(spec.power) + {"power":" · 화력","cool":" · 방열"}.get(str(spec.get("tune","")),"")

static func identity(id: String) -> String:
	var result: String = Ammo.AMMO[id].name
	if Ammo.grade(id) == 1: result += " · 고급"
	var profile := profile_mark(id)
	if not profile.is_empty(): result += " · " + profile
	return result

static func copy(owner):
	var sandbox = Campaign.new()
	sandbox.s = owner.s.duplicate(true)
	sandbox.model.s = owner.model.s.duplicate(true)
	sandbox.profile = owner.profile.duplicate(true)
	return sandbox

static func execute(owner, source: String) -> bool:
	if not owner.model.s.deck.has(source): return false
	return owner.resolve("compress", source)

static func inspect(owner, source: String) -> Dictionary:
	var result := {"valid":false, "source":source, "target":"", "required":2, "reason":"탄환을 선택하세요."}
	if not Ammo.AMMO.has(source) or not owner.model.s.deck.has(source): return result
	result.target = Ammo.compressed_id(source)
	if owner.s.resolved: result.reason = "이번 정비를 마쳤습니다."
	elif result.target.is_empty(): result.reason = "이미 강화했거나 강화할 수 없는 탄환입니다."
	elif owner.model.s.deck.count(source) < 2: result.reason = "같은 성능의 탄환 2발이 필요합니다."
	elif owner.model.s.deck.size() <= owner.minimum_deck(): result.reason = "최소 보유 %d발을 유지해야 합니다." % owner.minimum_deck()
	else: result.reason = "공방에서 강화할 수 있습니다."
	var sandbox = copy(owner)
	result.valid = execute(sandbox, source)
	if result.valid:
		result.after = sandbox.model.s.duplicate(true)
		result.reason = ""
	return result

static func comparison(source: String, target: String, state: Dictionary, count: int, after: int) -> Array:
	var a: Dictionary = Ammo.primary_stat(source,state)
	var b: Dictionary = Ammo.primary_stat(target,state)
	var label := "발당 " + str(a.label)
	var left := str(a.value)
	var right := str(b.value) if a.label == b.label else str(b.label) + " " + str(b.value)
	# Launch pass (2026-11-12): the left column is always "the two rounds together", the right
	# column the one round they become. Plain row names (피해 / 열 / 탄창 칸 / 덱).
	if a.label == "피해" and b.label == "피해":
		label = "피해 · 2발 합"
		left = str(2 * Ammo.damage(source,state) * Ammo.hit_count(source,state))
		right = str(Ammo.damage(target,state) * Ammo.hit_count(target,state))
	elif Ammo.AMMO[source].effect == "burn":
		label = "화상 · 발당"
		left = "%d턴" % Ammo.burn_amount(source,state)
		right = "%d턴" % Ammo.burn_amount(target,state)
	var heat_before := Ammo.heat_label(source,state) + " ×2" if str(Ammo.AMMO[source].effect) == "vent" else "%+d" % (2 * Ammo.heat_delta(source,state))
	return [[label,left,right], ["열 · 2발 합",heat_before,Ammo.heat_label(target,state)], ["탄창 칸","%d칸" % (2*Ammo.slot_cost(source)),"%d칸" % Ammo.slot_cost(target)], ["보유 탄약","%d발" % count,"%d발" % after if after >= 0 else "—"]]
