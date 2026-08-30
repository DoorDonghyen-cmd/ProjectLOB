# 🧪 tests — 헤드리스 자동 검증

Godot 4.7 프로젝트의 결정론적 로직을 **씬 없이 헤드리스로** 자동 검증한다.
수동 `walkthrough.md` 플레이테스트를 코드 회귀 테스트로 대체/보완한다.

## 실행

```powershell
# Windows
.\tests\run.ps1
# 또는 Godot 경로 직접 지정
.\tests\run.ps1 -Godot "C:\Program Files\Godot\Godot_v4.7-stable_win64.exe"
```

```bash
# Linux / macOS / CI
GODOT=/path/to/godot ./tests/run.sh
```

수동 실행:

```
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/run_all.gd
```

고정 전투 QA 브리지 실행:

```powershell
$env:QA_OUTPUT_DIR = "user://qa_runtime/fixed_ammo"
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/qa_session_runner.gd
```

실행기가 `state_0000.json`을 만든 뒤 같은 폴더의 `command_0000.json`을 기다린다.
명령이 수락되면 단계 번호가 증가하며 승패가 확정될 때까지 다음 command 파일을 처리한다.

실제 UI 체크포인트와 PNG 캡처 실행:

```powershell
$env:QA_OUTPUT_DIR = "user://qa_runtime/ui_phase_c"
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/qa_ui_session_runner.gd
```

렌더 이미지가 없는 환경에서도 JSON 의미 계약은 계속 기록되며, 캡처 실패는
게임 결함이 아닌 `qa_infrastructure`로 분리된다.

재현 가능한 1~2구역 캠페인 실행:

```powershell
$env:QA_OUTPUT_DIR = "user://qa_runtime/campaign_phase_d"
$env:QA_GAMEPLAY_SEED = "424242"
$env:QA_TARGET_SECTIONS = "2"
$env:QA_SESSION_ID = "qa-phase-d-424242"
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/qa_campaign_replay_runner.gd
```

실행기는 실제 메인 씬에서 타이틀→준비실→지도→전투 결과→보상·상점→다음 구역을
의미 행동으로 진행한다. `progress.json`은 매 행동 뒤 갱신되며, `replay_result.json`과
스키마 v3 플레이테스트 로그에 seed·세션 ID가 함께 남는다. `APPDATA`를 전용 경로로
지정하면 실제 사용자 세이브와 로그를 오염시키지 않는다.

네 경험 프로필 보고서 비교:

```powershell
$env:QA_REPORT_DIR = "user://qa_runtime/profile_reports"
$env:QA_COMPARISON_OUTPUT = "user://qa_runtime/profile_reports/profile_comparison.json"
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/qa_profile_compare_runner.gd
```

보고서 폴더에 `beginner.json`, `aggressive.json`, `conservative.json`,
`experimental.json`을 둔다. 네 파일의 commit·scenario·gameplay seed·시작 조건이
같아야 하며, 동일 행동열이면 비교 실패로 종료한다.

독립 QA 팀 실행 계약:

1. `QATeamOrchestrator.prepare()`로 동일 manifest에서 역할별 패킷을 만든다.
2. 기능 QA·경험 QA·전투 시뮬레이터는 서로의 결과를 받지 않고 각 패킷의 artifact만 읽는다.
3. 각 역할은 `QATeamReport` 계약으로 `reports/<role>.json`을 완료한다.
4. 세 원본이 모두 끝난 뒤에만 `integrate_from_directory()`를 호출한다.

경험 QA 패킷에는 소스·테스트·오라클·실제 플레이 원시 로그를 넣을 수 없다. 경험 QA는
기능 FAIL을 확정할 수 없고, 시뮬레이터는 UI FAIL을 확정할 수 없다. FAIL은 기대/실제,
재현 단계와 원본 artifact 경로가 모두 있을 때만 통합 리포트의 확정 버그 후보가 된다.

세 원본 통합이 성공하면 같은 QA runtime 폴더에 `dashboard_run.json`과
`dashboard_data.js`도 생성된다. 보관된 여러 실행을 다시 묶을 때는
`qa_dashboard_history_runner.gd`를 사용한다. HTML 운영 방법은
`docs/qa/dashboard/README.md`를 따른다.

종료 코드 **0 = 전체 통과**, **1 = 실패** (CI에서 레드/그린 판정 가능).

## 구성

