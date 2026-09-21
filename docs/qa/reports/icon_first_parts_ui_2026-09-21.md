# 아이콘 중심 파츠·성장 선택 UI QA

## 판정

**PASS** — 파츠, 압축 코어, 관문 성장 선택이 절차형 도형 카드로 렌더되며 기존 구매·장착·분해·상세·관문 입력 계약을 유지한다.

## 자동 검증

- 실행: Godot 4.7 stable, OpenGL Compatibility 실제 렌더러.
- 결과: `CITY UI COMPLETE checks=1659 failures=0 buttons=528`.
- 캠페인: 보행자 35층 UI 재생 완주.
- 해상도: 1280×800, 1008×630.
- 추가 고정 조건:
  - 무기고의 압축 코어가 그래픽 상태 카드로 존재한다.
  - 파츠 상세창이 상점 카드와 같은 시각 언어를 쓴다.
  - 구매한 파츠가 장착 카드로 다시 나타난다.
  - 관문 3택이 서로 다른 그래픽 카드를 쓴다.
  - 개발자 파츠 갤러리에 4종이 모두 렌더된다.

원본 실행 로그와 전체 캡처는 `qa_runtime/city/ui_ui_parts_icon4/`에 있다.

## 대표 화면

- [상점 1280×800](icon_first_parts_ui_2026-09-21_assets/city_debug_shop.png)
- [상점 1008×630](icon_first_parts_ui_2026-09-21_assets/city_phone_shop.png)
- [파츠 4종 갤러리](icon_first_parts_ui_2026-09-21_assets/part_icon_gallery.png)
- [파츠 상세](icon_first_parts_ui_2026-09-21_assets/city_part_detail.png)
- [구매 후 장착 상태](icon_first_parts_ui_2026-09-21_assets/city_shop_equipped_part.png)
- [관문 3택](icon_first_parts_ui_2026-09-21_assets/city_debug_gate.png)

## 시각 검수

- 파츠 4종은 색을 빼고 보아도 총열, 회전 링, 탄창, 코일 외곽으로 구분된다.
- 상점의 긴 파츠 설명은 기본 목록에서 사라지고 핵심 수치가 가장 크게 보인다.
- 상점의 `맵으로 계속`은 작은 화면에서도 파츠 보관 영역보다 위에 있어 스크롤 없이 접근 가능하다.
- 코어와 관문은 문장형 버튼 대신 상태와 변화 전후를 도형으로 보여 준다.
- 전체 문장은 상세창과 툴팁에 남아 정보 손실이 없다.
