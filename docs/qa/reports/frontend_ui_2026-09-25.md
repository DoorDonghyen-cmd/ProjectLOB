# 타이틀·출격 준비 UI QA

## 범위

타이틀 홈, 새 등반 진입, 총기 5종 선택, 선택 총기 쇼케이스, 시작 보급·난도·시드, 훈련 준비, 출격, 저장 교체 확인, 모바일 가로 레이아웃을 검증했다.

## 결과

| 검증 | 결과 |
|---|---:|
| 전체 회귀 | 3,730 통과 / 0 실패 |
| 프런트 실제 렌더·입력 | 33 통과 / 0 실패 |
| 총기 선택 UI | 290 통과 / 0 실패 |
| 저장·설정·뒤로 가기 UX | 32 통과 / 0 실패 |
| 최신 도시 UI 재생 | 3,698 통과 / 0 실패 / 1,186 입력 |

최신 도시 기준 기록으로 보행자와 쇄도 35층을 각각 완주했다. 2026-09-16의 오래된 캠페인 기록은 이후 전투 밸런스 변경으로 정산 상태가 달라 현재 UI 회귀 기준에서 제외했다.

## 시각 증거

- `qa_runtime/frontend_ui_20260925/artifacts/frontend_title.png`
- `qa_runtime/frontend_ui_20260925/artifacts/frontend_loadout_default.png`
- `qa_runtime/frontend_ui_20260925/artifacts/frontend_loadout_confirm.png`
- `qa_runtime/frontend_ui_20260925/artifacts/frontend_loadout_phone.png`
- `qa_runtime/frontend_ui_20260925/artifacts/frontend_training.png`

## 남은 사람 확인

실제 갤럭시에서 첫 실행 시 `새 등반 준비`를 주 행동으로 바로 인식하는지, 총기 5종을 비교한 뒤 최종 출격 버튼까지 스크롤하는 흐름이 자연스러운지 확인한다. APK는 명시 요청 시에만 제작한다.