| 파일 | 역할 |
|------|------|
| `run_all.gd` | 오케스트레이터(SceneTree). 모든 검증을 순차 실행하고 종료 코드 반환 |
| `lob_test.gd` | 미니 assert/집계 하니스 (`check`/`eq`/`warn`/`summary`) |
| `suite_damage.gd` | 전투 수식 — 이진 관통 게이트, 명중 `ACC≥EVA` 임계값 |
| `suite_magazine.gd` | 탄창 LIFO — 발사 순서, 용량/약실, unload/insert |
| `suite_enemy.gd` | 적 태세 전환(N발 주기), 전진/둔화/넉백 거리 계산 |
| `suite_boss_gimmicks.gd` | 보스 기믹·호위 대열 — 2m 편성, 차징 포격, 강제전진, 페이즈 전환, 넉백 저항 |
| `suite_campaign_integrity.gd` | 캠페인 관문 편성 — 보스 4종+정예 관문, 정식 보상 후보군, 스타팅 보증·암시장 결제 |
| `suite_enemy_roster.gd` | 일반·변종 9종의 계층 도달성, 표시명, 상층 차저 중첩과 실제 무대응 4~8행동 압력 |
| `suite_combat_rewards.gd` | 실제 격발 수 기반 탄약 효율 등급·전투 크레딧 정산 |
| `validate_data.gd` | CSV 정합성 — id 유니크·컬럼·정수·밴드(ERROR/WARN), `.tres` 매칭 |
| `suite_ammo_integrity.gd` | 탄환 CSV↔리소스↔시작 덱 역할·수치 완전 일치 |
| `suite_caliber_profiles.gd` | 3계열 고정 기술 규격 — 표준/강화 매핑, 공용 전술탄 보정, 기반탄 비중복 |
| `suite_ammo_family_behavior.gd` | 탄종 행동 — 경량 집중, 소총 직선 관통, 산탄 군집 확산, 중복 파츠·DPT 불변식 |
| `suite_playtest_logging.gd` | 런별 JSON 저장, 전투 문맥, 탄 사용·집중·파츠 효과 기여 집계 |
| `suite_qa_bridge.gd` | 전용 QA manifest, 단계별 상태/행동 JSON, 공개 상태/오라클 분리, 실제 전투 왕복 |
| `suite_qa_ui_checkpoints.gd` | 실제 메인 씬의 타이틀→구역→준비실→지도→전투→보상→상점 의미 행동, 공개 UI 상태·리롤 설명 정합·캡처 폴백 |
| `suite_qa_rng_replay.gd` | 게임플레이/FX RNG 분리, 명시적 스트림 독립성, seed 재현, manifest v2와 행동별 진행 저널 |
| `suite_qa_experience_metrics.gd` | 네 블랙박스 프로필 리포트, 재미 지표, 동일 행동열 거절, 지배 선택·강한 신호 비교 |
| `suite_qa_team_orchestration.gd` | 기능·경험·시뮬레이터 독립 입력 패킷, 원본 보고 계약, 후공유 통합, 정상 샘플 오탐·결함 샘플 미탐 방지 |
| `suite_qa_dashboard.gd` | QA 통합 결과의 실행 이력 JSON, 최종 판정, 역할·판정 집계, file 프로토콜용 데이터 스크립트 |
| `suite_qa_core_fun.gd` | 동일 탄환 멀티셋의 계획·역순·기본탄 실제 CombatManager 대조와 순서·상황·혼합·실전 압박 핵심 재미 게이트 |
| `qa_autonomous_playtest_runner.gd` | 실제 메인 씬과 CombatManager를 사용하는 4성향 블랙박스 플레이. 공개 UI 상태만 보고 행동 이유·기대·대안을 결과 전에 기록 |
| `qa_core_fun_probe_runner.gd` | 회피·장갑·피해 결산·마지막 탄의 동일 탄환 순서 반사실 결과를 JSON으로 생성 |
| `qa_playtest_finalize_runner.gd` | 독립 프로필 결과를 재미 신호·버그 후보·확정 버그로 분리하고 대시보드 실행 JSON 생성 |
| `suite_basic_supply.gd` | 기본탄 고정 보급 슬롯 — 총기별 상한, 장전 차감, 리로드 정량 복구 |
| `suite_save_load.gd` | 메타 저장·로드와 개발자 전체 초기화 — 세이브 삭제, 영구 진행·현재 런 기본값 복원 |
| `suite_ammo_matrix.gd` | 실제 몬스터별 공격·연계·연발 처치 조합 매트릭스 |
| `suite_ammo_specialization.gd` | 9종 총기×13종 적의 시작 탄창 전문축 조합 검증 |
| `lifo_depth_probe.gd` | 같은 6발의 고유 순열을 실제 CombatManager로 전투해 적별 최적 배치 산출 |
| `suite_lifo_depth_baseline.gd` | `baseline/lifo_depth_v5.json`과 현행 v5 순서 민감도 비교 |
| `ammo_v6_preflight_probe.gd` | v6 초안 기반탄을 런타임 교체 없이 9총기×13적에 임시 주입 |
| `ammo_v6_tuning_probe.gd` | v6 후보 피해·총기 보정의 사이클 화력, 거리별 도달성, 기반+지원탄 전수 순열 및 제어탄 구조 검사 |
| `suite_ammo_v6_tuning.gd` | 후보 피해 3/3/3/4/4, 9총기 화력 밴드, 일반 적 해법, 지배 지원 패키지 부재를 기준 JSON으로 회귀 고정 |
| `sim_harness.gd` | 결정론 전투 시뮬레이터 — 승패·마진·넉백락 산출(밸런스 회귀+튜닝) |
| `suite_conversion_kit.gd` | 컨버전 킷 — 클래스별 데이터, 장착 제한, 레거시 소멸 면제, 드래프트 가중, 가격 |
| `suite_continuous_run.gd` | 연속 런 — 첫 관문 자동 해금·계층 체이닝, 자원 유지, 고정 35층 |
| `suite_spawn_tiers.gd` | 계층별 스폰 3구간이 모두 도달 가능한지(사문화 콘텐츠 검출) |
| `suite_ui_data_drift.gd` | UI 소스에 계층 이름·층수가 복사돼 있지 않은지(정본은 `MapGenerator`) |
| `suite_doc_drift.gd` | GDD·스킬 문서에 폐기된 세계관 설정이 남아 있지 않은지 |
| `suite_ui_smoke.gd` | 메인 씬을 실제로 인스턴스화하고 오버레이를 호출 — 런타임 오류, 격발 중 재입력 잠금·총기별 표시 템포, 구역별 일반전 밀도, 상층 대표 편성 QA, 동거리 4체 편성 슬롯 검출 |

