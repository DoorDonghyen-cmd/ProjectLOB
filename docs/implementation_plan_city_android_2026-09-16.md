# 최신 도시 개편판 Galaxy APK — 2026-09-16

사용자가 모바일 플레이테스트용 APK 생성을 요청했다. 최신 다섯 무기 게임 소스에 패키징만 적용한다.

- 최신 `res://redesign/main.tscn`, 다섯 무기, 5계층35층 도시 등반/별도7교전 훈련.
- 기존 비교 APK 보존, `builds/city-android/LastOnBoard-city.apk`에 생성.
- 기존 `com.lastonboard.prototype`과 동일 로컬 debug certificate, ARM64/ARMv7, 가로 GL Compatibility.
- 버전code20260916/name0.3.20260916, 인터넷/외부 저장소 권한 없음.
- QA APPDATA에서 Android export, 원래 export_presets.cfg의 존재/바이트 복원.
- apksigner 서명, zipalign4-byte/16KiB, aapt 패키지·버전·ABI·화면방향·리소스 검사, 기존 APK 인증서 비교.
- 설치 안내/manifest/QA·워크스루/중앙 로그·히스토리/로컬 커밋으로 완료.
- 실제 Galaxy 설치·성능은 사용자의 테스트에서 확인한다.
