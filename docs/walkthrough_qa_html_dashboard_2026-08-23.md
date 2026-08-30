# 전용 플레이 QA HTML 대시보드 워크스루

> 세션 ID: `codex0823-qa-dashboard`
> 완료일: 2026-08-23

## 결과

[QA 대시보드](qa/dashboard/index.html)를 브라우저에서 직접 열면 서버나 설치 없이 최신 QA 결과와
이전 실행을 비교할 수 있다. 초기 데이터에는 Phase F 독립 팀 검증과 Phase E 4프로필 검증을 포함했다.

화면은 다음 정보를 제공한다.

- 최종 PASS/FAIL/BLOCKED와 판정 사유
- commit·dirty snapshot·session·seed·플랫폼·Godot 버전
- PASS·확정 버그·경험 신호·인프라·보류·상충 요약
- 자동 회귀 통과/실패/경보와 비율
- 최근 인간 로그의 발사·명중·유효타·피해·과잉 피해·최소 거리·리로드
- 기능 QA·경험 테스터·전투 시뮬레이터의 독립 원본 분포
- 판정 분류 필터, 텍스트 검색, 실행 이력 선택
- 통합 리포트·원본 보고·샘플 fixture·워크스루 링크

## 자동화

`qa_dashboard_exporter.gd`가 통합 결과를 검증 가능한 실행 이력 JSON으로 바꾸고,
`qa_team_orchestrator.gd`가 세 원본 통합 성공 시 `dashboard_run.json`과 `dashboard_data.js`를 자동 생성한다.
`qa_dashboard_history_runner.gd`는 보관된 여러 실행 JSON을 최신순 HTML 데이터로 묶는다.

HTML은 이 데이터를 다시 판정하지 않는다. 예를 들어 경험 QA의 SIGNAL이 HTML에서 FAIL로 승격되거나,
headless PNG INFRA가 제품 버그에 포함되는 경로가 없다.

## 검증

- Godot 전체 회귀: **3,582 통과 / 0 실패 / 기존 경보 3**
- 스크립트 스캔: 115개 전부 컴파일 성공
- Node `--check`: `app.js`, `dashboard_data.js` 구문 통과
- Chrome headless: 1440×1100 데스크톱 렌더와 390×844 소형 화면 렌더 생성·육안 확인
- `git diff --check`: 오류 없음

## 운영

상세 경로와 이력 갱신 명령은 [대시보드 README](qa/dashboard/README.md)에 기록했다.
향후 QA 팀 실행에서는 runtime의 `dashboard_run.json`을 `docs/qa/dashboard/runs/`에 보관하고
history runner를 실행하면 기존 이력을 유지한 채 화면을 갱신할 수 있다.
