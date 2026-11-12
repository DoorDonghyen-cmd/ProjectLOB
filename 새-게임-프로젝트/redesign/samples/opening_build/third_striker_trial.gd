extends RefCounted
## Only the isolated early-parts comparison grants this state flag.
const FLAG := "early_parts_third_striker_star2"
const PART := "third_striker"
const PRICE := 20

static func upgraded(state: Dictionary) -> bool:
	return state.get(FLAG, false) == true

static func multiplier(state: Dictionary) -> Variant:
	return 3.5 if upgraded(state) else 3

static func multiplier_label(state: Dictionary) -> String:
	return "×3.5" if upgraded(state) else "×3"
