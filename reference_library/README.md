# LoB 외부 제작 자료 보관소

사용자 요청으로 확보한 고정 버전 원본이다. 현재 기획의 원본은 `docs/direction/`이며, 외부 저장소의 지침 파일은 LoB 작업 지침으로 채택하지 않는다.

원본과 ZIP은 `cache/`에 있고, 버전·해시·전체 파일 목록·라이선스 사본·검토 결과는 별도로 보존한다. 자료를 받은 것, Godot에서 로드한 것, 본편에 통합한 것은 서로 다르다. 이번 확보로 활성화한 본편 플러그인은 없다.

확보: **12개 저장소 / 5,445개 파일 / 추출 원본 82.9 MiB**. 공식 예제 ZIP에는 추출 대상 외 원본도 포함된다.

| 자료 | 고정 버전 | 우선순위 | 활용과 진입점 | 확인 상태 |
|---|---|---|---|---|
| [card-skeleton](https://github.com/pudgypoultry/card-game-skeleton) | `b12123f60734` | A | 속성 검색·카드 비교·덱 제작 UI 구조를 현행 Content에 연결하는 제작 도구에 참고. [원본 열기](<cache/card-skeleton/b12123f607346cd24f27fa5e33f71ad207c02769/source/addons/CardGameSkeleton/CardLibrary/CardLibrary.gd>) | 독립 설치에 icon.svg/CardImages/CardBack.jpg 등 샘플 경로 의존. 즉시 플러그인 도입 대신 구조 활용 |
| [godot-demos](https://github.com/godotengine/godot-demo-projects) | `6ad6167e0577` | A | 4.7 릴리스 고정. GUI·2D·오디오 예제 추출; 전체 원본 ZIP도 보관. [원본 열기](<cache/godot-demos/6ad6167e0577fe3622c18546138f456b107ce93c/source/gui/control_gallery>) | control_gallery·drag_and_drop·accessibility·multiple_resolutions 확보; 각 예제 실행 미검증 |
| [pixel-ui](https://github.com/Spyridon-Pikoulas/godot-pixel-ui-fantasy-free) | `1b321ac44c8e` | A | 전체 위젯 상태·테마 구성 참고. 양피지 외형과 라틴 글꼴은 미채택. [원본 열기](<cache/pixel-ui/1b321ac44c8e55f89ba9aeae92f7b4feff5c2df1/source/addons/pixel_ui_fantasy/themes/parchment.tres>) | Godot 4.7 로드 및 주요6위젯 테마 존재 확인 통과 |
| [slay-robot](https://github.com/DesirePathGames/Slay-The-Robot) | `4dac5abe0d19` | A | 액션·조건·콘텐츠 묶음·도감. 포함된 스크롤·사운드 관리 애드온도 확보. [원본 열기](<cache/slay-robot/4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d/source/scripts/actions/BaseAction.gd>) | 주요 구조 읽기 완료; 전체 프레임워크 실행 검증 없음 |
| [vfx-library](https://github.com/haowg/GODOT-VFX-LIBRARY) | `6e8fc84ef426` | A | 장갑·증기·전격 외 추가 효과의 연출 재료. 적절한 도트 크기와 실제 이벤트에 맞춰 선별. [원본 열기](<cache/vfx-library/6e8fc84ef426f82f747cd540823e1d5e1fdc563a/source/addons/vfx_library/effects>) | 관련3씬 읽기; LoB 자체 표현에 참고 완료. 전체 플러그인 실행 미검증 |
| [awesome-godot](https://github.com/godotengine/awesome-godot) | `9aa855ff849a` | B | 오픈소스 게임·도구 추가 탐색 색인. 연결 저장소 전체를 일괄 설치하지 않음. [원본 열기](<cache/awesome-godot/9aa855ff849a1d7eb398b66329ab479974053af6/source/README.md>) | 목록 확보 |
| [awesome-pixel-art](https://github.com/Siilwyn/awesome-pixel-art) | `720818e85240` | B | 클러스터·색·동작 제작 자료 색인. 링크된 외부 자료 전체를 확보한 것은 아님. [원본 열기](<cache/awesome-pixel-art/720818e85240dea3c42c98fcde530ffcb3fb3a25/source/readme.md>) | 목록 확보 |
| [importality](https://github.com/nklbdev/godot-4-importality) | `532715c16788` | B | 후속 프레임 애니메이션과 태그 기반 가져오기 후보. 현재 LibreSprite 제작 경로 유지. [원본 열기](<cache/importality/532715c16788ac3d720879947f145d94379a619e/source/addons/nklbdev.importality/editor_plugin.gd>) | 4.7 플러그인 로드 중 파싱 오류 없음; 종료 시19 ObjectDB/8 resource 정리 경고. 실제 다중 프레임 가져오기 미검증 |
| [open-rpg](https://github.com/gdquest-demos/godot-open-rpg) | `19bd328fae9e` | B | 전투/메뉴 전환·대화·인벤토리 구조. 포함된 음원은 별도 출처와 함께 후보로 보관. [원본 열기](<cache/open-rpg/19bd328fae9e4b534d3bb6db380a3d871d6ea58f/source/combat>) | 4.6.2 안내 프로젝트; 4.7 전체 실행 미검증 |
| [pixelorama](https://github.com/Orama-Interactive/Pixelorama) | `e205f47699f4` | B | 편집기 전체 소스·팔레트·타임라인·내보내기 참고. 현재 LibreSprite와 선택적으로 비교. [원본 열기](<cache/pixelorama/e205f47699f424244a7ddc738bac2e0ca42769c1/source/src>) | 1.2.4-dev 소스 확보. 실행 파일 설치·빌드 안 함 |
| [palette-swap](https://github.com/idbrii/godot-colorful-palette-swap) | `e2fcc36339b0` | C | 팔레트 맵핑 개념만 검토. 원본 복사·게임 배포 대상 제외. [원본 열기](<cache/palette-swap/e2fcc36339b023f0a9d01cf625e5cc75cf0ae90a/source/addons/colorful-palette-swap/code/palette_swap.shader>) | Godot 3 config_version=4. 4.7 직접 호환 아님 |
| [smooth-pixel](https://github.com/apples/godot-smooth-pixel-subviewport-container) | `b49fdf5985d3` | C | 실제 카메라 스크롤이 필요해질 때 비교. 현행 전장 전체에 즉시 적용하지 않음. [원본 열기](<cache/smooth-pixel/b49fdf5985d341a582989c462705f3a904b38a8c/source/addons/smooth_pixel_subviewport_container>) | 소스 확보, 현재 렌더러/캔버스 조합 실행 미검증 |

## 라이선스와 원본 보존

| 자료 | 확인 범위 |
|---|---|
| awesome-godot | CC BY 4.0 list; linked projects have independent terms [원문1](<notices/awesome-godot/LICENSE.md>) |
| awesome-pixel-art | CC0 list; linked resources have independent terms [원문1](<notices/awesome-pixel-art/license.md>) |
| card-skeleton | MIT root LICENSE recovered at pinned revision; sample card images have separate external credit, not cleared for game reuse [원문1](<notices/card-skeleton/addons/CardGameSkeleton/Credits.txt>) · [원문2](<notices/card-skeleton/LICENSE>) |
| godot-demos | MIT plus embedded font/asset notices preserved [원문1](<notices/godot-demos/2d/dodge_the_creeps/LICENSE>) · [원문2](<notices/godot-demos/2d/dodge_the_creeps/fonts/LICENSE.txt>) · [원문3](<notices/godot-demos/3d/squash_the_creeps/fonts/LICENSE.txt>) · [원문4](<notices/godot-demos/3d/truck_town/town/lamp/license.txt>) · [원문5](<notices/godot-demos/3d/truck_town/town/tree/license.txt>) · [원문6](<notices/godot-demos/LICENSE.md>) · [원문7](<notices/godot-demos/gui/bidi_and_font_features/LICENSE.LinLibertine.txt>) · [원문8](<notices/godot-demos/gui/bidi_and_font_features/LICENSE.Noto.txt>) · [원문9](<notices/godot-demos/gui/translation/fonts/LICENSE.DroidSans.txt>) · [원문10](<notices/godot-demos/gui/ui_mirroring/LICENSE.Noto.txt>) · [원문11](<notices/godot-demos/loading/runtime_save_load/examples/fonts/LICENSE.txt>) · [원문12](<notices/godot-demos/mono/dodge_the_creeps/fonts/LICENSE.txt>) · [원문13](<notices/godot-demos/mono/squash_the_creeps/fonts/LICENSE.txt>) |
| importality | MIT LICENSE preserved [원문1](<notices/importality/LICENSE>) |
| open-rpg | MIT code, CREDITS.md and nested asset notices preserved [원문1](<notices/open-rpg/CREDITS.md>) · [원문2](<notices/open-rpg/LICENSE>) · [원문3](<notices/open-rpg/addons/dialogic/Example Assets/Fonts/LICENSE.txt>) · [원문4](<notices/open-rpg/addons/dialogic/Example Assets/sound-effects/LICENSE.txt>) |
| palette-swap | No explicit license file found in pinned snapshot; API unspecified. Do not copy into production.  |
| pixel-ui | CC BY 4.0 confirmed in addons/pixel_ui_fantasy/LICENSE.txt; credit required for reuse [원문1](<notices/pixel-ui/addons/pixel_ui_fantasy/LICENSE.txt>) |
| pixelorama | MIT top level; nested dependency licenses also preserved [원문1](<notices/pixelorama/LICENSE>) · [원문2](<notices/pixelorama/addons/aimg_io/COPYING.txt>) · [원문3](<notices/pixelorama/addons/dockable_container/LICENSE>) · [원문4](<notices/pixelorama/addons/gdgifexporter/LICENSE>) · [원문5](<notices/pixelorama/addons/gdgifexporter/gif-lzw/LICENSE>) · [원문6](<notices/pixelorama/installer/LICENSE>) · [원문7](<notices/pixelorama/installer/utils/LICENSE>) · [원문8](<notices/pixelorama/src/Preferences/LicenseProperties.gd>) · [원문9](<notices/pixelorama/src/Preferences/LicenseProperties.gd.uid>) |
| slay-robot | MIT code plus bundled addon licenses preserved; asset reuse requires per-file check [원문1](<notices/slay-robot/LICENSE>) · [원문2](<notices/slay-robot/addons/label_font_auto_sizer/LICENSE>) · [원문3](<notices/slay-robot/addons/smooth_scroll_container/LICENSE>) · [원문4](<notices/slay-robot/addons/sound_manager/LICENSE>) |
| smooth-pixel | MIT addon LICENSE.txt preserved [원문1](<notices/smooth-pixel/addons/smooth_pixel_subviewport_container/LICENSE.txt>) |
| vfx-library | MIT LICENSE preserved [원문1](<notices/vfx-library/LICENSE>) |

## 다시 확보 / 오프라인 검사

저장소 루트에서:

```powershell
python tools/acquire_reference_sources.py
python tools/acquire_reference_sources.py --verify
python tools/check_reference_candidates.py
python tools/build_reference_index.py
```

기본 확보 명령은 이미 기록된 커밋과 해시를 유지하며 누락된 캐시만 같은 버전에서 복구한다. 임의로 최신 버전으로 갱신하지 않는다. `--verify`는 네트워크 없이 모든 원본·ZIP·라이선스 사본의 해시를 대조한다.

대용량 캐시는 Git 추적에서 제외되어 있다. 다른 컴퓨터에서는 추적되는 lock·도구로 같은 자료를 다시 확보한다. 샘플 코드를 게임으로 옮길 때는 필요한 파일과 해당 저작권 고지를 함께 추적하고, 출처·수정 범위를 기록한다.

[개발 적용 순서](../docs/direction/external-adoption.md) · [버전/해시](sources.lock.json) · [판단 원본](review.json)
