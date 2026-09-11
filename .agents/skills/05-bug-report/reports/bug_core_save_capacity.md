# 버그 리포트 RD-02: 비정상 저장이 4칸 총기에 5발 계획을 허용

## 개요
2026-09-11 / 상태: Verified / 중요도: 보통 / prototype/core-redesign 전용 ID.

## 현상과 재현
문법상 유효한 저장에 plan 회수탄5개/supply9를 넣어 복원/확정하면 5발이 들어갔다. 정상 UI 생성 주장은 아님.

## 원인과 해결
복원 스키마/수량 검증 누락. 배열·범위·재고보존·계획/탄창 용량 검사와 confirm 자체 방어 추가.

## 검증
독립 2회 restore/confirm 거절 및 기존상태 보존, 정상계약25 유지.

원본/수정후 독립 기록: `docs/qa/reports/core_redesign_*_2026-09-11.md`. 통합 수정 기록: `docs/qa/reports/core_redesign_fixes_2026-09-11.md`.
