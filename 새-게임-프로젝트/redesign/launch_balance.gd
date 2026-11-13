extends RefCounted
## Launch balance (2026-11-12, user: "런칭 직전 수준까지 전체 작업"). Changes found by running
## all seven guns through the whole climb (solver and thoughtless play). New runs only
## (model.s.launch_balance_version); earlier saves keep their rules.
##
## 1. 리와인더 · 되감기 사격. The gun only reordered the magazine and had no numbers of its
##    own: the solver needed 664 enemy actions (other guns 226~428) and finished every region
##    with 1~2m to spare, including ordinary fights of region 1. Now the first attack round
##    fired right after the rewind (a manual cool that reversed the magazine) deals direct
##    damage ×3. Cooling before the heat limit is the game's core decision, and this is the
##    gun that is paid for it.
##    With the rewind shot alone the gun still lost under careful play (never overheat): at the
##    region 2 boss with a fire build, in region 4 with a direct build; only the 연타 build
##    finished, in 409 enemy actions (other guns 210~250). Its built-in drive was 열압, which
##    needs heat at half or more, while the rewind cools to 0. So in these runs the gun carries
##    돌파 (content.gd LAUNCH_GUN_ENGINES): the rewound round is one big hit, ×2 then ×3.
##
## 2. 난도 · 적 체력. 난도는 적의 시작 거리를 최대 4m 줄이고 보상 크레딧을 깎을 뿐이어서,
##    과열하지 않게만 쏘는 플레이가 난도 0에서 가장 가까운 적을 9m 밖에 두고 끝까지 갔고
##    난도를 올려도 달라질 것이 거의 없었다. 난도 1마다 적 체력을 더한다: 마지막에서 두 번째
##    구역 기준 +HARDEN_STEP%, 첫 구역은 그 40%, 마지막 구역은 120%. 처음에는 구역과 상관없이
##    +8%였는데, 파츠가 없는 1구역 보스에서 래칫이 난도 5에 막혔다(신중한 플레이). 플레이어의
##    성장이 적을 가장 크게 앞서는 곳은 후반이므로 그쪽을 더 올린다. 숫자를 키워야 잡는다는
##    체감이 다음 난도에서 다시 생기게 하려는 것이다. 난도 0은 그대로.
const VERSION := 1
const REWIND_FACTOR := 3
const HARDEN_STEP := 8

## Enemy HP percent at a difficulty level in a region (0~4). 100 at 난도 0.
## 난도 10: +32% / +48% / +64% / +80% / +96% by region.
static func harden_percent(difficulty: int, region: int) -> int:
	return 100 + HARDEN_STEP * clampi(difficulty, 0, 10) * (2 + clampi(region, 0, 4)) / 5

## Applied once when an encounter is built (campaign.gd), to the opening line and the reserve.
static func harden(state: Dictionary, difficulty: int, region: int) -> void:
	if not enabled(state) or difficulty <= 0: return
	var percent := harden_percent(difficulty, region)
	for group in [state.get("enemies", []), state.get("reinforcements", [])]:
		for enemy in group:
			var hp := ceili(int(enemy.get("hp", 0)) * percent / 100.0)
			enemy.hp = hp
			enemy.max_hp = maxi(hp, ceili(int(enemy.get("max_hp", hp)) * percent / 100.0))

static func enabled(state: Dictionary) -> bool:
	return int(state.get("launch_balance_version", 0)) == VERSION

static func valid(state: Dictionary) -> bool:
	var version = state.get("launch_balance_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION

## True when the last action of this fight was the manual cool that reversed the magazine.
static func rewind_ready(state: Dictionary) -> bool:
	if not enabled(state): return false
	var history: Array = state.get("history", [])
	if history.is_empty(): return false
	var last: Dictionary = history.back()
	return str(last.get("action", "")) == "cool" and bool(last.get("detail", {}).get("reversed", false))
