# VIS-01: 전장 글자 중첩

2026-09-11 / Verified / 보통 / prototype/core-redesign 범위.

## 재현과 원인
1280x800 개발자 최종 교전의 세 적 정보에서 이전 적의 속도와 다음 이름 간격이 좁았다. 16m 적 도탄/빗나감 문구는 위쪽 거리 눈금과 겹쳤다. 고정 행 간격에 비해 글자 기준선이 크고 피격 문구를 적 위에 배치했다.

## 수정과 검증
정보 행의 기준선을 조정하고 피격 문구를 적 옆의 여유 공간에 배치했다. 최종 화면43/0·연출39/0 및 재생 캡처 직접 확인. 모델 변경 없음.

원본 `docs/qa/reports/visual_combat_experience_2026-09-11.md`, 후속 `visual_combat_experience_recheck_2026-09-11.md`. 수정 전 캡처는 qa_runtime/visual_before_revision, 수정 후 캡처는 docs/qa/screenshots/visual_combat_*_20260911.png. 정지 화면 검토를 인간 플레이의 피로/재미 검증으로 취급하지 않는다.
