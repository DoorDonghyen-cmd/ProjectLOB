# 🎓 Walkthrough Master (완료 작업 워크스루 아카이브)

이 파일은 각 세션(Conversation)별로 정상 동작이 검증되고 병합 완료된 기능들의 워크스루(`walkthrough.md`)를 총망라하는 인덱스입니다.

---

## 📋 검증 히스토리 리스트

| 완료일 | 주제 | 세션 ID | 주요 구현 내용 | 문서 링크 |
| :--- | :--- | :--- | :--- | :--- |
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

---

## 🔗 세션별 원본 링크 (References)

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


