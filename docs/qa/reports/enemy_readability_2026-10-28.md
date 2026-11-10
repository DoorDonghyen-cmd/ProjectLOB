# 적 이동·겹침·위협 표시 개편

2026-10-28, `prototype/core-redesign`, 기준 HEAD `197c694`와 기존 미커밋 변경 위의 로컬 작업. 활성 프로젝트는 `새-게임-프로젝트`, Godot4.7 OpenGL/RTX4060Ti. 사용자 저장과 분리된 `qa_runtime/`에서 검사했다. [현행 결정](../../direction/enemy-readability.md) · [소스 해시](assets/enemy_readability_2026-10-28/source_hashes.json).

## 변경과 확인

이전 몸체 배치는 거리 순서로 정렬한 뒤 반지름과 여백을 강제로 확보하고, 마지막 적부터 화면 안으로 밀어 넣었다. 그래서 이웃의 이동·처치·등장도 내 위치를 바꿨다. 이번에는 실제 거리에서 각 개체의 가로 기준점을 독립적으로 정한다. 32m 밖은 먼 영역만 부드럽게 압축하며, 깊이·그리기 순서는 지속되는 개체의 전열 값으로 정한다.

몸체 일부 겹침을 허용하고 HP·상태·경고·터치 영역만 분리했다. 연결선과 포커스 시 몸체 강조를 사용한다. 검토 중 A–D 표식 시안은 기존 식별 문자 제거 결정에 따라 제외했다. 상시 거리 숫자는 없애고 상세에는 정확 거리·기본 속도·실제 다음 접근량을 남겼다. HP와 압력탄·피해 숫자를 공통 상위 레이어로 옮겨 큰 몸체에 가려지지 않게 했다.

행동 안내는 실제 모델의 `_advance(1)`을 분리된 상태에서 실행한다. 화상으로 먼저 죽는 적을 접촉 위험으로 잘못 표시하지 않으며, 속도0인 도약 적·지휘로 추가 접근하는 호위·차단된 발사·기존 압력탄 때문에 보류되는 발사를 구분한다. 이는 개입 전 다음 적 행동의 안내이며, 사격 후 예측이나 여러 행동을 쓰는 재장전의 안전 보장이 아니다. 연출 중 이전 상태의 다음 행동 문구는 숨긴다.

전투 수치·조준 규칙·저장 형식·적 편성은 변경하지 않았다. 이번 단계에서 새 전체 등반을 실행한 것으로 집계하지 않는다.

## 최종 검사

| 검사 | 통과한 확인 수 | 확인 범위 |
| --- | ---: | --- |
| threat | 2,035 | 접촉/화상 선처치/호위 추가 접근/차단/도약/축압/발사 경계, 3규칙 버전×5지역×3편성의 실제 행동 일치와 원본 보존 |
| threat_ui | 1,223 | 3화면 크기, 밀집/같은 거리/근접/32m 밖, 5지역 보스와 특수 행동 직전, 실제 터치 상세, 압력탄, 밀기·재장전, 빠르게/즉시 연출 |
| 기존 rules | 273 | 기존 전투 회귀 |
| payoff_ui | 445 | 직전 단계의 조합 발사·적중·결과 유지·성장 안내, 일반/빠르게/즉시/건너뛰기 |
| distance_order | 1,492 | 거리 순서·밀기·추월·처치·실제 증원. 연출141프레임에서 역전0 |
| enemy_hud | 1,748 | 상태 아이콘·HP·실제 터치·확정/무작위 예측·다중 상태 줄바꿈·경고 폭 |
| 실제 획득 상태 UI | 113 | 연사/산개의 초반·후반 기존 진행 상태 로드, 장전·사격 결과 일치, 화면 갱신 비용 |
| PC mobile_ui | 213 | 실제 저장·복구·대기 렌더링·반복 화면 정리, 이웃 이동/사망/압력탄 등장 후 기준점 유지 |
| **합계** | **7,542** | **최종 실패0. 검사 수는 사람의 이해도·재미 점수가 아니다.** |

규칙 자료: [threat](assets/enemy_readability_2026-10-28/threat.json), [threat_ui](assets/enemy_readability_2026-10-28/threat_ui.json), [payoff_ui](assets/enemy_readability_2026-10-28/payoff_ui.json), [이동 로그](assets/enemy_readability_2026-10-28/distance_order.log), [HUD 로그](assets/enemy_readability_2026-10-28/enemy_hud.log).

주요 실제 화면은1008×630에서 직접 열어 확인했다.1280×800·1440×630도 생성·배치 검사했다. 지역 편성 화면은 현행 편성을 주입한 합성 상황이며 자연 획득 경로의 승률 증거가 아니다.

