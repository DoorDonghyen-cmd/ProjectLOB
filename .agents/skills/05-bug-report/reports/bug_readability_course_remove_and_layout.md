# 학습 제거 한도와 피해 설명 레이아웃

Session `codex0913-ammo-readability`, 2026-09-13, 대상 `06fdd46` 위 구현 작업 트리. 두 항목 모두 보통 / Verified.

## READ-01 — 최소덱 2장인데 5장 덱의 제거가 거절됨

- 재현: 학습 모드, seed731042, 두 총기로 실제 첫 두 교전을 통과하여 덱5장 보상 상태. `choose_reward("remove", "charge")` 호출.
- 기대: 현재 최소2장을 초과하므로 제거 허용. 실제: false, UI와 모델 조건 불일치.
- 원인/수정: 모델의 고정 `<=6` 조건을 `minimum_deck()` 조회로 통일. 일반 최소6은 유지.
- 근거: 초기 `qa_runtime/readability_campaign/primary/campaign_report.json` removal_probes. 최종130제거probe 통과, 제거정책2개 캠페인 실제 완주. 독립 원본 `docs/qa/reports/readability_campaign_2026-09-13.md`.

## READ-02 — 긴 계산 설명이 장전 확정 버튼을 화면 밖으로 밀어냄

- 재현: 1280×800 또는 1920×864, 확장5칸 다수전에서 도약탄의 장갑/스침/보조피해 근거 표시.
- 기대: 핵심 행동 버튼이 현재 화면 안에 존재. 실제: 새 계산 Label이 탄창 하단 높이를 늘려 확정 버튼이 아래로 밀림. 최초 visual에서 두 viewport 경계 assertion 실패.
- 수정: 기존 탄환 설명 영역을 선택 탄 계산과 공유. 핵심 버튼 열에는 계산 Label을 추가하지 않는다.
- 검증: 최종 `readability_visual_runner.gd` 106/0, intro/boost/armor/shatter/full1280/fullphone/inspect/accuracy의 버튼경계, 실제 합성터치 조작. `docs/qa/reports/readability_visual_2026-09-13.json`와 독립 보존 PNG.

첫 visual의 저장재개 비교 1건은 JSON 숫자의 int/float 직렬화 차이였으며 양쪽 JSON정규화 전체상태 비교로 해결했다. 필드를 제외하지 않았다. 제품 저장 버그로 등록하지 않는다.
