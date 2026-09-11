# 버그 리포트 RD-04: 개발자 연습에서 같은 시드 재시도 시 저장 경계 해제

## 개요
2026-09-11 / 상태: Verified / 중요도: 보통 / prototype/core-redesign 전용 ID.

## 현상과 재현
개발자 연습 종료 화면의 같은 시드 재시도가 일반 시작 함수에서 debug_session=false로 전환하는 경로를 코드 점검에서 확인.

## 원인과 해결
일반 시작과 재시도가 같은 세션 초기화 사용. 같은 시드 재시도에서는 연습 상태 유지.

## 검증
연습 종료 화면 fixture에서 실제 retry 버튼 후 debug_session 유지 검증. 정상 전체런 재시도/저장 재개도493검사 통과.

원본/수정후 독립 기록: `docs/qa/reports/core_redesign_*_2026-09-11.md`. 통합 수정 기록: `docs/qa/reports/core_redesign_fixes_2026-09-11.md`.
