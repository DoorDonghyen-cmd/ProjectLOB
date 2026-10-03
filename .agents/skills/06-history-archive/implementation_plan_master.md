# 🗺️ Implementation Plan Master (구현 계획서 설계 아카이브)

* [Session codex0925-frontend-ui Plan](file:///D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_frontend_ui_2026-09-25.md)
* [Session codex0925-first-run-ux Plan](file:///D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_first_run_ux_2026-09-25.md)
* [Session codex0924-macro-uiux Plan](file:///D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_macro_uiux_2026-09-24.md)
* [Session codex0924-uiux-decision-flow Plan](file:///D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_uiux_decision_flow_2026-09-24.md)

이 파일은 각 기능 단위 개발이 착수되기 전, 기술적 분석과 기획 정합성을 맞춘 구현 계획서(`implementation_plan.md`)를 총망라하는 인덱스입니다.

---

## 📋 구현 계획서 리스트

| 생성일 | 주제 | 세션 ID | 주요 설계 방향 | 문서 링크 |
| :--- | :--- | :--- | :--- | :--- |
| 2026-09-25 | **타이틀·출격 준비 프런트엔드** | `codex0925-frontend-ui` | 메인 설정 폼을 타이틀 홈과 준비실로 분리하고 총기 선택→보급·난도→단일 출격 확정의 게임 흐름으로 재구성 | [implementation_plan.md](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_frontend_ui_2026-09-25.md) |
| 2026-09-25 | **첫 등반 UX 후속 개선** | `codex0925-first-run-ux` | 공개 화면 프로필 검토 뒤 상점 행동 결과와 빌드 작업실 탭 연속성을 직접 피드백으로 보강 | [implementation_plan.md](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_first_run_ux_2026-09-25.md) |
| 2026-09-24 | **거시 UI/UX 구조 개편** | `codex0924-macro-uiux` | 지도·전투·보상·상점·빌드 작업실의 역할 분리, 압축 공통 헤더, 전체 화면 빌드 편집, 모바일 주 행동 고정 | [implementation_plan.md](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_macro_uiux_2026-09-24.md) |
| 2026-09-24 | **덱·장비 통합과 전투 작업대 UI** | `codex0924-loadout-combat-ui` | 상점·덱 파츠 UI를 하나로 통합하고 전장·단계·탄환 후보·발사 순서를 장면화. 1008px 동시 비교와 900px 미만 접힘, 기존 입력·전투 규칙 보존 | [implementation_plan.md](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_loadout_combat_ui_2026-09-24.md) |
| 2026-09-21 | **무기고·파츠 작업대 UI** | `codex0921-shop-workbench` | 고정 구조는 `.tscn`, 동적 상품·상태만 코드 바인딩. 현재 빌드→진열→압축→장착 계층, 중복 설명 축약, 1280/1008 반응형·실제 입력 QA | [implementation_plan.md](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_shop_workbench_ui_2026-09-21.md) |
| 2026-09-21 | **5칸 파츠 빌드·코어 패널티** | `codex0921-joker-parts` | 파츠를 5개 조합하는 런 빌드로 전환하고 일반14·코어6, 코어1개 제한, 장점/대가, 다중 구매·보관·교체와 저장 호환을 정의 | [문서](../../../../docs/implementation_plan_joker_parts_2026-09-21.md) |
| 2026-09-21 | **저체력 다수전·공개 증원·전투 UI** | `codex0921-horde-reinforcement` | 최대 4기 전열, 공개 대기열, 처치 후 보충, 직접 정보 전장과 휴대폰 화면 밀도 개편 | [문서](../../../../docs/implementation_plan_horde_reinforcement_ui_2026-09-21.md) |
| 2026-09-11 | **Godot 시각 전투 개선** | `codex0911-visual-combat` | 거리 전장·탄창·순차 연출, 화면43·연출39·전체UI493·독립100 통과. 브랜치 검증, main 미병합 | [문서](../../../../docs/implementation_plan_visual_combat_2026-09-11.md) |
| 2026-09-11 | **별도 브랜치 핵심 재설계 계획** | `codex0911-core-redesign` | 2총기/8탄종/7교전, 규칙48·독립37·UI43·전체UI493 통과. 인간 재미 판단 별도 | [문서](../../../../docs/implementation_plan_core_redesign_2026-09-11.md) |
| 2026-09-11 | **전술 장전 작업대 개선 계획** | `codex0911-tactical-workbench` | UI 변경 위임, 공개 적/순서/후보 통합과 비용·실제 입력 검증 | [implementation_plan.md](../../../../docs/implementation_plan_tactical_workbench_2026-09-11.md) |
| 2026-09-11 | **아트 이전 전체 개발 실행 계획** | `codex0911-preart` | 기능·기록·A/B·정렬·로어·패키징과 사람 체감/실기 승인 경계 | [implementation_plan.md](../../../../docs/implementation_plan_preart_completion_2026-09-11.md) |
| 2026-08-30 | **LIFO 탄환 조합 핵심 재미 정밀 QA** | `codex0830-core-fun-qa` | 순서 영향·상황별 해법·혼합 장전 가치·실제 선택 압력·표본 범위를 독립 게이트로 판정하고, 자동화 불가 체감은 사람 확인으로 분리하는 보수적 핵심 재미 평가 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_lifo_core_fun_qa_2026-08-30.md) |
| 2026-08-30 | **QA 대시보드 Windows 실행 파일 런처** | `codex0830-qa-exe` | 저장소 상대 경로에서 기존 QA 컨트롤러를 고정 호출하고 localhost 준비 뒤 브라우저를 여는 경량 EXE. 자체 점검·live probe·포트/Godot 지정과 재현 가능한 Windows 기본 컴파일 제공 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_qa_windows_launcher_2026-08-30.md) |
| 2026-08-23 | **QA 실제 플레이테스트 컨트롤러** | `codex0823-qa-controller` | 루프백 전용 대시보드 컨트롤러가 격리된 사용자 데이터에서 전체 회귀와 4성향 실제 메인 씬 플레이를 실행. 재미 신호는 REVIEW, 제품 버그는 동일 지문 2/2 재현 시 FAIL로 분리 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_qa_playtest_controller_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA HTML 대시보드** | `codex0823-qa-dashboard` | 기존 QA 통합 분류를 재계산하지 않는 실행 이력 schema와 자동 exporter를 두고, file 프로토콜에서 동작하는 외부 의존성 없는 반응형 HTML로 빌드·판정·전투·역할·증거·이력을 표시 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_qa_html_dashboard_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀** | `codex0823-qa-team` | 기능 QA 리드·블랙박스 경험 테스터·기존 전투 시뮬레이터를 독립 실행하고, Godot 상태/행동 브리지·UI 체크포인트·RNG 재현·통합 리포트로 고정 전투부터 전체 런까지 단계 확장 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_playtest_qa_team_2026-08-23.md) |
| 2026-08-17 | **조합탄 전문축 가독성·피해 증폭탄** | `codex0821-ammo-axis` | 기본탄과 전술탄의 표시 언어를 분리하고 ACC/PEN/DMG/CTRL 전체·축약 배지를 정의. 연쇄탄을 다음 1발 DMG +2 셋업탄으로 전환하되 게이트·소비·리로드·크리티컬 순서를 결정론적으로 고정 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_axis_readability_2026-08-17.md) |
| 2026-08-15 | **조합탄 전투 전문축 분리** | `codex0815-ammo-specialty` | 기존 운용 분류와 별도로 화력/관통/명중/제어 전문축을 도입하고, 19종 수치 경계·카드 배지·LIFO 파츠 판정·시작 패키지를 9총기×13적 대진으로 검증 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_stat_specialization_2026-08-15.md) |
| 2026-08-15 | **격발 입력 잠금·총기별 연출 템포** | `codex0815-fire-pacing` | 연출 중 전투 액션 재입력을 차단하고 입력 버퍼 없이 결과 판독 후 다음 선택을 받는다. 단발 0.32~0.52초 최소 표시 시간, Tempo 0.13초·Suppressor 0.20초 연발 간격을 UI 전용으로 분리 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_fire_input_pacing_2026-08-15.md) |
| 2026-08-15 | **관리·정점 복합 편성 플레이테스트 지원** | `codex0815-upper-roster` | 상층 차저 중복을 제거하고 실제 전진·차징·긴급 격퇴 기준 4~8행동 압력을 회귀 고정. 관리·정점 대표 4체 즉시 QA와 공통 Workhorse 탄약 제공 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_upper_roster_playtest_2026-08-15.md) |
| 2026-08-15 | **몬스터 13종 계층 배치·표기명 정합** | `codex0815-enemy-roster` | 일반·변종 9종의 5계층 초·중·종반 편성을 단일 정본으로 분리하고, 관문 보스 4종을 포함한 전체 도달성·최초 등장·편성 밀도·표시명 일치를 회귀 고정. 적 수치·기믹 무변경 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_enemy_roster_placement_2026-08-15.md) |
| 2026-08-09 | **조합탄 결산 구조·2탄창 전투 호흡** | `codex0809-ammo-payoff` | 연쇄탄·교대탄 결산 태그와 LIFO 예상 주 피해 예고, 연계 보유 시 첫 결산탄 후보 보증, 동일 탄 보유량 가중치 완화, Tempo 혼합 편성 2탄창 생존 회귀. 수치·시작 패키지 무변경 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_payoff_cadence_2026-08-09.md) |
| 2026-08-09 | **모바일 스캔·해금 표기·조합탄 전술 예고** | `codex0809-mobile-guidance` | 미지 노드 첫 탭 스캔·재탭 진입, 무기 해금명 단일 정본, 연계탄 3범위 배지와 현재 LIFO 명중·관통 게이트 전환 예고. 수치·드래프트 무변경 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_mobile_scan_unlock_ammo_guidance_2026-08-09.md) |
| 2026-07-30 | **탄종 3계열 행동·기술 규격·파츠 시너지** | `codex0730-ammo-family` | 경량탄 적별 3회 집중, 소총탄 후열 직선 관통, 산탄 근거리 군집 확산을 기본 행동으로 정립하고 9mm/.45 ACP·5.56/7.62를 표준/강화 규격으로 분리. 기존 관통·확산·관성 파츠 중복 해소와 계열별 예고·연출 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_family_behaviors_2026-07-30.md) |
| 2026-07-28 | **개발자 테스트 전체 데이터 초기화** | `codex0728-dev-reset` | 메타·현재 런 초기화 진입점, 세이브 삭제 실패 시 기본값 덮어쓰기, 확인 대화상자와 메인 화면 갱신, 저장·UI 회귀 안전망 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_dev_reset_all_2026-07-28.md) |
| 2026-07-28 | **기본탄 고정 보급 슬롯 및 리로드 정량 복구** | `codex0728-basic-supply` | 기본탄을 런 덱에서 분리해 탄창+약실 상한의 고정 보급원으로 운용하고, 리로드 정량 복구·발당 슬롯 점유·LIFO를 유지. 전술탄만 제한 덱 자원으로 분리 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_basic_ammo_supply_2026-07-28.md) |
| 2026-07-28 | **역할명 기반 표준 3종·전용 2종 고정 규격 및 역할 전환** | `codex0728-fixed-caliber` | 경량탄·소총탄·산탄을 초반 표준으로, 중량탄·저격탄을 특수 총기 전용으로 공개하고 실제 구경은 보조 기술 표기로 유지. 자기 기반탄+공용 전술탄 드래프트와 역할 전환 LIFO 효과로 이관 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_fixed_caliber_profiles_2026-07-28.md) |
| 2026-07-28 | **첫 구역 이후 35층 연속 상승 복구** | `codex0728-continuous-ascent` | 해금 여부와 런 목적지 분리, 관문 즉시 해금·연속 진입, 자원 유지, 지도·브리핑·디브리핑의 조기 종료 상한 제거 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_continuous_ascent_2026-07-28.md) |
| 2026-07-27 | **탄환 v6 런타임 마이그레이션** | `codex0727-ammo-v6-runtime` | 19종 데이터 계약 이관, 크리티컬·탄창 버프·교차 구경·영구 소실 런타임, 시작 덱·상점·UI·회귀의 원자적 교체 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_runtime_migration_2026-07-27.md) |
| 2026-07-27 | **탄환 v6 수치 튜닝 및 해법 존재 검사** | `codex0727-ammo-v6-tuning` | 기반탄 3/3/3/4/5, 총기 시그니처 보정, 9총기×13적 거리·지원탄 전수 순열, 클래스별 시작 덱 56조합 탐색 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_tuning_2026-07-27.md) |
| 2026-07-27 | **탄환 v6 사전검증 및 규칙 계약** | `codex0727-ammo-v6-preflight` | v5 LIFO 기준선, Tempo 6발 정합, 데이터 필드·결정형 크리티컬·교차 구경·소실 계약, 9총기×13적 기반탄 비파괴 매트릭스 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_preflight_2026-07-27.md) |
| 2026-07-27 | **탄환 역할 단순화 및 조합 밸런스 재조정** | `codex0727-ammo-rebalance` | 공격/연계/제어 3역할, 공격탄 단독 유효성, 연계탄 전문 적 대응 확장, 실제 몬스터 전투 매트릭스 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_role_rebalance_2026-07-27.md) |
| 2026-07-24 | **기관단총 연발 전환과 탄환 역할 UI** | `codex0724-smg-role` | Tempo 전탄 커밋·Gambler 단발 분리, 셋업 유효 적중 수치 정합, 리듬 챔버 폭증 차단, 27종 역할 메타데이터와 LIFO 연계 배지 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_smg_full_auto_ammo_role_ui_2026-07-24.md) |
| 2026-07-24 | **탄환 데이터 v5 27종 마이그레이션** | `codex0724-ammo-v5` | 헤더 기반 데이터 계약, 27종 CSV·리소스 일치, 시작 덱·상점·프리로드 ID 교체, 엄격한 무결성 회귀 안전망 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v5_migration_2026-07-24.md) |
| 2026-07-17 | **렐릭 시스템 전면 제거** | `codex0717` | 런타임 상태·호출 계약·UI·맵 조건·정산을 함께 제거하고 포인트블랭크 파츠 및 기존 맵 연결 구조는 보존 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_relic_system_removal_2026-07-17.md) |
| 2026-06-27 | **에이전트 지침 및 매니지먼트 이식** | `2bed5975` | D:\ProjectLoB 내 범용 매니지먼트 환경 직접 구축 설계 | [계획서 없음](#) |
| 2026-06-28 | **combat_scene.gd 리팩토링** | `bbacb3ae` | 씬 라우터 및 5대 독립 서브 오버레이 컴포넌트 모듈 분리 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/bbacb3ae-bec7-4690-b500-e3c4ec102daf/implementation_plan.md) |
| 2026-06-28 | **미드저니 MCP 서버 연동** | `287baf0e` | python-uv 및 mcp_config.json 구성을 통한 midjourney-mcp 연결 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/287baf0e-2bda-448a-bf37-3a9f62aa7cfe/implementation_plan.md) |
| 2026-06-29 | **Tier 1 & 2 코어 전술 시스템 고도화** | `168caff8` | 다수 적 스태거링 공유 트랙, 술사 적 차징 공격, 슬로우 저격 조준, 관통 다중타 피해, 7.62mm 구경 보너스, 원터치 클릭 장전/회수 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/168caff8-edab-4761-b950-f0bd42e12149/implementation_plan.md) |
| 2026-06-30 | **스탯 시스템 개편 & 팝업 연출** | `8acd207f` | PRES 폐지 및 이진 관통 게이트 적용, 난이도 층별 거리 보정, 실시간 도탄/빗나감 예고 UI, 대미지 팝업 연출 구현 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/8acd207f-7395-4eef-8fdf-3a9dd9f951e9/implementation_plan.md) |
| 2026-07-01 | **특수 탄환 가방 미노출 버그 해결** | `820f3ccd` | combat_overlay.gd의 강제 다운캐스팅 치환문을 제거하고, run_manager.deck의 BulletData 인스턴스를 _bullet_pool에 직접 보존/전달하여 UI 렌더링 및 전투 효과 격발 보장 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/820f3ccd-0935-4d7b-bf5c-e814640fb44e/implementation_plan.md) |
| 2026-07-01 | **속사형 "더블탭" 시그니처 테스트** | `70fd47fc` | 속사형(Tempo) 총기용 더블탭 토글 구현, 연속 2발 사격, 2발째 리듬 챔버 시너지 연동, 1회 전진 및 삽탄과의 상호배제 처리 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/70fd47fc-a52b-4449-9675-a36976f0100e/implementation_plan.md) |
| 2026-07-02 | **요원 준비실 UI 확장 및 발사 버튼/몬스터 스프라이트/빼내기 밸런스 설계** | `46ca166d` | 준비실 UI 전체 가로 확장, 발사 버튼 모바일 가로 14 크기 제한 및 텍스트 단축, 몬스터 갤러리 이미지 크기 무시 설정 및 icon 폴백 인게임 적용, 빼내기 패널티 삭제 및 전술 장갑 턴 감소 구현 설계 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/implementation_plan.md) |
| 2026-07-03 | **보상/해금, 맵, 몬스터 & 반복성/완결 개편** | `64478efc` | TDC 가속 및 8종 총기 영구 해금 연동, 준비실 🔒 잠금 UI 설계. 10층 압축 구조 맵 제너레이터, 2~3갈래 가로 분기 UI 그리기, 미지 노드 스캔 힌트, 조건부 우회로 실시간 개방 및 층 상승 연출 설계. 스택 스펀지(유효타 3회 및 관통 스침) 처치 기믹, ◆ ◆ ◆ 배리어 UI 표시, 태세병 1턴 전 변경 예고 HUD 설계. 5단계 침투 위험도 전술 제약(예고창 가림, 적 전진 배치, 쉴드량 스케일링, 빼내기 시 적 전진), 기밀 파편(Lore Fragment) 20종 도감 우회로 매핑 연동 및 10F 최종 탈출 성공 시 블랙박스 해독 보안 로그 폭로 소프트 엔딩 완결 설계 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/64478efc-e950-4f76-80ad-e56539a2c655/implementation_plan.md) |
| 2026-07-05 | **거리 표시, 분석 패널 워터마크, 상황 라벨 이동 및 장전 탄환 순서/은폐/아이콘 개선** | `3c923ccb` | 상황 대기 중 라벨을 전투 트랙 우상단으로 오버레이 배치, 거리 표시부 VBox 제거 및 중앙 고정, 격발 분석 패널 워터마크화(배경 25%/테두리 20%/마우스무시), 장전 탄환 LIFO 역순 정렬 및 카드 내 18px 총알 픽셀 아이콘 표시, 3번째 깊이부터 은폐(???), 가로폭 축소(180), 중심선/캐릭터/몬스터 앵커 하향(75%) | [implementation_plan.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/3c923ccb-57f1-422f-9175-9d6ccf802e20/implementation_plan.md) |
| 2026-07-05 | **상황 대기 패널 및 전투 대기 라벨 레이아웃 개편** | `047ebef9` | 상황 대기 패널을 교전 거리 아래로 배치하고 전투 대기 라벨을 전투 영역(트랙) 우측 상단으로 이동 | [implementation_plan.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/implementation_plan.md) |
| 2026-07-06 | **V2 전투 UI 컴포넌트 분할 리팩토링** | `c3f9c023` | `combat_overlay_v2.gd` 거대 UI 스크립트(God Object)를 4대 독립 서브 뷰 컴포넌트(`CylinderView`, `EnemyTrackView`, `BagInventoryDrawer`, `RewardDraftPanel`)로 분할하여 결합도 하향 및 확장성 확보. 빌드본 호환성 및 보상 드래프트 락 버그 해결 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/c3f9c023-2d6f-4c73-86ee-661f3c2221e8/implementation_plan.md) |
| 2026-07-06 | **Phase 4: Visual & Map 연출 고도화** | `2a3802e2` | 총기 격발 반동 및 액션바 덜컹임 트윈, 탄창 실린더 Elastic 바운스/회전, 몬스터 대기 숨쉬기 및 이동 뒤뚱거림 모션 구현. 격발(Muzzle Flash) 및 피격(Blood Spurt) 2D 파티클 이펙트 개발자 팝업 숏컷 연동 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a3802e2-7bad-40e1-a189-cac0623ac593/implementation_plan.md) |
| 2026-07-07 | **탄환 반환 플로팅 UI 및 개발자 테스트 3열 개편** | `2a7f1e25` | 명중/실질 대미지 시 몬스터 옆에 32x32 아이콘 및 ♻ 반환 마크가 떠오르다 소멸하는 연출 기획 및 개발자 테스트 팝업 3열 그리드 정렬 및 폰트 11px 와이드 레이아웃 조율 설계 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a7f1e25-5d85-42cc-a209-fa37ce653956/implementation_plan.md) |
| 2026-07-12 | **맵 · 레벨 구조 개정안 GDD 반영** | `ffd285f8` | 15노드(전투 10, 상점 3, 히든 2) 3구역 구조, 보상 드래프트 방안 A, 히든 노드 위험 완충, 매판 종료 시 크레딧 이월/작전 보급금 보너스 정책 기획서 반영 설계 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/ffd285f8-d243-4078-8f8b-4340ac3f48b8/implementation_plan.md) |
| 2026-07-12 | **맵 · 레벨 구조 및 경제 개정 기획 인게임 연동 구현** | `16ba329e` | 15노드 맵 구조 개편, 보상 드래프트 3탄환 교체(Swap) 기능, 스타팅 보증금/금고 크레딧 이월, 히든 노드 안전 완충망 연동 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/16ba329e-a924-4c77-947c-907545fa1730/implementation_plan.md) |
| 2026-07-12 | **작전 침투 구역 순차 해금 및 노드 완결 구조 구현** | `afaad6f3` | 5개 침투 구역 순차 해금, current_section 및 10~15층 동적 맵 생성, 구역별 적 스폰 및 숏컷 연동, 타이틀 ➡️ 구역 선택 ➡️ 요원 준비실 UI/UX 전환 흐름 개편 | [implementation_plan.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/afaad6f3-77c6-4268-acfb-c7f4a2acdd2c/implementation_plan.md) |
| 2026-07-18 | **통로 분기 목적지 가격 구조 구현** | `codex0718` | 계단·환기구 2종화, 목적지 1회 선택, 실제 연결 노드 제한, 환기 압박 다음 전투 이월·비중첩, 무기고 통로 가변 배치 및 층 스킵 통로 제거 | [implementation_plan.md](file:///D:/ProjectLoB/docs/implementation_plan_route_branching_2026-07-18.md) |
| 2026-09-12 | **Godot 텍스트 밀도 정리** | `codex0912-quiet-ui` | 탄환 공용 수치·정보 창, 반복 설명 정리. 화면49·연출39·전체UI493 통과. main 미병합 | [문서](../../../../docs/implementation_plan_quiet_ui_2026-09-12.md) |
| 2026-09-12 | **다수 적 표적 예고** | `codex0912-multi-target` | 탄별 A/B/C 예고·개별 정보·같은 거리 표시. 집중129·독립2627·전체UI493. main 미병합 | [문서](../../../../docs/implementation_plan_multi_target_2026-09-12.md) |
| 2026-09-12 | **갤럭시 테스트 APK** | `codex0912-android-test` | ARM64/ARMv7 APK·서명/정렬/패키지·PC 터치34 통과, 실기 미검증 | [문서](../../../../docs/implementation_plan_android_test_2026-09-12.md) |
| 2026-09-13 | **연계 전투 전면 개편** | `codex0913-chain` | 사용자 승인: 클릭순 발사·균열·축전·시드별 상황·교환·5칸·저장 v2 | [문서](../../../../docs/implementation_plan_chain_edition_2026-09-13.md) |
| 2026-09-13 | **탄환 정보·초반 학습 흐름** | `codex0913-readability-plan` | 카드 수치/역할·피해 원인·적/덱/보상 단계 도입. 회피 축 후속 판단. 계획만, APK 요청 시에만 | [계획](../../../../docs/implementation_plan_ammo_readability_2026-09-13.md) |
| 2026-09-13 | **탄환 정보 계획 실행** | `codex0913-ammo-readability` | 승인된 1~3단계 구현 검증. 사람 이해도/회피 태세 후속 판단 | [문서](../../../../docs/implementation_plan_ammo_readability_2026-09-13.md) |
| 2026-09-16 | **탄환 카드 아이콘 정보 체계** | `codex0916-ammo-icons` | 위력·관통·명중 고정 픽셀 아이콘, 부호 효과 행, 단계 공개·보상·개발자 숏컷 적용 | [계획](../../../../docs/ui_request_ammo_icon_cards_2026-09-16.md) |
| 2026-09-16 | **피해·관통 및 3속성 개편** | `codex0916-elemental-ammo` | 명중/회피 제거, 탄환7종·물리/화염/전기·화상/전이·저장 변환·두 수치 UI | [계획](../../../../docs/implementation_plan_elemental_ammo_2026-09-16.md) |
| 2026-09-21 | **고정 전열·탄 순서·파츠 빌드·상점 UX** | `codex0921-order-parts` | 고정 레인, 회수탄 약화와 전술탄 역할, 적 약점 공개, 8종 파츠와 미확인 우선 순환, 상점·보관함 비교 UX | [계획](../../../../docs/implementation_plan_core_order_parts_ux_2026-09-21.md) |

---

## 🔗 세션별 원본 링크 (References)

* [Session codex0921-order-parts Plan](file:///D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_core_order_parts_ux_2026-09-21.md)
* [Session codex0830-core-fun-qa Plan](file:///D:/ProjectLoB/docs/implementation_plan_lifo_core_fun_qa_2026-08-30.md)
* [Session codex0830-qa-exe Plan](file:///D:/ProjectLoB/docs/implementation_plan_qa_windows_launcher_2026-08-30.md)
* [Session codex0823-qa-controller Plan](file:///D:/ProjectLoB/docs/implementation_plan_qa_playtest_controller_2026-08-23.md)
* [Session codex0823-qa-team Plan](file:///D:/ProjectLoB/docs/implementation_plan_playtest_qa_team_2026-08-23.md)
* [Session codex0821-ammo-axis Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_axis_readability_2026-08-17.md)
* [Session codex0815-fire-pacing Plan](file:///D:/ProjectLoB/docs/implementation_plan_fire_input_pacing_2026-08-15.md)
* [Session codex0815-upper-roster Plan](file:///D:/ProjectLoB/docs/implementation_plan_upper_roster_playtest_2026-08-15.md)
* [Session codex0815-ammo-specialty Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_stat_specialization_2026-08-15.md)
* [Session codex0815-enemy-roster Plan](file:///D:/ProjectLoB/docs/implementation_plan_enemy_roster_placement_2026-08-15.md)
* [Session codex0809-ammo-payoff Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_payoff_cadence_2026-08-09.md)
* [Session codex0809-mobile-guidance Plan](file:///D:/ProjectLoB/docs/implementation_plan_mobile_scan_unlock_ammo_guidance_2026-08-09.md)
* [Session codex0730-ammo-family Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_family_behaviors_2026-07-30.md)
* [Session codex0728-dev-reset Plan](file:///D:/ProjectLoB/docs/implementation_plan_dev_reset_all_2026-07-28.md)
* [Session codex0728-basic-supply Plan](file:///D:/ProjectLoB/docs/implementation_plan_basic_ammo_supply_2026-07-28.md)
* [Session codex0728-fixed-caliber Plan](file:///D:/ProjectLoB/docs/implementation_plan_fixed_caliber_profiles_2026-07-28.md)
* [Session codex0728-continuous-ascent Plan](file:///D:/ProjectLoB/docs/implementation_plan_continuous_ascent_2026-07-28.md)
* [Session codex0727-ammo-v6-runtime Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_runtime_migration_2026-07-27.md)
* [Session codex0727-ammo-v6-tuning Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_tuning_2026-07-27.md)
* [Session codex0727-ammo-v6-preflight Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v6_preflight_2026-07-27.md)
* [Session codex0727-ammo-rebalance Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_role_rebalance_2026-07-27.md)
* [Session codex0724-smg-role Plan](file:///D:/ProjectLoB/docs/implementation_plan_smg_full_auto_ammo_role_ui_2026-07-24.md)
* [Session codex0724-ammo-v5 Plan](file:///D:/ProjectLoB/docs/implementation_plan_ammo_v5_migration_2026-07-24.md)
* [Session codex0718 Plan](file:///D:/ProjectLoB/docs/implementation_plan_route_branching_2026-07-18.md)
* [Session codex0717 Plan](file:///D:/ProjectLoB/docs/implementation_plan_relic_system_removal_2026-07-17.md)
* [Session afaad6f3-77c6-4268-acfb-c7f4a2acdd2c Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/afaad6f3-77c6-4268-acfb-c7f4a2acdd2c/implementation_plan.md)
* [Session ffd285f8-d243-4078-8f8b-4340ac3f48b8 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/ffd285f8-d243-4078-8f8b-4340ac3f48b8/implementation_plan.md)
* [Session 16ba329e-a924-4c77-947c-907545fa1730 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/16ba329e-a924-4c77-947c-907545fa1730/implementation_plan.md)
* [Session 2a7f1e25-5d85-42cc-a209-fa37ce653956 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a7f1e25-5d85-42cc-a209-fa37ce653956/implementation_plan.md)
* [Session 2a3802e2-7bad-40e1-a189-cac0623ac593 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a3802e2-7bad-40e1-a189-cac0623ac593/implementation_plan.md)
* [Session c3f9c023-2d6f-4c73-86ee-661f3c2221e8 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/c3f9c023-2d6f-4c73-86ee-661f3c2221e8/implementation_plan.md)
* [Session 047ebef9-20e0-4ac7-bd96-831ae6624080 Plan](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/implementation_plan.md)
* [Session 3c923ccb-57f1-422f-9175-9d6ccf802e20 Plan](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/3c923ccb-57f1-422f-9175-9d6ccf802e20/implementation_plan.md)
* [Session 64478efc-e950-4f76-80ad-e56539a2c655 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/64478efc-e950-4f76-80ad-e56539a2c655/implementation_plan.md)
* [Session 46ca166d-2f0e-4374-9d61-863e0f35dfaf Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/implementation_plan.md)
* [Session 287baf0e-2bda-448a-bf37-3a9f62aa7cfe Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/287baf0e-2bda-448a-bf37-3a9f62aa7cfe/implementation_plan.md)
* [Session 168caff8-edab-4761-b950-f0bd42e12149 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/168caff8-edab-4761-b950-f0bd42e12149/implementation_plan.md)
* [Session 8acd207f-7395-4eef-8fdf-3a9dd9f951e9 Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/8acd207f-7395-4eef-8fdf-3a9dd9f951e9/implementation_plan.md)
* [Session 820f3ccd-0935-4d7b-bf5c-e814640fb44e Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/820f3ccd-0935-4d7b-bf5c-e814640fb44e/implementation_plan.md)
* [Session 70fd47fc-a52b-4449-9675-a36976f0100e Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/70fd47fc-a52b-4449-9675-a36976f0100e/implementation_plan.md)
* [Session 46ca166d-2f0e-4374-9d61-863e0f35dfaf Plan](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/implementation_plan.md)




2026-09-12 참조: [텍스트 밀도 정리](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_quiet_ui_2026-09-12.md)


2026-09-12 참조: [다수 적 표적 예고](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_multi_target_2026-09-12.md)


2026-09-12 참조: [갤럭시 테스트 APK](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_android_test_2026-09-12.md)

2026-09-13 참조: [연계 전투 전면 개편](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_chain_edition_2026-09-13.md)

2026-09-13 참조: [탄환 정보·초반 학습 계획](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_ammo_readability_2026-09-13.md)

2026-09-13 참조: [탄환 정보 계획 실행](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_ammo_readability_2026-09-13.md)

2026-09-16 참조: [탄환 카드 아이콘 정보 체계](D:/ProjectLoB/worktrees/core-redesign/docs/ui_request_ammo_icon_cards_2026-09-16.md)

2026-09-16 참조: [피해·관통 및 3속성 개편](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_elemental_ammo_2026-09-16.md)

2026-09-26 참조: [전투 전체 화면 UI 개편](D:/ProjectLoB/worktrees/core-redesign/docs/implementation_plan_combat_fullscreen_ui_2026-09-26.md)
