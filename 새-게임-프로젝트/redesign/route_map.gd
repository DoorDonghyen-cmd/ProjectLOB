extends RefCounted
## Version 2: deterministic, non-crossing branching graphs. Version 1 lives in campaign_content.
const VERSION := 3
const LENGTHS := [8, 9, 9, 9, 10]

static func generate(region: int, seed_value: int, version: int = VERSION) -> Array:
	var rooms := generate_v2(region, seed_value)
	if version == 2: return rooms
	for room in rooms:
		room.map_version = VERSION
		room.shortcuts = []
		if room.kind == "bypass":
			room.kind = "event"
			room.event = ["siphon", "archive", "salvage"][posmod(seed_value + int(room.id), 3)]
		if room.get("workshop", false): room.name = "정비 공방"
		elif room.kind == "supply": room.name = "탄약고"
		elif room.kind == "event": room.name = "조우"
	# One optional route per region: skip exactly one ordinary fight on an
	# already connected route. Never skip the opening core or a gate/facility.
	var candidates: Array = []
	for origin in rooms:
		if origin.kind != "combat" or int(origin.floor) < 2: continue
		for middle in rooms:
			if not origin.next.has(middle.id) or middle.kind != "combat" or middle.elite: continue
			for destination in rooms:
				if middle.next.has(destination.id) and destination.kind != "boss":
					candidates.append([origin, destination])
	if not candidates.is_empty():
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + region * 104729 + 84191
		var path: Array = candidates[random.randi_range(0, candidates.size() - 1)]
		_link(path[0], path[1])
		path[0].shortcuts.append(path[1].id)
	return rooms

# Frozen algorithm: existing v2 saves must regenerate their original graph.
static func generate_v2(region: int, seed_value: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + (region + 1) * 739391
	var floors: int = LENGTHS[region]
	var result: Array = []
	var rows: Array = []
	var service_floor := random.randi_range(4, 5)
	for floor_number in range(1, floors + 1):
		var lanes: Array = [0, 1, 2, 3]
		if floor_number == floors: lanes = [1]
		elif floor_number > 1 and floor_number != service_floor and random.randf() < 0.45:
			lanes.erase(random.randi_range(0, 3))
		var kinds: Array = []
		if floor_number == floors: kinds = ["boss"]
		elif floor_number == 1 or (region == 0 and floor_number == 2): kinds = ["combat", "combat", "combat", "combat"]
		elif floor_number == service_floor: kinds = ["shop", "workshop", "shop", "supply"]
		elif floor_number == floors - 1: kinds = ["workshop", "bypass", "supply", "event"]
		elif region == 0 and floor_number == 3: kinds = ["combat", "combat", "supply", "event"]
		else: kinds = ["combat", "elite", "event", "combat"]
		_shuffle(kinds, random)
		var row: Array = []
		for i in range(lanes.size()):
			var lane: int = lanes[i]
			var role := str(kinds[i])
			var kind := "combat" if role == "elite" else ("supply" if role == "workshop" else role)
			var event_kind: String = ["siphon", "archive", "salvage"][random.randi_range(0, 2)] if kind == "event" else ""
			var risky := kind == "combat" and role != "elite" and floor_number > 2 and random.randf() < 0.3
			var label: String = {"combat": "순찰 구역", "elite": "강화 경비 구역", "shop": "생존자 상점", "workshop": "정비 작업대", "supply": "보급 보관소", "event": "잔류 신호", "bypass": "빈 연결 통로", "boss": "구역 관문"}[role]
			var item := {"id": region * 10000 + floor_number * 100 + lane + 1, "region": region, "floor": floor_number, "lane": lane, "kind": kind, "name": label, "route": "duct" if risky else "stairs", "event": event_kind, "elite": role == "elite", "workshop": role == "workshop", "next": [], "map_version": 2}
			row.append(item)
			result.append(item)
		rows.append(row)
	for index in range(rows.size() - 1):
		var from: Array = rows[index]
		var to: Array = rows[index + 1]
		# Monotonic nearest-neighbour links ensure every room is reachable and has an exit.
		for item in from: _link(item, _nearest(item, to))
		for target in to: _link(_nearest(target, from), target)
		# Extra adjacent links fork/merge paths without crossing another corridor.
		var candidates: Array = []
		for item in from:
			for target in to:
				if absi(int(item.lane) - int(target.lane)) <= 1: candidates.append([item, target])
		_shuffle(candidates, random)
		var added := 0
		for pair in candidates:
			if pair[0].next.has(pair[1].id): continue
			var crosses := false
			for item in from:
				for target in to:
					if item.next.has(target.id) and (int(pair[0].lane) - int(item.lane)) * (int(pair[1].lane) - int(target.lane)) < 0: crosses = true
			if not crosses and (added < 2 or random.randf() < 0.35):
				_link(pair[0], pair[1])
				added += 1
	return result

static func _nearest(item: Dictionary, candidates: Array) -> Dictionary:
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if absi(int(item.lane) - int(candidate.lane)) < absi(int(item.lane) - int(best.lane)): best = candidate
	return best

static func _link(from: Dictionary, to: Dictionary) -> void:
	if not from.next.has(to.id): from.next.append(to.id)

static func _shuffle(values: Array, random: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var value = values[i]
		values[i] = values[j]
		values[j] = value
