# 현장 압축 드래그 Galaxy APK — 2026-09-20

사용자 모바일 플레이테스트 요청으로 관문 압축탄, 전투당 1회 현장 압축, 개별 탄환 카드와 직접 드래그 합성을 포함한 Android APK를 생성했다.

- 파일: [LastOnBoard-city.apk](../builds/city-android/LastOnBoard-city.apk)
- 버전: `0.4.20260920`, code `20260920`
- 패키지: `com.lastonboard.prototype` · 앱 이름 `Last on Board Test`
- 소스 기준 커밋: `7e2e6aa98ed4fb70486602dab8f13e5528544050` + 현장 압축 작업 트리
- 크기: `81,499,947`바이트
- SHA-256: `B94BC5496878280155B71DB5C75CE277C06515AD05BE3333D704EF557E6A4A8D`

이전 APK와 같은 로컬 테스트 인증서를 사용하고 버전 코드를 올렸다. 기존 앱을 삭제하지 않고 업데이트 설치하면 앱 저장을 유지할 수 있다. ARM64와 ARMv7, minSDK24, targetSDK36, 화면 방향11(user landscape)을 확인했으며 앱 요청 권한은 없다.

`apksigner` v2/v3 서명, `zipalign` 4바이트·16KiB 정렬, ZIP 638항목 CRC, 패키지·버전·ABI를 검사했다. APK에서 538개 Godot 에셋을 별도로 추출해 테스트 파일 0개와 `ammo_hand_button.gdc` 포함을 확인했다. 추출한 컴파일 리소스를 PC Godot에서 직접 불러 모델 v6, 드래그 카드, 현장 압축, 실행 취소와 도시 메인 씬을 실행했다.

기능 소스는 빌드 전에 무기 규칙 3,190/0, 가독성 30,247/0, 현장 압축 밸런스 264/0, 기존 전체 회귀 3,730/0, 실제 터치 도시 UI 2,667/0을 통과했다. Android 기기에서의 실행 성능·발열·실제 손가락 드래그 감각은 이번 APK로 사용자가 확인한다.

[설치 안내](android_install_city_2026-09-20.md) · [패키지 검사 기록](qa/reports/city_android_2026-09-20.json)
