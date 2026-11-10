extends RefCounted
## Versioned magazine abilities. Legacy burst comparisons keep their opt-in state;
## native new weapons must carry the matching state. Other old runs never opt in.
## A magazine index identifies one physical occurrence, never every copy of an ID.
const VERSION := 1
const KINDS := ["deadbolt", "rewinder"]
const NAMES := {"deadbolt":"데드볼트", "rewinder":"리와인더"}
const TEXT := {
	"deadbolt":"장전 시 무작위 공격탄 1발의 직접 피해 ×3 · 봉인탄은 빼내기 불가 · 발사 전 탄창 교체 불가",
	"rewinder":"탄창당 첫 수동 냉각 시 고정탄을 제외한 남은 탄 순서 반전"
}

static func enabled(state: Dictionary) -> bool:
	return state.get("weapon_role_trial") is Dictionary and _whole(state.weapon_role_trial.get("version"),VERSION,VERSION) and state.weapon_role_trial.get("kind") is String and state.weapon_role_trial.kind in KINDS

static func kind(state: Dictionary) -> String:
	return str(state.weapon_role_trial.kind) if enabled(state) else ""

static func activate(state: Dictionary, role: String) -> bool:
	if role not in KINDS or state.get("gun","") not in ["burst",role] or state.get("phase","") != "plan" or not state.get("magazine",[]).is_empty() or int(state.get("weapon_magazine_version",0)) != 1: return false
	state.weapon_role_trial = {"version":VERSION,"kind":role,"mark":-1,"rewound":false}
	return true

static func clear(state: Dictionary) -> void:
	if not enabled(state): return
	state.weapon_role_trial.mark = -1
	state.weapon_role_trial.rewound = false

static func on_load(state: Dictionary, is_attack: Callable) -> void:
	if not enabled(state): return
	clear(state)
	if kind(state) != "deadbolt": return
	var candidates: Array[int] = []
	for i in range(state.magazine.size()):
		if is_attack.call(str(state.magazine[i])): candidates.append(i)
	if candidates.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.state = int(state.rng_state)
	state.weapon_role_trial.mark = candidates[rng.randi_range(0,candidates.size()-1)]
	state.rng_state = str(rng.state)

static func mark(state: Dictionary) -> int:
	return int(state.weapon_role_trial.mark) if kind(state) == "deadbolt" else -1

static func locked(state: Dictionary) -> bool:
	return mark(state) >= 0

## Called BEFORE removing the front card. Consuming the cartridge unlocks it,
## even when a barrier absorbs all damage. No hit/kill condition or RNG here.
static func consume_front(state: Dictionary) -> int:
	var position := mark(state)
	if position < 0: return 1
	state.weapon_role_trial.mark = position-1
	return 3 if position == 0 else 1

static func on_eject(state: Dictionary, positions: Array) -> void:
	var position := mark(state)
	if position < 0: return
	state.weapon_role_trial.mark = position-positions.filter(func(i): return int(i)<position).size()

static func can_reverse(state: Dictionary, anchor: Callable) -> bool:
	if kind(state) != "rewinder" or bool(state.weapon_role_trial.rewound): return false
	return state.magazine.filter(func(id): return str(anchor.call(str(id))).is_empty()).size() >= 2

static func after_cool(state: Dictionary, forced: bool, anchor: Callable) -> bool:
	if forced or state.phase != "ready" or not can_reverse(state,anchor): return false
	var positions: Array[int] = []
	var rounds: Array = []
	for i in range(state.magazine.size()):
		if str(anchor.call(str(state.magazine[i]))).is_empty():
			positions.append(i)
			rounds.append(state.magazine[i])
	rounds.reverse()
	for i in range(positions.size()): state.magazine[positions[i]] = rounds[i]
	state.weapon_role_trial.rewound = true
	return true

static func valid(state: Dictionary, is_attack: Callable) -> bool:
	if not state.has("weapon_role_trial"): return state.get("gun","") not in KINDS
	var role: Variant = state.weapon_role_trial
	if not role is Dictionary or role.size()!=4 or not enabled(state): return false
	if not _whole(role.get("version"),VERSION,VERSION) or not role.get("kind") is String: return false
	if state.get("gun","") not in ["burst",kind(state)] or state.get("version",0)!=15 or state.get("weapon_version",0)!=1 or state.get("magazine_trial_version",0)!=1 or state.get("weapon_magazine_version",0)!=1 or state.get("fire_control_version",0)!=1: return false
	if not role.get("rewound") is bool or not _whole(role.get("mark"),-1,state.magazine.size()-1): return false
	if kind(state)=="deadbolt":
		if role.rewound: return false
		if int(role.mark)>=0 and not is_attack.call(str(state.magazine[int(role.mark)])): return false
	elif int(role.mark)!=-1: return false
	if state.phase!="ready" and (int(role.mark)!=-1 or role.rewound): return false
	return true

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=minimum and value<=maximum
