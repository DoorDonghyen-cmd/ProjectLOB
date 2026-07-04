# 🗺️ Implementation Plan Master (구현 계획서 설계 아카이브)

이 파일은 각 기능 단위 개발이 착수되기 전, 기술적 분석과 기획 정합성을 맞춘 구현 계획서(`implementation_plan.md`)를 총망라하는 인덱스입니다.

---

## 📋 구현 계획서 리스트

| 생성일 | 주제 | 세션 ID | 주요 설계 방향 | 문서 링크 |
| :--- | :--- | :--- | :--- | :--- |
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
| 2026-07-05 | **상황 대기 패널 및 전투 대기 라벨 레이아웃 개편** | `047ebef9` | 상황 대기 패널을 교전 거리 아래로 배치하고 전투 대기 라벨을 전투 영역 우측 상단으로 이동 | [implementation_plan.md](file:///C:/Users/도얼동현/.gemini/antigravity-ide/brain/047ebef9-20e0-4ac7-bd96-831ae6624080/implementation_plan.md) |

---

## 🔗 세션별 원본 링크 (References)

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


