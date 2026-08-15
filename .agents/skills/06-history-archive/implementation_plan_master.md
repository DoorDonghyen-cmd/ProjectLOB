# 🗺️ Implementation Plan Master (구현 계획서 설계 아카이브)

이 파일은 각 기능 단위 개발이 착수되기 전, 기술적 분석과 기획 정합성을 맞춘 구현 계획서(`implementation_plan.md`)를 총망라하는 인덱스입니다.

---

## 📋 구현 계획서 리스트

| 생성일 | 주제 | 세션 ID | 주요 설계 방향 | 문서 링크 |
| :--- | :--- | :--- | :--- | :--- |
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

---

## 🔗 세션별 원본 링크 (References)

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


