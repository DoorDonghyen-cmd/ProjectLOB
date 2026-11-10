# 성장·파츠 발동 체감 1차 — 2026-10-28

[통합 우선순위](../../direction/playtest-priorities.md)3번의 첫 적용이다. **전투 수치는 유지하고 강화의 원인·결과를 표시했으며, 실제 계산과 다른 성장 안내를 수정했다.** 사람의 재미와 장기 강적 균형까지 완료한 상태는 아니다.

## 변경

- 연쇄/복열은 분리된 궤적과 연속 타격 흔적, 돌파/후미는 긴 궤적과 좌우 충격, 열압은 잔열 궤적과 확산 흔적으로 구별한다. 실제 `part_effects`와 적중 결과를 사용한다. 발동하지 않은 파츠, 전부 막힌 코어 공격에 강화 성공을 붙이지 않는다.
- 전장 왼쪽에 대표 발동과 실제 사격 피해·처치 합계를 표시한다. 사격 후에도 `직전`으로 남기고 탄창 아래에는 발동한 파츠 이름을 보인다. 재장전/새 교전에서 이전 결과를 지운다. 지원탄은 다음 공격 증폭 등 지원 효과로 표시한다.
- 합계는 주 타격/후속의 실제 피해이며 파츠별 추가 HP 피해를 역산하지 않는다. 처치 대상은 중복을 제거하고 투사체를 제외한다. 복열의 타격 횟수에는 실제 잔타 전달을 포함하고 전기 전이 등은 제외한다.
- 코어 성장 결과를 `타격 +1 → 타격 +2`, `단타 ×2.00 → 단타 ×2.15`처럼 전후 값으로 표시한다. 연쇄의 홀수 성장에는 `성장 축적 1/2 · 다음 성장 시 타격 +N`을 보인다.
- **발견한 문구 결함:** 첫 코어 선택 화면은 현행 수치에서도 `매번 타격 +1 / 배율 +0.25`라는 옛 고정 문구를 사용했다. 현재 버전1/2는 `2회 성장마다 타격 +1 / 배율 +0.15`, 이전 버전0은 원래 수치를 계산에서 가져오도록 수정했다.
- 별도 파티클 노드나 상시 애니메이션을 추가하지 않았다. 적중 도형은 숫자 아래로 배치하고 피해 표시 경계를 한 프레임에 한 번 계산해 재사용한다. 연출 축소/즉시 보기/건너뛰기에서 실제 결과를 보존한다.

## 성장·강적 비교

현행 `combat_revision=2`로 같은 무기, 코어 성장0/4/8, 무리/장갑/보스, 맞춤/무관/빈 모듈, 조합탄/기본탄의162조건을 실제 모델과 예측으로 비교했다. **변경 전후162조건의 결과 행은 모두 동일**하다. 실제 HP 감소를 사용하며 빌드 간 획득 비용까지 동일하다는 실험은 아니다.

성장0→8, 맞춤 파츠와 조합탄의 비교:

| 조합 | 무리 피해 / 처치 / 소모 턴 | 장갑 대상 피해 | 보스형 대상 피해 |
|---|---|---|---|
| 연쇄·시퀀서·복열 | 60 / 2기 / 4턴 → 74 / 3기 / 1턴 | 34 → 50 | 44 → 64 |
| 돌파·시퀀서·후미 | 36 / 1기 / 1턴 → 57 / 2기 / 1턴 | 36 → 57 | 36 → 57 |
| 열압·시퀀서·회수 | 36 / 0기 / 4턴 → 52 / 1기 / 1턴 | 22 → 38 | 27 → 48 |

성장으로 처치선과 냉각/과열 부담이 달라지는 경우를 확인했다. 보스형에서는 한 번의 사격으로 처치하지 못하는 경우도 있어 피해량만으로 재미나 난이도 해결을 주장하지 않는다. 이번 단계에서 적 HP·장갑·패턴·탄환 피해를 추가 조정하지 않았다. 이전 리액터 경로의 탐색 한계와 획득·탄약 경제는 계속 후속이다.

## 검증

Windows / Godot4.7 stable `5b4e0cb0f` / OpenGL Compatibility / RTX4060Ti. `qa_runtime/playtest_revision_20261026/`와 `qa_runtime/damage_engines/`로 APPDATA/LOCALAPPDATA를 격리했다. 기존 작업 트리를 보존했다.

| 검사 | 결과 |
|---|---|
| 새 발동·집계·성장 안내, 이전 규칙/저장, 지원/차폐/투사체/중복 처치 | 223검사 실패0 |
| 실제 화면·터치,3조합×3화면, 빠르게/즉시/건너뛰기, 성장/코어 선택 | 445검사 실패0 |
| 대표162조건 전후 비교·예측 정합성 | 756검사 실패0 |
| 장갑·강행·강적 회귀 | 449검사 실패0 |
| 기존 상태·예측 회귀 | 273검사 실패0 |
| 성장 코어·저장 회귀 | 657검사 실패0 |
| 실제 등반에서 획득한 초반/후반 상태의 UI·실행 | 113검사 실패0 |
| 저장·배치·대기 렌더링·화면 재생성 | 142검사 실패0 |

