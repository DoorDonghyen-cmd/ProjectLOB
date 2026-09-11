# Pre-art 전체 캠페인 독립 기능 QA — 2026-09-11

## 입력 계약

- 역할: 독립 기능 QA. 다른 QA 역할의 결론을 받지 않고 실제 UI 브리지의 원본 행동·체크포인트로 판정했다.
- 모드: 기능 집중. Godot 4.7 stable headless, seed `424242`, 기본 신규 플레이어 상태.
- 빌드: `b76484966c2b7035571af27dde86e14aa724159c`, dirty worktree. 부모 개발 에이전트가 동시에 작업 중인 소스 트리이며 커밋 전체의 판정이 아니다.
- 관찰 시점: 2026-09-11 14:20~14:28 KST. 초기 재현 직후 관련 4개 파일 SHA256을 `qa_runtime/preart_20260911/campaign/full_before/source_hashes.json`에 보존했다. 수정 후 재실행 시작 전에 `full_after/source_hashes.json`에도 저장했다.
- 사용자 데이터: `qa_runtime/preart_20260911/campaign/{appdata,localappdata,godot_home}`. 매 실행 별도 `QA_OUTPUT_DIR/meta_override.cfg`를 사용해 사용자 실제 세이브를 건드리지 않았다.
- 프로필: 지도에서 첫 합법 경로, 전투 보상은 크레딧, 상점 첫 구매 가능 슬롯 구매 및 리롤, 이벤트는 건너뛰기.
- 허용된 기존 이슈: 상위 작업에서 전달한 전체 회귀 baseline 3,655 PASS / 0 FAIL / 기존 WARN 3개. 이 숫자는 이 독립 runner의 실행 결과가 아니다.

**모든 전투 승리는 `present_victory_fixture`로 보상 UI를 여는 테스트 fixture다. 전투 밸런스, 실제 승률, 실제 35층 생존 가능성, 재미에 관한 증거가 아니다.**

## 원본 결과

| 세션 | 결과 | 행동 / 완료 노드 | 증거 |
|---|---|---|---|
| `preart-campaign-full-before` | FAIL | 117 / 35 | `qa_runtime/preart_20260911/campaign/full_before/replay_result.json` |
| `preart-campaign-full-repeat` | FAIL, 동일 재현 | 117 / 35 | `qa_runtime/preart_20260911/campaign/full_repeat/replay_result.json` |
| `preart-campaign-compat-1` | PASS | 23 / 6 | `qa_runtime/preart_20260911/campaign/compat_1/replay_result.json` |
| `preart-campaign-compat-2` | PASS | 46 / 13 | `qa_runtime/preart_20260911/campaign/compat_2/replay_result.json` |
| `preart-campaign-full-after` | PASS, 수정 후 | 122 / 35 | `qa_runtime/preart_20260911/campaign/full_after/replay_result.json` |

공통 실행 인프라 메시지로 Windows root certificate store 읽기 실패가 출력됐다. 네트워크가 없는 로컬 UI·저장 검증은 정상 진행됐고, 테스트 assertion 결과와 분리한다. headless 실행이므로 시각 캡처는 요청하지 않았으며 각 체크포인트 JSON에 이를 명시한다.

## 확인한 범위

- PASS: 타이틀 → 계층 안내 → 준비실 → 지도 → 합법 노드 진입 → 전투 fixture → 보상 → 다음 층.
- PASS: 5개 계층 전체 방문, 총 35개 노드 완료, 4회 계층 전환 UI의 계속 버튼 작동.
- PASS: 상점 리롤·구매·퇴장 및 정비/이벤트 건너뛰기를 포함한 경로 진행.
- PASS: 정점 디브리핑 제목 `▲ 정점`, 5계층 영구 해금, 승천 1등급 해금.
- PASS: 최종 메타 cfg 파일 읽기, 메모리의 크레딧·코어·계층·무기·승천·보너스·로어 상태를 비운 다음 실제 `RunManager.load_meta()`로 동일 상태 복원.
- 수정 후 PASS: 완료 층수 35 및 환전 크레딧 +575 계산. 신규 메타 100에서 최종 675로 저장·reload됐다.
- 수정 후 PASS: 디브리핑 확인 버튼 → 타이틀 → 계층 안내 → 준비실 → 시작 보너스 선택 → section_a 1층 지도. 메타 675 유지 및 새 런 크레딧 50 확인.

## 재현된 기능 결함 — 완주 정산 한 층 초과

중요도: 보통. 2개의 독립 신규 QA 저장 경로에서 동일 재현.

1. 신규 상태로 시작해 UI에서 모든 계층을 진행한다.
2. 전투는 명시적 승리 fixture로 통과하며 전투 보상은 크레딧을 고른다.
3. section_e 8층 801 코어 노드 보상을 선택해 최종 정산을 연다.
4. 원본 `summit_progress.completed_nodes`에는 35개가 기록된다.

기대: 최종 정산 35층, `35 × 15 + 50 = 575 Cr`.

실제: `current_floor = 9`, `total_floors_climbed = 36`, 디브리핑 `오른 층수: 36 층`, 환전 `590 Cr`. 잘못 계산된 수치가 그대로 메타 저장에 반영된다. 새 세션에서도 같은 117행동 시점에 같은 두 assertion이 실패했다.

원인 후보 전달: `combat_scene._advance_floor_or_finish()`가 마지막 층을 먼저 증가시킨 후 debrief를 열며, `RunManager.total_floors_climbed()`가 이를 그대로 합산한다. QA 역할은 프로덕션 코드를 수정하지 않았다.

**수정 검증: PASS, 24 checks / 0 failures.** 부모 개발 에이전트가 누적 층수에 총 런 길이 상한을 적용한 후 동일 seed, 새 QA 저장 경로에서 독립 재실행했다. 35개 노드·4개 계층 전환 후 정산 35층/+575 Cr로 정상화됐고, 메타 저장 reload와 새 런 재시작까지 총 122 UI 행동이 통과했다. 초기 실패 원본은 덮어쓰지 않았다.

수정 후 검증 대상 `run_manager.gd` SHA256: `8D9D1817F46DA6EAF3840B02DEDD4B434FF5E2C6AE666F72D7D51B384AC77EE9`. 이번 PASS는 이 파일과 `full_after/source_hashes.json`에 기록된 UI/runner 스냅샷에 대한 판정이다.

## 검증 도구 변경

`tests/qa_campaign_replay_runner.gd`의 `QA_TARGET_SECTIONS` 범위를 1~5로 확장했다. 기본값 2와 기존 1~2계층 종료 동작은 실제 재실행으로 유지 확인했다. 테스트 파일 내부에서만 UI executor를 확장하여 최종 디브리핑 확인 버튼을 실제 `pressed` 신호로 누르도록 했다. 35개 노드·정산·메타 reload·재시작 assertion, 단계별 UI 체크포인트, fixture 고지, 120초/500행동 제한을 추가했다.

재실행 시 `QA_OUTPUT_DIR`에는 **새 디렉터리**를 지정한다. 기존 메타 세이브를 재사용하면 신규 플레이어 승천 1 및 시작 크레딧 전제가 달라질 수 있다.
