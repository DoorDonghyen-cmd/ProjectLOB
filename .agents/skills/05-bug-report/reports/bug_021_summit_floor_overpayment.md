# 버그 #021: 최종 관문 뒤 36층으로 메타 보상 과다 정산

- 제보/수정: 2026-09-11
- 상태: `Verified` (사용자 Closed 확인 대기)
- 중요도: 높음
- 세션: `codex0911-preart`

## 현상과 원인
5계층 마지막 관문 완료 뒤 current_floor=9 sentinel을 누적층에 포함해36층/590Cr로 정산했다. 독립 캠페인2회 재현.

## 수정
total_floors_climbed를 total_run_length=35로 제한해35층/575Cr 계약 복구.

## 검증
suite_continuous_run 및 캠페인35노드24검증 통과. 메타 저장/reload, 승천 해금, 타이틀 재시작 확인. 전투는 승리 fixture.

상세 근거: [기능 검토 보고서](../../../../docs/walkthrough_preart_completion_2026-09-11.md).