| 상황 | 캡처 |
| --- | --- |
| 같은 거리의 네 적과 독립 HP | [밀집](assets/enemy_readability_2026-10-28/crowd_1008_18.png) |
| 다음 행동 접촉 | [접촉](assets/enemy_readability_2026-10-28/crowd_1008_1.png) |
| 주거 관문 | [주거](assets/enemy_readability_2026-10-28/region_0_1008.png) |
| 주조장 축압 해제·원거리 발사 직전 | [주조장](assets/enemy_readability_2026-10-28/region_1_imminent.png) |
| 정원 도약 직전 | [정원](assets/enemy_readability_2026-10-28/region_2_imminent.png) |
| 귀족 편성 | [귀족](assets/enemy_readability_2026-10-28/region_3_1008.png) |
| 친위대 지휘 직전 | [친위대](assets/enemy_readability_2026-10-28/region_4_imminent.png) |
| 압력탄 다음 적 행동 도달 | [압력탄](assets/enemy_readability_2026-10-28/pressure_imminent.png) |
| 실제 밀기 사격 후 | [밀기](assets/enemy_readability_2026-10-28/push_result.png) |
| 긴 화면 | [1440](assets/enemy_readability_2026-10-28/region_4_1440.png) |

## 성능과 한계

렌더링 검사는 순차 실행했다. PC 후반 대기 프레임 중앙값 약6.063ms, 잔열 상태의 전장 다시 그리기 약18.0~20.8회/초. 후반 렌더 호출 중앙값은 연사232/산개233으로 이전 단계232/234와 비슷하다. 장비 대기111도 유지됐다. 경고 계산은 화면 동기화 시 수행하며 전체 등반 이력을 깊은 복사에서 제외한다. [측정 원본](assets/enemy_readability_2026-10-28/metrics.json).

전체 화면 재생성 CPU는 연사 초반50.807/후반56.108ms, 산개 초반48.297/후반48.031ms. 이전 단계 후반57.182/52.710ms와 비교할 때 이번 표본에서 증가하지 않았으나, 수십ms 재생성 병목은 여전히 남는다. 실행 시점 차이를 분리한 통제 실험이나 모바일 측정이 아니므로 성능 문제가 해결됐다고 판단하지 않는다. [갱신 측정](assets/enemy_readability_2026-10-28/ui_performance.json).

같은 거리에서 큰 몸체가 모이면 상당 부분 가려질 수 있다. 모든 HP·상태와 개별 상세 접근은 유지하지만, 연결선과 포커스 강조만으로 사람이 빠르게 구분하는지는 플레이 테스트가 필요하다. Android 지속 FPS·기기 발열·손가락 가림·사람의 위험 이해도는 미검증이다. 성장/강적 장기 균형·탄약 경제와 이전 리액터 경로 탐색 문제도 이번 단계에서 닫지 않았다.

## 검사 기준 교정과 실행

- 기존 mobile_ui의 ‘성능 수정 전 모든 좌표와 동일’ 검사는 이번 개편의 의도와 충돌해1건 실패했다. 이웃의 이동·처치·압력탄 등장에도 남은 개체 기준점이 유지되는 검사로 교체해 재실행했다.
- 기존 distance_order는 모든 몸체가 같은 바닥 높이·직접 클릭 영역을 독점한다는 가정과 겹친 동일 거리에서 첫 배열 개체가 항상 표적이라는 가정을 갱신했다. 별도로, 기본탄을 주지 않은 손패에서 `load_basic`을 누르는 오래된 fixture 때문에4건 실패해 해당 손패를 수정했다. 실제 규칙의 추월·표적 일치는 유지한다.
- 기존 HUD 검사의 상시 거리 영역 조건을 제거하고 현재 HP/경고/상세·레이어·포커스 안정성으로 갱신했다. HP·아이콘·피해 숫자 간 충돌 검사는 유지했다.
- 오래된 eavesback 실행기는 import 단계의 루트 인증서 저장소 경고를 PowerShell 예외로 처리해 UI 실행 전 멈췄다. 숨김 프로세스에서 stdout/stderr를 분리하고 종료 코드·스크립트 오류를 검사하도록 수정한 후 통과했다. 최종 실행에도 `Failed to read the root certificate store` 환경 경고는 남았으며 스크립트 오류는 없다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode threat -Tag threat_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode threat_ui -Tag threat_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode rules -Tag threat_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode payoff_ui -Tag threat_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_distance_order_checks.ps1 -Stage after
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_eavesback_checks.ps1 -Mode hud
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode ui -Tag threat_solo_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode mobile_ui -Tag threat_solo_20261028
```

다음 독립 작업은5번 발열·연속 사격·고장 방식의 비교다. 확률 고장 도입은 확정하지 않았다. APK·커밋·푸시·외부 게시 없음.