### 드리프트 검사에 대해

같은 사실이 여러 곳에 **복사**돼 있으면 한쪽만 고쳐져 조용히 어긋난다. 2026-07-24에 이 종류로만 6건이 한꺼번에 발견됐다(구역 선택 화면·지도 층수·스폰 구간·보스 구성·정산 기준·디브리핑 텍스트). 전부 기존 스위트를 통과한 상태였다.

- **폐기어를 의도적으로 써야 하는 자리**("되살리지 말 것" 경고 등)에는 그 줄에 `[drift-allow]`(GDScript) 또는 `<!-- drift-allow -->`(마크다운)를 붙인다.
- **이력 보관 문서**(`04-daily-logs`, `06-history-archive`)는 문서 검사에서 제외한다. 당시 기록을 현재 정본에 맞춰 고쳐 쓰면 기록으로서의 가치가 사라진다.
- 소스 검사로는 **맨 숫자 리터럴**(`end_floor = 15` 같은)을 잡을 수 없다. 이런 값은 `suite_ui_smoke`가 실제로 렌더해 결과를 세는 쪽으로 검증한다.

- **ERROR**(FAIL, 종료 1): 구조적 오류(관통 게이트 위반, 중복 id, 컬럼 부족 등).
- **WARN**(경보만): 밸런스 밴드 이탈, `.tres` 파일명 불일치 등. 종료 코드에 영향 없음.

## 새 테스트 추가

1. `suite_*.gd`에 `static func run(t) -> void:` 작성, `t.eq(...)` / `t.check(...)` 사용.
2. `run_all.gd`에 `preload` + `Suite.run(t)` 한 줄 추가.

> **씬 트리가 필요한 스위트**(노드 인스턴스화·`_ready` 실행)는 `_initialize()`가 아니라
> `run_all.gd`의 `_process()`에 넣는다. `_initialize()` 시점에는 root Window가 아직 트리에
> 들어가지 않아 자식 `_ready()`가 호출되지 않고, 노드 참조가 전부 null인 채로 검사하게 된다.
> `suite_ui_smoke.gd`가 이 형태이며 `run(t, tree)` 시그니처를 쓴다.

## 참고

- **레이아웃·연출은 여전히 자동화 대상이 아니다** → 인게임 `🛠️ 개발자 테스트` 메뉴 활용.
  다만 "화면이 뜨긴 하는가 / 표시 문자열이 정본과 어긋나지 않는가"는 자동으로 잡는다
(`suite_ui_smoke`, `suite_ui_data_drift`). 2026-07-24에 구역 선택 화면이 구버전 세계관과
구 층수를 표시하고 있었는데도 전 스위트가 통과한 사고를 계기로 추가됐다.

## 탄환 v6 사전검증 산출물 재생성

```powershell
<Godot> --headless --path <프로젝트> --script res://tests/generate_lifo_depth_baseline.gd
<Godot> --headless --path <프로젝트> --script res://tests/generate_ammo_v6_preflight.gd
<Godot> --headless --path <프로젝트> --script res://tests/generate_ammo_v6_tuning.gd
```

첫 명령은 **v5 마이그레이션 전에만** 실행한다. 이후 v6 비교를 위해
`baseline/lifo_depth_v5.json`을 역사 기준값으로 보존한다.
- 로직 검증은 순수 static 클래스(`DamageCalculator`/`DataLoader`)와 `RefCounted`
  (`Magazine`/`EnemyInstance`) 대상. UI는 위 두 스위트로만 얕게 훑는다.
- 밸런스 밴드 정본은 `.agents/skills/10-balance-designer/SKILL.md`, 전투 공식 정본은 `docs/gdd/03_combat_system.md §3.2`.
