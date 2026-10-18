# GitHub 자료 확보와 첫 적용 검증

사용자 요청 범위: 기존에 논의한 GitHub 자료에서 활용 후보를 우선 충분히 확보하고 게임 개발에 활용.

## 확보·무결성

- **12개 저장소 / 5,445개 추출 파일**, 각 커밋/원본 ZIP SHA-256/파일별 SHA-256/라이선스 사본을 보존. [목록과 진입점](../../../reference_library/README.md).
- `python tools/acquire_reference_sources.py --verify`: 네트워크 없이 소스·아카이브·복사한 저작권 고지를 대조. 결과 `REFERENCE VERIFY PASS sources=12 files=5445`.
- `python tools/build_reference_index.py`: 색인에 기록한 모든 로컬 진입점이 실제 존재함을 확인.
- 카드 도구 ZIP에 없는 LICENSE/README는 같은 커밋에서 보충했다. 원본 복구 시에도 보충 파일을 받도록 기록했다.
- 원본은 `reference_library/cache/`에 실제 저장되어 있다. Git 추적 대상은 lock·파일 목록·라이선스·판단·확보/검사 도구다. 본편 export 대상 폴더 밖에 보관한다.

## 별도 후보 실행 시험

`python tools/check_reference_candidates.py`는 QA 전용 폴더에 후보를 복사하고 APPDATA/LOCALAPPDATA를 분리한다. 본편 플러그인을 켜거나 사용자 설정을 바꾸지 않는다.

| 후보 | 관찰 결과 | 해석 |
|---|---|---|
| Pixel UI Fantasy | 편집기 import 및 Button/OptionButton/HSlider/VScrollBar/TabContainer/PopupMenu 테마 로드 통과 | 테마 구성 참고 가능. 화풍/한글 검증이나 본편 외형 채택 아님 |
| Importality0.3.0 | 파싱 오류 없음. 종료 시 ObjectDB19개/리소스8개 정리 경고 | 로드는 됐으나 깨끗한 종료 통과 아님. 실제 프레임 가져오기 미검증 |
| Card Game Skeleton | icon.svg/CardImages/CardBack.jpg 등 샘플 경로 누락으로 오류 | 애드온만 복사해 즉시 사용할 수 있는 상태 아님. 구조를 현행 Content에 맞춰 활용 |

[시험 결과 JSON](reference_acquisition_2026-10-11_assets/candidates.json). 나머지 후보는 소스/권리/버전 확보이며 전체 실행 검증을 하지 않았다. Colorful Palette Swap은 Godot3 형식·명시 라이선스 부재로 게임 코드 복사 대상에서 제외했다.

## 첫 게임 적용과 검증

외부 테마의 전체 위젯 구성에서 착안해 기존 LoB 버튼/팔레트를 드롭다운·선택 목록·토글·스크롤바·도움말에 연결했다. 자체 코드와 기존 자체 리소스를 사용하며 외부 테마/그림 복사나 게임 수치 변경은 없다.

- `run_console_visual_checks.ps1`: **75검사 / 0실패**,1008×630·1280×800.
- 실제 Godot 렌더링: 메인·무기·설정·상점·파츠·맵. 설정 선택/토글의 연결, 정확한 구매 비용·중복 구매 차단·파츠 교체를 검사했다. 이 러너는 주로 신호/속성으로 조작하므로 실제 터치 입력 검증과 구별한다.
- 작은 화면의 설정 선택 목록·파츠 교체 화면을 직접 열어 글자와 새 조작부를 확인했다. 설정창의 기존 회색 외곽과 일반 글꼴 등은 후속 마감 대상이다. 전체 UI가 완료되었다고 주장하지 않는다.
- 스크립트 오류 없음. 편집기 import의 기존 Android build-tools 경고는 데스크톱 검사와 별개이며 APK는 요청하지 않아 생성하지 않았다.

[설정 선택 목록](reference_acquisition_2026-10-11_assets/settings_options_1008.png) · [파츠 화면](reference_acquisition_2026-10-11_assets/parts_1008.png) · [UI 로그](reference_acquisition_2026-10-11_assets/ui_stdout.log)

다음 개발 범위와 도입 조건은 [외부 자료 적용 순서](../../direction/external-adoption.md)에 구분했다.
