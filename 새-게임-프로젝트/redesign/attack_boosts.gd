extends RefCounted
## Layers keep their own duration and one-reload carry. Legacy buffs are read
## without rewriting their granted amount. Aggregates are only UI conveniences.
static func layers(buff: Dictionary) -> Array:
	if buff.has("layers"): return buff.layers.duplicate(true)
	if buff.has("dmg") and int(buff.dmg) > 0:
		return [{"dmg":int(buff.dmg), "factor":1, "left":int(buff.dmg_left), "carry":bool(buff.get("persistent", false))}]
	return []

static func pack(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var result := {"layers":values, "dmg":0, "dmg_left":0, "factor":1}
	for value in values:
		result.dmg += int(value.dmg)
		result.factor *= int(value.factor)
		result.dmg_left = maxi(result.dmg_left, int(value.left))
		if value.carry: result.persistent = true
	return result

static func grant(buff: Dictionary, amount: int, factor: int, duration: int, carry: bool) -> Dictionary:
	var values := layers(buff)
	values.append({"dmg":amount, "factor":factor, "left":duration, "carry":carry})
	return pack(values)

# New grants replace the same channel. Legacy granted layers keep their values.
static func channel(value: Dictionary) -> String:
	if value.has("channel"): return str(value.channel)
	return "carry" if bool(value.carry) else ("factor" if int(value.factor) > 1 else "flat")

static func prepare(buff: Dictionary, amount: int, factor: int, duration: int, carry: bool, hot: bool = false, heat: int = 0) -> Dictionary:
	var key := "carry" if carry else ("factor" if factor > 1 else "flat")
	var values := layers(buff).filter(func(v): return channel(v) != key)
	values.append({"dmg":amount,"factor":factor,"left":duration,"carry":carry,"channel":key,"hot":hot,"heat":heat})
	return pack(values)

static func resolve(buff: Dictionary, temperature: int, threshold: int) -> Dictionary:
	var result := {"dmg":0,"factor":1,"heat":0,"hot_failed":false}
	for value in layers(buff):
		if bool(value.get("hot",false)) and temperature < threshold:
			result.hot_failed = true
			continue
		result.dmg += int(value.dmg)
		result.factor *= int(value.factor)
		result.heat += int(value.get("heat",0))
	return result

static func consume(buff: Dictionary) -> Dictionary:
	var values := layers(buff)
	for value in values: value.left = int(value.left) - 1
	return pack(values.filter(func(v): return int(v.left) > 0))

static func after_reload(buff: Dictionary) -> Dictionary:
	var values := layers(buff).filter(func(v): return bool(v.carry))
	for value in values: value.carry = false
	return pack(values)

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and float(value) == floorf(value) and value >= low and value <= high

static func valid(buff: Dictionary) -> bool:
	if not buff.has("layers"):
		for key in buff:
			if key == "persistent":
				if not buff[key] is bool or not buff.has("dmg"): return false
			elif key not in ["dmg", "dmg_left"] or not whole(buff[key], 0, 10): return false
		return buff.has("dmg") == buff.has("dmg_left") and (not buff.has("dmg") or whole(buff.dmg_left, 1, 2))
	if not buff.layers is Array or buff.layers.is_empty() or buff.layers.size() > 32: return false
	for value in buff.layers:
		if not value is Dictionary or value.size() not in [4,7]: return false
		if value.size() == 7:
			if value.get("channel", "") not in ["flat","factor","carry"] or not value.get("hot") is bool or not whole(value.get("heat"),0,3): return false
		if not whole(value.get("dmg"), 0, 16) or not whole(value.get("factor"), 1, 3) or not whole(value.get("left"), 1, 2) or not value.get("carry") is bool: return false
		if value.dmg == 0 and value.factor == 1: return false
		if value.has("channel"):
			if value.channel == "factor" and (value.dmg != 0 or value.factor <= 1 or value.hot or value.carry): return false
			if value.channel != "factor" and (value.factor != 1 or value.heat != 0): return false
			if value.channel == "flat" and value.carry: return false
			if value.channel == "carry" and value.hot: return false
	var expected := pack(buff.layers)
	if buff.size() != expected.size(): return false
	for key in expected:
		if not buff.has(key) or buff[key] != expected[key]: return false
	return true
