# 현행 검증 경로

2026-10-09. `새-게임-프로젝트/redesign`이 현행 게임이다. 검사 이름에 regression이 있다는 이유만으로 현행 게임 전체를 검증했다고 쓰지 않는다.

| 범위 | 실행 경로 | 의미 |
| --- | --- | --- |
| 생성형 맵·정비·정예 | `tools/run_map_checks.ps1 -Mode rules/ui/combat -Label current` (각각 지정) | 100시드×5지역 연결/다양성,45방 진행·구35방 저장, 실제 터치3해상도,5무기 실제 전투 명령. 규칙 검사의 승리 fixture와 combat 모드의 실제 전투를 구별한다. [보고서](../qa/reports/route_map_2026-10-09.md) |
| 등반 동기·기록·복구 | `tools/run_story_checks.ps1 -Label current` | 도입/건너뛰기/중간 이어하기·상점 대화 복귀·3화면비율·1.1배 글자·20기록·구 저장·복구 중복 방지. 전투 승리는 fixture로 생성한다. [보고서](../qa/reports/story_flow_2026-10-09.md) |
| 탄창·파츠·총기 연결 | `tools/run_build_synergy_checks.ps1 -Mode rules/ui/audit` (각각 지정) | 신규4탄/3파츠·5총기·성장·예약 소유권·차단·확산·연계·v11→12·실제 구매/장비/화면. [현재 검증](../qa/reports/build_synergy_2026-10-05.md) |
| 패 선택·순환·잔열 | `tools/run_decision_revision_checks.ps1 -Mode rules/ui` (각각 지정), `python tools/summarize_decision_revision.py` | 탄창+2패·미사용 패 순환·일부 냉각·정확한1장 교환·v10→11·후보10장 페이지/3비율·큰 글자. [현재 검증](../qa/reports/decision_revision_2026-10-04.md) |
| 선택 가치 심층 감사 | `tools/run_ammo_choice_audit.ps1`, `tools/run_decision_depth_audit.ps1`, `python tools/summarize_decision_depth.py` | 현행 LIFO 시작 덱·270실제 등반·초반 최대 장전 열거·2,400통제 빌드. 무작위 허용 범위/열 대가/성장 후 선택 여유. [진단·한계](../qa/reports/decision_depth_2026-10-04.md), 사람 승률·최적 정책 아님 |
| 마지막 장전 우선 규칙·실제 조작 | `tools/run_lifo_checks.ps1 -Mode rules` / `-Mode ui` | 5무기 순열·예측/발사·고정 탄·전장 압축·회수/드래그·v9 복원, 세 비율 실제 입력/캡처. [결과](../qa/reports/lifo_2026-10-04.md) |
| 발열 빌드 비교/결과 피드백 | `tools/run_heat_polish_checks.ps1 -Mode audit/rules/ui` (각각 지정) | 2,400 독립 전투, 실제 기록 집계·원인 안내·세 화면비율 보상/기록/파츠. [근거와 한계](../qa/reports/heat_polish_2026-10-04.md) |
| 발열·강제 재장전 | `tools/run_heat_checks.ps1 -Mode rules` | 한계·중단·냉각 순서·부분 경과·증원/요격·압축 잔탄·구 저장·산개 실제 실행 |
| 발열 실제 화면·조작 | 위 명령의 `-Mode ui` | 세 비율, 과열 탄/미발사/최고 열, 실제 발사→강제 재장전·현재 열·연출 결과 |
| 선택 가치 통제 비교 | `tools/run_ammo_choice_audit.ps1` | 5무기·6시드·36편성·2,592독립전투. 회수탄/무작위/32후보 선택 비교이며 사람 승률 아님 |
| 새 등반 기록 재생 | `tools/run_ammo_expansion_checks.ps1 -Mode replay -Label heat` | 기본 `campaign_heat` 기록의 모든 명령·저장·최종 전투 이력 대조. `-CampaignSource` 지정 가능 |
| 탄환 확장·저장·보급 | `tools/run_ammo_expansion_checks.ps1 -Mode rules` | 파쇄/기폭/추격/우회/냉각 순서, 무기/파츠 배율, 산개 분기, 구 저장, 30시드 보급/진열 |
| 탄환·과열 본편 실제 UI | 위 명령의 `-Mode ui -Label heat` | 세 화면 비율, 사격 전후 열/비용, 효과 표시, 요격 생성, 상점 구매와 보상 획득. 전투는 재현용 fixture와 공개 입력 |
| 빌드 통제 비교 | `tools/run_progression_checks.ps1 -Mode balance` | 720사례, 실제 모델·8개 고정 정책. 파츠 개수/미래 RNG/교환 미탐색의 한계를 보고한다 |
| 첫 지역·파츠·경제 규칙 | 위 명령의 `-Mode rules` | 24시드×5무기·4시작보급, 첫 패 소유권/RNG, 소개 순서, 진열 다양성, 정확한 비용·저장·교환 예산 |
| 현행 전체 캠페인 기준 기록 | 위 명령의 `-Mode campaign -Label synergy_final` | 마지막 장전 우선·패/잔열·신규 탄/파츠, 5무기×2경로·35층, 매 명령 저장 복원. 후보 제한800의 기능 탐색이며 사람 승률이 아님 |
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


## 발열 빌드 확장 검증

최신 파츠3종·탄환2종, 스레드 예측·작은 화면·상점/장착은 [보고서](../qa/reports/heat_builds_2026-10-04.md)를 따른다. `tools/run_heat_builds_checks.ps1 -Mode rules|ui`. 새 상점 풀의 전체 등반은 `run_progression_checks.ps1 -Mode campaign -Label heat_builds`, 재생은 `run_ammo_expansion_checks.ps1 -Mode replay -Label heat_builds -CampaignSource qa_runtime/progression/campaign_heat_builds/city_campaign_report.json`이다. 과거 시드 명령 기록을 새 보급 풀에 그대로 재사용하지 않는다.
