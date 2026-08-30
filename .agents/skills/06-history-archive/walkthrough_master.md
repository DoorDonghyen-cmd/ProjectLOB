# 🎓 Walkthrough Master (완료 작업 워크스루 아카이브)

이 파일은 각 세션(Conversation)별로 정상 동작이 검증되고 병합 완료된 기능들의 워크스루(`walkthrough.md`)를 총망라하는 인덱스입니다.

---

## 📋 검증 히스토리 리스트

| 완료일 | 주제 | 세션 ID | 주요 구현 내용 | 문서 링크 |
| :--- | :--- | :--- | :--- | :--- |
| 2026-08-30 | **LIFO 탄환 조합 핵심 재미 정밀 QA** | `codex0830-core-fun-qa` | 동일 탄환 묶음 순서 대조, 상황 대응 장전, 총점 없는 5개 재미 게이트와 대시보드 우선 결론. 실주행은 가능성 있으나 표본·깊이가 부족하다고 보수 판정, 전체 3,599 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_lifo_core_fun_qa_2026-08-30.md) |
| 2026-08-30 | **QA 대시보드 Windows 실행 파일 런처** | `codex0830-qa-exe` | `ProjectLoB-QA.exe` 더블클릭으로 QA 컨트롤러와 브라우저 자동 실행. 상대 경로 탐색, check/live probe, 포트·Godot 지정, Ctrl+C 종료와 재빌드 제공. Godot 4.7 자동 탐지·localhost 응답·종료 정리 검증 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_qa_windows_launcher_2026-08-30.md) |
| 2026-08-23 | **QA 실제 플레이테스트 컨트롤러** | `codex0823-qa-controller` | 대시보드 시작·취소·진행률, 격리 세이브, 실제 메인 씬 4성향 플레이와 행동 근거 수집, 재미 REVIEW·버그 후보·제품 버그 2/2 확정 분리. 실주행 4교전·76행동·25격발·신호 5·확정 버그 0, 전체 3,587 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_qa_playtest_controller_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA HTML 대시보드** | `codex0823-qa-dashboard` | QA 통합 결과를 판정 변경 없이 실행 이력 JSON으로 내보내고, 빌드·회귀·전투·역할·판정·증거·이력을 오프라인 반응형 HTML로 시각화. 자동 export, 필터·검색, 브라우저 렌더와 전체 3,582 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_qa_html_dashboard_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀 Phase F·구축 완료** | `codex0823-qa-team-front-validation` | 세 역할 독립 입력 패킷·원본 보고·후공유 통합 계약과 정상/seeded 결함 오탐·미탐 회귀. 실제 동시 전방 검증에서 신규 버그 0, sample 오탐·미탐 0, 최근 인간 로그 16발 수식 불일치 0. 전체 3,562 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_f_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀 Phase E** | `codex0823-qa-team-metrics` | reference 기반 4프로필, player_view 전용 증거 계약과 7종 재미 지표, 동일 행동열 거절·지배 대안 격차·강한 신호/인간 확인 비교. 전체 3,541 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_e_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀 Phase D** | `codex0823-qa-team-rng` | 게임플레이 6개 스트림과 FX RNG 분리, manifest v2·로그 v3 seed/세션 기록, 행동별 진행 저널. 깨끗한 전용 세이브에서 2구역 46행동·13노드 재생 및 동일 seed 독립 실행 일치, 전체 3,515 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_d_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀 Phase C** | `codex0823-qa-team-ui` | 실제 메인 씬의 타이틀→전투→보상→상점 의미 행동과 9개 UI 체크포인트, 공개 컨트롤·상점 카드 JSON, 리롤 설명/잔존 카드 검출, Viewport PNG 및 headless 폴백. 전체 3,502 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_c_2026-08-23.md) |
| 2026-08-23 | **전용 플레이 QA 팀 Phase A~B** | `codex0823-qa-team` | 기능 QA 리드·블랙박스 경험 테스터 스킬과 실제 CombatManager 상태/행동 JSON 브리지 구현. 공개/오라클 분리, 단계·합법 행동 계약, LIFO 2발 고정 전투와 합법 행동 20단계 왕복 및 전체 3,471 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_ab_2026-08-23.md) |
| 2026-08-21 | **조합탄 전문축 가독성·피해 증폭탄** | `codex0821-ammo-axis` | 기본탄과 ACC/PEN/DMG/CTRL 전술 배지를 분리하고, 기존 연쇄탄을 유효 적중 시 다음 1발 DMG +2인 장약 증폭탄으로 전환. 카드 효과 한 줄·QA·전체 3,431 테스트와 9×13 대진 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_axis_readability_2026-08-17.md) |
| 2026-08-15 | **조합탄 전투 전문축 분리** | `codex0815-ammo-specialty` | 화력/관통/명중/제어 전문축 데이터와 전 UI 배지, 교대/유지 파츠 판정, 시작 패키지·전용 QA를 구현. 9총기×13적 기본/환기구 대진 및 전체 3,424 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_stat_specialization_2026-08-15.md) |
| 2026-08-15 | **격발 입력 잠금·총기별 연출 템포** | `codex0815-fire-pacing` | 연출 중 발사·빼내기·재장전·이젝트 재입력 차단, 입력 버퍼 금지, 단발 0.32~0.52초와 Tempo 0.13초·Suppressor 0.20초 표시 템포 분리. 전체 3,351 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_fire_input_pacing_2026-08-15.md) |
| 2026-08-15 | **관리·정점 복합 편성 플레이테스트 지원** | `codex0815-upper-roster` | 정점 차저 중복 2개 후보 정리, 상층 전 후보 무대응 4~8행동 압력 회귀, 관리·정점 대표 4체 Workhorse QA 버튼. 전체 3,342 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_upper_roster_playtest_2026-08-15.md) |
| 2026-08-15 | **몬스터 13종 계층 배치·표기명 정합** | `codex0815-enemy-roster` | `EnemyRoster` 편성 정본과 관리/정점 독립 편성, 일반·변종 9종 + 관문 보스 4종 도달성, 최초 등장·최대 4체·고속 적 중첩·CSV 표시명 회귀. 전체 3,297 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_enemy_roster_placement_2026-08-15.md) |
| 2026-08-09 | **조합탄 결산 구조·2탄창 전투 호흡** | `codex0809-ammo-payoff` | 연쇄탄·교대탄 `[결산]` 공용 표기와 LIFO 성공/실패·예상 주 피해 예고, 첫 결산탄 후보 보증, 동일 탄 보유량 가중치, Tempo 혼합 편성 재장전 생존 회귀. 전체 2,827 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_payoff_cadence_2026-08-09.md) |
| 2026-08-09 | **모바일 스캔·해금 표기·조합탄 전술 예고** | `codex0809-mobile-guidance` | 미지 노드 첫 탭 스캔·재탭 진입, 제압형 해금명 단일화, 연계탄 3범위 배지와 LIFO 게이트 전환 예고, 통합 개발자 QA. 최종 전체 2,827 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_mobile_scan_unlock_ammo_guidance_2026-08-09.md) |
| 2026-08-06 | **전투 효율 정산·상점 파츠 구매 제한 정확성 수정** | `codex0806-function-accuracy` | 실제 격발 수 기반 S~D 효율·크레딧 정산으로 기본탄 100% 폴백 제거. 파츠 구매 상태를 상점 방문에 귀속해 리롤 우회를 차단하고 전체 2,734 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_function_accuracy_2026-08-06.md) |
| 2026-08-05 | **캠페인 보스 연결·보상 풀 정상화** | `codex0805-campaign-integrity` | A/B/C/E 실제 보스 4체와 D 관리 계층 정예 관문을 단일 편성 정본으로 연결. 일반 파츠·전술탄 후보를 정규화하고 스타팅 보너스 초기화 유실, 암시장 가방 포화 결제 소실을 차단. 전체 2,718 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_campaign_integrity_2026-08-05.md) |
| 2026-08-01 | **플레이테스트 텔레메트리·일반전 증원·개발자 도구** | `codex0801-playtest-telemetry` | 런별 전투·탄종·파츠 JSON 로깅, 공역 이후 일반전 3~4체 증원과 동거리 4체 분산, 모든 무기 9종 영구 해금 버튼 구현. 전체 2,543 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_playtest_telemetry_density_dev_tools_2026-08-01.md) |
| 2026-07-30 | **탄종 3계열 행동·기술 규격·파츠 시너지** | `codex0730-ammo-family` | 경량탄 적별 3회 집중, 소총탄 후열 직선 관통, 산탄 3m 군집 확산과 표준/강화 기술 규격 구현. 관통탄·Heavy·확산 격발·관성 격발 중복 해소, 대상별 예고·계열별 연출, Tempo 3.20 DPT 및 전체 2,476 테스트 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_family_behaviors_2026-07-30.md) |
| 2026-07-28 | **개발자 테스트 전체 데이터 초기화** | `codex0728-dev-reset` | 확인 대화상자를 거쳐 현재 런·영구 진행·메타 세이브를 첫 실행 상태로 복원하고 타이틀 UI 갱신. 삭제 실패 폴백과 저장·UI 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_dev_reset_all_2026-07-28.md) |
| 2026-07-28 | **기본탄 고정 보급 슬롯 및 리로드 정량 복구** | `codex0728-basic-supply` | 기본탄을 덱·드래프트에서 분리해 가방 고정 슬롯으로 표시하고 탄창+약실 상한까지 리로드 복구. 발당 탄창 슬롯과 LIFO는 유지하고 전술탄만 제한 자원으로 분리, 승천 8 계약과 회귀 동기화 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_basic_ammo_supply_2026-07-28.md) |
| 2026-07-28 | **역할명 기반 표준 3종·전용 2종 고정 규격 및 역할 전환** | `codex0728-fixed-caliber` | 경량탄·소총탄·산탄 표준 규격과 중량탄·저격탄 전용 규격을 UI·카드·문서에 분리하고 실제 구경은 보조 표기로 유지. 공용 전술탄 프로필·자기 규격 드래프트·역할 파츠 시퀀스·DMR 게이트를 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_fixed_caliber_profiles_2026-07-28.md) |
| 2026-07-28 | **첫 구역 이후 35층 연속 상승 복구** | `codex0728-continuous-ascent` | 침전 보스 뒤 메인 복귀하던 과거 런 길이 램프 제거. 다음 계층 즉시 해금·연속 진입, 덱·파츠·가방·크레딧 유지와 지도·브리핑·디브리핑 계약 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_continuous_ascent_2026-07-28.md) |
| 2026-07-27 | **Phase 13-3 탄환 v6 런타임 마이그레이션** | `codex0727-ammo-v6-runtime` | 27종 v5를 19종 v6으로 교체하고 결정형 크리티컬·탄창 버프·교차 구경·영구 소실·UI 예고 구현. #009·#010 종결, 연발 넉백 2m 상한과 전체 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_runtime_migration_2026-07-27.md) |
| 2026-07-27 | **Phase 13-2 탄환 v6 수치 튜닝** | `codex0727-ammo-v6-tuning` | 기반탄 3/3/3/4/5와 도박형·제압형 보정안, 9총기×13적 기본/환기구 해법 및 시작 덱 56조합 검증. 일반 적 무해법 0, 런타임 드리프트 2건 분리 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_tuning_2026-07-27.md) |
| 2026-07-27 | **Phase 13 탄환 v6 사전검증** | `codex0727-ammo-v6-preflight` | v5 360순열 기준선, Tempo 실제 7발 결함 수정, v6 규칙 계약과 9총기×13적 기반탄 매트릭스 작성. 런타임 v5를 유지한 채 마이그레이션 전 위험을 분리 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_preflight_2026-07-27.md) |
| 2026-07-27 | **Phase 12 탄환 역할 단순화 및 조합 매트릭스** | `codex0727-ammo-rebalance` | 공격/연계/제어 17/8/2 전환, 특수 공격탄 5종 단독 사용성 보정, 실제 적 단독·연계·연발·게이트 실패 매트릭스와 전체 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_role_rebalance_2026-07-27.md) |
| 2026-07-26 | **Phase 12 컨버전 킷** | `codex0726-conversion-kit` | 클래스별 5종 킷, 장착 제한, 지정탄 소멸 면제·승천8 해제, 드래프트 3배 가중, 무기고 전용 판매와 총기별 가격 배수 구현 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_conversion_kit_2026-07-26.md) |
| 2026-07-26 | **보스 호위 대열 밸런싱 QA** | `codex0726-boss-qa` | 세라프/L.O.B 2m 편성·차징 포격·호위 강제전진·넉백 저항 실측, 보스 차징 미작동 결함 수정 및 페이즈2 동시 이동 회귀 고정 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_boss_formation_balance_qa_2026-07-26.md) |
| 2026-07-24 | **기관단총 연발 전환과 탄환 역할 UI** | `codex0724-smg-role` | Tempo 6발 전탄 커밋·더블탭 제거·Gambler 단발 유지, 조율/과부하 체인 정합, 리듬 챔버 폭증 차단, 전 UI 역할·연계 배지와 회귀 검증 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_smg_full_auto_ammo_role_ui_2026-07-24.md) |
| 2026-07-24 | **탄환 데이터 v5 27종 마이그레이션** | `codex0724-ammo-v5` | 현대 구경 표기를 유지한 역할 기반 27종 데이터 교체, 헤더 기반 CSV 계약, 시작 덱·상점 도달성 및 CSV↔리소스 완전 일치 회귀 검증 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_ammo_v5_migration_2026-07-24.md) |
| 2026-07-17 | **렐릭 시스템 전면 제거** | `codex0717` | 문자열 기반 렐릭 상태·전투 효과·로드아웃 UI·정산·맵 조건을 제거하고 가스 우회로를 일반 경로로 전환, 현행 GDD와 프로젝트 지침 동기화 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_relic_system_removal_2026-07-17.md) |
| 2026-06-27 | **에이전트 지침 이식** | `2bed5975` | 새로운 프로젝트에 맞춘 범용 SOP 및 템플릿 환경 구축 | [이식 가이드](#) |
| 2026-07-04 | **CombatOverlayV2 삽탄 오류 수정 및 가방 연동** | `4948a7e9` | 가방 내 잔여 탄환 풀 연동, 동적 탄창 용량 계산 및 플레이어 턴 삽탄 로직 이식, 준비단계 삽탄 취소(Undo) 구현 완료 | [walkthrough.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/4948a7e9-5ecb-4e3a-8f7a-cbfe2a652b65/walkthrough.md) |
| 2026-07-04 | **전투 화면 UI V2 전면 재구축** | `f67c8c81` | 기획 지침 노드 트리 구조 및 절대 규칙(컨테이너 앵커 배제, Track 앵커 비율 동적 배치, BagDrawer 오버레이, FloatingLayer 적용) 전면 리모델링 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/f67c8c81-36ad-4694-9a43-bf26cd183c8c/walkthrough.md) |
| 2026-07-05 | **거리 표시, 분석 패널 워터마크, 상황 라벨 이동 및 장전 탄환 순서/은폐/아이콘 개선** | `3c923ccb` | 상황 대기 중 라벨을 전투 트랙 우상단으로 오버레이 배치, 거리 표시부 VBox 제거 및 중앙 고정, 격발 분석 패널 워터마크화(배경 25%/테두리 20%/마우스무시), 장전 탄환 LIFO 역순 정렬 및 카드 내 18px 총알 픽셀 아이콘 표시, 3번째 깊이부터 은폐(???), 가로폭 축소(180), 중심선/캐릭터/몬스터 앵커 하향(75%) | [walkthrough.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/3c923ccb-57f1-422f-9175-9d6ccf802e20/walkthrough.md) |
| 2026-07-05 | **상황 대기 패널 및 전투 대기 라벨 레이아웃 개편** | `047ebef9` | 상황 대기 패널을 교전 거리 바로 아래로 수직 배치하고 전투 대기 라벨을 전투 영역(트랙) 우측 상단으로 이동 완료 | [walkthrough.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/walkthrough.md) |
| 2026-07-03 | **보상/해금, 맵, 몬스터 & 반복성/완결 개편** | `64478efc` | TDC 가속 및 8종 총기 영구 해금 연동, 준비실 🔒 잠금 UI. 10층 압축 구조 맵 제너레이터, 2~3갈래 가로 분기 UI 그리기, 미지 노드 스캔 힌트, 조건부 우회로 실시간 개방 및 층 상승 연출 완결. 스택 스펀지(유효타 3회 및 관통 스침) 처치 기믹, ◆ ◆ ◆ 배리어 UI 표시, 태세병 1턴 전 변경 예고 HUD 연동. 5단계 침투 위험도 전술 제약(예고창 가림, 적 전진 배치, 쉴드량 스케일링, 빼내기 시 적 전진), 기밀 파편(Lore Fragment) 20종 도감 우회로 매핑 연동 및 10F 최종 탈출 성공 시 블랙박스 해독 보안 로그 폭로 소프트 엔딩 완결 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/64478efc-e950-4f76-80ad-e56539a2c655/walkthrough.md) |
| 2026-07-02 | **C_NEON_GOLD 오류 및 요원 준비실 UI & 버그/밸런스 수정 6종** | `46ca166d` | C_NEON_GOLD 상수 추가, 준비실 UI 100% 확장, 발사 버튼 모바일 오버플로우 수정, 몬스터 갤러리 카드 크기 고정 및 인게임 스프라이트 매칭 완료, 빼내기 패널티 제거 및 전술 장갑 턴 단축 재구현 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/walkthrough.md) |
| 2026-07-01 | **속사형 더블탭 & 몬스터 4종 & 총기 8종 구현** | `70fd47fc` | 속사형 더블탭 및 기믹형 몬스터 4종 설계/적용 완료. 핵심 총기 8종(표준, 저격, 돌격, 속사, 중장, 곡예, 도박, 태세사냥꾼) 리소스 및 고유 시그니처/패널티 전투 규칙 전면 구현, 준비실 스크롤 뷰 지원 및 이젝트 버튼/태세 전환 예고 HUD 연동 완료 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/70fd47fc-a52b-4449-9675-a36976f0100e/walkthrough.md) |
| 2026-07-01 | **특수 탄환 가방 미노출 버그 해결** | `820f3ccd` | 전투 인벤토리 가방 내 특수 탄환 5종 기본형 치환문 제거 및 원본 데이터 전달로 15종 탄환 개별 렌더링 및 전투 효과 활성화 보장 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/820f3ccd-0935-4d7b-bf5c-e814640fb44e/walkthrough.md) |
| 2026-06-30 | **스탯 시스템 개편 & 팝업 연출** | `8acd207f` | PRES 폐지 및 이진 관통 게이트 적용, 난이도 층별 거리 보정, 실시간 도탄/빗나감 예고 UI, 대미지 팝업 연출 구현 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/8acd207f-7395-4eef-8fdf-3a9dd9f951e9/walkthrough.md) |
| 2026-06-29 | **Tier 1 & 2 코어 전술 시스템 고도화** | `168caff8` | 다수 적 스태거링 공유 트랙, 술사 적 차징 공격, 슬로우 저격 조준, 관통 다중타 피해, 7.62mm 구경 보너스, 원터치 클릭 장전/회수 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/168caff8-edab-4761-b950-f0bd42e12149/walkthrough.md) |
| 2026-06-28 | **미드저니 MCP 서버 연동** | `287baf0e` | mcp_config.json에 python-uv 기반으로 midjourney-mcp 연동 등록 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/287baf0e-2bda-448a-bf37-3a9f62aa7cfe/walkthrough.md) |
| 2026-06-28 | **combat_scene.gd 리팩토링** | `bbacb3ae` | 씬 라우터 및 5대 독립 서브 오버레이 컴포넌트 모듈 분리 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/bbacb3ae-bec7-4690-b500-e3c4ec102daf/walkthrough.md) |
| 2026-07-05 | **상황 대기 패널 및 전투 대기 라벨 레이아웃 개편** | `047ebef9` | 상황 대기 패널을 교전 거리 바로 아래로 수직 배치하고 전투 대기 라벨을 전투 영역(트랙) 우측 상단으로 이동 완료 | [walkthrough.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/walkthrough.md) |
| 2026-07-06 | **V2 전투 UI 컴포넌트 분할 리팩토링** | `c3f9c023` | `combat_overlay_v2.gd` 거대 UI 스크립트(God Object)를 4대 독립 서브 뷰 컴포넌트(`CylinderView`, `EnemyTrackView`, `BagInventoryDrawer`, `RewardDraftPanel`)로 분할하여 결합도 하향 및 확장성 확보. 빌드본 호환성 및 보상 드래프트 락 버그 해결 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/c3f9c023-2d6f-4c73-86ee-661f3c2221e8/walkthrough.md) |
| 2026-07-06 | **Phase 4: Visual & Map 연출 고도화** | `2a3802e2` | 총기 격발 반동 및 액션바 덜컹임 트윈, 탄창 실린더 Elastic 바운스/회전, 몬스터 대기 숨쉬기 및 이동 뒤뚱거림 모션 구현. 격발(Muzzle Flash) 및 피격(Blood Spurt) 2D 파티클 이펙트 개발자 팝업 숏컷 연동 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a3802e2-7bad-40e1-a189-cac0623ac593/walkthrough.md) |
| 2026-07-07 | **탄환 반환 플로팅 UI 및 개발자 테스트 3열 개편** | `2a7f1e25` | 유효 적중(damage > 0) 시 몬스터 옆에 탄환 아이콘 및 ♻ 반환 마크 플로팅 연출 적용, 개발자 팝업 3열 GridContainer 슬롯 정렬 개편(Vector2(720, 380)), 무기 캐비닛 숏컷 및 널 크래시(Nil current_gun) 오류 해결 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a7f1e25-5d85-42cc-a209-fa37ce653956/walkthrough.md) |
| 2026-07-12 | **맵 · 레벨 구조 개정안 GDD 반영** | `ffd285f8` | 15노드(전투 10, 상점 3, 히든 2) 3구역 구조, 보상 드래프트 방안 A, 히든 노드 위험 완충, 매판 종료 시 크레딧 이월/작전 보급금 보너스 정책 기획서 공식 반영 완료 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/ffd285f8-d243-4078-8f8b-4340ac3f48b8/walkthrough.md) |
| 2026-07-12 | **맵 · 레벨 구조 및 경제 개정 기획 인게임 연동 구현** | `16ba329e` | 15노드 맵 제너레이터 개편, 맵 UI 15층 확장, 보상 드래프트 3탄환 교체(Swap) 기능, 스타팅 보증금/금고 크레딧 이월, 히든 노드 안전 완충망 구현 완료 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/16ba329e-a924-4c77-947c-907545fa1730/walkthrough.md) |
| 2026-07-12 | **작전 침투 구역 순차 해금 및 노드 완결 구조 구현** | `afaad6f3` | 5개 작전 침투 구역(섹션 A~E)의 순차 해금 조건 및 10~15층 완결 노드 구조를 인게임 진행과 로비 UI에 완전히 연동 완료, 타이틀 ➡️ 구역 선택 ➡️ 요원 준비실 UI/UX 전환 흐름 개편 적용 | [walkthrough.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/afaad6f3-77c6-4268-acfb-c7f4a2acdd2c/walkthrough.md) |
| 2026-07-18 | **통로 분기 목적지 가격 구조 구현** | `codex0718` | 목적지 클릭 한 번으로 통로 확정, 연결 노드 제한, 환기구 `-2m` 다음 전투 이월·비중첩, 무기고 통로 가변 배치, 층 스킵·통로 보상 제거 및 GDD/목업 동기화 완료 | [walkthrough.md](file:///D:/ProjectLoB/docs/walkthrough_route_branching_2026-07-18.md) |

---

## 🔗 세션별 원본 링크 (References)

* [Session codex0830-core-fun-qa Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_lifo_core_fun_qa_2026-08-30.md)
* [Session codex0830-qa-exe Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_qa_windows_launcher_2026-08-30.md)
* [Session codex0823-qa-controller Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_qa_playtest_controller_2026-08-23.md)
* [Session codex0823-qa-team Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_playtest_qa_team_phase_ab_2026-08-23.md)
* [Session codex0821-ammo-axis Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_axis_readability_2026-08-17.md)
* [Session codex0815-fire-pacing Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_fire_input_pacing_2026-08-15.md)
* [Session codex0815-upper-roster Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_upper_roster_playtest_2026-08-15.md)
* [Session codex0815-enemy-roster Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_enemy_roster_placement_2026-08-15.md)
* [Session codex0809-ammo-payoff Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_payoff_cadence_2026-08-09.md)
* [Session codex0809-mobile-guidance Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_mobile_scan_unlock_ammo_guidance_2026-08-09.md)
* [Session codex0806-function-accuracy Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_function_accuracy_2026-08-06.md)
* [Session codex0805-campaign-integrity Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_campaign_integrity_2026-08-05.md)
* [Session codex0801-playtest-telemetry Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_playtest_telemetry_density_dev_tools_2026-08-01.md)
* [Session codex0815-ammo-specialty Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_stat_specialization_2026-08-15.md)
* [Session codex0730-ammo-family Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_family_behaviors_2026-07-30.md)
* [Session codex0728-dev-reset Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_dev_reset_all_2026-07-28.md)
* [Session codex0728-basic-supply Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_basic_ammo_supply_2026-07-28.md)
* [Session codex0728-fixed-caliber Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_fixed_caliber_profiles_2026-07-28.md)
* [Session codex0728-continuous-ascent Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_continuous_ascent_2026-07-28.md)
* [Session codex0727-ammo-v6-runtime Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_runtime_migration_2026-07-27.md)
* [Session codex0727-ammo-v6-tuning Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_tuning_2026-07-27.md)
* [Session codex0727-ammo-v6-preflight Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_v6_preflight_2026-07-27.md)
* [Session codex0727-ammo-rebalance Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_role_rebalance_2026-07-27.md)
* [Session codex0726-conversion-kit Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_conversion_kit_2026-07-26.md)
* [Session codex0726-boss-qa Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_boss_formation_balance_qa_2026-07-26.md)
* [Session codex0724-smg-role Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_smg_full_auto_ammo_role_ui_2026-07-24.md)
* [Session codex0724-ammo-v5 Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_ammo_v5_migration_2026-07-24.md)
* [Session codex0718 Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_route_branching_2026-07-18.md)
* [Session codex0717 Walkthrough](file:///D:/ProjectLoB/docs/walkthrough_relic_system_removal_2026-07-17.md)
* [Session afaad6f3-77c6-4268-acfb-c7f4a2acdd2c Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/afaad6f3-77c6-4268-acfb-c7f4a2acdd2c/walkthrough.md)
* [Session ffd285f8-d243-4078-8f8b-4340ac3f48b8 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/ffd285f8-d243-4078-8f8b-4340ac3f48b8/walkthrough.md)
* [Session 16ba329e-a924-4c77-947c-907545fa1730 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/16ba329e-a924-4c77-947c-907545fa1730/walkthrough.md)
* [Session 2a7f1e25-5d85-42cc-a209-fa37ce653956 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a7f1e25-5d85-42cc-a209-fa37ce653956/walkthrough.md)
* [Session 2a3802e2-7bad-40e1-a189-cac0623ac593 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/2a3802e2-7bad-40e1-a189-cac0623ac593/walkthrough.md)
* [Session c3f9c023-2d6f-4c73-86ee-661f3c2221e8 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/c3f9c023-2d6f-4c73-86ee-661f3c2221e8/walkthrough.md)
* [Session 047ebef9-20e0-4ac7-bd96-831ae6624080 Walkthrough](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/walkthrough.md)
* [Session 3c923ccb-57f1-422f-9175-9d6ccf802e20 Walkthrough](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/3c923ccb-57f1-422f-9175-9d6ccf802e20/walkthrough.md)
* [Session 4948a7e9-5ecb-4e3a-8f7a-cbfe2a652b65 Walkthrough](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/4948a7e9-5ecb-4e3a-8f7a-cbfe2a652b65/walkthrough.md)
* [Session 64478efc-e950-4f76-80ad-e56539a2c655 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/64478efc-e950-4f76-80ad-e56539a2c655/walkthrough.md)
* [Session 46ca166d-2f0e-4374-9d61-863e0f35dfaf Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/walkthrough.md)
* [Session 287baf0e-2bda-448a-bf37-3a9f62aa7cfe Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/287baf0e-2bda-448a-bf37-3a9f62aa7cfe/walkthrough.md)
* [Session 168caff8-edab-4761-b950-f0bd42e12149 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/168caff8-edab-4761-b950-f0bd42e12149/walkthrough.md)
* [Session 8acd207f-7395-4eef-8fdf-3a9dd9f951e9 Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/8acd207f-7395-4eef-8fdf-3a9dd9f951e9/walkthrough.md)
* [Session 820f3ccd-0935-4d7b-bf5c-e814640fb44e Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/820f3ccd-0935-4d7b-bf5c-e814640fb44e/walkthrough.md)
* [Session 70fd47fc-a52b-4449-9675-a36976f0100e Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/70fd47fc-a52b-4449-9675-a36976f0100e/walkthrough.md)
* [Session 46ca166d-2f0e-4374-9d61-863e0f35dfaf Walkthrough](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/46ca166d-2f0e-4374-9d61-863e0f35dfaf/walkthrough.md)


