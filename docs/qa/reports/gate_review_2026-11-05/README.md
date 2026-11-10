# 구역 관문 Godot 시안

왼쪽에서 현재 구역의 차단문과 다음 목적지를 확인한다. 오른쪽 조작부는 무료 개조, 유료 재정비, 출발 순으로 전환된다. 개조와 수납 확장은 적용 전후를 같은 위치에 표시하고, 출발을 누르면 차단문이 열려 이어지는 통로가 보인다.

## 실행

`OPEN_GATE_REVIEW.cmd -Classic`으로 이 분할 화면 시안을 실행한다. F1은 개조 처음부터, F2는 개조한 상태에서 재정비부터 시작한다. 기본 실행은 [문 옆 출발을 적용한 시안](../gate_threshold_2026-11-05/README.md)이다.

- **개조.** 적용 전후 수치와 조건을 읽고 하나를 적용한다. 전용 탄약 생산은 견본을 선택한 뒤 교체할 기본탄 3장을 고른다. 보류도 한 번 확인한다.
- **재정비.** 적용한 개조를 확인하고 수납 확장 또는 보유 탄 복제에 유료 정비 1회를 쓸 수 있다.
- **출발.** 유료 정비 여부와 관계없이 출발할 수 있다. 차단문이 열린 뒤 다음 구역으로 이동한 상태가 표시된다.

| 장면 | PC 1280×800 | 작은 가로 창 1008×454 | S26 가로 크기 2340×1080 |
| --- | --- | --- | --- |
| 무료 개조 | [화면](upgrade_1280x800.png) | [화면](upgrade_1008x454.png) | [화면](upgrade_2340x1080.png) |
| 유료 재정비 | [화면](service_1280x800.png) | [화면](service_1008x454.png) | [화면](service_2340x1080.png) |
| 차단문 개방 | [화면](depart_1280x800.png) | [화면](depart_1008x454.png) | [화면](depart_2340x1080.png) |
| 전용 탄약 생산 | [화면](production_1280x800.png) | | |

## 레퍼런스

- 《Dishonored 2》의 시계태엽 저택에서 조작이 공간 자체의 변화로 드러나는 방식을 참고했다. 관문에서는 출발 명령에 맞춰 차단문이 열린다. [Bethesda의 미션 소개](https://bethesda.net/en-US/news/dishonored-2-inside-the-epic-themed-missions)
- 《Dome Keeper》에서 교전 사이의 짧은 준비를 별도 구간으로 다루는 점을 참고했다. 개조와 유료 재정비를 한 화면에 동시에 펼치지 않고 차례로 보여 준다. [Raw Fury 소개](https://rawfury.com/announcing-dome-keeper/)
- 기존 조사에서 《Slay the Spire》의 개조 전후 비교, 《Moonlighter》의 장소와 작업 연결을 가져왔다. [기존 관문 레퍼런스](../../../art/references/2026-11-04-ui/README.md#관문)

## 검증

Godot 4.7에서 `OPEN_GATE_REVIEW.cmd -Capture -Classic` 검사 102개를 통과했다. 세 해상도의 화면 경계, 실제 개조·정비 비용과 공유 횟수 제한, 기본탄 3장 교체, 보류 취소, 차단문 개방과 다음 구역 전환을 확인했다. S26 해상도는 PC에서 실행했다.

시안은 실제 보스 노드의 승리 상태를 재현한 뒤 Campaign의 관문 규칙을 사용한다. 선택은 시안 세션에만 적용된다. 본편 진입과 자동 저장, 재정비 중 빌드 화면 연결, S26 실기는 후속 검증 범위다.

## 관문 배경 제작 기록

내장 ImageGen을 사용해 [차단문 배경](../../../../새-게임-프로젝트/assets/art/gate_review_20261105/airlock.png)을 만들었다. 축열 주조장 상층 배경을 픽셀 화풍 참고로 사용했고, 움직이는 문짝은 Godot에서 따로 그렸다.

> Design one original game environment raster for ORVASK, for the left portrait half of a landscape Godot UI. Use supplied image solely as reference for the project's pixel-cluster style, machinery scale and color family; depict a new location. Portrait 4:5 composition. Frame an industrial district boundary inside an ancient vertical factory: a single massive and perfectly front-facing RECTANGULAR freight airlock, centered horizontally; its opening is clearly visible and empty, x about 29% to 71%, y about 25% to 73%. Inside that open rectangular opening an amber-lit metal corridor with distance, iron stair or catwalk extending into an immense vertical shaft. The sides of the opening are dark rigid frames with square rivets and horizontal steel ribs. Hard edges and broad readable silhouettes. One metal foreground floor at 75% of image height and moody partial framing by pipes. Top-left 22% somewhat quiet and dark for later title placement. Predominantly dusty brown-black gunmetal, muted slate, rusty ochre and lamp-lit amber at threshold. Very little teal. Strong depth conveyed by 5-7 hand-placed tonal levels. Authentic low-res pixel art, 1 common chunky grid, no dither blanket, no smooth gradient gloss, no realistic photography, no haze over edges. No text, lettering, signs, numerals, buttons, game UI, border, people, enemies, crates or decorative chips. The gate frame and the open central void are the focal point. Image fills canvas edge to edge.
