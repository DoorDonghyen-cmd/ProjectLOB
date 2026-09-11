# 버그 #026: 전투 중 추가 장전 후 일부 닫기 경로에서 적 전진 비용 누락

- 상태: `Verified` (사용자 Closed 확인 대기)
- 생성/수정: 2026-09-11
- 중요도: 높음
- 세션: `codex0911-tactical-workbench`

## 현상·원인
패널의 상단 닫기 및 소모품 사용 후 닫기가 toggle_drawer(false)를 직접 호출해 CombatOverlayV2의 apply_bullet_insertion_tax를 실행하지 않는다.

## 수정
모든 사용자 닫기 경로를 overlay._toggle_drawer로 통일한다. 초기화 시 단순 숨김은 유지하고 중복 닫기는 비용 플래그로 재과금하지 않는다.

## 검증
실제 UI54검증: 카드 viewport입력, 확정/발사 분리, 전장보기·탭닫기·확정닫기3경로의 추가 장전/실제 전진/플래그 해제 및 중복과금 없음 확인.

[상세 검증 보고](../../../../docs/walkthrough_tactical_workbench_2026-09-11.md)
