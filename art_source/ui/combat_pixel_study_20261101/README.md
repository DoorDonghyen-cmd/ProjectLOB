# Combat pixel study — 2026-11-01

사용자가 검토한 제안을 실제 게임 캡처 위에서 비교하는 **정지 목업**이다. 기획 원본은 [전투 HUD](../../../docs/direction/combat-hud.md), 결과와 한계는 [검수 보고서](../../../docs/qa/reports/combat_pixel_study_2026-11-01.md)에 둔다.

- 제작: LibreSprite 1.3의 네이티브 이미지 픽셀 API. `draw.js`가 UI 프레임·탄환·글리프를 정수 좌표에 그린다. 모든 래스터 출력/축소/정수 확대는 LibreSprite가 수행한다. Python은 상태·폰트·색 읽기, 텍스트/JSON 작성, 도구 호출과 읽기 전용 검증만 수행한다.
- 크기: 640×400 원본 / 1280×800 정수 2배 표시. 이번 비교안의 값이며 프로젝트 해상도 확정이 아니다.
- 배경 입력: `captures/*_source.png`, 현재 게임의 별도 QA 저장에서 캡처한 5상태. `capture_states.gd`는 실제 전투 명령과 화면 값의 수집 원본이다. 원래 캡처를 1/2로 줄인 전장과 적 정보는 그대로 사용했다.
- 팔레트: `palette.json`. 전장에서 읽은 17색과 텍스트/위험 판독용 파생 2색. 각 표본 좌표를 보존했다. 전체 배경을 19색으로 바꿨다는 뜻은 아니다.
- 폰트: Galmuri11 / Galmuri9 BDF의 원래 비트맵을 1배로 사용. 텍스트 안티앨리어싱 없음. [Galmuri](https://github.com/quiple/galmuri), 고정 커밋 `71e1cacf1437a11220307120e63e30bc275312d4`. `fonts/OFL.md`와 폰트 원본을 함께 보존한다. 게임의 현재 폰트를 교체하거나 시스템에 설치하지 않았다.
- 상태: `states.json`은 실제 모델의 잔탄·발열·예측·버튼 문구와 선택 값을 보존한다. `layout-metrics.json`은 그 값으로 그린 칸과 글자 경계다. 빼내기 배열은 이후 전투 초기화로 바뀌지 않도록 수집 시 복제했다.
- 결과: [PNG / ASE](../../../docs/art/combat-pixel-study-20261101/). ASE는 픽셀을 편집할 수 있는 **한 레이어**의 원본이다. 부품별 레이어나 런타임 9-slice는 아직 분리하지 않았다. 코드 기반 재제작은 `draw.js`에서 한다.
- 증거: `verification.json`에 원본/출력/폰트 SHA-256과 검증 결과가 있다.

활성 저장소 루트에서 재생성:

```powershell
python -X utf8 art_source/ui/combat_pixel_study_20261101/build.py
python -X utf8 art_source/ui/combat_pixel_study_20261101/verify.py
```

로컬 LibreSprite와 Pillow, NumPy를 사용한다. `qa_runtime/pixel_study_20261101`에 새 수집 결과가 있으면 준비 단계에서 보존 캡처를 갱신한다. 없으면 이 폴더에 보존된 캡처/상태로 재생성한다. 게임에 넣을 때에는 글자·수치·상호작용을 Godot 노드로 분리해야 한다.
