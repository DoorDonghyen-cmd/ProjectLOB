# 아트 자산과 적용 상태

**정예·보스 원화 — 2026-10-18 본편 적용:** `elite_boss_20261018/resonant_eavesback_states.png`와 `closure_watch_states.png`를 편성5 주거구에 연결했다. 각각 대기/공명·닫힘/열림2상태, 기존 큰 색면 참조를 실제 이미지 입력으로 사용했다. 생성 PNG는 그대로 보존하고 Godot 영역/발 기준점/nearest/기존 알파 컷아웃으로 표시한다. 상태·피격·사망의 절차형 동작 포함, 모든 프레임을 그린 애니메이션은 아니다. 제작자 실제 화면 검수 완료, 사용자 미감/Galaxy는 후속. [프롬프트·출처·해시](../art/concepts/elite-boss-20261018/provenance.json) · [전투 화면](../qa/reports/elite_boss_2026-10-18.md).

**탄환 공용 아트 — 2026-10-18 후속:** 기존6종 v4와 새 `ammo_recast_20261018/special_rounds_v1.png` 12종을 공용 렌더에 연결. 현재 획득17가족 + 기존 연계탄을 같은 무광 큰 색면으로 표시한다. 예약/차단의 이전 보유물은 기존 그림 유지. 보상·상점·가방·압축도 같은 원화 사용. 생성 원본 그대로, Godot 영역 등록/nearest 렌더. [생성 기록·해시](../art/concepts/ammo-recast-20261018/provenance.json) · [실제 화면](../qa/reports/ammo_collection_2026-10-18.md). 아래 전투만 적용/나머지 기존 그림 내용은 이전 단계다.

**탄환6종 v4 원화 — 본편 전투 적용(2026-10-18):** `ammo_recast_20261017/cartridges_v4.png`를 손패·발사 레일·장전 이동·손패 상세에 연결했다. 기본/철갑/연타/증폭/냉각/전격과 해당 변형에 사용하며, 나머지 가족은 기존 그림을 보존한다. 상점/보상/가방 그림은 기존 공용 카드 유지. 사용자 승인으로 본편 적용, 실제 사용자 미감 확인은 후속. [출처](../art/concepts/ammo-recast-20261017/provenance-v4.json) · [화면·범위](../qa/reports/combat_hand_live_2026-10-18.md).


**쇄도 표시 해상도 후속:** 신규 원화 없이 `burst_v4.png`를 유지하고 무기만 낮은 해상도 레이어로 합성한다. 캐릭터와 앞손은 기존 렌더, 총구·재장전 등록도 유지. 다른4총기에는 적용하지 않았다. [이전/이후·실제 전투](../qa/reports/weapon_density_2026-10-14.md). 사용자 체감 확인 전이다.

**쇄도 굵은 외곽선 비교 v4:** `weapons_mass_20261013/burst_v4.png`만 본편 쇄도에 적용했다. 사용자 요청에 따라 바깥 도트 경계를 굵게 하고 내부 선은 적게 유지했다. 나머지4총기는 v3. [전후·프롬프트·검증](../qa/reports/burst_contour_2026-10-14.md). 사용자 미감 확인 전 비교안이다.

**전투 총기 표현 v3:** 다섯 총의 검은 내부 경계·밝은 테두리·잔선을 덜고 캐릭터의 큰 색면에 맞췄다. `weapons_mass_20261013/*_v3.png`를 공용 `weapon_actor.gd`에서 사용한다. 장비 선택용 원화 유지. [전후·검증·생성 기록](../qa/reports/weapon_mass_2026-10-13.md). 제작자 시각 검수 완료, 사용자 체감은 후속. v2는 중간 후보다.

**신규 복장 본편 4종:** `outfits_live_20261013`의 방열복·인양·회수 15개 PNG와 기존 `outfit_preview_20261011` 원정복5개를 `outfit_art.gd`/`service_actor_catalog.gd`에서 공유한다. 선택·전투·실내·복장 작업실에 적용. [생성 프롬프트·참조·해시](../../새-게임-프로젝트/assets/art/outfits_live_20261013/provenance.json) · [화면·검증](../qa/reports/outfits_live_2026-10-13.md). 인양 대기 팔은 재생성v2 사용, 새 자산 원본 알파 보존. 기존 scout/carrier 별도 전투·실내 원화는 후속.


**첫 구역 높이별 전투 배경:** 기존 `tower_sample_20261003/residential_tower.png` + `residential_ascent_20261011/middle_v1.png`, `upper_v1.png`. 후속2종은 기존 승인 배경을 참조한 내장 image_gen 원본이며 후처리 없이 발판 높이를 등록했다. [화면/검증/전체 프롬프트](../qa/reports/ascent_background_2026-10-11.md). 다른 구역 전용3종은 아직 제작 전이다.

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
