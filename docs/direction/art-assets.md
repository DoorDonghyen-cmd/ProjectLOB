# 아트 자산과 적용 상태

2026-10-03. 이 목록은 완성된 원화와 실행 화면에 적용한 범위를 구분한다.

전투 샘플 제작: C+B 캐릭터와 주거구 배경을 원본 그대로 `assets/art/tower_sample_20261003/`에 복사하고 별도 `redesign/samples/tower_battle.tscn`에서 실제 카드·예측·발사와 함께 표시했다. [샘플 화면·검사·실행 경로](../qa/reports/tower_art_sample_2026-10-03.md). 기본 캠페인의 임시 아트는 유지하며 새 선택 자산은 이 샘플에만 적용됐다. 아래 개별 시안의 미적용 표시는 제작 당시 이력이다.

최신 캐릭터 조합 요청: [C 복장 + B 방한모 v2](../art/concepts/2026-10-03-character-variants/character-c-expedition-cap-v2.png). 사용자가 조합과 모자 색상 조정을 요청해 청회색 모자·적갈색 띠로 C의 긴 외투/붉은 어깨 덮개와 맞췄다. 입력 두 장과 결과를 시각 확인하고 해시 일치로 복사를 검증했다. 프롬프트는 같은 폴더의 provenance-c-expedition-cap-v2.json에 기록했으며 게임 적용 전의 시안이다.

추가 비교 요청으로 [주인공 후보 A/B/C](../art/concepts/2026-10-03-character-variants/README.md)를 제작했다. 작업모·짧은 재킷, 방한모·탐험복, 각진 헬멧·긴 외투로 머리와 몸의 실루엣을 나눴다. 기존 헬멧 v2를 입력으로 내장 image_gen을 사용했고 프롬프트·출처·해시는 후보 폴더에 보존했다. 새 후보는 사용자 검토 전이며 기존 시작 외형 채택을 자동으로 바꾸지 않는다. 실제 게임에는 미적용이다.

최신 채택 상태: 사용자가 헬멧 캐릭터 v2를 시작 외형으로 확정했다. 아래 제작 당시의 검토 전 상태는 생성 이력이다. 후속 복장/헬멧 수집 요청과 분리 제작 계획은 [외형 설계](appearance.md)를 따른다. 실제 게임 교체와 수집 기능은 아직 미구현이다.

후속 피드백: 사용자가 레퍼런스 시안의 도트풍을 긍정적으로 확인하고 주인공의 헬멧/모자를 요청했다. [헬멧 수정안 v2](../art/concepts/2026-10-03-pixel-reference/character-reference-v2-helmet.png)를 별도 제작했다. 청록색 정비용 헬멧·짧은 챙·황토색 띠·작은 점검등을 더했고 기존 도트 표현과 복장·자세를 유지했다. 원본/사본 해시를 확인하고 [프롬프트와 출처](../art/concepts/2026-10-03-pixel-reference/provenance-helmet-v2.json)를 남겼다. 화풍 확인과 헬멧 최종 디자인 확정은 구분하며 런타임에는 적용하지 않았다.

사용자 요청으로 [캐릭터·배경 레퍼런스 시안 각 1장](../art/concepts/2026-10-03-pixel-reference/README.md)을 제작했다. 내장 image_gen으로 생성 후 사용자 원본을 참조해 큰 도트 색면으로 수정했다. 캐릭터 PNG 1254×1254(알파 포함), 배경 PNG 1672×941이며 원본 해시·전체 프롬프트·수정 입력은 해당 폴더의 provenance.json에 있다. **검토용 컨셉이며 사용자 확정/런타임 교체/엄격한 픽셀 격자 검수는 아직 아니다.**

사용자 제공 시각 레퍼런스 10개는 [별도 레퍼런스 폴더](../art/references/2026-10-03-user/README.md)에 원본 파일명과 바이트를 유지해 복사했다. 캐릭터 5개·배경 5개이며 [해시/크기](../art/references/2026-10-03-user/manifest.json)를 기록했다. 전 이미지를 직접 검토했고 [비교 보드](../art/references/2026-10-03-user/reference-board.html)와 [도트 제작 방향](pixel-style.md)에 연결했다. 런타임 자산이나 새로 제작한 시안으로 집계하지 않는다.

현재 전투 자산은 `assets/art/pixel_20261003/`이다. 회수자 1종·적 6종·공업 지대 배경 1종을 PixelLab Pixen으로 제작해 실제 전투에 적용했다. [생성 요청과 출처](../../새-게임-프로젝트/assets/art/pixel_20261003/provenance.json), [투명도·팔레트·해시·발 기준점 검사](../../새-게임-프로젝트/assets/art/pixel_20261003/asset_report.json)를 함께 보존한다. 탄환 7종의 구별 가능한 실루엣과 금속 바닥은 `redesign/pixel_art.gd`에서 픽셀 도형으로 그린다.

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
