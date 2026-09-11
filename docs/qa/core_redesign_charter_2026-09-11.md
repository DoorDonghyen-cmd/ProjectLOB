# Core redesign QA charter

- 유형: 기능 집중 + 독립 경험 검토. 출시/아트 착수의 최종 재미 승인은 범위 밖.
- 대상: `prototype/core-redesign`, 기준 `f5da527` 위 새 `redesign/` 및 진입점 변경. main은 보존.
- 승인: 사용자 별도 작업 폴더 재설계 승인 및 더 재미있는 규칙 변경 위임.
- 고정 규칙: 7교전, 2총기, 8탄종, 5장 패, 3발 공급, 준비 1발, 밀기 탄창당 2m, 한 칸 파츠.
- 허용 환경 이슈: Windows root certificate store 읽기 경고. 새 저장은 QA별 APPDATA/LOCALAPPDATA에만.
- 검증 중 제품 소스/데이터 고정. 발견 결함은 원본 기록 후 별도 수정 및 재검증.
- 수학 담당: `core_redesign_combat_2026-09-11.md`.
- 공개 화면 담당: `core_redesign_experience_2026-09-11.md`. 구현/다른 QA 결론 비공개.
- 실제 UI 전체 경로 담당: `core_redesign_campaign_ui_2026-09-11.md`.
- 자체 규칙: `tests/redesign_rules_runner.gd`.
- 완주 탐색: `tests/redesign_campaign_runner.gd`, 강제 승리 금지. 결과를 사용자 승률로 표현하지 않음.
- 렌더: `tests/redesign_visual_runner.gd`. 마지막 교전 숏컷 캡처는 화면 fixture로 표시.
- 기존 foundation: `tests/run_all.gd` 회귀.

후속 사람 검증은 같은 시드로 두 총기를 비교하고, 스스로 순서를 바꿔 해결한 순간 / 비용 오해 / 보상으로 달라진 계획 / 반복 계산 피로 / 다시 하고 싶은 이유를 기록한다. 이 질문의 답을 자동 경로에서 추정하지 않는다.
