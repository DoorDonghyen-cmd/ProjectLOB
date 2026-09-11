# 버그 #023: 첫 장전 화면에서 사용할 수 없는 리로드 안내

- 제보/수정: 2026-09-11
- 상태: `Verified` (사용자 Closed 확인 대기)
- 중요도: 보통
- 세션: `codex0911-preart`

## 현상과 원인
첫 교전 신호가 LOADING 상태 전환보다 먼저 발생해 빈 탄창 설명에 리로드 필요 문구가 남았다.

## 수정
빈 LOADING 안내를 가방 장전으로 변경하고 loading_phase_started에서 갱신.

## 검증
첫 구현 회귀 실패를 확인한 뒤 상태 진입 갱신 수정. suite_ui_smoke 최초 장전 안내와 최종3690/0 및 실제 화면 확인.

상세 근거: [기능 검토 보고서](../../../../docs/walkthrough_preart_completion_2026-09-11.md).
