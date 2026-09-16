# 최신 다섯 무기 Galaxy APK — 2026-09-16

사용자 모바일 테스트 요청으로 최신 도시 등반 개편판을 Android APK로 생성했다. 게임 소스는 이전 Windows 다섯 무기 버전과 동일하며 패키징 스크립트·설치 안내·기록을 추가했다.

- 파일: [LastOnBoard-city.apk](../builds/city-android/LastOnBoard-city.apk)
- 버전: 0.3.20260916, code20260916
- 패키지: `com.lastonboard.prototype`, 앱 `Last on Board Test`
- 소스: `524e30365dbc53fff4be1618bbc0eda1becace42`, 깨끗한 작업 트리에서 생성
- 크기: 81,474,840바이트 (약81.5MB)
- SHA-256: `692FB0E716F094251AD10ED86480B8380654968400C4D0E46946514D2A52F1F3`

보행자/쇄도/산개/압쇄/증강, 5계층35층 맵·상점·이벤트·성장과 별도7교전 훈련을 포함한다. 기존 APK는 비교용으로 보존했다. 기존 최근 chain APK와 새 APK의 인증서 SHA-256이 같아 동일 앱 업데이트에 사용할 수 있다. 정상 업데이트는 앱 내부 데이터를 유지하며 PC 저장과는 별개다.

Godot4.7, 설치된Java17/Android SDK36.1.0으로 QA APPDATA에서 내보냈다. apksigner 서명 검증, zipalign4-byte/16KiB 정렬, aapt 패키지·버전·ARM64/ARMv7·minSDK24·targetSDK36·화면방향11(user landscape)을 확인했다. 인터넷/외부저장소 권한이 없다. export_presets.cfg는 원래 없는 상태로 복원했다.

ZIP CRC 전체 검사와 main.tscn remap의 실제 바이너리 씬, 최신 전투·도시 스크립트, ARM 라이브러리 존재와 QA 스크립트 제외를 확인했다. APK에서 꺼낸 compiled 리소스를 격리 폴더에서 PC Godot로 직접 로드해5종 로스터·Modelv4·탄창·기본 피해·연쇄/단발·실제 명령을 확인했다. 이는 Android 기기 실행이 아니며 Galaxy 성능·발열·터치감은 사용자 테스트에서 확인한다.

패키지 검사 원본: [city_android_2026-09-16.json](qa/reports/city_android_2026-09-16.json). [설치 안내](android_install_city_2026-09-16.md). 재생성: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_city_android.ps1`.

초기 ZIP 검사에서 main.tscn이 그대로 들어간다고 가정한 검사식을 실제 .tscn.remap/바이너리 씬 경로로 고쳐 다시 검사했다. APK와 게임에는 결함이 없었다. exporter의 방향 명세는 실제 Android manifest값11로 기록하도록 바로잡았다. 로컬 커밋만 수행했다.
