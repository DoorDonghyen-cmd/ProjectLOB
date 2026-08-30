# ProjectLoB QA HTML 대시보드

## QA 테스트 실행

### 실행 파일로 시작

프로젝트 루트의 `ProjectLoB-QA.exe`를 더블클릭하면 컨트롤러가 시작되고 기본 브라우저에
대시보드가 자동으로 열린다. 함께 열린 콘솔 창을 닫거나 `Ctrl+C`를 누르면 컨트롤러가
종료된다. 이 실행 파일은 QA 프로젝트 파일과 Godot를 호출하는 런처이므로 저장소 밖으로
단독 복사해서 사용하는 배포본은 아니다.

필요하면 명령줄 옵션을 사용할 수 있다.

```powershell
.\ProjectLoB-QA.exe --check
.\ProjectLoB-QA.exe --probe
.\ProjectLoB-QA.exe --port 8877
.\ProjectLoB-QA.exe --godot "C:\path\to\Godot_v4.x-stable_win64_console.exe"
```

런처를 다시 만들려면 다음 명령을 사용한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_qa_launcher.ps1
```

### PowerShell로 시작

프로젝트 루트에서 아래 컨트롤러를 실행한 뒤 `http://127.0.0.1:8765/`로 접속한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\qa_dashboard_controller.ps1
```

Godot 자동 탐지가 되지 않는 환경에서는 실행 파일을 직접 지정할 수 있다.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\qa_dashboard_controller.ps1 `
  -GodotPath "C:\path\to\Godot_v4.x-stable_win64_console.exe"
```

대시보드의 `QA 테스트 시작`을 누르면 다음 작업을 순서대로 수행한다.

1. 전체 자동 회귀 테스트
2. 동일 빌드·시드에서 초보/공격/보수/실험 성향의 실제 메인 씬 플레이
3. 공개된 UI 상태만 사용한 행동·선택·중단 지점 분석
4. 재미·UX·밸런스 신호와 기능 버그 후보의 독립 통합
5. 실행 결과를 `runs/`에 보존하고 대시보드 이력 갱신

컨트롤러는 로컬 루프백에서만 수신하며 브라우저가 임의 명령이나 파일 경로를 전달할 수
없다. 각 실행은 별도 `APPDATA`, `LOCALAPPDATA`, Godot 사용자 폴더를 사용하므로 실제 플레이
세이브를 변경하지 않는다.

## 결과만 열기

`index.html`을 브라우저에서 직접 열면 최근 결과를 조회할 수 있다. 로컬 서버와 외부
라이브러리가 필요 없으며 `dashboard_data.js`를 일반 `<script>`로 읽기 때문에 `file://`에서도
동작한다. 단, 직접 연 상태에서는 실행 버튼을 사용할 수 없는 조회 전용 모드다.

## 데이터 흐름

1. `QATeamOrchestrator.integrate_from_directory()`가 세 독립 원본을 통합한다.
2. 같은 QA runtime 폴더에 `dashboard_run.json`과 `dashboard_data.js`가 자동 생성된다.
3. 보존할 `dashboard_run.json`을 이 폴더 아래 `runs/`에 이름이 겹치지 않게 둔다.
4. 아래 실행기로 전체 이력을 최신순 `dashboard_data.js`로 다시 생성한다.

```powershell
$env:QA_DASHBOARD_RUNS_DIR = "res://../docs/qa/dashboard/runs"
$env:QA_DASHBOARD_DATA_PATH = "res://../docs/qa/dashboard/dashboard_data.js"
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/qa_dashboard_history_runner.gd
```

직접 QA runtime 결과만 확인하려면 그 폴더의 `dashboard_data.js`를 이 폴더에 복사해도 된다.
이 경우 기존 실행 이력은 교체되므로, 장기 보존은 `runs/`와 이력 실행기를 사용한다.

## 표시 범위

- 최종 PASS/FAIL/REVIEW/BLOCKED
- commit, dirty worktree, seed, 플랫폼, 엔진
- PASS·확정 버그·경험 신호·인프라·보류·상충 수
- 자동 회귀 통과/실패/경보
- 역할별 독립 원본 보고 분포
- 전투 텔레메트리
- 판정 분류 필터와 검색
- 원본 리포트·fixture·워크스루 링크
- 이전 실행 이력 비교

대시보드는 판정을 새로 계산하지 않는다. 확정 버그와 경험 신호의 분류 정본은 QA 통합 JSON과
원본 리포트이며, HTML은 이를 필터링하고 시각화하기만 한다.

기능 버그는 실제 제품 런타임에서 같은 결함 지문이 2회 시도 중 2회 재현되어야 `FAIL`로
승격한다. seeded/synthetic 결함은 검출기 검증용으로만 따로 표시하며 제품 버그 수에 포함하지
않는다. 재미 신호는 총점으로 합산하지 않고 축별 행동 근거와 함께 `REVIEW`로 남긴다. 타격감,
오디오, 입력 피로도처럼 물리적 체감이 필요한 항목은 자동 합격 처리하지 않고 사람 확인 항목으로
유지한다.

## 파일

| 파일 | 역할 |
|---|---|
| `index.html` | 대시보드 구조와 접근성 landmark |
| `styles.css` | 반응형 레이아웃과 판정별 시각 언어 |
| `app.js` | 실행 선택·필터·검색·지표·이력 렌더링 |
| `dashboard_data.js` | `file://` 호환 실행 이력 데이터 |
| `runs/*.json` | 장기 보존할 실행별 원본 데이터 |

## 핵심 재미 판정 읽는 법

대시보드 상단의 **“이 게임의 탄환 순서 설계가 재미있는가?”** 패널이 이번 실행의 우선 결론이다. 자동 테스트 통과 수나 버그 수만으로 재미를 판정하지 않으며, 다음 다섯 질문을 각각 확인한다.

1. 같은 탄환 묶음의 순서가 실제 결과를 바꾸는가
2. 적과 상황에 따라 필요한 조합이 달라지는가
3. 혼합 장전이 기본탄 반복보다 가치가 있는가
4. 실제 캠페인에서 그 선택 압력이 발생하는가
5. 여러 시드와 충분한 전투에서 같은 구조가 반복되는가

판정은 총점이 아니라 독립 근거로 결정된다.

- `CORE_FUN_CONFIRMED`: 기계적 근거와 반복 표본이 모두 충분함
- `PROMISING_BUT_THIN`: 순서 퍼즐은 작동하지만 빈도·깊이·표본이 부족함
- `NOT_DEMONSTRATED`: 현재 근거로는 조합 재미가 입증되지 않음
- `STRUCTURAL_PROBLEM`: 순서나 혼합 장전이 결과에 의미 있는 차이를 만들지 못함

타격감, 장전 피로도, 재도전 욕구는 자동화가 객관적으로 확정할 수 없으므로 **사람 확인 필요**로 별도 표시한다. 현재 실행이 단일 시드라면 결과가 좋아도 `CORE_FUN_CONFIRMED`로 승격되지 않는다.
