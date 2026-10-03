# 현행 검증 경로

2026-10-03. `새-게임-프로젝트/redesign`이 현행 게임이다. 검사 이름에 regression이 있다는 이유만으로 현행 게임 전체를 검증했다고 쓰지 않는다.

| 범위 | 실행 경로 | 의미 |
| --- | --- | --- |
| 빌드 통제 비교 | `tools/run_progression_checks.ps1 -Mode balance` | 720사례, 실제 모델·8개 고정 정책. 파츠 개수/미래 RNG/교환 미탐색의 한계를 보고한다 |
| 첫 지역·파츠·경제 규칙 | 위 명령의 `-Mode rules` | 24시드×5무기·4시작보급, 첫 패 소유권/RNG, 소개 순서, 진열 다양성, 정확한 비용·저장·교환 예산 |
| 현행 전체 캠페인 기준 기록 | 위 명령의 `-Mode campaign` | 5무기×2경로·35층, 매 명령 저장 복원. 후보 제한800의 기능 탐색이며 사람 승률이 아님 |
| 첫 지역·상점 실제 조작 | `tools/run_director_ui_checks.ps1 -Mode progression` | 세 비율/큰 글자·실제 경로 선택·첫 조합·구매/잔액/진열 비용·파츠 상세 |
| 파츠·조합 피드백 | `tools/run_director_ui_checks.ps1 -Mode feedback` | 실제 발동/예상 슬롯, 보호·화상 상한·처치, 저장·이전 기록, 교전 분리, 순서/파츠 비교, 산개 조건·장착 캐시, 세 비율 5파츠·터치·명중·건너뜀·보상 |
| 조합 편집·결과 전달 | `tools/run_director_ui_checks.ps1 -Mode interaction` | 다음 발사/전체 탄창 범위, 고정 손패, 터치 드래그와 버튼 순서 변경, 앵커 제약, 압축 취소, 단일 구매, 교체 효과 손실, 접힌 설정·시작 탄환 상세 |
| 현행 무기·탄환·파츠 규칙 | `tools/run_weapon_checks.ps1 -Mode rules` | `weapon_rules_runner.gd`, 헤드리스 규칙 검사 |
| 무기 선택·실제 입력·최대 탄창 | `tools/run_director_ui_checks.ps1 -Mode weapons` | 5종 무기, 저장 보호, 화면 경계, 실제 렌더 |
| 메인·출격 준비 | `tools/run_director_ui_checks.ps1 -Mode frontend` | 주 행동과 화면 전환 |
| 비전투 선택·교체 흐름 | `tools/run_director_ui_checks.ps1 -Mode navigation` | 세 가로 비율의 실제 터치, 무기별 시작 보급 일치, 고정 상점 비교, 코어 교체/거부/저장 복원, 모든 보관 파츠 접근, 분해 취소, 이어하기/새 등반 보호, 키보드 초점 복원 |
| 후반 6칸 탄창 | `tools/run_director_ui_checks.ps1 -Mode city` | 소유권이 유효한 캠페인 상태 재생 |
| 전체 캠페인 UI | 위 city 명령에 `-FullCampaign` | 지도·상점·보상·장비·압축·캠페인 재생 |
| 전체 자산·상점·다섯 장착·연출 | `tools/run_director_ui_checks.ps1 -Mode production` | 현행 자산, 구매 예측, 작은 화면 배치, 실제 결과와 발사 연출 정합성 |
| 세 화면 비율·6장 손패 | `tools/run_director_ui_checks.ps1 -Mode layout` | 불필요한 전투 스크롤·핵심 조작 경계 검사 |
| 첫 도트 전투 화면 | `tools/run_director_ui_checks.ps1 -Mode pixel` | 적 4종·손패 6장·접지·밀집·명찰 경계·실제 장전/발사·상세 입력·세로 위치 안정성 |
| 역사 버전 호환 | `tests/run_all.gd` | 구형 `scripts/`·LIFO·CSV·레거시 UI 포함. 현행 재미 기준으로 사용하지 않음 |

모든 검사는 격리된 `qa_runtime` 저장을 사용한다. UI 검사는 실제 렌더러로 실행한다. 자동 완료 수는 가독성 점수나 재미 점수가 아니다. 한글 글꼴은 번들로 고정했으며 실제 Android 기기의 렌더·터치·성능은 별도로 확인한다.

도입·경제 개편 후 city UI 기본 기준 기록은 `docs/qa/reports/progression_2026-10-03_assets/city_campaign_report.json`이다. `-CampaignSource <경로>`로 새 기준을 지정하고 `-Weapons single,burst` 등으로 대상을 제한할 수 있다. 전체 UI 제한은 900초, 개별 검사는 300초다. 이전 규칙의 기록을 재생해 실패하면 실제 규칙 필드를 삭제해 통과시키지 않는다. 새 기준 생성과 이전 저장의 읽기 호환을 별개로 검증한다.

`run_all.gd`의 2026-10-02 실행은 구형 UI 스모크 단계에서 300초 제한으로 종료되었다. 성공으로 집계하지 않았으며 현행 무기 규칙·UI를 별도로 확인한다.