합계3,058검사 실패0. 이번에는 새 전체 등반 탐색을 수행하지 않았다. 전투 수치의 동일성과 기존 획득 상태의 예측/실행을 검사했으며, 지난 관문 개편의 전체 등반 결과를 이번 신규 실행으로 집계하지 않았다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode payoff -Tag payoff_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode payoff_ui -Tag payoff_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode builds -Tag payoff_20261028 -Revision 2
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode pressure -Tag payoff_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode rules -Tag payoff_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_damage_engines_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode ui -Tag payoff_solo_20261028
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode mobile_ui -Tag payoff_solo_20261028
```

자료: [발동 규칙](assets/build_feedback_2026-10-28/payoff.json) · [UI](assets/build_feedback_2026-10-28/payoff_ui.json) · [162조건 전](assets/build_feedback_2026-10-28/builds_before.json) / [후](assets/build_feedback_2026-10-28/builds_after.json) · [UI 측정](assets/build_feedback_2026-10-28/ui_performance.json) · [저장·대기 측정](assets/build_feedback_2026-10-28/metrics.json) · [소스 SHA256](assets/build_feedback_2026-10-28/source_hashes.json).

## 실제 화면

1008×630/1280×800/1440×630 창에서 프로젝트의1280×800 기준 확장 정책으로 확인했다. 테스트용 조합 화면이며 자연 획득 장면으로 표시하지 않는다. 실제 애니메이션 프레임과 최종 화면을 직접 확인했다.

- [복열 발사 궤적](assets/build_feedback_2026-10-28/volley_1008_trail.png) · [적중](assets/build_feedback_2026-10-28/volley_1008_impact.png) · [사격 후 결과](assets/build_feedback_2026-10-28/volley_1008_result.png)
- [후미·돌파 궤적](assets/build_feedback_2026-10-28/siege_1008_trail.png) · [후미 적중](assets/build_feedback_2026-10-28/siege_1008_impact.png) · [긴 화면 결과](assets/build_feedback_2026-10-28/siege_1440_result.png) · [열압 적중](assets/build_feedback_2026-10-28/thermal_1008_impact.png)
- [현재 규칙의 코어 선택](assets/build_feedback_2026-10-28/core_rules_2.png) · [성장 축적](assets/build_feedback_2026-10-28/growth_1.png) · [타격 강화 전후](assets/build_feedback_2026-10-28/growth_2.png)

## 성능·검사 교정·남은 일

- UI 검사의 초기 설정이 프로젝트 확장 정책을 없애1008폭을 논리 뷰포트로 강제하면서 발사 버튼이 화면 밖으로 나갔다. 실제 프로젝트 확장 정책과 기존 터치 좌표 변환으로 교정했다. 테스트 스크립트의 타입 추론 오류도 수정 후 재실행했다.
- 옛 성장 저장 검사는 전투를 끝내지 않고 캠페인만 보상 상태로 바꿔 저장했다. 현재2단계 첫 보상에서 올바르게 거절되는 상태였다. 적을 정리하고 전투 결과를 동기화한 QA fixture로 고친 뒤657검사가 통과했다. 제품 저장 검증을 느슨하게 만들지 않았다.
- UI 검사를 동시에 실행한 시간 측정은 최종 비교에 쓰지 않고 단독 실행했다. PC 후반 잔열 화면의 다시 그리기 약19~21회/초, 프레임 중앙값 약6.06ms, 장비 대기 렌더 호출111로 이전 최적화 수준을 유지했다. 짧은 PC 표본이며 모바일 FPS/발열을 뜻하지 않는다.
- **전체 화면 재생성 비용은 남는다.** 이번 단독 표본 후반 래칫57.2ms/스플린터52.7ms로 이전 보고서의 약47~50ms보다 높다. 실행 시점 차이와 변경 비용을 분리한 대조 실험은 아니므로 원인이나 무회귀를 단정하지 않는다. 모바일 지속 성능과 함께 추적한다.
- 루트 인증서 저장소 경고 외 실행 오류는 최종 로그에서 발견하지 않았다. Android 실기기·사람의 성장/파츠 인지·재미는 미검증이다. 다음 독립 구현은 적 이동·겹침·위협 표시이며, 성장/강적의 수치와 장기 탄약 경제 판단은 후속 플레이 결과와 함께 이어간다.

APK·커밋·푸시·외부 게시를 수행하지 않았다.
