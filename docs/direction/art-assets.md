# 아트 자산과 적용 상태

**전투 복장 7종 G안 적용(2026-11-08)** — 승인된 운반복 G를 기준으로 권총·장총의 실제 사용 자세 77개를 [몸체·앞손 공용 아틀라스](../../새-게임-프로젝트/assets/art/combat_outfit_grid_20261108/provenance.json)에 구웠다. 전투와 장비 선택의 총을 든 배우에 적용했다. 복장별 재질색을 살리고 손·총·발 등록을 유지한다. [Godot 28컷 복장·자세 비교](../qa/reports/combat_outfit_grid_2026-11-08/outfits.png)

**이전 전투 복장 7종 색면 정리(2026-11-07)** — 운반복 E안을 기준으로 헬멧·어깨·가방·바지의 도트 덩어리를 정리했다. [자산 21장과 출처](../../새-게임-프로젝트/assets/art/combat_outfit_blocks_20261107/provenance.json)는 원본 포즈·파지·발 좌표 및 G의 제작 입력을 보존한다. [당시 Godot 복장 비교](../qa/reports/combat_outfit_blocks_2026-11-07/outfits.png)

**신규 총기2종(2026-11-06):** `assets/art/weapon_expansion_20261106/{deadbolt_break_v4,rewinder_v1}.png`와 같은 폴더의 provenance를 등록했다. 생성 원본/프롬프트·참조·폐기 후보는 [제작 기록](../art/concepts/2026-11-06-new-weapons/provenance.json), 실제 본편 선택/7복장·6자세/사격/냉각은 [검수](../qa/reports/weapon_live_2026-11-06/README.md)를 따른다. 리와인더 외형은 사용자 긍정, 데드볼트는 사용자 중절식 방향 선택의 구현안이며 최종 화면 미감 확인은 남는다.

**정적 리소스 수의 범위 정정(2026-11-06 후속 UI 검수):** 과거 기록의 ‘magazine-journey/여정’ 개수는 공유 HUD의 별도5전투 연구판을 추적한 목록이다. 본편 전체 리소스 수/패키지 포함 검사로 사용하지 않는다. [실제 본편 main.tscn 진입 기준 검사](../qa/reports/interaction_fx_2026-11-06/README.md)를 구분한다. 기존 VFX의 본편 연결 자체는 실제 캠페인 장면/공개 입력 검사로 확인했다.

**장갑·차폐/불꽃 시트1차(2026-11-06):** `assets/art/surface_fx_20261106/`의 금속 접촉29·차폐23·화염 반복12프레임 시트3개를 본편에 연결했다. 고정 pixelfx의 실제 접점/팔레트를 등록하고 횃불 하드웨어는 제외했다. 전류·불씨 이동/장갑 조각은 제한된 Godot 도형이다. [출처·해시](../../새-게임-프로젝트/assets/art/surface_fx_20261106/provenance.json) · [26구성/5구역 실제 화면·검증/한계](../qa/reports/surface_fx_2026-11-06/README.md). 숫자 위계를 지키고12Hz/그리기 상한·동작 축소를 적용했다. 여정 참조365개. 세부 재질·사람/S26은 후속이다.

