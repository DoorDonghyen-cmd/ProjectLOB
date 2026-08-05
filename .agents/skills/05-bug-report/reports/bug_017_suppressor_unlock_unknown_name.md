# 🐛 [버그 리포트] #017. 제압형 해금 정산에서 무기명이 알 수 없음으로 표시됨

## 1. 개요 (Overview)
*   **제보 일시**: 2026-08-05
*   **상태**: `Open`
*   **중요도**: `낮음`
*   **관련 컴포넌트**: 디브리핑 UI, 무기 해금

## 2. 현상 설명 (Description)
*   제압형(`suppressor`) 해금 조건을 달성하면 해금 자체는 처리되지만 디브리핑의 신규 무기명이 `알 수 없음`으로 표시된다.

## 3. 재현 경로 (Steps to Reproduce)
1. 미해금 상태에서 탄창을 한 발도 남기지 않고 비운 채 전투에서 승리한다.
2. 런 종료 후 디브리핑의 신규 화기 해금 문구를 확인한다.
3. 제압형 이름 대신 `알 수 없음`이 표시되는 것을 확인한다.

## 4. 원인 분석 (Root Cause)
*   `RunManager.check_weapon_unlocks()`는 `suppressor`를 반환하지만 `debriefing_overlay.gd`의 무기명 `match` 목록에는 `suppressor` 분기가 없다.

## 5. 해결 방안 (Resolution)
*   미적용. 디브리핑이 `LoadoutOverlay.WEAPON_PROFILES`의 표시명을 재사용하도록 단일화하거나 최소한 `suppressor` 매핑을 추가한다.

## 6. 검증 내용 (Verification)
*   미검증. 정적 코드 감사로 누락을 확인했다.
