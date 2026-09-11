# 버그 #025: 실제 전투의 적 복제가 CSV 기준 스탯을 누락

- 상태: `Verified` (사용자 Closed 확인 대기)
- 생성/수정: 2026-09-11
- 중요도: 높음
- 세션: `codex0911-tactical-workbench`

## 현상·원인
EnemyData.duplicate의 resource_path가 비어 EnemyInstance CSV 조회가 실패한다. 돌격병이HP6/거리10 대신HP8/거리8, 굴절병이HP8/거리9 대신HP6/거리10으로 생성된다. 독립 프로브2회 재현.

## 수정
EnemyData.for_encounter가 원본 CSV를 복제본에 반영한 다음 거리 보정을 적용한다. 원본 리소스와 합성 QA 적은 보존한다.

## 검증
13적×3계약+합성1=40회귀. 전체3730/0, 별도 직접/준비경로·승천/위험도/대열 순서 재검증 및 후반10조건 승리증거2회 일치.

[상세 검증 보고](../../../../docs/walkthrough_tactical_workbench_2026-09-11.md)