**탄두형 투사체 후속(2026-11-06):** 승인된 탄환의 구리/강철 색면을 참고해 `projectile_visual.gd`에서 계단형 금속 탄두를 그린다. 기본·침형·띠형·둔형·소이형/지원 캡슐로 구분하고 실제 비행 방향으로 회전한다. PNG 추가 없이 기존 섬광 시트/탄환 카드와 연결하며 강화색은 띠/짧은 잔상에 남긴다. [최신 실제 화면·범위·검증](../qa/reports/firing_fx_2026-11-06/README.md#탄두형-투사체-후속). 본편 참조361개, 실제 화면17구성/66단계 확인. 이전 본편 섬광 시트는 유지한다.

**5총기 발사 시트1차(2026-11-06):** `assets/art/firing_fx_20261106/muzzle.png`는 고정 pixelfx의 섬광 레시피만 재구성한480×384/30프레임 중립 시트다. 실제 총구 좌표/회전과 강화 적중색에 연결한다. 탄도는 실제 결과당 한 줄이며 지원/강행·동작 축소를 구분한다. [출처/해시](../../새-게임-프로젝트/assets/art/firing_fx_20261106/provenance.json) · [실제 화면/검증·한계](../qa/reports/firing_fx_2026-11-06/README.md). 후보 전체 효과의 연기·탄피·다수 탄도는 복사하지 않았다. 사람/S26과 나머지 타격·속성 효과는 후속이다.

**파츠/배율 적중 시트1차 본편(2026-11-06):** `assets/art/impact_parts_20261106/multiplier.png`는 고정 pixelfx의23프레임 중립색 시트864×816이다. 실제 적용된 효과에 따라 본편에서 색/단계를 지정하며 접점(84,80)을 맞춘다. 숫자의 +/모서리/이중 눈금과 중첩 측면 무늬는 Godot 도형이다. [출처/옵션·해시/고지](../../새-게임-프로젝트/assets/art/impact_parts_20261106/provenance.json) · [색/실제 입력·동작 축소·검증](../qa/reports/impact_parts_2026-11-06/README.md). 선택한 시트만 본편 참조하며 비교용 hit-spark는 QA에 보존했다. 사람 미감·Android와 재질/차폐/다른 효과는 후속이다.

**리벳 양손 카빈 본편(2026-11-06):** `assets/art/rivet_twohand_20261106/rivet_carbine_v1.png`는 내장 image_gen/4실제 참조로 만든2172×724 RGBA 원화이며 `rivet_carbine_v1_pixel.png`는 선택한 PixelOE RGB 정리본이다. 본편 `weapon_art.gd`의 장비/전투 공통 프로필에 등록했고7복장 장총 자세를 재사용했다. [전체 프롬프트/참조/해시](../../새-게임-프로젝트/assets/art/rivet_twohand_20261106/provenance.json) · [후보8종과 처리](../../새-게임-프로젝트/assets/art/style_pilot_20261106/provenance.json) · [전후/검증](../qa/reports/rivet_art_2026-11-06/README.md). 기존 원화/몸체/배경은 보존했다. 선택안은 본편 적용, 나머지 후보는 비교용이며 사람의 미감 채택/Android는 후속이다.

**전투 기호 최신 — 2026-11-01 후속:** 사용자 승인으로 `pipe_map_art_20261101/combat.png`는 교차 총기36px, `elite.png`는 같은 총기 뒤 방호판44px, `elite_detail.png`는 별도36px 판으로 교체했다. 앞선 몬스터 얼굴 두 형태를 대체한다. 관문 차단문과 나머지26PNG·씬·게임 규칙은 동일하다. 지도/선택 패널/범례 공통 적용. 픽셀 좌표 원본과 정확한2배 내보내기를 기존 제작 도구에 유지한다. [최신 화면·변경 범위·검증](../qa/reports/pipe_map_symbols_density_2026-11-01.md). 미감의 사용자 확인은 후속이다.

**배관도 전용 그래픽 — 2026-11-01:** `assets/ui/pipe_map_art_20261101/`의29PNG와 지도 전용 면을 본편에 연결했다. 장소 기호7종+정예 상세1, 구역 문양5종×3상태, 밸브2, 관문 크기/상태3, 지도 면1이다. 원본은 `art_source/ui/pipe_map_20261101/`, 편집 가능한 픽셀 좌표/제작 명령은 `tools/build_pipe_map_art.py`다. 코드로 직접 그린 도트이며 생성형 이미지나 기존 그림의 자동 임계값 변환을 사용하지 않았다. [참조·해시 목록](../../새-게임-프로젝트/assets/ui/pipe_map_art_20261101/provenance.json) · [실제 전후·검증](../qa/reports/pipe_map_art_2026-11-01.md). 기존 동네/제어실2기호·공통 라인 테마와 과거 지도 자산은 보존한다. 제작 원본 폴더의 미사용 관문 변형3개는 초안이며 런타임 내보내기에서 제외했다. 사용자 미감과 Android 실기기 검증은 별도다.

**최신 적용 — 픽셀 전투 HUD(2026-11-01):** 승인 목업을 `assets/ui/combat_pixel_20261101/`의32×32 상태 프레임10종,14×22 탄환20종, Galmuri9/11 비트맵 글꼴과 테마로 분리해 탄창 여정/비교 HUD에 연결했다. 글꼴은각1024×2048 두 페이지와OFL을 포함한다. LibreSprite 네이티브 픽셀 제작, 모든 글리프의 원본BDF 대조와 투명성 검증 완료. [제작·해시](../../새-게임-프로젝트/assets/ui/combat_pixel_20261101/provenance.json) · [실제 화면·검증](../qa/reports/combat_pixel_live_2026-11-01.md). 글자/수치는 Godot 노드이며 공용 탄환/배우/배경 원본과 feedkit 이력은 보존한다. 현재 HUD의 feedkit 외피를 대체하며 Android/사용자 체감은 후속이다.

**최신 적용 — 같은 제작소의 급탄 장비8종(2026-10-31):** `assets/art/combat_feedkit_20261031/kit.png`는 내장 image_gen으로 제작한 RGBA1536×1024 원본이다. 레일·발사/대기 패·사격/냉각/교체판·발열계·모달8종을 사용한다. 읽기 전용 알파 경계 측정과 Godot AtlasTexture/9분할/축척으로 연결했고 원본 비트맵은 편집하지 않았다. [전체 프롬프트·참조·해시](../../새-게임-프로젝트/assets/art/combat_feedkit_20261031/provenance.json) · [등록 도구](../../tools/build_combat_feedkit_resources.py) · [실제 화면·검증](../qa/reports/combat_feedkit_2026-10-31.md). 앞선 천/종이/개별 소품 원본은 보존한다. 사용자 미감은 확인 전이다.

**최신 적용 — 전투 도트 소품 원화(2026-10-31):** `assets/art/combat_pixelcraft_20261031/kit.png` RGBA1536×1024 원본8부품과 AtlasTexture8등록을 추가했다. 천 받침·표찰·사격/냉각/교체판·계기 홈·모달7종은 적용, 헤더 탭은 미사용 원본으로 보존한다. PNG무편집·읽기 전용 알파 측정·Godot영역/9분할/축척/nearest 표시로 연결했다. [원화·프롬프트·참조·해시](../../새-게임-프로젝트/assets/art/combat_pixelcraft_20261031/provenance.json) · [등록 도구](../../tools/build_combat_pixelcraft_resources.py) · [실제 화면·검증](../qa/reports/combat_pixelcraft_2026-10-31.md). 기존 배우/배경/탄환 PNG는 무변경이며 사용자 미감 확인은 남는다.

**최신 적용 — 전투 UI 색·형태 분리(2026-10-31):** `assets/ui/combat_identity/`의 SVG8개·TRES27개로 반복 청회색 박스를 대체했다. 밝은 탄약 표찰과 주홍 트리거는 모서리 고정9분할, 공통 받침·냉각·교체는 네이티브 스타일, 포커스는 밝고 어두운 면에 대응하는 두 색 모서리다. 기능 글자/숫자는 Godot노드로 남는다. 기존 작은 탄환 원화는 무변경. [제작 원본](../../tools/build_combat_hud_identity.py) · [출처·용도·해시](../../새-게임-프로젝트/assets/ui/combat_identity/manifest.json) · [실제 화면·검증](../qa/reports/combat_identity_2026-10-31.md). 새 미감은 사용자 확인 전이다.

**최신 적용 — 작은 무광 탄환과 단순한 HUD(2026-10-31):** 이전 큰 탄환의 도트·광택에 대한 사용자 지적으로 `assets/art/ammo_quiet_20261031/rounds.png`의20프레임 원화를 공용 표시로 연결했다. 승인 캐릭터와 기존 탄종 형태를 참조하고 원본 PNG를 바이트 그대로 보존했다.189탄환 ID와 thermal→bore 별칭을 유지하며 주 탄창의 그림은 최대28×44다. `assets/ui/combat_quiet/`의18개 네이티브 StyleBox가 주 화면의 두꺼운 외피·홈을 대체한다. 이전 원화/금속 HUD는 이력으로 보존한다. [출처·프롬프트·해시](../../새-게임-프로젝트/assets/art/ammo_quiet_20261031/provenance.json) · [통합 화면·검증](../qa/reports/combat_focus_2026-10-31.md). 새 미감의 사용자 확인은 남는다.

**최신 적용 — 탄환 재질 통일(2026-10-31):** `assets/art/ammo_cohesion_20261031/`의 생성 원본PNG3장(기본6·특수12·이전 저장용2)을 공용 `ammo_art.gd`에 연결했다. 현재189탄환 ID의 원형/개조/등급/이전 별칭에 대응한다. `thermal`은 기존대로 `bore`를 사용하므로 별도 규칙이나 새 탄종이 생긴 것이 아니다. 기존 원화와 과거 비교 시안은 보존했다. 원본 파일은 바이트 그대로 복사하고 Godot의 영역 등록·nearest 표시만 적용했다. [참조·프롬프트·원본/결과 해시](../../새-게임-프로젝트/assets/art/ammo_cohesion_20261031/provenance.json) · [전체·인게임·검증](../qa/reports/ammo_cohesion_2026-10-31.md). 사용자 미감 확인은 후속이다.

**최신 적용 — 전투 HUD 재질(2026-10-31):** `assets/ui/combat_hardware/`에 도트 금속 프레임20종의SVG/TRES와 냉각·교체·사격 기호3종을 추가했다. 새 공통 전투HUD에 연결하고 기존 배경·배우·탄환 원화는 보존했다. 이미지 생성이나 래스터 편집 없이 직접 작성한 벡터 모양이며,9분할로 모서리를 유지한다. [제작 원본](../../tools/build_combat_hud_materials.py) · [용도·참조·해시](../../새-게임-프로젝트/assets/ui/combat_hardware/manifest.json) · [실제 화면/검증](../qa/reports/combat_hud_cohesion_2026-10-31.md). 미감의 사용자 확인은 후속이다.

**최신 적용 — 승인 B 친위대6종(2026-10-26):** `central_guard_alt_20261025/`의 사용자 선택 B 일반4PNG와 `central_leaders_20261026/`의 친위대장/탑의 지배자 추가 원화2PNG를 본편에 연결했다. 추가2종은 같은 계열의 디렉터 임시 원화이며 사용자 선호는 후속이다. 원본 픽셀 보존, alpha/발 기준 측정과 export-safe texture 등록, 이동·피격·사망·지휘 강조·피니시 통합. 별도 상태 키포즈 시트는 제작하지 않았다. A/B 비교 뷰어는 이력으로 유지. [추가 원화 출처](../../새-게임-프로젝트/assets/art/central_leaders_20261026/provenance.json) · [실제 화면·검증](../qa/reports/central_live_2026-10-26.md).

**최신 적용 — 귀족 거주구6종(2026-10-25):** `assets/art/noble_enemies_20261025/`의 최종5PNG로 일반4종·정예·보스를 본편에 연결했다. 차폐형4종은 각3자세, 가문 시종/경호기는 정지 원화와 절차적 동작이다. 원본 픽셀은 보존하고 알파 경계·발 접점·축척을 Godot에 등록했다. C 주인공과 귀족 배경을 함께 참조했다. 제작자 화면 검수 완료, 사용자 미감은 후속. [실제 화면](../qa/reports/noble_live_2026-10-25.md) · [원본·프롬프트](../../새-게임-프로젝트/assets/art/noble_enemies_20261025/provenance.json).

**최신 적용 — 승인7복장 본편 통합(2026-10-25):** `assets/art/outfits_unified_20261025/`의 대기7장/동작13장(교정2장 포함)/실내7장으로 장비 선택·전투·21실내 자세를 연결했다. 기본 권총은 기존 C를 보존하며 운반복 멜빵/정찰복 길이/인양 릴을 교정했다. 아래 시안 미적용 상태는 제작 당시 이력이다. [화면·검증](../qa/reports/outfits_unified_2026-10-25.md) · [원본·프롬프트](../../새-게임-프로젝트/assets/art/outfits_unified_20261025/provenance.json).

**전체7복장 시안 후속 — 2026-10-25:** 운반복 멜빵이 한손 앞팔을 덮던 오류를carrier_v4에서 양쪽 파지 모두 교정. 방열/인양/회수/원정4종을 C의 몸 비율·색면·윤곽과 기존 낮은 파지를 기준으로 시안 제작했다. 실제 복장 고유 장치/밀폐 헬멧은 유지. Godot245px/94px 전체7종 비교, 본편 미적용·사용자 검토 전. [전체 비교·출처](../art/concepts/2026-10-25-outfit-unification/ALL_OUTFITS.md).

**기본·운반·정찰 통일 시안 — 2026-10-25 후속:** 리벳·스파이크 C를 기준으로 기본 양손 몸체를 맞추고, 운반복은 긴 적재 외투/정찰복은 짧은 재킷으로 구분한2자세 원화3장을 제작했다. 실제 총기와 Godot245px/94px 정지 비교까지이며 본편은 미변경. 최초 양손 팔 들림을 기존 low-ready 파지로 교정했다. 사용자 검토·6키포즈/접점·전체5무기·실내 연결은 후속. [비교판·프롬프트·범위](../art/concepts/2026-10-25-outfit-unification/README.md).

**스플린터 최신v3:** v2의 벌어진 총열은 사용자에게 닭발처럼 보여 제외. `weapon_redesign_20261024/scatter_splinter_v3.png`(2172×724 RGBA)는 v1을 입력으로 원통형 덮개와 전면 세 총구로 수정한 정지 시안이다. 원본·다른 무기는 보존. Godot400px/110px 비교 확인, 본편/파지/모션 미적용. [제작 기록](../../새-게임-프로젝트/assets/art/weapon_redesign_20261024/splinter_v3_provenance.json).

**스플린터 외형 수정:** 사용자 요청으로 `weapon_redesign_20261024/scatter_splinter_v2.png`(2172×724 RGBA)를 제작했다. v1을 실제 편집 입력으로 사용해 전면을 세 노출 총열로 변경, 원본/몸체 계열/다른 무기는 보존했다. 정지 시안이며 본편 미적용. [수정 프롬프트·해시](../../새-게임-프로젝트/assets/art/weapon_redesign_20261024/splinter_v2_provenance.json) · [작은 크기 비교](../qa/reports/assets/weapon_remaining_concepts_2026-10-24_splinter_v2/remaining_concepts_1440.png).

**무기 시안 최신:** 아래 첫 시안의 빗장은 현재 **리벳(Rivet)** 제안으로 변경. 생성PNG는 보존하고 Godot 부착 축척을0.13→0.10, 진열을82%로 줄였다. 래칫은 유지. 후속 요청으로 스플린터2172×724/리액터2160×728/스파이크2098×749 RGBA 원본도 각1장 확보했다. 기존 두 총기와 승인 주인공을 image_gen 입력으로 사용, 원본 무편집·전체 프롬프트·참조/출력 해시 보존. 새3종은400px/110px 폭의 Godot 정지 비교까지이며 파지·모션·본편은 미적용이다. [최신 설계](weapon-design.md) · [검수](../qa/reports/weapon_concepts_2026-10-24.md) · [새3종 제작 기록](../../새-게임-프로젝트/assets/art/weapon_redesign_20261024/remaining_concepts_provenance.json).

**무기 디자인 시안2종 — 2026-10-24:** `weapon_redesign_20261024/single_latch_v1.png`(1536×1024), `burst_ratchet_v1.png`(1774×887) RGBA. 내장 image_gen 원본 보존, 기존 무기/승인 캐릭터/실제 정원 화면을 참조했다. 독립 뷰어의 장비 크기·몸체 합성·6자세·복장 전환에만 연결. 빗장/래칫은 이름 제안이며 본편은 보행자/쇄도와 기존 이미지 유지. [프롬프트·해시](../../새-게임-프로젝트/assets/art/weapon_redesign_20261024/provenance.json) · [렌더](../qa/reports/weapon_concepts_2026-10-24.md).

**우수 정원 정예·보스 — 2026-10-24:** `garden_leaders_20261024/longleg_states_v1.png`, `watermother_states_v1.png`. 내장 image_gen2장/각3키포즈,2172×724 RGBA 원본 보존. 승인 숨접이/빗주머니/주인공/실제 정원 화면 참조. UV 다각형·발 위치·종별 동일 축척으로 분리/표시하며 메타데이터 측정 재현 도구를 보존했다. 본편3구역 신규 편성9와 개발 정예/보스 바로가기, 피격·도약·피니시 통합. 3비율23캡처 중 대표7장 검수, 사용자 미감/Galaxy는 확인 전. [전체 프롬프트·해시](../art/garden-leaders-20261024.json) · [화면·검증](../qa/reports/garden_live_2026-10-24.md).

**중앙 통제구 전용3단계 전투 배경 — 2026-10-24 후속:** `central_ascent_20261024/{lower,middle,upper}_v1.png`. 내장 image_gen3장, 승인 주거/최근 귀족 원화·실제 전투 화면 참조.1672×941 RGB 생성 원본 보존, 실제 지면686/687/687 등록. 검문 회랑→공급 통제실→중앙 제어핵으로 본편5구역에 적용. 3비율 일반/정예/보스·피니시·기존 엔딩19렌더 중16장 확인. 1~5구역 전용 전투 배경 적용 완료이며 아래 과거 미제작 표기보다 이 항목이 우선한다. 사용자 미감·Galaxy·친위대/지배자·엔딩 전용 아트는 후속. [화면·전체 프롬프트·검증](../qa/reports/central_background_2026-10-24.md).

**귀족 거주구 전용3단계 전투 배경 — 2026-10-24:** `noble_ascent_20261024/{lower,middle,upper}_v1.png`. 내장 image_gen3장, 승인 주거/정원 상층v2와 실제 전투 화면 참조.1672×941 RGB 원본 보존, 실제 지면686/686/687 등록. 전용 승강장→저택 거리→가문 접견관으로 본편4구역에 적용하고 표시명을 ‘귀족 거주구’로 정리했다.3비율 일반/정예/보스·피니시16장 중 대표13장 시각 확인. 사용자 미감·Galaxy·귀족 전용 적은 후속이며5구역 원화는 위 항목에서 적용했다. [실제 화면·전체 프롬프트·검증](../qa/reports/noble_background_2026-10-24.md). 아래 정원 제작 당시4~5구역 미제작 상태보다 이 항목이 우선한다.

**우수 정원 전용3단계 전투 배경:** `garden_ascent_20261023/lower_v1.png`, `middle_v1.png`, `upper_v2.png`. 승인 주거/주조장 원화 참조, 내장 image_gen으로 제작.1672×941 RGB 원본 보존, 발판y663/698/687 등록. 사육 통로→온실→집수 수로로 본편3구역에 적용했다. 사용자 전체 방향 긍정 평가 후 상층 식물 보강 요청으로 수문·기둥의 뿌리와 덩굴, 하부 잎을 추가한v2로 교체했다. 상층v1은 이력 보존. [화면·전체 프롬프트·검증](../qa/reports/garden_background_2026-10-23.md). 상층v2 사용자 미감은 후속,4~5구역 전용 배경은 미제작.

**주조장 전용3단계 전투 배경:** `foundry_ascent_20261023/lower_v1.png`, `middle_v1.png`, `upper_v1.png`. 내장 image_gen으로 승인 주거 배경과 실제 전투 화면을 참조해 제작.1672×941 원본을 보존하고 발판 y702/713/713 등록. 본편2구역과 개발 비교에 적용,3비율/피니시13화면 검수. [실제 화면·전체 프롬프트·검증](../qa/reports/foundry_background_2026-10-23.md). 주조장 배경은 사용자 긍정 평가를 받았고,3구역 배경은 위의 후속 작업으로 적용했다.4~5구역은 미제작.

**주조장 본편 동작 — 2026-10-23 후속:** 이전6종 원화와 `foundry_motion_20261023/`의 2포즈 시트3장(금형 파수꾼 축압/전진, 주조 감독 축압/전진, 압력공 조준/반동)을 편성8 본편에 연결했다. 키포즈+절차형 이동·피격·사망이며 프레임별 수작업 걷기 애니메이션은 아니다. 원본 PNG·전체 프롬프트·해시·발 기준·UV 등록 보존. 보스 시트의 두 실루엣은 좌우 폭이 일부 겹쳐 투명한 사이를 나누는 UV 다각형으로 분리한다. 실제 렌더에서는 체력 영역을 확보하도록 정예140px/보스148px 표시 높이를 사용한다. 아래 정지 시안 단계보다 이 적용 상태가 우선한다. [출처·등록](../../새-게임-프로젝트/assets/art/foundry_motion_20261023/provenance.json) · [화면·검증](../qa/reports/foundry_live_2026-10-23.md).

**주조장 정예·보스 콘셉트 — 2026-10-23:** `foundry_leaders_20261023/`의 금형 파수꾼·주조 감독 정지 원화2장을 추가했다. 이전 일반4종과 같은 재질/화풍을 사용하며 기존 비교 뷰어에 그룹 전환을 추가했다. 원본 RGBA/발 기준/전체 프롬프트와 참조·출력 해시 보존,3해상도 실제 비교 완료. 본편 아트 교체·상태 키포즈는 후속. [제작 기록](../../새-게임-프로젝트/assets/art/foundry_leaders_20261023/provenance.json) · [화면·검증](../qa/reports/foundry_leaders_2026-10-23.md).

**주조장 일반4종 콘셉트 — 2026-10-22:** `foundry_concepts_20261022/`의 노역 인형·금형공·압력공·재받이4장을 정지 시안으로 제작했다. 원본 RGBA/측정 영역/발 기준을 보존하고 확대·전투 크기 비교 화면과 개발 메뉴 진입을 연결했다. 본편 편성/아트는 미교체, 새 배경/상태 동작/사용자 미감은 후속. [원본·전체 프롬프트](../../새-게임-프로젝트/assets/art/foundry_concepts_20261022/provenance.json) · [비교 화면·검증](../qa/reports/foundry_concepts_2026-10-22.md).

**정예·보스 원화 — 2026-10-18 본편 적용:** `elite_boss_20261018/resonant_eavesback_states.png`와 `closure_watch_states.png`를 편성5 주거구에 연결했다. 각각 대기/공명·닫힘/열림2상태, 기존 큰 색면 참조를 실제 이미지 입력으로 사용했다. 생성 PNG는 그대로 보존하고 Godot 영역/발 기준점/nearest/기존 알파 컷아웃으로 표시한다. 상태·피격·사망의 절차형 동작 포함, 모든 프레임을 그린 애니메이션은 아니다. 제작자 실제 화면 검수 완료, 사용자 미감/Galaxy는 후속. [프롬프트·출처·해시](../art/concepts/elite-boss-20261018/provenance.json) · [전투 화면](../qa/reports/elite_boss_2026-10-18.md).

**탄환 공용 아트 — 2026-10-18 후속:** 기존6종 v4와 새 `ammo_recast_20261018/special_rounds_v1.png` 12종을 공용 렌더에 연결. 현재 획득17가족 + 기존 연계탄을 같은 무광 큰 색면으로 표시한다. 예약/차단의 이전 보유물은 기존 그림 유지. 보상·상점·가방·압축도 같은 원화 사용. 생성 원본 그대로, Godot 영역 등록/nearest 렌더. [생성 기록·해시](../art/concepts/ammo-recast-20261018/provenance.json) · [실제 화면](../qa/reports/ammo_collection_2026-10-18.md). 아래 전투만 적용/나머지 기존 그림 내용은 이전 단계다.

**탄환6종 v4 원화 — 본편 전투 적용(2026-10-18):** `ammo_recast_20261017/cartridges_v4.png`를 손패·발사 레일·장전 이동·손패 상세에 연결했다. 기본/철갑/연타/증폭/냉각/전격과 해당 변형에 사용하며, 나머지 가족은 기존 그림을 보존한다. 상점/보상/가방 그림은 기존 공용 카드 유지. 사용자 승인으로 본편 적용, 실제 사용자 미감 확인은 후속. [출처](../art/concepts/ammo-recast-20261017/provenance-v4.json) · [화면·범위](../qa/reports/combat_hand_live_2026-10-18.md).


**쇄도 표시 해상도 후속:** 신규 원화 없이 `burst_v4.png`를 유지하고 무기만 낮은 해상도 레이어로 합성한다. 캐릭터와 앞손은 기존 렌더, 총구·재장전 등록도 유지. 다른4총기에는 적용하지 않았다. [이전/이후·실제 전투](../qa/reports/weapon_density_2026-10-14.md). 사용자 체감 확인 전이다.

**쇄도 굵은 외곽선 비교 v4:** `weapons_mass_20261013/burst_v4.png`만 본편 쇄도에 적용했다. 사용자 요청에 따라 바깥 도트 경계를 굵게 하고 내부 선은 적게 유지했다. 나머지4총기는 v3. [전후·프롬프트·검증](../qa/reports/burst_contour_2026-10-14.md). 사용자 미감 확인 전 비교안이다.

**전투 총기 표현 v3:** 다섯 총의 검은 내부 경계·밝은 테두리·잔선을 덜고 캐릭터의 큰 색면에 맞췄다. `weapons_mass_20261013/*_v3.png`를 공용 `weapon_actor.gd`에서 사용한다. 장비 선택용 원화 유지. [전후·검증·생성 기록](../qa/reports/weapon_mass_2026-10-13.md). 제작자 시각 검수 완료, 사용자 체감은 후속. v2는 중간 후보다.

**신규 복장 본편 4종:** `outfits_live_20261013`의 방열복·인양·회수 15개 PNG와 기존 `outfit_preview_20261011` 원정복5개를 `outfit_art.gd`/`service_actor_catalog.gd`에서 공유한다. 선택·전투·실내·복장 작업실에 적용. [생성 프롬프트·참조·해시](../../새-게임-프로젝트/assets/art/outfits_live_20261013/provenance.json) · [화면·검증](../qa/reports/outfits_live_2026-10-13.md). 인양 대기 팔은 재생성v2 사용, 새 자산 원본 알파 보존. 기존 scout/carrier 별도 전투·실내 원화는 후속.


**첫 구역 높이별 전투 배경:** 기존 `tower_sample_20261003/residential_tower.png` + `residential_ascent_20261011/middle_v1.png`, `upper_v1.png`. 후속2종은 기존 승인 배경을 참조한 내장 image_gen 원본이며 후처리 없이 발판 높이를 등록했다. [화면/검증/전체 프롬프트](../qa/reports/ascent_background_2026-10-11.md). 2구역 전용3종은 위의 주조장 배경으로 후속 적용했다.3구역도 우수 정원 후속 원화로 적용했다.4~5구역은 제작 전이다.

**전투 잔열 표시:** 별도 사각 막대를 없애고 각 무기 텍스처의 금속 영역에만 열기 색을 적용한다. 투명 영역·손·몸체 윤곽은 유지하며 냉각0에서 원복된다. [사용자 캡처 재현/수정](../qa/reports/weapon_heat_artifact_2026-10-11.md).

**현행 주인공 전투:** `weapon_motion_20261011/`의 권총/장총v2 몸체와 `weapons_combat_20261011/`의 전투용 단순화 총기5종을 분리 합성한다. 장비 선택은 `weapons_20261011/` 원화를 유지한다. 총열의 홈/밝은 고리와 앞손 가림을 줄인 [가독성 수정](../qa/reports/weapon_readability_2026-10-11.md)을 현재 적용한다. 기존 고정 총기4포즈와 ASE 원본은 보존하되 본편 렌더러는 새 몸체를 사용한다. [출처](../../새-게임-프로젝트/assets/art/weapon_motion_20261011/provenance.json) · [실제 화면](../qa/reports/weapon_motion_2026-10-11.md).

**타이틀 대기 주인공:** `assets/art/title_20261011/reclaimer_idle_v1.png`와 `reclaimer_idle_frames.tres`, `redesign/title_reclaimer.tscn`. 승인 주인공/기존 키포즈 참조, built-in image_gen 생성·손 오류 교정. 왼쪽을 보는4포즈/6.9초 대기, RGBA 원본 보존·아틀라스 발 등록·표시 시 alpha cutout. [전체 프롬프트](../art/title-idle-20261011.json) · [실제 화면/190검사](../qa/reports/title_idle_2026-10-11.md). 모션 미감은 사용자 확인 전.

**처마등 동작:** `assets/art/monster_motion_20261011/eavesback.png`와 `eavesback_frames.tres`, 편집 원본 `art_source/monsters/eavesback/eavesback.ase`. 승인 정지 시안을 참조한4키포즈(걷기2프레임), built-in image_gen 제작 후 자체 태그/시간/발 등록 경로. 생성 알파의 흐린 가장자리는 전용 런타임 컷아웃 shader로 제거한다. 개발 시연에만 적용, 기존 정지 원본 보존. [생성 프롬프트](../../art_source/monsters/eavesback/provenance.json) · [실제 화면과 검증](../qa/reports/monster_motion_2026-10-11.md).

**현행 전투 도트 UI:** `combat_pixel_skin.gd`의 24×24 직접 구성한 3색 프레임과 16×16 조작 기호, `combat_pixel_font.tres`의 기존 NeoDunggeunmoPro를 공용 적용한다. Godot에서 9분할하고 글자/수치를 실시간 표시한다. 탄창·손패·발사·재장전(접촉 위험 포함)·보조 조작·드래그 미리보기·HP/거리까지 연결. 이전 `fieldkit_ui_20261009` PNG는 사용자 미채택 제작 이력으로 보존하며 본편에서 참조하지 않는다. [제작 기록](../art/combat-pixel-ui-20261009.json), [실제 화면](../qa/reports/combat_pixel_ui_2026-10-09.md).

**전투 비주얼 공용 마감 1차:** `combat_surface.gd`의 도형 기반 금속 프레임과 탄창/발열계, 기존 전투 어댑터의 접지·입자·탄피·과열/냉각 반응. 생성 PNG 교체 없음. 본편 공용 적용, 개발 시연의 생물 시안은 본편 적 교체와 구분한다. [제작 출처](../art/combat-finish-20261009.json), [실제 화면·검증](../qa/reports/combat_finish_2026-10-09.md).

**파츠28종 리터치:** [part_icon_art.gd](../../새-게임-프로젝트/redesign/part_icon_art.gd)의 수작업 CanvasItem 도트 도형을 공용 카드에 연결했다. 비트맵 생성/필터 보정 없이 각 부품의 본체·접속부·기능 형상을 새로 설계했다. [출처·표시 크기·검증](../qa/reports/part_art_2026-10-09.md). 실제 적용 완료, 사용자 확인 전이다.

**후속 생물 시안:** `monster_concept_20261009/foldrunner_v1.png`·`rainpouch_v1.png`를 개발 전투에 연결했다. 승인 주인공·처마등·배경 참조, 각1회 생성 후 원본 보존. [제작·전체 프롬프트](../../새-게임-프로젝트/assets/art/monster_concept_20261009/family-provenance.json), [3해상도·221검사](../qa/reports/residential_creatures_2026-10-09.md). 본편 미교체/새 두 시안 사용자 확인 전이다.

**몬스터 대표 시안:** `monster_concept_20261009/eavesback_v1.png`는 장갑 생물 ‘처마등’ 후보. 승인 주인공/배경 참조, 투명 가장자리 추가 편집1회, 개발 전투에서만 사용한다. [원본·출처](../../새-게임-프로젝트/assets/art/monster_concept_20261009/provenance.json), [실제 화면·163검사](../qa/reports/eavesback_concept_2026-10-09.md). 본편 대체/사용자 디자인 채택 전이다.

**탐사도 표식 본편 적용:** `map_chart_20261009/survey_symbols.png`의7종과 `survey_symbols_guard.png`의 기계 경비 표장을 본편·개발 지도와 범례에서 사용한다. 초기 뿔 가면은 제외했다. 사용자 채택 후 동일 자산을 통합했으며 이번에 재생성하지 않았다. [출처·프롬프트·해시](../../새-게임-프로젝트/assets/art/map_chart_20261009/provenance.json), [실제 화면·583검사](../qa/reports/map_chart_adoption_2026-10-09.md).

**지도 배경:** `map_residential_20261009/residential_shaft.png`를 모든 구역의 지도 가장자리에 사용하며 구역별 바탕색·색조를 다르게 한다. 지역별 신규 배경5장을 제작한 것은 아니다. 기존 `facilities.png`와 `facilities_v2.png`는 비교 가능한 제작 이력으로 보존하고 현행 본편 기호로 사용하지 않는다.

2026-10-05. 현재 적용과 이전 제작 이력을 구분한다.

**몬스터 정체 재설계 예정:** 현재7종 PNG 중 두꺼비 외6종은 기계형 임시 외형이다. 색면 정리와 기존 반응 구현을 새 세계관 컨셉의 완료로 취급하지 않는다. [몬스터 설정 v0.5](monster-roster.md)의 낯선 생물·인간형 순수 기계/태엽 개성 논의를 먼저 진행한다. 전체 일반15종은 초기7역할을 포함해 사용자가 채택한 제작 규모이며, 개별 종과 새 자산은 미확정이다. 이번에는 PNG를 제작하거나 교체하지 않았다.

**주인공 동작 적용:** `actor_motion_20261005/reclaimer_actions_v1.png`의 조준·반동·재장전4키포즈를 본편에 연결했다. 내장 image_gen 생성 원본을 보존하고 자세별 발/총구 기준점은 Godot에서 정렬한다. [최종 파일·프롬프트·출처](../../새-게임-프로젝트/assets/art/actor_motion_20261005/provenance.json), [실제 화면·검증](../qa/reports/actor_motion_2026-10-05.md). 대기는 확정 v2 원본을 유지한다. 적에는 기존 그림을 활용한 보조 움직임만 추가했다.

**후속 적 v2:** 현재7종의 잔선/반사광을 주인공 v2와 같은 색면 중심 표현으로 정리해 본편·샘플·증원 미리보기에 적용했다. [전후 화면·출처·검증](../qa/reports/enemy_mass_v2_2026-10-05.md).

**현재 본편:** 주거구 배경 `tower_sample_20261003/residential_tower.png`, 수정 주인공과 압력두꺼비/기존 적 6종 `actor_cohesion_20261005/`를 사용한다. 후속 증원 아이콘도 새 적 그림과 연결했다. [전체 자산·프롬프트·해시](../../새-게임-프로젝트/assets/art/actor_cohesion_20261005/provenance.json), [실제 화면·350검사](../qa/reports/actor_cohesion_2026-10-05.md). 아래 미적용/샘플 전용 문구는 해당 제작 시점의 기록이다.

2026-10-03 전투 샘플 제작: C+B 캐릭터와 주거구 배경을 원본 그대로 `assets/art/tower_sample_20261003/`에 복사하고 별도 `redesign/samples/tower_battle.tscn`에서 실제 카드·예측·발사와 함께 표시했다. [샘플 화면·검사·실행 경로](../qa/reports/tower_art_sample_2026-10-03.md). 기본 캠페인의 임시 아트는 유지하며 새 선택 자산은 이 샘플에만 적용됐다. 아래 개별 시안의 미적용 표시는 제작 당시 이력이다.

최신 캐릭터 조합 요청: [C 복장 + B 방한모 v2](../art/concepts/2026-10-03-character-variants/character-c-expedition-cap-v2.png). 사용자가 조합과 모자 색상 조정을 요청해 청회색 모자·적갈색 띠로 C의 긴 외투/붉은 어깨 덮개와 맞췄다. 입력 두 장과 결과를 시각 확인하고 해시 일치로 복사를 검증했다. 프롬프트는 같은 폴더의 provenance-c-expedition-cap-v2.json에 기록했으며 게임 적용 전의 시안이다.

추가 비교 요청으로 [주인공 후보 A/B/C](../art/concepts/2026-10-03-character-variants/README.md)를 제작했다. 작업모·짧은 재킷, 방한모·탐험복, 각진 헬멧·긴 외투로 머리와 몸의 실루엣을 나눴다. 기존 헬멧 v2를 입력으로 내장 image_gen을 사용했고 프롬프트·출처·해시는 후보 폴더에 보존했다. 새 후보는 사용자 검토 전이며 기존 시작 외형 채택을 자동으로 바꾸지 않는다. 실제 게임에는 미적용이다.

최신 채택 상태: 사용자가 헬멧 캐릭터 v2를 시작 외형으로 확정했다. 아래 제작 당시의 검토 전 상태는 생성 이력이다. 후속 복장/헬멧 수집 요청과 분리 제작 계획은 [외형 설계](appearance.md)를 따른다. 실제 게임 교체와 수집 기능은 아직 미구현이다.

후속 피드백: 사용자가 레퍼런스 시안의 도트풍을 긍정적으로 확인하고 주인공의 헬멧/모자를 요청했다. [헬멧 수정안 v2](../art/concepts/2026-10-03-pixel-reference/character-reference-v2-helmet.png)를 별도 제작했다. 청록색 정비용 헬멧·짧은 챙·황토색 띠·작은 점검등을 더했고 기존 도트 표현과 복장·자세를 유지했다. 원본/사본 해시를 확인하고 [프롬프트와 출처](../art/concepts/2026-10-03-pixel-reference/provenance-helmet-v2.json)를 남겼다. 화풍 확인과 헬멧 최종 디자인 확정은 구분하며 런타임에는 적용하지 않았다.

사용자 요청으로 [캐릭터·배경 레퍼런스 시안 각 1장](../art/concepts/2026-10-03-pixel-reference/README.md)을 제작했다. 내장 image_gen으로 생성 후 사용자 원본을 참조해 큰 도트 색면으로 수정했다. 캐릭터 PNG 1254×1254(알파 포함), 배경 PNG 1672×941이며 원본 해시·전체 프롬프트·수정 입력은 해당 폴더의 provenance.json에 있다. **검토용 컨셉이며 사용자 확정/런타임 교체/엄격한 픽셀 격자 검수는 아직 아니다.**

사용자 제공 시각 레퍼런스 10개는 [별도 레퍼런스 폴더](../art/references/2026-10-03-user/README.md)에 원본 파일명과 바이트를 유지해 복사했다. 캐릭터 5개·배경 5개이며 [해시/크기](../art/references/2026-10-03-user/manifest.json)를 기록했다. 전 이미지를 직접 검토했고 [비교 보드](../art/references/2026-10-03-user/reference-board.html)와 [도트 제작 방향](pixel-style.md)에 연결했다. 런타임 자산이나 새로 제작한 시안으로 집계하지 않는다.

2026-10-03 초기 전투 자산은 `assets/art/pixel_20261003/`였다. 주인공/적의 본편 표시는 위 수정 자산으로 전환했고 이전 파일은 보존한다. 회수자 1종·적 6종·공업 지대 배경 1종을 PixelLab Pixen으로 제작해 실제 전투에 적용했다. [생성 요청과 출처](../../새-게임-프로젝트/assets/art/pixel_20261003/provenance.json), [투명도·팔레트·해시·발 기준점 검사](../../새-게임-프로젝트/assets/art/pixel_20261003/asset_report.json)를 함께 보존한다. 탄환 7종의 구별 가능한 실루엣과 금속 바닥은 `redesign/pixel_art.gd`에서 픽셀 도형으로 그린다.

아래 표는 이전 일러스트 자산이다. 원본은 보존하며 메인·지도·상점·배너에는 아직 사용한다. 전투의 회수자·배경·여섯 적 표현은 위 도트 자산으로 교체했다.

| 자산 | 출처·제작 | 실제 적용 |
| --- | --- | --- |
| `art/director_20261002/transit_platform.png` | 내장 이미지 생성, 2172×724 | 첫 구역 전투·타이틀·화면 배너 |
| `art/production_20261002/reclaimer.png` | 내장 이미지 생성, 투명 RGBA 1024×1536 | 타이틀 및 실제 전장 회수자 |
| `art/production_20261002/workshop.png` | 내장 이미지 생성, 2172×724 | 상점·보급 작업대 |
| `art/production_20261002/city_overview.png` | 내장 이미지 생성, 1536×1024 | 도시 지도 배경 |
| `foundry`, `maintenance`, `administration`, `summit` | 내장 이미지 생성, 각 2172×724 | 나머지 네 구역의 실제 전투·배너 |
| `redesign/weapon_view.gd` | 엔진 네이티브 기하 도형 | 다섯 무기별 약실·총열·실루엣 |
| `redesign/enemy_art.gd` | 엔진 네이티브 기하 도형 | 여섯 적 역할의 기계 실루엣·분절 관절 |
| `redesign/part_card_view.gd` | 엔진 네이티브 기하 도형 | 장치 기호와 다섯 장착 카드, 이득·대가 |
| `assets/fonts/NotoSansKR.ttf` | Google Fonts의 Noto Sans KR, SIL OFL 1.1 | 공통 한글 글꼴 번들, `ui_font.tres` weight=500 |

새 자산의 정확한 프롬프트·원본 경로·해시·크기는 [provenance.json](../../새-게임-프로젝트/assets/art/production_20261002/provenance.json)에 기록했다. 내장 `image_gen.imagegen`을 사용했으며 외부 레퍼런스 이미지는 넣지 않았다. 생성 원본을 보존하고 프로젝트에 복사했다.

글꼴은 [Google Fonts 원본](https://github.com/google/fonts/tree/main/ofl/notosanskr)에서 받았고 [라이선스 원문](../../새-게임-프로젝트/assets/fonts/NotoSansKR-OFL.txt)을 포함한다. 운영체제 글꼴을 복사하지 않는다. 동작·줄바꿈은 실제 렌더로 재검증한다.

## 배경 생성 프롬프트

도구: 내장 `image_gen.imagegen`. 생성 원본을 보존하고 프로젝트로 복사했다. 다른 게임의 이미지·상표를 참조 입력으로 제공하지 않았다.

```text
Use case: stylized-concept. Asset type: production background texture for a 2D tactical ammunition-combo roguelike named Last on Board, to be consumed in a Godot side-view battle and title. Create one ultra-wide 3:1 panoramic illustration, 1536x512 or nearest supported wide format. Art direction: refined industrial graphic novel, large flat cut-paper shapes, dark ink navy structures, warm desaturated oxidized copper, ivory highlights, a few amber industrial lights; restrained screenprint grain, beautifully designed independent video game world, confident architectural forms, NOT a software dashboard. Scene: interior transit platform of a colossal vertical mechanical city. Side-on horizontal walkway at the lower fifth, giant elevator door and articulated steel rib silhouettes on far right, distant layered machinery and tiny light windows, a quiet maintenance alcove on left. Strong depth through 3 flat value planes. Composition: generous low-detail dark negative space in central 70% for live game enemies and readable UI; silhouettes frame the edges. No characters, no monsters, no guns, no cards, no UI, no numerals, no words, no lettering, no logos, no watermark. Avoid photorealism, neon cyberpunk clutter, gradients, dense pixel noise, bright busy foreground. This is a polished reusable environmental game asset, not a mockup screenshot.
```

## 제작 경계

메뉴·지도·상점의 이전 일러스트와 새 전투 도트 표현이 전환 중 공존한다. 전투는 단일 포즈와 반동·이동·타격 연출이며 프레임별 보행 애니메이션 세트는 아니다. 지역별 도트 배경, 전용 보스 원화, 음악과 효과음, 실제 Android 성능·터치 검수는 후속 품질 작업이다.

[전체 경험 검증 보고서](../qa/reports/full_experience_2026-10-02.md)에 실제 렌더와 검사 범위를 남긴다.


## 등반 장비실 제작 자산

- `assets/art/equipment_20261011/workshop_v1.png`: 탑 내부 정비실, 기존 주거구역의 청회색/황색 조명 참고.
- `outfits_v1.png`: 기본/운반/정찰3종 착용 미리보기. 투명 아틀라스 원본 보존, Godot 영역 분리와 alpha0.5 컷오프로 가장자리 정리. 전투 동작에는 아직 미적용.
- 생성 도구·전체 프롬프트·교정·참고 파일: 같은 폴더 `provenance.json`. 외부 게임 그림 복사 없음.
- `equipment_screen.tscn` / `equipment_weapon.tscn`: 에디터에서 시각 계층·기본 선택·그림 확인 가능. 런타임은 데이터/선택/화면 크기를 바인딩한다.


## 총기 원화5종

### 현행 캐릭터 C안·장비 선택 공유 — 2026-10-25

`hero_contours_20261025/work_pistol.png`는 사용자가 채택한 C안 그대로, `work_long.png`는 같은 윤곽 기준을 기존 양손6자세에 적용한 image_gen 편집본이다. [전체 프롬프트·원본·해시](../../새-게임-프로젝트/assets/art/hero_contours_20261025/provenance.json). 장비 선택은 `equipment_actor.gd`에서 본편 `weapon_actor.tscn`을 그대로 사용하며, 전투 몸체·재질·총·손 합성을 공유한다. 선택용 별도 초상화는 현행 표시에서 제외했다. 기존 특수4복장 몸체는 유지한다. [화면·검증](../qa/reports/hero_contour_live_2026-10-25.md).

`assets/art/weapons_20261011/`의 `single/burst/scatter/heavy/amplifier_v1.png`를 장비실의 큰 그림·선택 목록에 공유한다. 승인 주인공의 색면/재료를 참고한 built-in image_gen 원화이며 각 전체 프롬프트·해시·범위는 `provenance.json`에 있다. PNG는 수정 없이 보존하고 각 `.tres`의 영역과 기존 alpha0.5 셰이더로 여백/가장자리를 처리한다. 이전 장비 그림의 SubViewport6개를 TextureRect로 대체했다. [검수·캡처](../qa/reports/weapon_art_2026-10-11.md).

### 장소 실내 3종 적용
`assets/art/service_locations_20261011/{shop,supply,workshop}_v1.png`: 가판대 대화/보급함 수령/등 보이는 작업대 장면. 원본·참조 해시와 built-in image_gen 전체 프롬프트는 같은 폴더 provenance.json. Godot 실제 통합 검수 완료, 사용자 선호는 후속 확인. [검증](../qa/reports/service_locations_2026-10-11.md).

### 공통 실내 v2 — 외부 풍경 제거
사용자 승인 실내 구도를 유지하고 `service_locations_20261011/{shop,supply,workshop}_v2.png`로 교체. 창밖 탑·하늘을 닫힌 철문/셔터/벽으로 바꿔 모든 지역에 공통 사용. v1은 제작 기록으로 보존. 프롬프트·입출력 해시는 `indoor_v2_provenance.json`. 인물은 여전히 기본 복장이 포함된 통합 PNG이고 복장 교체는 미구현. [복장 가능성 검토](appearance.md).

### 장소 분리 리소스 적용
현행은 service_layers_20261011의 빈 실내3 + 투명 work 인물3. 이전 v1/v2 통합 PNG는 기록 보존용. 프로필.tres와 catalog로 outfit/place 조회, 미제작 복장은 work 대체. 작업대 손 잔존 수정 포함. [자산·검수517/0](../qa/reports/service_layers_2026-10-11.md).

## 복장 작업실 — 2026-10-11
- assets/art/outfit_preview_20261011/: 네 복장 시안 복사본과 채택 원정복의 권총·장총 각각6자세, 장소3자세 신규 원본. 전체 프롬프트·참조·해시는 provenance.json.
- 전용 outfit_preview.tscn에서만 원정복 전투/장소 배우를 사용한다. 본편 복장 카탈로그와 저장에는 미연결.
- 원정복 v3는 사용자 채택, 신규 동작/화면은 사용자 확인 전. 다른3종은 시안만 존재.
- [검증·차이·실행 경로](../qa/reports/outfit_preview_2026-10-11.md).


## 무기5종 본편·배우 화풍 통합

`weapon_redesign_20261024`의 리벳/래칫/리액터/스파이크 원화와 스플린터v4를 본편에 연결했다. 원본은보존하며 공통 등록/표시를 통해 전투와 장비의 밀도를 조정했다. 신규 생성은 스플린터 색 수정1장이고, 다른 배우는 표시 격자/그림자 처리 조정이다. [전체 프롬프트·해시](../../새-게임-프로젝트/assets/art/weapon_redesign_20261024/splinter_v4_provenance.json) · [실제 화면과 범위](../qa/reports/art_cohesion_2026-10-24.md).
