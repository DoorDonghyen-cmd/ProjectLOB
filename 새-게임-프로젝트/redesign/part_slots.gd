extends RefCounted
## Part types by gun component (2026-11-11, user: "현재 파츠를 총구, 탄창, 손잡이 뭐 이런 식으로
## 종류를 구분하는 건 어떻게 생각해", "1단계부터 진행"). Stage 1 is labels only: the type name
## and colour on part details, shop, rewards, combat build window. Equip rules do not change.
## Stage 2 (per-gun typed mount slots) is a later decision.
##   총열 — what happens when the round lands (pierce, burn, arc, push, tag +)
##   조준기 — conditional multipliers by target or state (처형, 화상 중, 감속, 고열)
##   약실 — the power and heat of one shot (drives, 공명, 숙련형, 방열)
##   탄창 — magazine composition, order and loading (선두·후미, 교차, 확장, 혼합)
##   회로 — copies another part (복제 기판)
const NAMES := {"barrel": "총열", "sight": "조준기", "chamber": "약실", "magazine": "탄창", "circuit": "회로"}
const COLORS := {"barrel": Color("e3a35b"), "sight": Color("e57a72"), "chamber": Color("7fb8e6"), "magazine": Color("9fd37a"), "circuit": Color("c49be8")}
const SLOTS := {
	"lens": "barrel", "overbore": "barrel", "capacitor": "barrel", "arc_splitter": "barrel", "rammer": "barrel", "momentum": "barrel",
	"breaker": "barrel", "coil": "barrel", "inferno": "barrel", "tag_fire_add": "barrel", "tag_shock_add": "barrel", "tag_fire_burn": "barrel",
	"executioner": "sight", "igniter": "sight", "tag_low_mult": "sight", "tag_control_mult": "sight", "tag_burning_mult": "sight",
	"tag_hot_mult": "sight", "tag_single_add": "sight", "tag_finisher_add": "sight", "tag_single_mult": "sight",
	"volley_drive": "chamber", "thermal_drive": "chamber", "siege_drive": "chamber", "cooling_breech": "chamber", "compression_sink": "chamber",
	"ember_core": "chamber", "duplex": "chamber", "sequencer": "chamber", "tag_multi_add": "chamber", "resonator": "chamber", "tally": "chamber",
	"tag_fire_growth": "chamber", "field_press": "chamber", "reclaimer": "chamber", "radiator": "chamber",
	"supply": "magazine", "loader": "magazine", "reserve": "magazine", "indexer": "magazine", "ordinary_chain": "magazine", "triad": "magazine",
	"opening": "magazine", "afterburner": "magazine", "chain_sink": "magazine", "third_striker": "magazine", "tag_variety": "magazine",
	"tag_fire_deck": "magazine",
	"tag_copy": "circuit",
}

static func slot(id: String) -> String:
	return str(SLOTS.get(id, "chamber"))

static func name_of(id: String) -> String:
	return str(NAMES[slot(id)])

static func color_of(id: String) -> Color:
	return COLORS[slot(id)]
