# 전용 플레이 QA HTML 대시보드 구현 계획

> 세션 ID: `codex0823-qa-dashboard`
> 작성·완료일: 2026-08-23
> 상태: 구현·검증 완료

## 목적

QA 팀의 독립 원본과 통합 판정을 사람이 한 화면에서 비교할 수 있도록 오프라인 HTML 대시보드를 제공한다.
대시보드는 판정을 다시 계산하지 않고 기존 QA 통합 결과를 읽고 표현하는 관제 화면으로 한정한다.

## 설계

### 데이터 계층

- `QADashboardExporter`가 통합 summary와 빌드 metadata를 schema v1 실행 이력으로 변환한다.
- PASS/FAIL/SIGNAL/INFRA/BLOCKED는 `QATeamIntegrator` 분류를 그대로 사용한다.
- commit, dirty worktree, seed, 플랫폼, 엔진, 회귀 수, 전투 지표, 역할별 분포와 증거 링크를 보존한다.
- `dashboard_run.json`은 실행별 정본, `dashboard_data.js`는 `file://`에서 읽기 위한 렌더 입력이다.
- 여러 실행 JSON은 history runner가 최신순으로 묶는다.

### 표현 계층

- 외부 서버와 외부 JavaScript/CSS 라이브러리를 사용하지 않는다.
- 최신 최종 판정, 빌드 추적, 자동 회귀, 전투 텔레메트리, 독립 역할 보고를 상단에 배치한다.
- 판정 항목은 분류 필터와 텍스트 검색을 제공한다.
- 원본 리포트·fixture·워크스루로 이동할 수 있는 상대 링크를 제공한다.
- 실행 이력 행이나 상단 선택기로 이전 결과를 즉시 전환한다.
- 데스크톱 2열과 소형 화면 1열에 대응하고 키보드 포커스와 skip link를 유지한다.

### QA 통합 연결

`QATeamOrchestrator.integrate_from_directory()`가 통합 성공 뒤 다음 파일을 같은 QA runtime 폴더에 생성한다.

- `integrated_summary.json`
- `dashboard_run.json`
- `dashboard_data.js`

대시보드 내보내기가 실패해도 QA 통합 판정을 변조하지 않고 `summary.dashboard.errors`에 인프라 오류로 남긴다.

## 테스트

- 실행 이력 필수 필드와 최종 PASS/FAIL/BLOCKED 검증
- 통합 분류별 수와 역할별 원본 보고 집계
- 회귀 실패가 있으면 HTML 최종 판정 FAIL 고정
- JSON 저장·이력 최신순 로드·file 프로토콜용 JavaScript 생성
- QA 팀 통합 완료 시 대시보드 두 파일 자동 생성
- 전체 Godot 스크립트 컴파일과 회귀
- Node JavaScript 구문 검사
- Chrome headless 1440×1100 데스크톱 및 390×844 소형 화면 렌더 캡처 확인

## 완료 조건

- `index.html`을 직접 열었을 때 별도 서버 없이 최신 결과를 볼 수 있다.
- 판정 분류가 기존 QA 통합 결과와 다르게 재해석되지 않는다.
- 과거 실행을 선택하고 분류·텍스트로 판정 항목을 찾을 수 있다.
- 게임 코드와 사용자 세이브를 변경하지 않는다.
- 전체 회귀가 실패 0으로 통과한다.
