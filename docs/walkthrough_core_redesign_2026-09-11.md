# 핵심 재설계 — 플레이 가능한 7교전 프로토타입

## 실행과 비교
- 새 실행 파일: `builds/redesign-windows/Play-Redesign.cmd` (이 worktree 기준).
- Godot 프로젝트: `새-게임-프로젝트/project.godot`, 독립 시작 씬 `redesign/main.tscn`.
- 브랜치: `prototype/core-redesign`, 폴더 `D:/ProjectLoB/worktrees/core-redesign`.
- 원본: main `f5da527`, `D:/ProjectLoB/builds/preart-windows/Play-Preart.cmd` 보존.
- 새 실행 파일 SHA256: `1BECF514BBEA98FCFBC79B1D0A394962CED90E3B16954449839FC37B077200FC`.
- Windows 실행 파일 126,647,696 bytes. 내장 PCK, 별도 설치 없이 런처로 실행. export 및 실행 파일 headless 시작 검사 통과.

사용자가 승인한 별도 브랜치 개발과 규칙 변경 위임으로 만든 첫 채택 후보이다. 기존 35층 게임의 개선판과 달리, 적은 콘텐츠 안에서 순서 설계의 차이를 비교하는 독립 런이다. main 병합이나 원격 업로드는 하지 않았다.

## 플레이 규칙
| 항목 | 이번 실험 |
|---|---|
| 핵심 | LIFO, 가까운 적 자동 표적, 명중/관통 임계값, 거리 0 즉시 패배 |
| 단발 총기 | 4칸, 피해 +1, 한 발 1턴, 재장전 1턴 |
| 일제 총기 | 4칸, 전탄 1턴, 재장전 3턴, 발마다 표적 재선정 |
| 후보 | 전술 패 5장, 다음 최대 2장 예고, 미사용 패 유지, 사용탄 순환 |
| 공급 | 회수탄 재장전마다 3발, 공급 파츠 사용 시 4발 |
| 계획과 실행 | 계획 중 무료 취소, 확정 후 발사 또는 유료 재장전 |
| 준비탄 | 명중 여부와 무관하게 다음 한 발에만 효과, 다음 발에 소비, 재장전 시 제거 |
| 제어 | 명중 시 밀기/둔화, 밀기 탄창당 총 2m, 둔화 다음 전진 1회 |
| 콘텐츠 | 총기 2, 탄환 8, 적 전술 유형 3, 교전 7, 파츠 3종 중 1개 장착 |
| 보상 | 다음 적 공개 후 탄환 추가 / 파츠 교체 / 덱 유지 / 1장 정제 중 선택 |
| 저장 | 행동 후 자동 저장, 중간 계획/확정 상태 재개, 같은 시드 재시도 |

기존의 전투 중 삽탄, 무료 추출 예외, 긴급 격퇴, 영구 메타 성장은 이번 짧은 실험에서 제외했다. 단발에 효과 없는 재장전 감소 파츠도 보상에서 제외한다. 보상 수치는 기본값과 현재 총기·파츠 적용값을 구분한다.

## 구현
- 기존 프로젝트와 `DamageCalculator`, `BulletData`, 한글 폰트를 재사용했다. 원래 전투 매니저의 메타/구경/해금 결합은 새 모델에 넣지 않았다.
- `redesign/content.gd`: 독립 탄환/총기/적/교전/보상 데이터.
- `redesign/model.gd`: 검증된 명령, 상태 전이, 효과, 손패 순환, 같은 함수로 계산하는 다음 한 발 예측, 저장/검증.
- `redesign/screen.gd`: 메뉴, 통합 장전, 전투, 다음 교전 공개 보상, 결과, 규칙, 개발자 연습.
- 저장은 `Last on Board - Core Redesign/core_redesign_run.json`. 런처는 실행 폴더의 `qa-profile`로 APPDATA를 분리한다. 연습 및 연습 재시도는 일반 진행을 저장하지 않는다.
- 시드와 RNG 상태를 문자열로 저장해 64비트 정밀도를 보존한다. 저장 복원 시 탄창 용량·배열·적 수치·탄환 재고 보존을 검증한다.

## 검증 결과
| 검증 | 결과 | 범위 |
|---|---|---|
| 신규 규칙 | 48 통과 / 0 실패 | LIFO, 비용, 효과, 재고, 큰 시드, 잘못된 저장, 재개 |
| 독립 전투 감사 수정 후 | 37 통과 / 0 실패 | 정상 계약 25 + 결함/파츠 확인 12 |
| 실제 렌더 UI | 43 통과 / 0 실패 | 메뉴·장전·첫 실제 보상·규칙·작은 창·연습 재시도 |
| 완주 탐색+실제 명령 재생 | 6 / 6 완주 | 두 총기 × 시드 731042, 42, 901; 강제 승리 없음 |
| 전체 UI 런 | 493 검사 / 0 실패, 214 버튼 | 두 총기 각 7교전, 4교전 중간 저장/재개, 실제 승리, 재시도/메뉴 |
| 기존 foundation 회귀 | 3730 통과 / 0 실패 / 기존 경보 3 | 기존 시스템 보존. 제목으로 옮겨진 안내를 본문에서 찾던 assertion 정정 |
| Windows export | 통과 | 실행 파일 생성, headless 시작, 저장 프로필 분리 |

실제 UI 완주(시드 731042)는 단발 42턴/36발/재장전 6회, 일제 39턴/51발/재장전 8회였다. 이는 탐색된 경로를 버튼으로 재현한 증거이며 사람의 승률이나 정답 강제 정책이 아니다.

독립 검토에서 큰 시드 정밀도 손실, 비정상 저장의 과대 장전을 발견하고 수정했다. 시드 라벨·보상 수치 기준·행동 버튼 노출·규칙 창 높이도 보완했다. 원본 및 수정 후 보고는 `docs/qa/reports/core_redesign_*`에 분리 보관한다. UI 저장 비교의 JSON 정수/실수 형식 차이는 QA 인프라 문제로 별도 기록했다.

## 재현
```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_redesign_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_redesign_checks.ps1 -Mode campaign
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_redesign_checks.ps1 -Mode visual
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_redesign_checks.ps1 -Mode ui_campaign
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_redesign_checks.ps1 -Mode regression
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_windows_redesign.ps1
```
`ui_campaign`은 먼저 생성한 `campaign` JSON의 경로를 사용한다. 원본 로그·스크린샷은 `qa_runtime/redesign/` 및 독립 감사 폴더에 있다. 주요 결과와 대표 화면은 `docs/qa/`에 추적한다.

## 남은 판단
사람이 느끼는 순서 설계의 성공감, 반복 계산 피로, 두 총기/보상 간 균형, 전체 시드와 덱 선택의 난이도는 미확정이다. Android 실기 및 최종 아트·오디오 제작도 이번 Windows 프로토타입의 완료 범위에 포함하지 않는다. 자동 결과를 근거로 최적의 재미나 아트 착수 최종 승인을 주장하지 않는다.
